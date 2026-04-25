import Foundation
import SocketIO

class EMSSocketManager {
    static let shared = EMSSocketManager()
    private init() {}

    private var manager: SocketManager?
    private var socket:  SocketIOClient?

    // ⚠️ Replace with your server IP
    private let serverURL = "http://embtech.llc:3030"

    func connect() {
        guard let url = URL(string: serverURL) else {
            print("❌ Invalid server URL")
            return
        }

        manager = SocketManager(socketURL: url, config: [
            .log(false), .compress,
            .reconnects(true), .reconnectAttempts(-1),
            .reconnectWait(3), .forceWebsockets(true)
        ])
        socket = manager?.defaultSocket

        socket?.on(clientEvent: .connect) { _, _ in
            print("✅ Socket connected")
            DispatchQueue.main.async { CallDataModel.shared.isConnected = true }
        }

        socket?.on(clientEvent: .disconnect) { _, _ in
            print("⚠️ Socket disconnected")
            DispatchQueue.main.async { CallDataModel.shared.isConnected = false }
        }

        socket?.on(clientEvent: .error) { data, _ in
            print("❌ Socket error: \(data)")
        }

        socket?.on("callsUpdate") { data, _ in
            guard let calls = data[0] as? [[String: Any]], !calls.isEmpty else {
                print("📭 Call cleared")
                DispatchQueue.main.async {
                    // Clear the call display but keep lastNotifiedCallID
                    // so next reconnect still recognises it as the same call
                    CallDataModel.shared.currentCall            = nil
                    CallDataModel.shared.activeCallDispatchTime = nil
                    CallDataModel.shared.lastNotifiedCallID     = ""
                }
                return
            }

            let first = calls[0]
            let call = EMSCall(
                address:   first["address"]   as? String ?? "Unknown Address",
                cross:     first["cross"]     as? String ?? "",
                problem:   first["problem"]   as? String ?? "Unknown Problem",
                units:     first["units"]     as? String ?? "",
                age:       first["age"]       as? String ?? "",
                sex:       first["sex"]       as? String ?? "",
                conscious: first["conscious"] as? String ?? "",
                breathing: first["breathing"] as? String ?? "",
                lat:       first["lat"]       as? Double ?? 0,
                lng:       first["lng"]       as? Double ?? 0
            )

            let callID    = "\(call.address)|\(call.problem)"
            let savedID   = CallDataModel.shared.lastNotifiedCallID
            let isNewCall = callID != savedID

            print("📡 callsUpdate — id='\(callID)' savedID='\(savedID)' isNew=\(isNewCall)")

            DispatchQueue.main.async {
                if isNewCall {
                    // Genuinely new call — record everything
                    CallDataModel.shared.lastNotifiedCallID     = callID
                    CallDataModel.shared.activeCallDispatchTime = Date()  // fresh timer
                    CallHistoryManager.shared.saveCall(call)
                    NotificationManager.shared.sendCallNotification(call: call)
                    print("🚨 NEW call — dispatchTime set to NOW")
                } else {
                    // Reconnect replay of same call — preserve existing dispatch time
                    let existing = CallDataModel.shared.activeCallDispatchTime
                    print("🔁 Same call replay — existing dispatchTime=\(String(describing: existing))")
                }
                // Always update currentCall so UI stays current
                CallDataModel.shared.currentCall = call
            }
        }

        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
    }
}
