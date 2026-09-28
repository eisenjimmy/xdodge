import Combine
import GameKit
import OSLog
import UIKit

enum GameCenterConfig {
    /// Must match the leaderboard ID created in App Store Connect (Game Center > Leaderboards).
    static let leaderboardID = "xdodge.highscore"
}

struct GameCenterPlayerState: Equatable {
    var isAuthenticated = false
    var alias = ""
}

/// Game Center is optional: when it is unavailable, signed out or not configured, the game keeps its on-device leaderboard.
@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    @Published private(set) var playerState = GameCenterPlayerState()
    var isAuthenticated: Bool { playerState.isAuthenticated }
    var alias: String { playerState.alias }
    var onWillPresentInterface: (() -> Void)?

    private var pendingAuthenticationViewController: UIViewController?
    private var hasStartedAuthentication = false

    private override init() {
        super.init()
    }

    func authenticate() {
        guard !hasStartedAuthentication else { return }
        hasStartedAuthentication = true
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            Task { @MainActor in
                GameCenterManager.shared.handleAuthenticationResult(viewController: viewController, error: error)
            }
        }
    }

    func submitScore(_ score: Int) {
        let player = GKLocalPlayer.local
        guard player.isAuthenticated, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: player, leaderboardIDs: [GameCenterConfig.leaderboardID]) { error in
            if let error {
                Logger.gameCenter.error("Score submission failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func showLeaderboard() {
        guard GKLocalPlayer.local.isAuthenticated else {
            presentPendingAuthentication()
            return
        }
        let leaderboard = GKGameCenterViewController(leaderboardID: GameCenterConfig.leaderboardID, playerScope: .global, timeScope: .allTime)
        leaderboard.gameCenterDelegate = self
        presentFromTopMostViewController(leaderboard)
    }

    private func handleAuthenticationResult(viewController: UIViewController?, error: Error?) {
        if let error {
            Logger.gameCenter.notice("Game Center unavailable: \(error.localizedDescription, privacy: .public)")
        }
        pendingAuthenticationViewController = viewController
        presentPendingAuthentication()
        let player = GKLocalPlayer.local
        playerState = GameCenterPlayerState(isAuthenticated: player.isAuthenticated, alias: player.isAuthenticated ? player.alias : "")
    }

    /// Kept pending if no window is ready yet; retried when the game asks for the leaderboard.
    private func presentPendingAuthentication() {
        guard let viewController = pendingAuthenticationViewController, viewController.presentingViewController == nil else { return }
        if presentFromTopMostViewController(viewController) {
            pendingAuthenticationViewController = nil
        }
    }

    @discardableResult
    private func presentFromTopMostViewController(_ viewController: UIViewController) -> Bool {
        guard let presenter = UIApplication.shared.topMostViewController else { return false }
        onWillPresentInterface?()
        presenter.present(viewController, animated: true)
        return true
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in
            gameCenterViewController.dismiss(animated: true)
        }
    }
}

private extension UIApplication {
    var topMostViewController: UIViewController? {
        let windowScenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = windowScenes.first { $0.activationState == .foregroundActive } ?? windowScenes.first
        var top = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
