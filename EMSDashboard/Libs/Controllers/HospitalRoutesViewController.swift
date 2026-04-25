import UIKit
import GoogleMaps
import CoreLocation

// ⚠️ Same key as CallDetailViewController
private let kGoogleAPIKey = "AIzaSyA11vd0wsPQBOZxNY1KiSI15cuFMEhFwUU"

// MARK: - Hospital Route Model
struct HospitalRoute {
    let hospital:    HospitalResult
    let steps:       [GoogleStep]
    let encodedPath: String          // encoded polyline string from Google API
    let duration:    String
    let distance:    String
    let durationSec: Int

    var etaColor: UIColor {
        let mins = durationSec / 60
        return mins <= 5 ? .systemGreen : mins <= 10 ? .systemOrange : .systemRed
    }

    // Always create a fresh GMSPolyline from path — never reuse after removal
    func makeFreshPolyline() -> GMSPolyline? {
        guard let path = GMSPath(fromEncodedPath: encodedPath) else { return nil }
        return GMSPolyline(path: path)
    }

    var path: GMSPath? { GMSPath(fromEncodedPath: encodedPath) }
}

// MARK: - Hospital Routes View Controller
class HospitalRoutesViewController: UIViewController {

    // MARK: - Properties
    private let call: EMSCall
    private var routes:           [HospitalRoute]   = []
    private var pendingHospitals: [HospitalResult]  = []
    private var selectedIndex     = 0
    private var isNavigating      = false
    private var userLocation:     CLLocation?       = nil
    private var lastHeading:      CLLocationDirection = 0
    private var rerouteTimer:     Timer?
    private var routeSteps:       [GoogleStep]      = []
    private var currentStepIndex  = 0
    private var currentPolyline:  GMSPolyline?
    private let locationManager   = CLLocationManager()

    // MARK: - UI
    private var mapView:         GMSMapView!
    private let spinner          = UIActivityIndicatorView(style: .medium)
    private let scrollView       = UIScrollView()
    private let contentStack     = UIStackView()
    private let statusLabel      = UILabel()
    private let routeStack       = UIStackView()
    private let dirBanner        = UIView()
    private let dirIcon          = UILabel()
    private let dirText          = UILabel()
    private let dirDist          = UILabel()
    private let navOverlay       = UIView()
    private let navEtaLabel      = UILabel()
    private let navDistLabel     = UILabel()
    private let navNameLabel     = UILabel()
    private let stopBtn          = UIButton()
    private var mapHeightConstraint: NSLayoutConstraint!

    // MARK: - Init
    init(call: EMSCall) { self.call = call; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        setupNavBar()
        setupGoogleMap()
        setupDirBanner()
        setupScrollView()
        buildHeader()
        buildRouteSection()
        buildNavOverlay()
        startLocationManager()
        findHospitals()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rerouteTimer?.invalidate()
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - Location Manager
    private func startLocationManager() {
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter  = 5
        locationManager.headingFilter   = 3
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    // MARK: - Nav Bar
    private func setupNavBar() {
        title = "HOSPITAL ROUTES"
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        ]
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        let back = UIBarButtonItem(title: "◀  Back", style: .plain, target: self, action: #selector(backTapped))
        back.tintColor = .systemRed
        navigationItem.leftBarButtonItem = back; navigationItem.hidesBackButton = true
    }

    // MARK: - Google Map
    private func setupGoogleMap() {
        let startCoord = call.hasLocation
            ? call.coordinate
            : CLLocationCoordinate2D(latitude: 40.9, longitude: -73.85)

        let camera = GMSCameraPosition(target: startCoord, zoom: 12, bearing: 0, viewingAngle: 0)
        mapView    = GMSMapView(frame: .zero, camera: camera)
        mapView.isMyLocationEnabled       = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton    = true
        mapView.delegate                  = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        mapHeightConstraint = mapView.heightAnchor.constraint(equalToConstant: 260)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapHeightConstraint
        ])

        spinner.color = .white; spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: mapView.centerYAnchor)
        ])
        spinner.startAnimating()
    }

    // MARK: - Direction Banner
    private func setupDirBanner() {
        dirBanner.backgroundColor     = UIColor(red: 0.04, green: 0.09, blue: 0.18, alpha: 0.97)
        dirBanner.layer.shadowColor   = UIColor.black.cgColor
        dirBanner.layer.shadowOpacity = 0.4
        dirBanner.layer.shadowRadius  = 8
        dirBanner.layer.shadowOffset  = CGSize(width: 0, height: 3)
        dirBanner.isHidden            = true
        dirBanner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dirBanner)
        NSLayoutConstraint.activate([
            dirBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            dirBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dirBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        dirIcon.font = .systemFont(ofSize: 40); dirIcon.text = "⬆️"
        dirIcon.setContentHuggingPriority(.required, for: .horizontal)
        dirText.font = .systemFont(ofSize: 17, weight: .bold); dirText.textColor = .white; dirText.numberOfLines = 2
        dirDist.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        dirDist.textColor = UIColor(white: 0.6, alpha: 1)

        let col = UIStackView(arrangedSubviews: [dirText, dirDist])
        col.axis = .vertical; col.spacing = 2; col.alignment = .leading

        let row = UIStackView(arrangedSubviews: [dirIcon, col])
        row.axis = .horizontal; row.spacing = 14; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        dirBanner.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: dirBanner.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: dirBanner.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: dirBanner.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: dirBanner.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Scroll View
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        contentStack.axis = .vertical; contentStack.spacing = 14; contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        let cg = scrollView.contentLayoutGuide; let fg = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: mapView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: cg.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: cg.bottomAnchor, constant: -40),
            contentStack.leadingAnchor.constraint(equalTo: cg.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: cg.trailingAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: fg.widthAnchor, constant: -32)
        ])
    }

    private func buildHeader() {
        let p = UILabel(); p.text = call.problem.uppercased()
        p.font = .systemFont(ofSize: 17, weight: .heavy); p.textColor = .systemRed
        let a = UILabel(); a.text = "From: \(call.address)"
        a.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        a.textColor = UIColor(white: 0.5, alpha: 1); a.numberOfLines = 2
        let s = UIStackView(arrangedSubviews: [p, a]); s.axis = .vertical; s.spacing = 4
        contentStack.addArrangedSubview(s)
    }

    private func buildRouteSection() {
        let hdr = UILabel(); hdr.text = "🏥  ROUTES TO NEAREST HOSPITALS"
        hdr.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        hdr.textColor = UIColor(white: 0.45, alpha: 1)
        statusLabel.text = "Finding hospitals..."
        statusLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = UIColor(white: 0.4, alpha: 1); statusLabel.textAlignment = .center
        routeStack.axis = .vertical; routeStack.spacing = 10; routeStack.alignment = .fill
        let sec = UIStackView(arrangedSubviews: [hdr, statusLabel, routeStack])
        sec.axis = .vertical; sec.spacing = 10
        contentStack.addArrangedSubview(sec)
    }

    private func buildNavOverlay() {
        navOverlay.backgroundColor     = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.97)
        navOverlay.layer.cornerRadius  = 20
        navOverlay.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        navOverlay.layer.shadowColor   = UIColor.black.cgColor
        navOverlay.layer.shadowOpacity = 0.5
        navOverlay.layer.shadowRadius  = 12
        navOverlay.layer.shadowOffset  = CGSize(width: 0, height: -4)
        navOverlay.isHidden            = true
        navOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navOverlay)
        NSLayoutConstraint.activate([
            navOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            navOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        navEtaLabel.font = UIFont.monospacedSystemFont(ofSize: 30, weight: .bold); navEtaLabel.textColor = .systemGreen
        navDistLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular); navDistLabel.textColor = UIColor(white: 0.55, alpha: 1)
        navNameLabel.font = .systemFont(ofSize: 13, weight: .semibold); navNameLabel.textColor = UIColor(white: 0.75, alpha: 1); navNameLabel.numberOfLines = 2

        var stopCfg = UIButton.Configuration.filled()
        stopCfg.title = "■  Stop"; stopCfg.baseBackgroundColor = .systemRed; stopCfg.cornerStyle = .large
        stopCfg.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        stopBtn.configuration = stopCfg; stopBtn.addTarget(self, action: #selector(stopNavigation), for: .touchUpInside)

        let left = UIStackView(arrangedSubviews: [navEtaLabel, navDistLabel, navNameLabel])
        left.axis = .vertical; left.spacing = 2; left.alignment = .leading
        let row = UIStackView(arrangedSubviews: [left, UIView(), stopBtn])
        row.axis = .horizontal; row.alignment = .center; row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        navOverlay.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: navOverlay.topAnchor, constant: 20),
            row.bottomAnchor.constraint(equalTo: navOverlay.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            row.leadingAnchor.constraint(equalTo: navOverlay.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: navOverlay.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Find Hospitals
    private func findHospitals() {
        HospitalFinder.shared.findNearestHospitals(near: call.coordinate, limit: 3) { [weak self] hospitals in
            guard let self = self else { return }
            if hospitals.isEmpty { self.statusLabel.text = "No hospitals found"; self.spinner.stopAnimating(); return }
            if let loc = self.userLocation { self.calculateRoutes(from: loc, to: hospitals) }
            else { self.statusLabel.text = "📍 Getting your location..."; self.pendingHospitals = hospitals }
        }
    }

    // MARK: - Calculate Routes via Google Directions API
    private func calculateRoutes(from origin: CLLocation, to hospitals: [HospitalResult]) {
        statusLabel.text = "Calculating routes..."; spinner.startAnimating()

        let group = DispatchGroup(); var results: [HospitalRoute] = []; let lock = NSLock()

        for hospital in hospitals {
            group.enter()
            let urlStr = "https://maps.googleapis.com/maps/api/directions/json" +
                "?origin=\(origin.coordinate.latitude),\(origin.coordinate.longitude)" +
                "&destination=\(hospital.coordinate.latitude),\(hospital.coordinate.longitude)" +
                "&mode=driving&departure_time=now&key=\(kGoogleAPIKey)"

            guard let url = URL(string: urlStr) else { group.leave(); continue }

            URLSession.shared.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                guard let data = data,
                      let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let routes = json["routes"] as? [[String: Any]],
                      let first  = routes.first,
                      let legs   = first["legs"] as? [[String: Any]],
                      let leg    = legs.first else { return }

                let duration    = (leg["duration_in_traffic"] as? [String: Any] ?? leg["duration"] as? [String: Any] ?? [:])?["text"]  as? String ?? "—"
                let durationSec = (leg["duration_in_traffic"] as? [String: Any] ?? leg["duration"] as? [String: Any] ?? [:])?["value"] as? Int    ?? 0
                let distance    = (leg["distance"] as? [String: Any])?["text"] as? String ?? "—"

                let rawSteps = leg["steps"] as? [[String: Any]] ?? []
                let steps: [GoogleStep] = rawSteps.compactMap { s in
                    guard let html   = s["html_instructions"] as? String,
                          let endLoc = s["end_location"] as? [String: Double],
                          let lat    = endLoc["lat"], let lng = endLoc["lng"],
                          let distV  = (s["distance"] as? [String: Any])?["value"] as? Double else { return nil }
                    let instruction = html
                        .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .replacingOccurrences(of: "  +",     with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    return GoogleStep(instruction: instruction, maneuver: s["maneuver"] as? String ?? "",
                                     endLocation: CLLocationCoordinate2D(latitude: lat, longitude: lng), distanceM: distV)
                }

                // Store encoded path string — GMSPolyline must be created on main thread
                let encoded = (first["overview_polyline"] as? [String: Any])?["points"] as? String ?? ""

                lock.lock()
                results.append(HospitalRoute(hospital: hospital, steps: steps, encodedPath: encoded,
                                              duration: duration, distance: distance, durationSec: durationSec))
                lock.unlock()
            }.resume()
        }

        group.notify(queue: .main) {
            guard !results.isEmpty else { self.statusLabel.text = "Could not calculate routes"; self.spinner.stopAnimating(); return }
            self.routes = results.sorted { $0.durationSec < $1.durationSec }
            self.spinner.stopAnimating(); self.statusLabel.isHidden = true
            self.displayRoutes(); self.drawAllRoutes()
        }
    }

    // MARK: - Route Cards
    private func displayRoutes() {
        routeStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, hr) in routes.enumerated() { routeStack.addArrangedSubview(makeRouteCard(hr, index: i)) }
    }

    private func makeRouteCard(_ hr: HospitalRoute, index: Int) -> UIView {
        let colors: [UIColor] = [.systemGreen, .systemOrange, .systemRed]
        let info = HospitalConfig.shared.info(for: hr.hospital.name)

        let card = UIView(); card.backgroundColor = UIColor(white: 0.1, alpha: 1)
        card.layer.cornerRadius = 16; card.layer.borderWidth = 1
        card.layer.borderColor  = UIColor(white: 0.18, alpha: 1).cgColor

        let badge = UIView(); badge.backgroundColor = colors[min(index, 2)]; badge.layer.cornerRadius = 4
        let rankL = UILabel(); rankL.text = "#\(index+1)"
        rankL.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold); rankL.textColor = .white
        rankL.translatesAutoresizingMaskIntoConstraints = false; badge.addSubview(rankL)
        NSLayoutConstraint.activate([
            rankL.topAnchor.constraint(equalTo: badge.topAnchor, constant: 3),
            rankL.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -3),
            rankL.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6),
            rankL.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6)
        ])

        let nameL = UILabel(); nameL.text = hr.hospital.name
        nameL.font = .systemFont(ofSize: 15, weight: .bold); nameL.textColor = .white; nameL.numberOfLines = 2
        let topRow = UIStackView(arrangedSubviews: [badge, nameL])
        topRow.axis = .horizontal; topRow.spacing = 8; topRow.alignment = .center

        var rows: [UIView] = [topRow]

        if let phone = info?.phone, !phone.isEmpty {
            let btn = UIButton(type: .system); btn.setTitle("📞  \(phone)", for: .normal)
            btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
            btn.tintColor = .systemGreen; btn.contentHorizontalAlignment = .left
            btn.accessibilityValue = phone
            btn.addTarget(self, action: #selector(callHospital(_:)), for: .touchUpInside)
            rows.append(btn)
        }
        if let code = info?.doorCode, !code.isEmpty {
            rows.append(makeLabelRow("🚪 Door Code:", value: code, color: .systemYellow))
        }

        let div1 = makeDivider()
        let etaL = UILabel(); etaL.text = "⏱  \(hr.duration)"
        etaL.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold); etaL.textColor = hr.etaColor
        let distL = UILabel(); distL.text = hr.distance
        distL.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        distL.textColor = UIColor(white: 0.55, alpha: 1); distL.textAlignment = .right
        let statsRow = UIStackView(arrangedSubviews: [etaL, UIView(), distL])
        statsRow.axis = .horizontal; statsRow.alignment = .center

        let div2 = makeDivider()
        let navBtn = UIButton(type: .system); navBtn.setTitle("▶  Navigate In-App", for: .normal)
        navBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        navBtn.tintColor = .white; navBtn.backgroundColor = colors[min(index, 2)]
        navBtn.layer.cornerRadius = 10; navBtn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        navBtn.tag = index; navBtn.addTarget(self, action: #selector(startNavigation(_:)), for: .touchUpInside)

        rows.append(contentsOf: [div1, statsRow, div2, navBtn])
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical; stack.spacing = 8; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }

    private func makeLabelRow(_ label: String, value: String, color: UIColor) -> UIView {
        let l = UILabel(); l.text = label; l.font = .systemFont(ofSize: 12)
        l.textColor = UIColor(white: 0.45, alpha: 1); l.setContentHuggingPriority(.required, for: .horizontal)
        let v = UILabel(); v.text = value; v.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        v.textColor = color; v.textAlignment = .right
        let row = UIStackView(arrangedSubviews: [l, UIView(), v])
        row.axis = .horizontal; row.alignment = .center; row.spacing = 8; return row
    }

    private func makeDivider() -> UIView {
        let v = UIView(); v.backgroundColor = UIColor(white: 0.18, alpha: 1)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true; return v
    }

    // MARK: - Draw Overview (all routes, color-coded)
    // Always call mapView.clear() FIRST, then create fresh GMSPolyline objects.
    // GMSPolyline cannot be re-used after .map = nil — must recreate from path.
    private func drawAllRoutes() {
        mapView.clear()   // clears everything cleanly

        let colors: [UIColor] = [.systemGreen, .systemOrange, .systemRed]
        var allPaths: [GMSPath] = []

        // Drop call pin
        if call.hasLocation {
            let m = GMSMarker(position: call.coordinate)
            m.title = call.problem; m.icon = GMSMarker.markerImage(with: .systemRed); m.map = mapView
        }

        for (i, hr) in routes.enumerated() {
            guard let poly = hr.makeFreshPolyline(), let path = hr.path else { continue }
            poly.strokeColor = colors[min(i, colors.count - 1)]
            poly.strokeWidth = i == 0 ? 5 : 3
            poly.map = mapView

            let hPin = GMSMarker(position: hr.hospital.coordinate)
            hPin.title   = hr.hospital.name
            hPin.snippet = hr.duration
            hPin.icon    = GMSMarker.markerImage(with: colors[min(i, colors.count - 1)])
            hPin.map     = mapView

            allPaths.append(path)
        }

        // Fit camera to show all routes
        if !allPaths.isEmpty {
            var bounds = GMSCoordinateBounds()
            for path in allPaths { bounds = bounds.includingPath(path) }
            let update = GMSCameraUpdate.fit(bounds, with: UIEdgeInsets(top: 30, left: 20, bottom: 30, right: 20))
            mapView.animate(with: update)
        }
    }

    // MARK: - GPS Driving Camera
    private func updateDrivingCamera(location: CLLocation, heading: CLLocationDirection) {
        let camera = GMSCameraPosition(
            target: location.coordinate,
            zoom:   18,
            bearing: heading,
            viewingAngle: 65
        )
        mapView.animate(to: camera)
    }

    // MARK: - Start Navigation
    @objc private func startNavigation(_ sender: UIButton) {
        guard sender.tag < routes.count, let origin = userLocation else {
            let a = UIAlertController(title: "Location Not Ready", message: "Still getting GPS. Please wait.", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default)); present(a, animated: true); return
        }

        selectedIndex    = sender.tag; isNavigating = true; currentStepIndex = 0
        let selected     = routes[selectedIndex]
        routeSteps       = selected.steps

        locationManager.startUpdatingLocation(); locationManager.startUpdatingHeading()

        // Expand map
        UIView.animate(withDuration: 0.3) {
            self.mapHeightConstraint.constant = self.view.bounds.height
            self.scrollView.alpha = 0; self.view.layoutIfNeeded()
        }

        // Clear map first, THEN draw route and markers
        mapView.clear()

        // Draw selected route in blue (fresh polyline from encoded path)
        guard let navPolyline = selected.makeFreshPolyline() else { return }
        navPolyline.strokeColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1)
        navPolyline.strokeWidth = 7
        navPolyline.map = mapView
        currentPolyline = navPolyline

        // Call pin
        if call.hasLocation {
            let m = GMSMarker(position: call.coordinate)
            m.title = call.problem; m.icon = GMSMarker.markerImage(with: .systemRed); m.map = mapView
        }
        // Destination pin
        let destM = GMSMarker(position: selected.hospital.coordinate)
        destM.title = selected.hospital.name
        destM.icon  = GMSMarker.markerImage(with: .systemGreen); destM.map = mapView

        // GPS camera
        updateDrivingCamera(location: origin, heading: lastHeading)

        // Direction banner — first step
        if let first = routeSteps.first {
            dirIcon.text = maneuverIcon(first.maneuver, instruction: first.instruction)
            dirText.text = first.instruction.isEmpty ? "Head toward \(selected.hospital.name)" : first.instruction
            dirDist.text = fmtDist(first.distanceM)
        }

        UIView.animate(withDuration: 0.25) { self.dirBanner.isHidden = false; self.navOverlay.isHidden = false }

        navEtaLabel.text  = selected.duration
        navDistLabel.text = selected.distance
        navNameLabel.text = "→ \(selected.hospital.name)"
        navEtaLabel.textColor = selected.etaColor
    }

    // MARK: - Step Detection
    private func updateStep(userLocation: CLLocation) {
        guard currentStepIndex < routeSteps.count else { return }
        let step    = routeSteps[currentStepIndex]
        let stepEnd = CLLocation(latitude: step.endLocation.latitude, longitude: step.endLocation.longitude)

        if userLocation.distance(from: stepEnd) < 25, currentStepIndex + 1 < routeSteps.count {
            currentStepIndex += 1
            UIView.animate(withDuration: 0.15, animations: { self.dirBanner.alpha = 0.3 }) { _ in
                UIView.animate(withDuration: 0.2) { self.dirBanner.alpha = 1 }
            }
        }

        let cur    = routeSteps[currentStepIndex]
        let curEnd = CLLocation(latitude: cur.endLocation.latitude, longitude: cur.endLocation.longitude)
        dirIcon.text = maneuverIcon(cur.maneuver, instruction: cur.instruction)
        dirText.text = cur.instruction.isEmpty ? "Continue" : cur.instruction
        dirDist.text = fmtDist(userLocation.distance(from: curEnd))
    }

    // MARK: - Reroute
    private func scheduleReroute(from location: CLLocation) {
        rerouteTimer?.invalidate()
        rerouteTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            guard let self = self, self.isNavigating, self.selectedIndex < self.routes.count else { return }
            let hospital = self.routes[self.selectedIndex].hospital
            let urlStr = "https://maps.googleapis.com/maps/api/directions/json" +
                "?origin=\(location.coordinate.latitude),\(location.coordinate.longitude)" +
                "&destination=\(hospital.coordinate.latitude),\(hospital.coordinate.longitude)" +
                "&mode=driving&departure_time=now&key=\(kGoogleAPIKey)"
            guard let url = URL(string: urlStr) else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data,
                      let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let routes = json["routes"] as? [[String: Any]],
                      let first  = routes.first,
                      let legs   = first["legs"] as? [[String: Any]],
                      let leg    = legs.first else { return }
                let duration = (leg["duration_in_traffic"] as? [String: Any] ?? leg["duration"] as? [String: Any] ?? [:])?["text"] as? String ?? "—"
                let distance = (leg["distance"] as? [String: Any])?["text"] as? String ?? "—"
                let rawSteps = leg["steps"] as? [[String: Any]] ?? []
                let steps: [GoogleStep] = rawSteps.compactMap { s in
                    guard let html = s["html_instructions"] as? String,
                          let end  = s["end_location"] as? [String: Double],
                          let lat  = end["lat"], let lng = end["lng"],
                          let dv   = (s["distance"] as? [String: Any])?["value"] as? Double else { return nil }
                    let instr = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                    return GoogleStep(instruction: instr, maneuver: s["maneuver"] as? String ?? "",
                                     endLocation: CLLocationCoordinate2D(latitude: lat, longitude: lng), distanceM: dv)
                }
                // Store encoded string — create GMSPolyline on main thread
                let rerouteEncoded = (first["overview_polyline"] as? [String: Any])?["points"] as? String ?? ""
                DispatchQueue.main.async {
                    self.currentPolyline?.map = nil
                    self.currentPolyline = nil
                    if let path = GMSPath(fromEncodedPath: rerouteEncoded) {
                        let poly = GMSPolyline(path: path)
                        poly.strokeColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1)
                        poly.strokeWidth = 7
                        poly.map = self.mapView
                        self.currentPolyline = poly
                    }
                    self.routeSteps = steps; self.currentStepIndex = 0
                    self.navEtaLabel.text = duration; self.navDistLabel.text = distance
                    print("🔄 Rerouted to \(hospital.name)")
                }
            }.resume()
        }
    }

    private func isOffRoute(userLocation: CLLocation) -> Bool {
        guard let path = currentPolyline?.path else { return false }
        var minDist = Double.greatestFiniteMagnitude
        for i in 0..<path.count() {
            let pt  = path.coordinate(at: i)
            minDist = min(minDist, userLocation.distance(from: CLLocation(latitude: pt.latitude, longitude: pt.longitude)))
        }
        return minDist > 50
    }

    // MARK: - Stop Navigation
    @objc private func stopNavigation() {
        isNavigating = false; rerouteTimer?.invalidate()
        locationManager.stopUpdatingLocation(); locationManager.stopUpdatingHeading()
        UIView.animate(withDuration: 0.25) { self.dirBanner.isHidden = true; self.navOverlay.isHidden = true }
        UIView.animate(withDuration: 0.35) {
            self.mapHeightConstraint.constant = 260; self.scrollView.alpha = 1; self.view.layoutIfNeeded()
        }
        drawAllRoutes()
    }

    // MARK: - Actions
    @objc private func callHospital(_ sender: UIButton) {
        guard let phone = sender.accessibilityValue else { return }
        let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let url = URL(string: "tel://\(digits)") else { return }
        let alert = UIAlertController(title: "Call \(phone)?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Call", style: .default) { _ in UIApplication.shared.open(url) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func backTapped() { if isNavigating { stopNavigation() }; navigationController?.popViewController(animated: true) }

    // MARK: - Helpers
    private func maneuverIcon(_ maneuver: String, instruction: String) -> String {
        switch maneuver {
        case "turn-left", "turn-sharp-left":        return "⬅️"
        case "turn-right", "turn-sharp-right":      return "➡️"
        case "turn-slight-left":                    return "↖️"
        case "turn-slight-right":                   return "↗️"
        case "uturn-left", "uturn-right":           return "↩️"
        case "roundabout-left", "roundabout-right": return "🔄"
        case "merge":                               return "🔀"
        case "ramp-left", "fork-left":              return "↙️"
        case "ramp-right", "fork-right":            return "↘️"
        case "straight":                            return "⬆️"
        default:
            let l = instruction.lowercased()
            if l.contains("arrive") || l.contains("destination") { return "🏁" }
            if l.contains("left")  { return "⬅️" }
            if l.contains("right") { return "➡️" }
            return "⬆️"
        }
    }

    private func fmtDist(_ m: Double) -> String {
        m < 161 ? "In \(Int(m * 3.281)) ft" : String(format: "In %.1f mi", m / 1609.34)
    }
}

// MARK: - CLLocationManagerDelegate
extension HospitalRoutesViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy > 0, location.horizontalAccuracy < 50 else { return }
        let isFirst = (userLocation == nil); userLocation = location
        if isFirst, !pendingHospitals.isEmpty { calculateRoutes(from: location, to: pendingHospitals); pendingHospitals = [] }
        if isNavigating {
            updateDrivingCamera(location: location, heading: lastHeading)
            updateStep(userLocation: location)
            if isOffRoute(userLocation: location) { scheduleReroute(from: location) }
            else { rerouteTimer?.invalidate() }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading h: CLHeading) {
        guard h.headingAccuracy >= 0 else { return }; lastHeading = h.trueHeading
        if isNavigating, let loc = userLocation { updateDrivingCamera(location: loc, heading: lastHeading) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { print("❌ \(error)") }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways { locationManager.startUpdatingLocation(); locationManager.startUpdatingHeading() }
    }
}

// MARK: - GMSMapViewDelegate
extension HospitalRoutesViewController: GMSMapViewDelegate {}
