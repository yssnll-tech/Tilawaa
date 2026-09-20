import SwiftUI
import UIKit

/// Gère l'écran externe (AirPlay, adaptateur HDMI ou écran compatible).
///
/// L'iPhone reste l'écran de contrôle. Quand iOS connecte un deuxième écran,
/// on lui donne sa propre fenêtre et une mise en page TV en 16:9.
@MainActor
final class ExternalDisplayManager: NSObject, ObservableObject {
    static let shared = ExternalDisplayManager()

    @Published private(set) var isConnected = false
    @Published private(set) var displaySize: CGSize = .zero

    private var externalWindow: UIWindow?

    private override init() {
        super.init()

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(screenDidConnect(_:)),
                           name: UIScreen.didConnectNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(screenDidDisconnect(_:)),
                           name: UIScreen.didDisconnectNotification,
                           object: nil)

        connectExistingScreen()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screenDidConnect(_ notification: Notification) {
        guard let screen = notification.object as? UIScreen else { return }
        showExternalWindow(on: screen)
    }

    @objc private func screenDidDisconnect(_ notification: Notification) {
        guard let screen = notification.object as? UIScreen,
              externalWindow?.screen === screen else { return }
        hideExternalWindow()
    }

    private func connectExistingScreen() {
        guard let screen = UIScreen.screens.first(where: { $0 !== UIScreen.main }) else {
            return
        }
        showExternalWindow(on: screen)
    }

    private func showExternalWindow(on screen: UIScreen) {
        externalWindow?.isHidden = true

        let controller = UIHostingController(
            rootView: ExternalDisplayView()
                .environmentObject(PlayerService.shared)
        )
        controller.view.backgroundColor = UIColor(Theme.night)

        let window = UIWindow(frame: screen.bounds)
        window.screen = screen
        window.rootViewController = controller
        window.backgroundColor = UIColor(Theme.night)
        window.isHidden = false

        externalWindow = window
        displaySize = screen.bounds.size
        isConnected = true
    }

    private func hideExternalWindow() {
        externalWindow?.isHidden = true
        externalWindow = nil
        displaySize = .zero
        isConnected = false
    }
}