import OSLog
import UIKit
import WebKit

/// JS contract. JS -> native: `window.webkit.messageHandlers.xdodge.postMessage({type, ...})`.
/// Native -> JS: `xdodge-native` CustomEvent on `window`, latest Game Center state mirrored on `window.xdodgeNative.gc`.
@MainActor
final class GameBridge: NSObject, WKScriptMessageHandler {
    static let messageHandlerName = "xdodge"

    weak var webView: WKWebView?

    func install(in userContentController: WKUserContentController) {
        userContentController.addUserScript(Self.makeDocumentStartScript())
        userContentController.add(WeakScriptMessageHandler(target: self), name: Self.messageHandlerName)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        switch type {
        case "score": submitScore(body["value"])
        case "showLeaderboard": GameCenterManager.shared.showLeaderboard()
        case "haptic": playHaptic(body["style"] as? String ?? "")
        default: Logger.app.debug("Ignored bridge message type: \(type, privacy: .public)")
        }
    }

    func sendGameCenterState(_ state: GameCenterPlayerState) {
        let event = GameCenterEvent(ok: state.isAuthenticated, name: state.alias)
        guard let webView, let detail = Self.javaScriptLiteral(event) else { return }
        let script = "(function(d){if(window.xdodgeNative)window.xdodgeNative.gc=d;window.dispatchEvent(new CustomEvent('xdodge-native',{detail:d}))})(\(detail));"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// The game pauses itself on window `blur`.
    func pauseGame() {
        webView?.evaluateJavaScript("window.dispatchEvent(new Event('blur'));", completionHandler: nil)
    }

    private func submitScore(_ value: Any?) {
        guard let number = value as? NSNumber,
              let score = Int(exactly: number.doubleValue.rounded(.down)),
              score > 0 else { return }
        GameCenterManager.shared.submitScore(score)
    }

    private func playHaptic(_ style: String) {
        switch style {
        case "light": UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case "heavy": UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "error": UINotificationFeedbackGenerator().notificationOccurred(.error)
        default: break
        }
    }

    /// Runs before the page parses: exposes the native environment; the viewport and touch CSS duplicate the page's own as a safety net.
    private static func makeDocumentStartScript() -> WKUserScript {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let source = """
        (function () {
          var root = document.head || document.documentElement;
          var viewport = document.createElement('meta');
          viewport.name = 'viewport';
          viewport.content = 'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover';
          root.appendChild(viewport);
          var style = document.createElement('style');
          style.textContent = '*{-webkit-touch-callout:none;-webkit-user-select:none;user-select:none;-webkit-tap-highlight-color:transparent}';
          root.appendChild(style);
          window.xdodgeNative = {platform: 'ios', version: \(javaScriptLiteral(version) ?? "null")};
          if (navigator.audioSession) { try { navigator.audioSession.type = 'ambient'; } catch (e) {} }
        })();
        """
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// JSON-encodes a value so native strings (e.g. the player alias) never reach JS unescaped.
    private static func javaScriptLiteral<Value: Encodable>(_ value: Value) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private struct GameCenterEvent: Encodable {
    let type = "gc"
    let ok: Bool
    let name: String
}

/// WKUserContentController retains its handlers strongly; this breaks the cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
