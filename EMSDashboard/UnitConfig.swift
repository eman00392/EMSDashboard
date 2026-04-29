import Foundation

// MARK: - Call Origin
// Mirrors the agency detection logic in the web dashboard (index.html)

enum CallOrigin: Equatable {
    case eastchester   // default — our own calls
    case pelham        // units field contains "PELHAM"
    case scarsdale     // units field contains "SCARSDALE"
    case mutualAid     // units/type contains "MUTUAL", "M/A", or type is "MA"
    case unknown
}

// MARK: - Unit Config
// Logic copied directly from the web dashboard JavaScript:
//
//   const isPelham    = units.includes("PELHAM")
//   const isScarsdale = units.includes("SCARSDALE")
//   const isMutualAid = units.includes("MUTUAL") ||
//                       units.includes("M/A")    ||
//                       callType.includes("MA")
//
//   Priority: MutualAid → Pelham → Scarsdale → Eastchester (default)

class UnitConfig {

    static func origin(from units: String, type: String = "") -> CallOrigin {
        let u = units.uppercased()
        let t = type.uppercased()

        let isPelham    = u.contains("PELHAM")
        let isScarsdale = u.contains("SCARSDALE")
        let isMutualAid = u.contains("MUTUAL") || u.contains("M/A") || t.contains("MA")

        if isMutualAid {
            if isPelham    { return .pelham }    // MA - Pelham
            if isScarsdale { return .scarsdale } // MA - Scarsdale
            return .mutualAid
        }

        if isPelham    { return .pelham }
        if isScarsdale { return .scarsdale }

        // Default — Eastchester (our own units or unknown)
        return .eastchester
    }
}
