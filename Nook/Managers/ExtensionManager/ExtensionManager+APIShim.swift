// Licensed under GPL-3.0. See LICENSE.
//
//  ExtensionManager+APIShim.swift
//  Nook
//
//  Stand-ins for Chrome extension APIs WebKit does not implement, loaded ahead of an
//  extension's background code
//

import Foundation
import os

extension ExtensionManager {

    static let apiShimFile = "nook_api_shim.js"
    static let serviceWorkerEntryFile = "nook_sw_entry.js"

    /// WebKit's extension engine has no `notifications`, `idle`, `management`, `privacy` or
    /// `downloads` namespace. A Chrome extension that touches one while its background starts
    /// throws, and its worker never runs: 1Password's Chrome build dies on
    /// `chrome.notifications.onClicked`, so its popup spins forever and it never opens the
    /// native messaging port to the desktop app, then on `webNavigation.onCreatedNavigationTarget`.
    /// The shim fills in only what is missing (whole namespaces, and single events inside the
    /// namespaces WebKit does have), with inert events and methods that answer both callback
    /// and promise callers.
    static let apiShim = """
    // Nook: Chrome API shim for WebKit extension backgrounds
    (function () {
        if (typeof browser === 'undefined' && typeof chrome === 'undefined') return;

        function event() {
            var listeners = [];
            return {
                addListener: function (f) { if (listeners.indexOf(f) < 0) listeners.push(f); },
                removeListener: function (f) { var i = listeners.indexOf(f); if (i >= 0) listeners.splice(i, 1); },
                hasListener: function (f) { return listeners.indexOf(f) >= 0; },
                hasListeners: function () { return listeners.length > 0; }
            };
        }

        function method(value) {
            return function () {
                var args = Array.prototype.slice.call(arguments);
                var callback = typeof args[args.length - 1] === 'function' ? args.pop() : null;
                var result = typeof value === 'function' ? value.apply(null, args) : value;
                if (callback) { setTimeout(function () { callback(result); }, 0); return; }
                return Promise.resolve(result);
            };
        }

        function setting(value) {
            return {
                get: method({ value: value, levelOfControl: 'not_controllable' }),
                set: method(undefined),
                clear: method(undefined),
                onChange: event()
            };
        }

        // Any setting name answers, so an extension reading one this list never heard of still works.
        function settingGroup() {
            var cache = {};
            return new Proxy({}, {
                get: function (_, name) {
                    if (typeof name !== 'string') return undefined;
                    return cache[name] || (cache[name] = setting(false));
                }
            });
        }

        var notificationCount = 0;
        var shims = {
            notifications: function () {
                return {
                    create: method(function (id) {
                        return typeof id === 'string' && id ? id : 'nook-notification-' + (++notificationCount);
                    }),
                    update: method(false),
                    clear: method(false),
                    getAll: method({}),
                    getPermissionLevel: method('denied'),
                    onClicked: event(),
                    onButtonClicked: event(),
                    onClosed: event(),
                    onShowSettings: event(),
                    onPermissionLevelChanged: event()
                };
            },
            idle: function () {
                return {
                    queryState: method('active'),
                    setDetectionInterval: method(undefined),
                    getAutoLockDelay: method(0),
                    onStateChanged: event()
                };
            },
            management: function (root) {
                function self() {
                    var manifest = {};
                    try { manifest = root.runtime.getManifest(); } catch (_) {}
                    return {
                        id: root.runtime && root.runtime.id,
                        name: manifest.name,
                        shortName: manifest.short_name || manifest.name,
                        version: manifest.version,
                        enabled: true,
                        mayDisable: true,
                        installType: 'normal',
                        type: 'extension',
                        offlineEnabled: false
                    };
                }
                return {
                    getSelf: method(self),
                    get: method(function (id) { var me = self(); return id === me.id ? me : undefined; }),
                    getAll: method(function () { return [self()]; }),
                    onInstalled: event(),
                    onUninstalled: event(),
                    onEnabled: event(),
                    onDisabled: event()
                };
            },
            privacy: function () {
                return { services: settingGroup(), network: settingGroup(), websites: settingGroup() };
            },
            downloads: function () {
                return {
                    download: method(undefined),
                    search: method([]),
                    pause: method(undefined),
                    resume: method(undefined),
                    cancel: method(undefined),
                    erase: method([]),
                    open: method(undefined),
                    show: method(undefined),
                    showDefaultFolder: method(undefined),
                    onCreated: event(),
                    onChanged: event(),
                    onErased: event(),
                    onDeterminingFilename: event()
                };
            }
        };

        // Chrome events missing from namespaces WebKit does implement.
        var events = {
            runtime: ['onSuspend', 'onSuspendCanceled', 'onMessageExternal', 'onConnectExternal', 'onUpdateAvailable', 'onRestartRequired'],
            tabs: ['onReplaced', 'onAttached', 'onDetached', 'onHighlighted', 'onZoomChange'],
            windows: ['onBoundsChanged'],
            webNavigation: ['onCreatedNavigationTarget', 'onHistoryStateUpdated', 'onReferenceFragmentUpdated', 'onTabReplaced'],
            webRequest: ['onBeforeRedirect', 'onAuthRequired', 'onResponseStarted', 'onErrorOccurred', 'onCompleted', 'onSendHeaders', 'onBeforeSendHeaders']
        };

        // Members missing from namespaces WebKit does implement, beyond plain events.
        var members = {
            // Policy storage an administrator fills; nothing manages a Nook profile.
            storage: {
                managed: function () {
                    return { get: method({}), getBytesInUse: method(0), onChanged: event() };
                }
            }
        };

        function missing(object, key) {
            var value;
            try { value = object[key]; } catch (_) {}
            return value === undefined || value === null;
        }

        function define(object, key, value) {
            try { Object.defineProperty(object, key, { value: value, configurable: true, writable: true }); } catch (_) {}
        }

        // Members of `extra` come from here; everything else reads through to the real object,
        // with methods bound to it so WebKit sees the receiver it expects.
        function passThrough(target, extra) {
            return new Proxy(target, {
                get: function (t, key) {
                    if (Object.prototype.hasOwnProperty.call(extra, key)) return extra[key];
                    var value = Reflect.get(t, key, t);
                    return typeof value === 'function' ? value.bind(t) : value;
                },
                has: function (t, key) {
                    return Object.prototype.hasOwnProperty.call(extra, key) || Reflect.has(t, key);
                }
            });
        }

        // WebKit rebuilds the namespace properties of `browser` on every read, so nothing added
        // to that object or to its namespaces sticks (a deleted and redefined `webNavigation`
        // still reads back as WebKit's). The globals themselves can be replaced, so `browser`
        // and `chrome` become proxies that supply the missing namespaces and events.
        var wrapped = [];
        ['browser', 'chrome'].forEach(function (globalName) {
            var root;
            try { root = globalThis[globalName]; } catch (_) {}
            if (!root) return;
            for (var i = 0; i < wrapped.length; i++) {
                if (wrapped[i].root === root) { define(globalThis, globalName, wrapped[i].proxy); return; }
            }
            var extra = {};
            Object.keys(shims).forEach(function (name) {
                if (missing(root, name)) extra[name] = shims[name](root);
            });
            Object.keys(events).forEach(function (name) {
                if (missing(root, name)) return;
                var namespace = root[name], stand = {};
                events[name].forEach(function (key) {
                    if (missing(namespace, key)) stand[key] = event();
                });
                if (Object.keys(stand).length) extra[name] = passThrough(namespace, stand);
            });
            Object.keys(members).forEach(function (name) {
                if (missing(root, name)) return;
                var namespace = root[name], stand = {};
                Object.keys(members[name]).forEach(function (key) {
                    if (missing(namespace, key)) stand[key] = members[name][key]();
                });
                if (Object.keys(stand).length) extra[name] = passThrough(namespace, stand);
            });
            var proxy = passThrough(root, extra);
            wrapped.push({ root: root, proxy: proxy });
            define(globalThis, globalName, proxy);
        });
    })();

    """

    /// Load `apiShim` ahead of the extension's own background code. Returns true when the
    /// manifest changed. Runs from `patchManifestForWebKit` at install and on every launch:
    /// the shim file is rewritten whenever a newer build changes it, and an extension update
    /// (which replaces the package) is wrapped again on its first load.
    ///
    /// - MV3 service worker: the manifest points at `nook_sw_entry.js`, which imports the shim
    ///   and then the original worker (`import` for module workers, `importScripts` otherwise).
    ///   Module imports evaluate in order, so the shim runs before any of the worker's code.
    /// - MV2 `background.scripts`: the shim is put first in the list.
    /// - `background.page` is left alone.
    static func installAPIShim(in manifest: inout [String: Any], packageDir: URL) -> Bool {
        guard var background = manifest["background"] as? [String: Any] else { return false }
        var changed = false

        if let worker = background["service_worker"] as? String {
            if worker != serviceWorkerEntryFile {
                let path = worker.hasPrefix("/") ? worker : "./" + worker
                let quoted = path.replacingOccurrences(of: "'", with: "\\'")
                let isModule = (background["type"] as? String) == "module"
                let entry = isModule
                    ? "// Nook: load the API shim, then the extension's worker\nimport './\(apiShimFile)';\nimport '\(quoted)';\n"
                    : "// Nook: load the API shim, then the extension's worker\nimportScripts('\(apiShimFile)', '\(quoted)');\n"
                do {
                    try entry.write(to: packageDir.appendingPathComponent(serviceWorkerEntryFile), atomically: true, encoding: .utf8)
                } catch {
                    logger.error("Could not write \(serviceWorkerEntryFile, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    return false
                }
                background["service_worker"] = serviceWorkerEntryFile
                changed = true
            }
        } else if var scripts = background["scripts"] as? [String] {
            if scripts.first != apiShimFile {
                scripts.removeAll { $0 == apiShimFile }
                scripts.insert(apiShimFile, at: 0)
                background["scripts"] = scripts
                changed = true
            }
        } else {
            return false
        }

        let shimURL = packageDir.appendingPathComponent(apiShimFile)
        if (try? String(contentsOf: shimURL, encoding: .utf8)) != apiShim {
            try? apiShim.write(to: shimURL, atomically: true, encoding: .utf8)
        }
        if changed {
            manifest["background"] = background
            logger.warning("Extension manifest modified: background loads \(apiShimFile, privacy: .public) first in \(packageDir.lastPathComponent, privacy: .public)")
        }
        return changed
    }
}
