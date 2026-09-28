import Combine
import OSLog
import SwiftUI
import UIKit
import WebKit

struct GameView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController {
        GameViewController()
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}

final class GameViewController: UIViewController {
    private let bridge = GameBridge()
    private lazy var webView: WKWebView = self.makeWebView()
    private var cancellables: Set<AnyCancellable> = []

    // Honored when this controller is the root; under SwiftUI the equivalent modifiers are set in XdodgeApp.
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func loadView() {
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bridge.webView = webView
        observeGameCenterState()
        pauseGameWhenInterrupted()
        loadGame()
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        bridge.install(in: configuration.userContentController)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .xdodgeBackground
        webView.scrollView.backgroundColor = .xdodgeBackground
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        return webView
    }

    private func loadGame() {
        guard let gameURL = Bundle.main.url(forResource: "xdodge", withExtension: "html") else {
            Logger.app.fault("xdodge.html is missing from the app bundle")
            return
        }
        webView.loadFileURL(gameURL, allowingReadAccessTo: gameURL.deletingLastPathComponent())
    }

    private func observeGameCenterState() {
        GameCenterManager.shared.$playerState
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] state in self?.bridge.sendGameCenterState(state) }
            .store(in: &cancellables)
    }

    /// Backgrounding already fires `visibilitychange`; resign-active (Control Center, calls) and
    /// Game Center sheets do not, so the game gets a synthetic `blur`.
    private func pauseGameWhenInterrupted() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.bridge.pauseGame() }
            .store(in: &cancellables)
        GameCenterManager.shared.onWillPresentInterface = { [weak self] in self?.bridge.pauseGame() }
    }
}

extension GameViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        bridge.sendGameCenterState(GameCenterManager.shared.playerState)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        loadGame()
    }
}

extension UIColor {
    static var xdodgeBackground: UIColor {
        UIColor(named: "LaunchBackground") ?? UIColor(red: 13 / 255, green: 7 / 255, blue: 23 / 255, alpha: 1)
    }
}
