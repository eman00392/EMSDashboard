//
//  CallHistoryManager.swift
//  EMSDashboard
//
//  Created by Ethan Bernstein on 4/23/26.
//
import Foundation

// MARK: - Call History Manager
// Persists the last 5 EMS calls to UserDefaults.
// Automatically called from MainDashboardViewController on every new call.

class CallHistoryManager {
    static let shared = CallHistoryManager()
    private init() {}

    private let key        = "ems_call_history"
    private let maxHistory = 5

    // MARK: - Save a Call

    func saveCall(_ call: EMSCall) {
        var history = loadRaw()

        let entry: [String: Any] = [
            "address":   call.address,
            "cross":     call.cross,
            "problem":   call.problem,
            "units":     call.units,
            "age":       call.age,
            "sex":       call.sex,
            "conscious": call.conscious,
            "breathing": call.breathing,
            "lat":       call.lat,
            "lng":       call.lng,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Newest first, trim to max
        history.insert(entry, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }

        UserDefaults.standard.set(history, forKey: key)
    }

    // MARK: - Load as Records (with timestamp)

    func loadRecords() -> [EMSCallRecord] {
        return loadRaw().compactMap { dict in
            guard
                let address = dict["address"] as? String,
                let problem = dict["problem"] as? String
            else { return nil }

            let call = EMSCall(
                address:   address,
                cross:     dict["cross"]     as? String ?? "",
                problem:   problem,
                units:     dict["units"]     as? String ?? "",
                age:       dict["age"]       as? String ?? "",
                sex:       dict["sex"]       as? String ?? "",
                conscious: dict["conscious"] as? String ?? "",
                breathing: dict["breathing"] as? String ?? "",
                lat:       dict["lat"]       as? Double ?? 0,
                lng:       dict["lng"]       as? Double ?? 0
            )

            let timestamp = Date(timeIntervalSince1970: dict["timestamp"] as? Double ?? 0)
            return EMSCallRecord(call: call, timestamp: timestamp)
        }
    }

    // MARK: - Clear

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private

    private func loadRaw() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
    }
}

// MARK: - EMS Call Record

struct EMSCallRecord {
    let call: EMSCall
    let timestamp: Date

    /// e.g. "2m ago", "3h ago", "1d ago"
    var timeAgoString: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60    { return "\(seconds)s ago" }
        if seconds < 3600  { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    /// e.g. "04/23  14:35"
    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd  HH:mm"
        return f.string(from: timestamp)
    }
}
