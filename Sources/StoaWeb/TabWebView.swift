import SwiftUI
import WebKit
import StoaCore

/// Hosts one `WKWebView` for a `BrowserTab` and mirrors navigation state back onto the model.
public struct TabWebView: NSViewRepresentable {
    public let tab: BrowserTab
    public let profileID: UUID?
    public var ruleList: WKContentRuleList?
    public var onOpenNewTab: ((URL) -> Void)?

    public init(tab: BrowserTab, profileID: UUID?, ruleList: WKContentRuleList? = nil, onOpenNewTab: ((URL) -> Void)? = nil) {
        self.tab = tab
        self.profileID = profileID
        self.ruleList = ruleList
        self.onOpenNewTab = onOpenNewTab
    }

    public func makeCoordinator() -> Coordinator { Coordinator(tab: tab, onOpenNewTab: onOpenNewTab) }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = StoaWeb.makeConfiguration(profileID: profileID)
        if let ruleList { configuration.userContentController.add(ruleList) }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        context.coordinator.observe(webView)
        if let data = tab.serializedState {
            webView.interactionState = data
        } else if let url = tab.url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        // Navigation requests arrive through the coordinator; the model's url is the
        // committed location, so only load when the tab was pointed somewhere new.
        if let url = tab.url, context.coordinator.lastRequestedURL != url, webView.url != url {
            context.coordinator.lastRequestedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    public static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.tab.serializedState = webView.interactionState as? Data
        coordinator.stopObserving()
    }

    @MainActor
    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tab: BrowserTab
        let onOpenNewTab: ((URL) -> Void)?
        var lastRequestedURL: URL?
        private var observations: [NSKeyValueObservation] = []

        init(tab: BrowserTab, onOpenNewTab: ((URL) -> Void)?) {
            self.tab = tab
            self.onOpenNewTab = onOpenNewTab
            self.lastRequestedURL = tab.url
        }

        func observe(_ webView: WKWebView) {
            observations = [
                webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in self?.tab.title = wv.title ?? "" }
                },
                webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.tab.url = wv.url
                        self.lastRequestedURL = wv.url
                    }
                },
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in self?.tab.loadingProgress = wv.estimatedProgress }
                },
                webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in self?.tab.isLoading = wv.isLoading }
                },
                webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in self?.tab.canGoBack = wv.canGoBack }
                },
                webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                    Task { @MainActor in self?.tab.canGoForward = wv.canGoForward }
                },
            ]
        }

        func stopObserving() { observations.removeAll() }

        // MARK: WKNavigationDelegate

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            tab.lastActiveAt = .now
        }

        // MARK: WKUIDelegate

        /// target="_blank" and window.open become new tabs, never new windows.
        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url { onOpenNewTab?(url) }
            return nil
        }
    }
}
