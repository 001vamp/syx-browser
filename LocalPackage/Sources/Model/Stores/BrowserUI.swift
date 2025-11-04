import DataSource
import Observation
import WebKit

@MainActor @Observable public final class BrowserUI {
    private let appStateClient: AppStateClient
    let action: (Action) async -> Void
    // Closure to check if popup kill is enabled (called synchronously from createWebView)
    @ObservationIgnored var shouldBlockPopup: (() -> Bool)?

    init(
        _ appDependencies: AppDependencies,
        action: @escaping (Action) async -> Void,
        shouldBlockPopup: (() -> Bool)? = nil
    ) {
        self.appStateClient = appDependencies.appStateClient
        self.action = action
        self.shouldBlockPopup = shouldBlockPopup
    }

    func runJavaScriptAlertPanel(with message: String) async {
        await action(.runJavaScriptAlertPanel(message))
        for await _ in appStateClient.withLock(\.alertResponseSubject.values) {
            return
        }
    }

    func runJavaScriptConfirmPanel(with message: String) async -> Bool {
        await action(.runJavaScriptConfirmPanel(message))
        for await value in appStateClient.withLock(\.confirmResponseSubject.values) {
            return value
        }
        return false
    }

    func runJavaScriptTextInputPanel(with prompt: String, defaultText: String?) async -> String? {
        await action(.runJavaScriptTextInputPanel(prompt, defaultText))
        for await value in appStateClient.withLock(\.promptResponseSubject.values) {
            return value
        }
        return nil
    }

    // This method is called when JavaScript tries to open a new window (window.open())
    // We check if popup kill is enabled and block the popup if needed
    func createWebView(with request: URLRequest) async -> WKWebView? {
        // Check if popup kill is enabled - if so, block the popup
        let shouldBlock = shouldBlockPopup?() ?? false
        if shouldBlock {
            // Notify Browser to save the blocked popup URL
            await action(.createWebView(request))
            // Return nil to prevent WebKit from creating a new webview
            return nil
        } else {
            // Popup kill is off, allow the popup by returning nil (WebKit will handle it)
            // For now, we'll notify Browser and let it load in current tab
            await action(.createWebView(request))
            return nil
        }
    }

    public enum Action: Sendable {
        case runJavaScriptAlertPanel(String)
        case runJavaScriptConfirmPanel(String)
        case runJavaScriptTextInputPanel(String, String?)
        case createWebView(URLRequest)
    }
}

public final class BrowserUIDelegate: NSObject, WKUIDelegate, ObservableObject {
    private var store: BrowserUI

    init(store: BrowserUI) {
        self.store = store
    }

    // Alert
    public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        await store.runJavaScriptAlertPanel(with: message)
    }

    // Confirm
    public func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async -> Bool {
        return await store.runJavaScriptConfirmPanel(with: message)
    }

    // Prompt
    public func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo
    ) async -> String? {
        await store.runJavaScriptTextInputPanel(with: prompt, defaultText: defaultText)
    }

    // Handle window.open() calls - this is where popups are created
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // This is called synchronously, so we use Task to handle async work
        Task {
            await store.createWebView(with: navigationAction.request)
        }
        // Return nil to prevent creating a new webview (popup is blocked)
        // The Browser store will handle loading the URL in current tab if popup kill is off
        return nil
    }
}
