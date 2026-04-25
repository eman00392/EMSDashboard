import CarPlay
import MapKit
import Combine

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    private var callCancellable: AnyCancellable?
    private var connCancellable: AnyCancellable?

    // MARK: - Timer
    private var dispatchTimer: Timer?
    private var dispatchStartTime: Date?
    private var elapsedSeconds: Int = 0

    // MARK: - Connect

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        print("🚗 [CarPlay] didConnect fired")
        self.interfaceController = interfaceController

        refreshDashboard(animated: false)

        // Refresh on call changes
        callCancellable = CallDataModel.shared.$currentCall
            .receive(on: DispatchQueue.main)
            .sink { [weak self] call in
                if call != nil {
                    self?.startDispatchTimer()
                } else {
                    self?.stopDispatchTimer()
                }
                self?.refreshDashboard(animated: true)
            }

        // Refresh on connection changes
        connCancellable = CallDataModel.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshDashboard(animated: false)
            }
    }

    // MARK: - Disconnect

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        print("🚗 [CarPlay] didDisconnect")
        stopDispatchTimer()
        self.interfaceController = nil
        callCancellable = nil
        connCancellable = nil
    }

    // MARK: - Scene lifecycle

    func sceneWillConnect(
        _ scene: UIScene,
        session: UISceneSession,
        connectionOptions: UIScene.ConnectionOptions
    ) {
        print("🚗 [CarPlay] sceneWillConnect — role: \(session.role.rawValue)")
    }

    // MARK: - Dispatch Timer

    private func startDispatchTimer() {
        guard dispatchStartTime == nil else { return } // Already running
        dispatchStartTime = Date()
        elapsedSeconds    = 0

        dispatchTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedSeconds += 1
            self.refreshDashboard(animated: false)
        }
        print("🚗 [CarPlay] Dispatch timer started")
    }

    private func stopDispatchTimer() {
        dispatchTimer?.invalidate()
        dispatchTimer     = nil
        dispatchStartTime = nil
        elapsedSeconds    = 0
    }

    private var timerString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Dashboard

    func refreshDashboard(animated: Bool) {
        let template = buildDashboard()
        interfaceController?.setRootTemplate(template, animated: animated, completion: nil)
    }

    func buildDashboard() -> CPListTemplate {
        guard let call = CallDataModel.shared.currentCall else {
            return buildStandbyTemplate()
        }
        return buildActiveCallTemplate(call: call)
    }

    // MARK: - Standby Template

    private func buildStandbyTemplate() -> CPListTemplate {
        let connected = CallDataModel.shared.isConnected

        let statusItem = CPListItem(
            text: "No Active Call",
            detailText: "Monitoring Active911..."
        )

        let connItem = CPListItem(
            text: connected ? "🟢 Connected to Server" : "🔴 Server Disconnected",
            detailText: connected ? "Waiting for dispatch" : "Check network connection"
        )

        let section = CPListSection(items: [statusItem, connItem])
        return CPListTemplate(title: "🚑 EMS Dashboard", sections: [section])
    }

    // MARK: - Active Call Template

    private func buildActiveCallTemplate(call: EMSCall) -> CPListTemplate {

        // Row 1 — Timer (live, updates every second)
        let timerItem = CPListItem(
            text: "⏱  Response Timer",
            detailText: timerString
        )

        // Row 2 — Problem + Address
        let callItem = CPListItem(
            text: call.problem.uppercased(),
            detailText: call.address
        )

        // Row 3 — Cross street
        let crossItem = CPListItem(
            text: "📍 Cross Street",
            detailText: call.cross.isEmpty ? "Not available" : call.cross
        )

        // Row 4 — Patient info
        let patientItem = CPListItem(
            text: "🧑‍⚕️ Patient",
            detailText: call.patientSummary
        )

        // Row 5 — Navigate
        let navItem = CPListItem(
            text: "🗺  Navigate to Scene",
            detailText: call.hasLocation ? call.address : "No GPS available"
        )
        navItem.handler = { [weak self] _, completion in
            self?.launchMaps(call: call)
            completion()
        }

        // Row 6 — Acknowledge
        let ackItem = CPListItem(
            text: "✅  Acknowledge Call",
            detailText: "Mark as received"
        )
        ackItem.handler = { _, completion in
            NotificationCenter.default.post(name: .callAcknowledged, object: nil)
            print("🚗 [CarPlay] Call acknowledged")
            completion()
        }

        // Sections
        let timerSection = CPListSection(
            items: [timerItem],
            header: "🚨 ACTIVE CALL",
            sectionIndexTitle: nil
        )

        let infoSection = CPListSection(
            items: [callItem, crossItem],
            header: "CALL INFO",
            sectionIndexTitle: nil
        )

        let patientSection = CPListSection(
            items: [patientItem],
            header: "PATIENT",
            sectionIndexTitle: nil
        )

        let actionsSection = CPListSection(
            items: [navItem, ackItem],
            header: "ACTIONS",
            sectionIndexTitle: nil
        )

        return CPListTemplate(
            title: "🚑 EMS Dashboard",
            sections: [timerSection, infoSection, patientSection, actionsSection]
        )
    }

    // MARK: - Maps

    private func launchMaps(call: EMSCall) {
        guard call.hasLocation else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: call.coordinate))
        mapItem.name = call.address
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
