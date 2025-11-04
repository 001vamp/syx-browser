import DataSource
import Observation
import WebKit

@MainActor @Observable public final class BrowserNavigation {
    private let appStateClient: AppStateClient
    let action: (Action) async -> Void
    // Closure to check if popup kill is enabled (called synchronously from decidePolicyFor)
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

    func decidePolicy(for request: URLRequest, navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        // Check if this is a popup (target="_blank" or new window)
        // targetFrame is nil when the link opens in a new window
        let isPopup = navigationAction.targetFrame == nil
        
        if isPopup {
            // This is a popup link - check if popup kill is enabled
            let shouldBlock = shouldBlockPopup?() ?? false
            if shouldBlock {
                // Block the popup and notify Browser to save the URL
                await action(.decidePolicyFor(request, isPopup: true))
                return .cancel
            }
        }
        
        // Not a popup, or popup kill is off - proceed normally
        await action(.decidePolicyFor(request, isPopup: false))
        for await value in appStateClient.withLock(\.actionPolicySubject.values) {
            return value
        }
        return .cancel
    }

    func didFailProvisionalNavigation(error: any Error) async {
        await action(.didFailProvisionalNavigation(error))
    }

    public enum Action: Sendable {
        case decidePolicyFor(URLRequest, isPopup: Bool)
        case didFailProvisionalNavigation(any Error)
    }
}

public final class BrowserNavigationDelegate: NSObject, WKNavigationDelegate, ObservableObject {
    private var store: BrowserNavigation

    init(store: BrowserNavigation) {
        self.store = store
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        preferences.preferredContentMode = .mobile
        let actionPolicy = await store.decidePolicy(for: navigationAction.request, navigationAction: navigationAction)
        return (actionPolicy, preferences)
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        Task {
            await store.didFailProvisionalNavigation(error: error)
        }
    }
}
