//
//  HospitalConfig.swift
//  EMSDashboard
//
//  Created by Ethan Bernstein on 4/23/26.
//
import Foundation

// MARK: - Hospital Info
// Add, remove, or edit entries here to configure your station's hospitals.
// The name must PARTIALLY match what Apple Maps returns for the hospital
// so the app can link the contact info to the route card.

struct HospitalInfo {
    let nameKeyword: String   // partial match against Apple Maps hospital name
    let phone: String
    let doorCode: String      // leave empty "" if no door code
    let notes: String         // optional extra info e.g. "Trauma Level II"
}

// MARK: - Emergency Contact
// Phone numbers shown on the Contacts page

struct EmergencyContact {
    let name: String
    let phone: String
    let category: ContactCategory
}

enum ContactCategory: String {
    case hospital  = "🏥 Hospitals"
    case police    = "👮 Police"
    case fire      = "🚒 Fire"
    case other     = "📋 Other"
}

// MARK: - Config Store
// ⚠️ EDIT THIS FILE to configure your station's contacts and door codes

class HospitalConfig {
    static let shared = HospitalConfig()
    private init() {}

    // ── Hospital Info ──────────────────────────────────────────────────
    // nameKeyword is case-insensitive partial match against Apple Maps name
    // Example: "White Plains" matches "White Plains Hospital"

    let hospitals: [HospitalInfo] = [
        HospitalInfo(
            nameKeyword: "White Plains",
            phone:       "(914) 681-2600",
            doorCode:    "0817",
            notes:       ""
        ),
        HospitalInfo(
            nameKeyword: "NewYork-Presbyterian Westchester",
            phone:       "(914) 787-1035",
            doorCode:    "1035#",
            notes:       ""
        ),
        HospitalInfo(
            nameKeyword: "Montefiore New Rochelle Hospital",
            phone:       "NA",
            doorCode:    "",
            notes:       ""
        ),
        HospitalInfo(
            nameKeyword: "Westchester Medical Center",
            phone:       "(914) 493-7307",
            doorCode:    "",
            notes:       ""
        ),
        HospitalInfo(
            nameKeyword: "Jacobi Medical Center",
            phone:       "‭(718) 918-7999‬",
            doorCode:    "",
            notes:       ""
        ),
        // ADD MORE HOSPITALS HERE:
        // HospitalInfo(
        //     nameKeyword: "Lawrence",
        //     phone:       "(516) 295-1000",
        //     doorCode:    "1234",
        //     notes:       ""
        // ),
    ]

    // ── Emergency Contacts ─────────────────────────────────────────────
    // Shown on the Contacts page from the main dashboard

    let contacts: [EmergencyContact] = [

        // Hospitals
        EmergencyContact(name: "White Plains Hospital",        phone: "(914) 681-2600", category: .hospital),
        EmergencyContact(name: "NewYork-Presbyterian Westchester",      phone: "(914) 787-1035", category: .hospital),
        EmergencyContact(name: "Montefiore New Rochelle Hospital",        phone: "NA", category: .hospital),
        EmergencyContact(name: "Westchester Medical Center",           phone: "(203) 863-3000", category: .hospital),
        EmergencyContact(name: "NYC H+H / Jacobi",           phone: "(203) 863-3000", category: .hospital),
        // Police
        EmergencyContact(name: "Eastchester PD",              phone: "(914) 961-3464", category: .police),
        EmergencyContact(name: "Tuckahoe PD",                 phone: "(914) 961-4800", category: .police),
        EmergencyContact(name: "Westchester County PD",       phone: "(914) 864-7700", category: .police),
        EmergencyContact(name: "Bronxville PD",               phone: "(914) 337-0500", category: .police),
        EmergencyContact(name: "Yonkers PD",                  phone: "(914) 377-7900", category: .police),

        // Fire

        // Other
        EmergencyContact(name: "60 Control",    phone: "‭(914) 231-1905‬", category: .other),
        EmergencyContact(name: "Poison Control",              phone: "(800) 222-1222", category: .other),
        // ADD MORE HERE:
        // EmergencyContact(name: "Mount Vernon PD", phone: "(914) 665-2500", category: .police),
    ]

    // MARK: - Lookup hospital info by name

    func info(for hospitalName: String) -> HospitalInfo? {
        let lower = hospitalName.lowercased()
        return hospitals.first { lower.contains($0.nameKeyword.lowercased()) }
    }

    // MARK: - Contacts grouped by category

    var groupedContacts: [(category: ContactCategory, contacts: [EmergencyContact])] {
        let order: [ContactCategory] = [.hospital, .police, .fire, .other]
        return order.compactMap { cat in
            let filtered = contacts.filter { $0.category == cat }
            return filtered.isEmpty ? nil : (category: cat, contacts: filtered)
        }
    }
}
