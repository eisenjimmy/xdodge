import AVFoundation
import OSLog
import SwiftUI
import UIKit

@main
struct XdodgeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Self.configureAmbientAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .background(Color(uiColor: .xdodgeBackground))
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .defersSystemGestures(on: .all)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    GameCenterManager.shared.authenticate()
                }
        }
        .onChange(of: scenePhase) { phase in
            UIApplication.shared.isIdleTimerDisabled = phase == .active
        }
    }

    /// Ambient: mixes with other apps' audio and respects the silent switch.
    private static func configureAmbientAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            Logger.app.error("Audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension Logger {
    static let app = Logger(subsystem: "com.eisenjimmy.xdodge", category: "App")
    static let gameCenter = Logger(subsystem: "com.eisenjimmy.xdodge", category: "GameCenter")
}
