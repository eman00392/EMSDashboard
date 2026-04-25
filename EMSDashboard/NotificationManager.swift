import UIKit   
import UserNotifications
import CoreLocation

// MARK: - Notification Action Identifiers
struct NotificationAction {
    static let acknowledge = "EMS_ACKNOWLEDGE"
    static let navigate    = "EMS_NAVIGATE"
    static let categoryID  = "EMS_CALL"
}

// MARK: - Notification Manager
class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private override init() {}

    // MARK: - Setup

    func requestPermission() {
        // Register action categories first
        registerCategories()

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                DispatchQueue.main.async {
                    UNUserNotificationCenter.current().delegate = self
                }
            } else if let error = error {
                print("❌ Notification error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Register Action Categories

    private func registerCategories() {
        // ✅ Acknowledge action
        let acknowledgeAction = UNNotificationAction(
            identifier: NotificationAction.acknowledge,
            title: "✅  Acknowledge",
            options: [.foreground]
        )

        // 🗺 Navigate action — opens app straight to call detail
        let navigateAction = UNNotificationAction(
            identifier: NotificationAction.navigate,
            title: "🗺  Navigate",
            options: [.foreground]
        )

        // Category groups both actions onto the notification
        let category = UNNotificationCategory(
            identifier: NotificationAction.categoryID,
            actions: [acknowledgeAction, navigateAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
        print("✅ Notification categories registered")
    }

    // MARK: - Send Call Notification

    func sendCallNotification(call: EMSCall) {
        let content = UNMutableNotificationContent()
        content.title    = "🚨 NEW EMS CALL"
        content.body     = "\(call.problem.uppercased())\n\(call.address)"
        content.sound    = .defaultCritical
        content.badge    = 1
        content.categoryIdentifier = NotificationAction.categoryID
        content.interruptionLevel  = .critical

        // Store call data in notification so Navigate action can use it
        content.userInfo = [
            "address": call.address,
            "problem": call.problem,
            "lat":     call.lat,
            "lng":     call.lng
        ]

        let request = UNNotificationRequest(
            identifier: "ems-call-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error.localizedDescription)")
            } else {
                print("✅ Call notification sent")
            }
        }
    }

    // MARK: - Clear Badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {

    // Show notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle action button taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {

        case NotificationAction.acknowledge:
            print("✅ Call acknowledged from notification")
            // Post notification so the app can show an acknowledged state
            NotificationCenter.default.post(name: .callAcknowledged, object: nil)

        case NotificationAction.navigate:
            print("🗺 Navigate tapped from notification")
            // Extract call location and open in Maps
            if let lat = userInfo["lat"] as? Double,
               let lng = userInfo["lng"] as? Double,
               let address = userInfo["address"] as? String {

                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)

                // Try Google Maps first, fall back to Apple Maps
                let googleURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")!
                let appleURL  = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=d")!
                let googleWeb = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=driving")!

                DispatchQueue.main.async {
                    if UIApplication.shared.canOpenURL(googleURL) {
                        UIApplication.shared.open(googleURL)
                    } else if UIApplication.shared.canOpenURL(appleURL) {
                        UIApplication.shared.open(appleURL)
                    } else {
                        UIApplication.shared.open(googleWeb)
                    }
                }
            }

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification body — open the app
            print("📱 Notification tapped — opening app")
            NotificationCenter.default.post(name: .notificationOpened, object: nil)

        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let callAcknowledged  = Notification.Name("EMSCallAcknowledged")
    static let notificationOpened = Notification.Name("EMSNotificationOpened")
}
