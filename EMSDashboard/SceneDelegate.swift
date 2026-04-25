import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        print("🔵 [SceneDelegate] willConnectTo")
        guard let windowScene = scene as? UIWindowScene else { return }

        window = UIWindow(windowScene: windowScene)
        window?.makeKeyAndVisible()

        // Check if already logged in
        if AuthManager.shared.isLoggedIn {
            // Validate token is still accepted by server
            AuthManager.shared.validateToken { [weak self] valid in
                if valid {
                    self?.showDashboard()
                } else {
                    self?.showLogin()
                }
            }
        } else {
            showLogin()
        }

        // Listen for force logout from server
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForceLogout),
            name: .userForcedLogout,
            object: nil
        )
    }

    // MARK: - Show Login

    func showLogin() {
        DispatchQueue.main.async {
            let loginVC = LoginViewController()
            self.window?.rootViewController = UINavigationController(rootViewController: loginVC)
            if let window = self.window {
                UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: nil)
            }
        }
    }

    // MARK: - Show Dashboard

    func showDashboard() {
        DispatchQueue.main.async {
            let dashVC = MainDashboardViewController()
            let nav    = UINavigationController(rootViewController: dashVC)
            self.window?.rootViewController = nav
            if let window = self.window {
                UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: nil)
            }
        }
    }

    // MARK: - Force Logout

    @objc private func handleForceLogout() {
        AuthManager.shared.logout {
            self.showLogin()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        print("🔵 [SceneDelegate] sceneDidBecomeActive")
    }
}
