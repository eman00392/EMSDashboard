import Foundation
import CoreLocation
import MapKit

// MARK: - Hospital Result

struct HospitalResult {
    let name:      String
    let address:   String
    let coordinate: CLLocationCoordinate2D

    var distanceString: String { String(format: "%.1f mi", distanceMiles) }
    var distanceMiles:  Double = 0

    var etaString: String {
        let mins = Int((distanceMiles / 40.0) * 60)
        return mins < 1 ? "< 1 min" : "~\(mins) min"
    }

    // MKMapItem for any legacy references (hospitals section on dashboard)
    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item      = MKMapItem(placemark: placemark)
        item.name     = name
        return item
    }
}

// MARK: - Hospital Finder
// No searching. Returns the fixed list of 6 hospitals sorted by
// driving distance from the given coordinate.

class HospitalFinder {
    static let shared = HospitalFinder()
    private init() {}

    // ── Fixed Hospital List ────────────────────────────────────────────
    // Edit coordinates or names here as needed.

    private let allHospitals: [(name: String, address: String, lat: Double, lng: Double)] = [
        (
            name:    "White Plains Hospital",
            address: "41 E Post Rd, White Plains, NY 10601",
            lat:     41.0340,
            lng:    -73.7629
        ),
        (
            name:    "NewYork-Presbyterian Westchester",
            address: "55 Palmer Ave, Bronxville, NY 10708",
            lat:     40.9419,
            lng:    -73.8368,
        ),
        (
            name:    "New Rochelle Hospital",
            address: "16 Guion Pl, New Rochelle, NY 10801",
            lat:     40.9107,
            lng:    -73.7744
        ),
        (
            name:    "Westchester Medical Center",
            address: "100 Woods Rd, Valhalla, NY 10595",
            lat:     41.0762,
            lng:    -73.7979
        ),
        (
            name:    "NYC Health + Hospitals / Jacobi",
            address: "1400 Pelham Pkwy S, Bronx, NY 10461",
            lat:     40.8502,
            lng:    -73.8582
        ),
        (
            name:    "Montefiore Mount Vernon",
            address: "12 N 7th Ave, Mount Vernon, NY 10550",
            lat:     40.9126,
            lng:    -73.8371
        ),
    ]

    // MARK: - Main Entry Point
    // Returns all 6 hospitals sorted by straight-line distance from coordinate.
    // limit is ignored — always returns all 6 — kept for API compatibility.

    func findNearestHospitals(
        near coordinate: CLLocationCoordinate2D,
        limit: Int = 6,
        completion: @escaping ([HospitalResult]) -> Void
    ) {
        let callLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let results: [HospitalResult] = allHospitals.map { h in
            let hospitalLocation = CLLocation(latitude: h.lat, longitude: h.lng)
            let miles = callLocation.distance(from: hospitalLocation) / 1609.34
            return HospitalResult(
                name:          h.name,
                address:       h.address,
                coordinate:    CLLocationCoordinate2D(latitude: h.lat, longitude: h.lng),
                distanceMiles: miles
            )
        }
        .sorted { $0.distanceMiles < $1.distanceMiles }

        print("🏥 Hospitals: \(results.map { "\($0.name) (\($0.distanceString))" }.joined(separator: ", "))")
        completion(results)
    }

    // Legacy — kept so any existing call sites don't break
    func navigate(to hospital: HospitalResult) {
        hospital.mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
