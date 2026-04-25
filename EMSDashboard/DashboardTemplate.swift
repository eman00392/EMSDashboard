import CarPlay

// MARK: - Dashboard Template Builder
// Builds the CPListTemplate shown on the CarPlay screen

class DashboardTemplate {

    static func build(
        onShowMap: @escaping () -> Void,
        onShowDetails: @escaping () -> Void
    ) -> CPListTemplate {

        if let call = CallDataModel.shared.currentCall {
            return buildActiveCallTemplate(call: call, onShowMap: onShowMap, onShowDetails: onShowDetails)
        } else {
            return buildStandbyTemplate()
        }
    }

    // MARK: - Standby Screen (No Active Call)

    private static func buildStandbyTemplate() -> CPListTemplate {
        let connected = CallDataModel.shared.isConnected

        let statusItem = CPListItem(
            text: "No Active Call",
            detailText: "Monitoring Active911..."
        )

        let connectionItem = CPListItem(
            text: connected ? "🟢 Server Connected" : "🔴 Server Disconnected",
            detailText: connected ? "Waiting for dispatch" : "Check network connection"
        )

        let section = CPListSection(items: [statusItem, connectionItem])
        return CPListTemplate(title: "🚑 EMS Dashboard", sections: [section])
    }

    // MARK: - Active Call Screen

    private static func buildActiveCallTemplate(
        call: EMSCall,
        onShowMap: @escaping () -> Void,
        onShowDetails: @escaping () -> Void
    ) -> CPListTemplate {

        // Row 1 — Address (primary info, most critical)
        let addressItem = CPListItem(
            text: call.address.uppercased(),
            detailText: call.problem.uppercased()
        )

        // Row 2 — Units responding
        let unitsItem = CPListItem(
            text: "🚒 Units",
            detailText: call.units.isEmpty ? "No units assigned" : call.units
        )

        // Row 3 — Patient details
        let patientItem = CPListItem(
            text: "🧑‍⚕️ Patient",
            detailText: call.patientSummary
        )

        // Row 4 — Full details drill-down
        let detailsItem = CPListItem(
            text: "ℹ️ Full Call Details",
            detailText: "Tap to view all info"
        )
        detailsItem.handler = { _, completion in
            onShowDetails()
            completion()
        }

        // Row 5 — Navigate button (launches Apple Maps)
        let mapItem = CPListItem(
            text: "🗺  Navigate to Scene",
            detailText: call.hasLocation ? call.address : "No GPS — tap to try"
        )
        mapItem.handler = { _, completion in
            onShowMap()
            completion()
        }

        // Section 1 — Call info
        let callSection = CPListSection(
            items: [addressItem, unitsItem],
            header: "🚨 ACTIVE CALL",
            sectionIndexTitle: nil
        )

        // Section 2 — Patient
        let patientSection = CPListSection(
            items: [patientItem],
            header: "PATIENT",
            sectionIndexTitle: nil
        )

        // Section 3 — Actions
        let actionsSection = CPListSection(
            items: [detailsItem, mapItem],
            header: "ACTIONS",
            sectionIndexTitle: nil
        )

        return CPListTemplate(
            title: "🚑 EMS Dashboard",
            sections: [callSection, patientSection, actionsSection]
        )
    }
}
