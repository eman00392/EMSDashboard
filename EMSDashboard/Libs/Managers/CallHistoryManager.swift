import Foundation

// MARK: - Call History Manager
// Persists the last 5 EMS calls to UserDefaults.
// Automatically saves whenever a new call comes in.

class CallHistoryManager {
    static let shared = CallHistoryManager()
    private init() {}

    private let key = "ems_call_history"
    private let maxHistory = 5

    // MARK: - Save a Call

    func saveCall(_ call: EMSCall) {
        var history = loadHistory()

        // Build a storable dictionary
        let entry: [String: Any] = [
            "address":   call.address,
            "cross":     call.cross,
            "problem":   call.problem,
            "units":     call.units,
            "comments":  call.comments,
            "type":      call.type,
            "age":       call.age,
            "sex":       call.sex,
            "conscious": call.conscious,
            "breathing": call.breathing,
            "lat":       call.lat,
            "lng":       call.lng,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Prepend newest, keep only last 5
        history.insert(entry, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }

        UserDefaults.standard.set(history, forKey: key)
    }

    // MARK: - Load History

    func loadHistory() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
    }

    // MARK: - Load as EMSCallRecord (includes timestamp)

    func loadRecords() -> [EMSCallRecord] {
        return loadHistory().compactMap { dict in
            guard let address = dict["address"] as? String,
                  let problem = dict["problem"] as? String else { return nil }

            return EMSCallRecord(
                call: EMSCall(
                    address:   address,
                    cross:     dict["cross"]     as? String ?? "",
                    problem:   problem,
                    units:     dict["units"]     as? String ?? "",
                    comments:  dict["comments"]  as? String ?? "",
                    type:      dict["type"]      as? String ?? "",
                    age:       dict["age"]       as? String ?? "",
                    sex:       dict["sex"]       as? String ?? "",
                    conscious: dict["conscious"] as? String ?? "",
                    breathing: dict["breathing"] as? String ?? "",
                    lat:       dict["lat"]       as? Double ?? 0,
                    lng:       dict["lng"]       as? Double ?? 0
                ),
                timestamp: Date(timeIntervalSince1970: dict["timestamp"] as? Double ?? 0)
            )
        }
    }

    // MARK: - Clear History

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - EMSCallRecord (Call + Timestamp)

struct EMSCallRecord {
    let call: EMSCall
    let timestamp: Date

    var timeAgoString: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60        { return "\(seconds)s ago" }
        if seconds < 3600      { return "\(seconds / 60)m ago" }
        if seconds < 86400     { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd  HH:mm"
        return formatter.string(from: timestamp)
    }
}
