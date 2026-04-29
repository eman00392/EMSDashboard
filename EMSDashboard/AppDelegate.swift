import UIKit
import CarPlay

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - App Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Start socket connection
        EMSSocketManager.shared.connect()

        // Request local notification permissions
        NotificationManager.shared.requestPermission()

        // Register for remote push notifications (APNs)
        // Required for calls to arrive when app is closed
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {

        if connectingSceneSession.role == UISceneSession.Role.carTemplateApplication {
            let config = UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - APNs Token Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("📱 APNs token: \(token)")
        UserDefaults.standard.set(token, forKey: "apns_device_token")

        // Register with server
        guard let url = URL(string: "\(AuthManager.shared.serverURL)/register-device") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["token": token])
        URLSession.shared.dataTask(with: req).resume()
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs failed: \(error.localizedDescription)")
    }

    // MARK: - Remote Notification Received
    // Called when a push arrives while app is in background OR closed.
    // The payload contains callData so we can update the UI without a socket.

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let callData = userInfo["callData"] as? [String: Any] else {
            completionHandler(.noData); return
        }

        let call = EMSCall(
            address:   callData["address"]   as? String ?? "",
            cross:     callData["cross"]     as? String ?? "",
            problem:   callData["problem"]   as? String ?? "",
            units:     callData["units"]     as? String ?? "",
            comments:  callData["comments"]  as? String ?? "",
            type:      callData["type"]      as? String ?? "",
            age:       callData["age"]       as? String ?? "",
            sex:       callData["sex"]       as? String ?? "",
            conscious: callData["conscious"] as? String ?? "",
            breathing: callData["breathing"] as? String ?? "",
            lat:       callData["lat"]       as? Double ?? 0,
            lng:       callData["lng"]       as? Double ?? 0
        )

        let callID    = "\(call.address)|\(call.problem)"
        let savedID   = CallDataModel.shared.lastNotifiedCallID
        let isNewCall = callID != savedID

        DispatchQueue.main.async {
            if isNewCall {
                CallDataModel.shared.lastNotifiedCallID     = callID
                CallDataModel.shared.activeCallDispatchTime = Date()
                CallHistoryManager.shared.saveCall(call)
                print("📲 Push — new call: \(callID)")
            }
            CallDataModel.shared.currentCall = call

            // Reconnect socket if needed so live updates resume
            if !CallDataModel.shared.isConnected {
                EMSSocketManager.shared.connect()
            }
        }

        completionHandler(isNewCall ? .newData : .noData)
    }
}
