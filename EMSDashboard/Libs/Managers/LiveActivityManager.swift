//
//  LiveActivityManager.swift
//  EMSDashboard
//
//  Created by Ethan Bernstein on 4/23/26.
//
import Foundation
import ActivityKit

// MARK: - Live Activity Attributes
// Defines what appears on the Lock Screen and Dynamic Island

@available(iOS 16.2, *)
struct EMSCallAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var address: String
        var problem: String
        var units: String
        var elapsedMinutes: Int
    }

    var eventNumber: String
}

// MARK: - Live Activity Manager
// Call startActivity(for:) when a new call comes in.
// Call endActivity() when the call is cleared.

class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var activityID: String?
    private var elapsedTimer: Timer?
    private var startTime: Date = Date()
    private var currentCall: EMSCall?

    // MARK: - Start

    func startActivity(for call: EMSCall) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities not enabled on this device")
            return
        }

        endActivity() // Clear any existing activity first

        currentCall = call

        let attributes = EMSCallAttributes(
            eventNumber: "EMS-\(Int(Date().timeIntervalSince1970))"
        )
        let state = EMSCallAttributes.ContentState(
            address: call.address,
            problem: call.problem,
            units: call.units,
            elapsedMinutes: 0
        )

        do {
            let activity = try Activity<EMSCallAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            activityID = activity.id
            print("✅ Live Activity started: \(activity.id)")
            startElapsedTimer()
        } catch {
            print("❌ Live Activity failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Elapsed Timer (updates every 60s)

    private func startElapsedTimer() {
        startTime = Date()
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateElapsed()
        }
    }

    private func updateElapsed() {
        guard #available(iOS 16.2, *),
              let id = activityID,
              let call = currentCall,
              let activity = Activity<EMSCallAttributes>.activities.first(where: { $0.id == id })
        else { return }

        let elapsed = Int(Date().timeIntervalSince(startTime) / 60)
        let updatedState = EMSCallAttributes.ContentState(
            address: call.address,
            problem: call.problem,
            units: call.units,
            elapsedMinutes: elapsed
        )

        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }

    // MARK: - End

    func endActivity() {
        guard #available(iOS 16.2, *) else { return }

        elapsedTimer?.invalidate()
        elapsedTimer = nil
        currentCall  = nil

        Task {
            for activity in Activity<EMSCallAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        activityID = nil
        print("🔴 Live Activity ended")
    }
}

// ─────────────────────────────────────────────────────────────
// WIDGET EXTENSION SETUP (required for Lock Screen display)
// ─────────────────────────────────────────────────────────────
//
// 1. In Xcode: File → New → Target → Widget Extension
// 2. Name it: EMSLiveActivity
// 3. Check "Include Live Activity"
// 4. Replace the generated Swift file contents with this:
//
// import WidgetKit
// import SwiftUI
//
// @available(iOS 16.2, *)
// struct EMSLiveActivityWidget: Widget {
//     var body: some WidgetConfiguration {
//         ActivityConfiguration(for: EMSCallAttributes.self) { context in
//
//             // ── Lock Screen Banner ──
//             HStack(spacing: 12) {
//                 VStack(alignment: .leading, spacing: 4) {
//                     Text("🚨 " + context.state.problem)
//                         .font(.headline).bold()
//                         .foregroundColor(.red)
//                     Text(context.state.address)
//                         .font(.subheadline)
//                         .foregroundColor(.white)
//                         .lineLimit(1)
//                     Text("🚒 " + context.state.units)
//                         .font(.caption)
//                         .foregroundColor(.gray)
//                         .lineLimit(1)
//                 }
//                 Spacer()
//                 VStack(spacing: 2) {
//                     Text("\(context.state.elapsedMinutes)")
//                         .font(.system(size: 30, weight: .black, design: .monospaced))
//                         .foregroundColor(.orange)
//                     Text("MIN")
//                         .font(.system(size: 9, weight: .bold, design: .monospaced))
//                         .foregroundColor(.gray)
//                 }
//             }
//             .padding()
//             .background(Color.black)
//
//         } dynamicIsland: { context in
//
//             // ── Dynamic Island ──
//             DynamicIsland {
//                 DynamicIslandExpandedRegion(.leading) {
//                     Text("🚨").font(.title2)
//                 }
//                 DynamicIslandExpandedRegion(.trailing) {
//                     Text("\(context.state.elapsedMinutes)m")
//                         .font(.headline)
//                         .foregroundColor(.orange)
//                 }
//                 DynamicIslandExpandedRegion(.bottom) {
//                     Text(context.state.problem + "  ·  " + context.state.address)
//                         .font(.caption)
//                         .foregroundColor(.white)
//                         .lineLimit(1)
//                 }
//             } compactLeading: {
//                 Text("🚨").font(.caption)
//             } compactTrailing: {
//                 Text("\(context.state.elapsedMinutes)m")
//                     .foregroundColor(.orange)
//                     .font(.caption2)
//             } minimal: {
//                 Text("🚨")
//             }
//         }
//     }
// }
//
// 5. In your main app target's Info.plist add:
//    <key>NSSupportsLiveActivities</key><true/>
//
// ─────────────────────────────────────────────────────────────
