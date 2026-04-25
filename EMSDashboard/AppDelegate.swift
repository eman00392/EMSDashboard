import UIKit
import CarPlay
import GoogleMaps

// In application(_:didFinishLaunchingWithOptions:)
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - App Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("🟢 [AppDelegate] didFinishLaunching")
        GMSServices.provideAPIKey("AIzaSyA11vd0wsPQBOZxNY1KiSI15cuFMEhFwUU")
        // Start Socket.IO
        EMSSocketManager.shared.connect()

        // Request notification permission and set delegate
        // NotificationManager sets itself as UNUserNotificationCenterDelegate
        NotificationManager.shared.requestPermission()

        // Register for remote push (APNs)
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {

        let role = connectingSceneSession.role.rawValue
        print("🟢 [AppDelegate] configurationForConnecting — role: \(role)")

        if connectingSceneSession.role == UISceneSession.Role.carTemplateApplication {
            print("🟢 [AppDelegate] → Routing to CarPlaySceneDelegate")
            let config = UISceneConfiguration(
                name: "CarPlay Configuration",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }

        print("🟢 [AppDelegate] → Routing to SceneDelegate")
        let config = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}

    // MARK: - APNs

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APNs token: \(token)")

        guard let url = URL(string: "http://www.embtech.llc:3030/register-device") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])
        URLSession.shared.dataTask(with: request).resume()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs failed: \(error.localizedDescription)")
    }
}
