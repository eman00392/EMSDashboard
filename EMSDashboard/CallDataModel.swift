import Foundation
import Combine
import CoreLocation

// MARK: - EMS Call Model

struct EMSCall {
    var address:   String
    var cross:     String
    var problem:   String
    var units:     String
    var age:       String
    var sex:       String
    var conscious: String
    var breathing: String
    var lat:       Double
    var lng:       Double

    var patientSummary: String {
        var parts: [String] = []
        if !age.isEmpty || !sex.isEmpty {
            parts.append("\(age)\(sex)".trimmingCharacters(in: .whitespaces))
        }
        if !conscious.isEmpty { parts.append(conscious) }
        if !breathing.isEmpty { parts.append(breathing) }
        return parts.isEmpty ? "No patient info" : parts.joined(separator: " · ")
    }

    var hasLocation: Bool { lat != 0 && lng != 0 }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

// MARK: - Call Data Model

class CallDataModel: ObservableObject {
    static let shared = CallDataModel()
    private init() {}

    @Published var currentCall: EMSCall? = nil
    @Published var isConnected: Bool     = false

    // ── Persisted in UserDefaults ──────────────────────────────────────
    // lastNotifiedCallID: the address|problem key of the current/last call.
    // Survives app relaunch so reconnects don't look like new calls.

    var lastNotifiedCallID: String {
        get { UserDefaults.standard.string(forKey: "lastNotifiedCallID") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastNotifiedCallID")
            UserDefaults.standard.synchronize()
            print("💾 lastNotifiedCallID saved: '\(newValue)'")
        }
    }

    // activeCallDispatchTime: when the call first arrived.
    // Used by dashboard and CallDetailViewController for the dispatch timer.

    var activeCallDispatchTime: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: "activeCallDispatchTime")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let d = newValue {
                UserDefaults.standard.set(d.timeIntervalSince1970,
                                          forKey: "activeCallDispatchTime")
                UserDefaults.standard.synchronize()
                print("💾 activeCallDispatchTime saved: \(d)")
            } else {
                UserDefaults.standard.removeObject(forKey: "activeCallDispatchTime")
                UserDefaults.standard.synchronize()
                print("💾 activeCallDispatchTime cleared")
            }
        }
    }
}
