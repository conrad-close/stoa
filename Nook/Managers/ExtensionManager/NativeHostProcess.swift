// Licensed under GPL-3.0. See LICENSE.
//
//  NativeHostProcess.swift
//  Nook
//
//  A native messaging host launched with posix_spawn, inside the browser's process group
//

import Darwin
import Foundation

/// Launches a native messaging host the way Chrome does: a direct child in the browser's own
/// process group, stdin and stdout on pipes, stderr to /dev/null, no other descriptors.
///
/// Foundation's `Process` puts every child in a new process group, and 1Password's
/// BrowserSupport refuses such a browser ("BrowserSupport was not part of the main browser's
/// tree", `BrowserVerificationFail`), so the extension's port closes before the first message.
final class NativeHostProcess {
    let executableURL: URL
    let arguments: [String]

    private(set) var processIdentifier: pid_t = 0
    /// Write end of the host's stdin. Valid after `run()`.
    private(set) var input: FileHandle!
    /// Read end of the host's stdout. Valid after `run()`.
    private(set) var output: FileHandle!

    /// Called once, on a background queue, when the host exits.
    var terminationHandler: (() -> Void)?

    private var exitSource: DispatchSourceProcess?
    private let lock = NSLock()
    private var exited = false

    init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return processIdentifier != 0 && !exited
    }

    func run() throws {
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, stdinPipe.fileHandleForReading.fileDescriptor, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stdoutPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // No POSIX_SPAWN_SETPGROUP: the host stays in our process group. Close every other
        // descriptor so the host inherits nothing but its three standard streams.
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))

        let argv: [UnsafeMutablePointer<CChar>?] = ([executableURL.path] + arguments).map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }

        var pid: pid_t = 0
        let status = posix_spawn(&pid, executableURL.path, &actions, &attributes, argv, environ)

        // The child has its own copies; keep only our ends.
        try? stdinPipe.fileHandleForReading.close()
        try? stdoutPipe.fileHandleForWriting.close()

        guard status == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(status))])
        }

        input = stdinPipe.fileHandleForWriting
        output = stdoutPipe.fileHandleForReading
        lock.lock()
        processIdentifier = pid
        lock.unlock()

        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in self?.reap() }
        exitSource = source
        source.resume()
        // A host that exits before the source is registered never fires it.
        reapIfExited()
    }

    func terminate() {
        lock.lock()
        let pid = processIdentifier
        let running = pid != 0 && !exited
        lock.unlock()
        if running { kill(pid, SIGTERM) }
    }

    private func reapIfExited() {
        var status: Int32 = 0
        if waitpid(processIdentifier, &status, WNOHANG) == processIdentifier {
            markExited()
        }
    }

    private func reap() {
        var status: Int32 = 0
        _ = waitpid(processIdentifier, &status, 0)
        markExited()
    }

    private func markExited() {
        lock.lock()
        let first = !exited
        exited = true
        lock.unlock()
        guard first else { return }
        exitSource?.cancel()
        let handler = terminationHandler
        terminationHandler = nil
        handler?()
    }
}
