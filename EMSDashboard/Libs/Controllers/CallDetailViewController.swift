import UIKit
import GoogleMaps
import CoreLocation

// ⚠️ Replace with your Google Maps API key (same one passed to GMSServices.provideAPIKey)
private let kGoogleAPIKey = "AIzaSyA11vd0wsPQBOZxNY1KiSI15cuFMEhFwUU"

class CallDetailViewController: UIViewController {

    // MARK: - Properties
    let call: EMSCall

    private var mapView:           GMSMapView!
    private var currentPolyline:   GMSPolyline?
    private var routeSteps:        [GoogleStep] = []
    private var currentStepIndex:  Int = 0
    private var isNavigating       = false
    private var cardIsVisible      = true
    private var userLocation:      CLLocation?
    private var lastHeading:       CLLocationDirection = 0
    private var rerouteTimer:      Timer?
    private let locationManager    = CLLocationManager()

    // MARK: - UI
    private let directionBanner    = UIView()
    private let dirBannerIcon      = UILabel()
    private let dirBannerText      = UILabel()
    private let dirBannerDist      = UILabel()
    private let bottomCard         = UIView()
    private let pullHandle         = UIButton()
    private let etaLabel           = UILabel()
    private let distanceLabel      = UILabel()
    private let problemLabel       = UILabel()
    private let addressLabel       = UILabel()
    private let crossLabel         = UILabel()
    private let patientLabel       = UILabel()
    private let navigateButton     = UIButton()
    private let hospitalRoutesButton = UIButton()
    private let googleMapsButton   = UIButton()
    private let copyButton         = UIButton()

    private var cardBottomConstraint: NSLayoutConstraint!
    private var cardHeight: CGFloat = 0

    // MARK: - Init
    init(call: EMSCall, dispatchStartTime: Date = Date()) {
        self.call = call
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        setupNavBar()
        setupGoogleMap()
        setupDirectionBanner()
        setupBottomCard()
        setupPullHandle()
        startLocationManager()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if cardHeight == 0 { cardHeight = bottomCard.bounds.height }
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
        title = "LAST CALL"
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        ]
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        let back = UIBarButtonItem(title: "◀  Dashboard", style: .plain, target: self, action: #selector(backTapped))
        back.tintColor = .systemRed
        navigationItem.leftBarButtonItem = back
        navigationItem.hidesBackButton   = true
    }

    // MARK: - Google Map Setup
    private func setupGoogleMap() {
        // Start camera centred on call location, or a default
        let startCoord = call.hasLocation
            ? call.coordinate
            : CLLocationCoordinate2D(latitude: 40.9, longitude: -73.85)

        let camera  = GMSCameraPosition(target: startCoord, zoom: 14, bearing: 0, viewingAngle: 0)
        mapView     = GMSMapView(frame: .zero, camera: camera)
        mapView.isMyLocationEnabled    = true
        mapView.settings.myLocationButton = false   // we control camera manually
        mapView.settings.compassButton    = true
        mapView.delegate                  = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Drop marker at call location
        if call.hasLocation {
            let marker       = GMSMarker(position: call.coordinate)
            marker.title     = call.problem
            marker.snippet   = call.address
            marker.icon      = GMSMarker.markerImage(with: .systemRed)
            marker.map       = mapView
        }
    }

    // MARK: - Direction Banner
    private func setupDirectionBanner() {
        directionBanner.backgroundColor     = UIColor(red: 0.04, green: 0.09, blue: 0.18, alpha: 0.97)
        directionBanner.layer.shadowColor   = UIColor.black.cgColor
        directionBanner.layer.shadowOpacity = 0.4
        directionBanner.layer.shadowRadius  = 8
        directionBanner.layer.shadowOffset  = CGSize(width: 0, height: 3)
        directionBanner.isHidden            = true
        directionBanner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(directionBanner)

        NSLayoutConstraint.activate([
            directionBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            directionBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            directionBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        dirBannerIcon.font = .systemFont(ofSize: 40); dirBannerIcon.text = "⬆️"
        dirBannerIcon.setContentHuggingPriority(.required, for: .horizontal)
        dirBannerText.font = .systemFont(ofSize: 17, weight: .bold)
        dirBannerText.textColor = .white; dirBannerText.numberOfLines = 2
        dirBannerDist.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
        dirBannerDist.textColor = UIColor(white: 0.6, alpha: 1)

        let textCol = UIStackView(arrangedSubviews: [dirBannerText, dirBannerDist])
        textCol.axis = .vertical; textCol.spacing = 2; textCol.alignment = .leading

        let row = UIStackView(arrangedSubviews: [dirBannerIcon, textCol])
        row.axis = .horizontal; row.spacing = 14; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        directionBanner.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: directionBanner.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: directionBanner.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: directionBanner.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: directionBanner.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Bottom Card
    private func setupBottomCard() {
        bottomCard.backgroundColor     = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 0.97)
        bottomCard.layer.cornerRadius  = 24
        bottomCard.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomCard.layer.shadowColor   = UIColor.black.cgColor
        bottomCard.layer.shadowOpacity = 0.4
        bottomCard.layer.shadowOffset  = CGSize(width: 0, height: -4)
        bottomCard.layer.shadowRadius  = 12
        bottomCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomCard)

        cardBottomConstraint = bottomCard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            cardBottomConstraint,
            bottomCard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomCard.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        buildBottomCardContent()
    }

    private func setupPullHandle() {
        pullHandle.translatesAutoresizingMaskIntoConstraints = false
        pullHandle.backgroundColor     = UIColor(white: 0.15, alpha: 0.92)
        pullHandle.layer.cornerRadius  = 18
        pullHandle.layer.shadowColor   = UIColor.black.cgColor
        pullHandle.layer.shadowOpacity = 0.3
        pullHandle.layer.shadowRadius  = 6
        pullHandle.layer.shadowOffset  = CGSize(width: 0, height: -2)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        pullHandle.setImage(UIImage(systemName: "chevron.down", withConfiguration: cfg), for: .normal)
        pullHandle.tintColor = .white
        pullHandle.addTarget(self, action: #selector(toggleCard), for: .touchUpInside)
        view.addSubview(pullHandle)

        NSLayoutConstraint.activate([
            pullHandle.widthAnchor.constraint(equalToConstant: 44),
            pullHandle.heightAnchor.constraint(equalToConstant: 36),
            pullHandle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            pullHandle.bottomAnchor.constraint(equalTo: bottomCard.topAnchor, constant: -8)
        ])
    }

    @objc private func toggleCard() {
        cardIsVisible.toggle()
        if cardHeight == 0 { cardHeight = bottomCard.bounds.height }
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        pullHandle.setImage(UIImage(systemName: cardIsVisible ? "chevron.down" : "chevron.up", withConfiguration: cfg), for: .normal)
        cardBottomConstraint.constant = cardIsVisible ? 0 : cardHeight
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    private func buildBottomCardContent() {
        // ETA row
        etaLabel.text = "📍 Getting location..."
        etaLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        etaLabel.textColor = UIColor(white: 0.5, alpha: 1)
        distanceLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        distanceLabel.textColor = UIColor(white: 0.5, alpha: 1); distanceLabel.textAlignment = .right
        let etaRow = UIStackView(arrangedSubviews: [etaLabel, UIView(), distanceLabel])
        etaRow.axis = .horizontal

        // Address (above problem — small, muted)
        addressLabel.text = call.address
        addressLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        addressLabel.textColor = UIColor(white: 0.5, alpha: 1); addressLabel.numberOfLines = 2

        // Cross street
        crossLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        crossLabel.textColor = UIColor(white: 0.4, alpha: 1)
        crossLabel.isHidden = call.cross.isEmpty
        crossLabel.text = call.cross.isEmpty ? "" : "Cross: \(call.cross)"

        // Problem (big headline)
        problemLabel.text = call.problem.uppercased()
        problemLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        problemLabel.textColor = .systemRed; problemLabel.numberOfLines = 2

        // Patient
        let patient = call.patientSummary
        patientLabel.font = .systemFont(ofSize: 13, weight: .semibold); patientLabel.textColor = .systemYellow
        patientLabel.isHidden = (patient == "No patient info")
        patientLabel.text = patient == "No patient info" ? "" : "🧑‍⚕️  \(patient)"

        // Navigate button
        var navCfg = UIButton.Configuration.filled()
        navCfg.title = "📍  Getting location..."; navCfg.baseBackgroundColor = .systemGray
        navCfg.cornerStyle = .large; navCfg.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 0, bottom: 14, trailing: 0)
        navigateButton.configuration = navCfg; navigateButton.isEnabled = false
        navigateButton.addTarget(self, action: #selector(navigateTapped), for: .touchUpInside)

        // Hospital Routes button
        var hospCfg = UIButton.Configuration.filled()
        hospCfg.title = "🏥  Hospital Routes"
        hospCfg.baseBackgroundColor = UIColor(red: 0.1, green: 0.35, blue: 0.55, alpha: 1)
        hospCfg.cornerStyle = .large; hospCfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
        hospitalRoutesButton.configuration = hospCfg
        hospitalRoutesButton.addTarget(self, action: #selector(hospitalRoutesTapped), for: .touchUpInside)

        // Open in Google Maps button
        var gmapCfg = UIButton.Configuration.tinted()
        gmapCfg.title               = "🗺  Open in Google Maps"
        gmapCfg.baseForegroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1)
        gmapCfg.baseBackgroundColor = UIColor(red: 0.1, green: 0.25, blue: 0.1, alpha: 1)
        gmapCfg.cornerStyle         = .large
        gmapCfg.contentInsets       = NSDirectionalEdgeInsets(top: 11, leading: 0, bottom: 11, trailing: 0)
        googleMapsButton.configuration = gmapCfg
        googleMapsButton.addTarget(self, action: #selector(openInGoogleMaps), for: .touchUpInside)

        // Copy button
        var copyCfg = UIButton.Configuration.tinted()
        copyCfg.title = "📋  Copy Address"; copyCfg.baseForegroundColor = .systemGray
        copyCfg.baseBackgroundColor = UIColor(white: 0.15, alpha: 1); copyCfg.cornerStyle = .large
        copyCfg.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 0, bottom: 11, trailing: 0)
        copyButton.configuration = copyCfg
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)

        let infoStack = UIStackView(arrangedSubviews: [
            etaRow, makeDivider(),
            addressLabel, crossLabel, problemLabel, patientLabel,
            navigateButton, hospitalRoutesButton, googleMapsButton, copyButton
        ])
        infoStack.axis = .vertical; infoStack.spacing = 10; infoStack.alignment = .fill
        infoStack.setCustomSpacing(4, after: addressLabel)
        infoStack.setCustomSpacing(10, after: crossLabel)
        infoStack.setCustomSpacing(14, after: makeDivider())
        infoStack.setCustomSpacing(8, after: problemLabel)
        infoStack.setCustomSpacing(8, after: navigateButton)
        infoStack.setCustomSpacing(8, after: hospitalRoutesButton)
        infoStack.setCustomSpacing(8, after: googleMapsButton)
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        bottomCard.addSubview(infoStack)

        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: bottomCard.topAnchor, constant: 20),
            infoStack.bottomAnchor.constraint(equalTo: bottomCard.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            infoStack.leadingAnchor.constraint(equalTo: bottomCard.leadingAnchor, constant: 20),
            infoStack.trailingAnchor.constraint(equalTo: bottomCard.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Google Directions API
    // Fetches a driving route from origin to destination.
    // Returns decoded polyline + step list via callback.

    private func fetchRoute(from origin: CLLocationCoordinate2D,
                            to destination: CLLocationCoordinate2D,
                            completion: @escaping ([GoogleStep], GMSPolyline?, String, String) -> Void) {

        let urlStr = "https://maps.googleapis.com/maps/api/directions/json" +
            "?origin=\(origin.latitude),\(origin.longitude)" +
            "&destination=\(destination.latitude),\(destination.longitude)" +
            "&mode=driving&departure_time=now" +
            "&key=\(kGoogleAPIKey)"

        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let first  = routes.first,
                  let legs   = first["legs"] as? [[String: Any]],
                  let leg    = legs.first
            else {
                print("❌ Directions API error: \(error?.localizedDescription ?? "no data")")
                return
            }

            // ETA + Distance
            let duration = (leg["duration_in_traffic"] as? [String: Any]
                         ?? leg["duration"]            as? [String: Any])?["text"] as? String ?? "—"
            let distance = (leg["distance"] as? [String: Any])?["text"] as? String ?? "—"

            // Steps
            let rawSteps = leg["steps"] as? [[String: Any]] ?? []
            let steps: [GoogleStep] = rawSteps.compactMap { s in
                guard
                    let html    = s["html_instructions"] as? String,
                    let endLoc  = s["end_location"] as? [String: Double],
                    let endLat  = endLoc["lat"], let endLng = endLoc["lng"],
                    let distMap = s["distance"] as? [String: Any],
                    let distM   = distMap["value"] as? Double
                else { return nil }

                let instruction = html
                    .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                    .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                let maneuver = s["maneuver"] as? String ?? ""
                return GoogleStep(
                    instruction: instruction,
                    maneuver:    maneuver,
                    endLocation: CLLocationCoordinate2D(latitude: endLat, longitude: endLng),
                    distanceM:   distM
                )
            }

            // Decode polyline
            let encodedPoly = (first["overview_polyline"] as? [String: Any])?["points"] as? String ?? ""
            let path        = GMSPath(fromEncodedPath: encodedPoly)
            let polyline    = GMSPolyline(path: path)
            polyline.strokeWidth = 6
            polyline.strokeColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1)

            DispatchQueue.main.async {
                completion(steps, polyline, duration, distance)
            }
        }.resume()
    }

    // MARK: - Draw Route (overview)
    private func drawRoute(from origin: CLLocation) {
        guard call.hasLocation else { return }
        fetchRoute(from: origin.coordinate, to: call.coordinate) { [weak self] steps, polyline, duration, distance in
            guard let self = self else { return }
            self.routeSteps = steps
            self.currentStepIndex = 0

            // Remove old route
            self.currentPolyline?.map = nil
            polyline?.map = self.mapView
            self.currentPolyline = polyline

            // Fit camera to route
            if let path = polyline?.path {
                let bounds = GMSCoordinateBounds(path: path)
                let update = GMSCameraUpdate.fit(bounds, with: UIEdgeInsets(top: 80, left: 40, bottom: self.cardHeight + 40, right: 40))
                self.mapView.animate(with: update)
            }

            // Update ETA
            self.etaLabel.text      = "ETA: \(duration)"
            self.etaLabel.textColor = .systemGreen
            self.distanceLabel.text = distance

            // Enable navigate button
            var cfg = self.navigateButton.configuration
            cfg?.title = "▶  Start Navigation"; cfg?.baseBackgroundColor = .systemBlue
            self.navigateButton.configuration = cfg; self.navigateButton.isEnabled = true
        }
    }

    // MARK: - GPS Driving Camera
    private func updateDrivingCamera(location: CLLocation, heading: CLLocationDirection) {
        let camera = GMSCameraPosition(
            target:      location.coordinate,
            zoom:        18,           // street-level zoom
            bearing:     heading,      // map rotates with travel direction
            viewingAngle: 65           // 65° tilt = road fills screen like a GPS
        )
        mapView.animate(to: camera)
    }

    // MARK: - Step Detection
    private func updateStep(userLocation: CLLocation) {
        guard currentStepIndex < routeSteps.count else { return }
        let step    = routeSteps[currentStepIndex]
        let stepEnd = CLLocation(latitude: step.endLocation.latitude, longitude: step.endLocation.longitude)

        if userLocation.distance(from: stepEnd) < 25,
           currentStepIndex + 1 < routeSteps.count {
            currentStepIndex += 1
            flashBanner()
        }

        let cur    = routeSteps[currentStepIndex]
        let curEnd = CLLocation(latitude: cur.endLocation.latitude, longitude: cur.endLocation.longitude)
        dirBannerIcon.text = maneuverIcon(cur.maneuver, instruction: cur.instruction)
        dirBannerText.text = cur.instruction.isEmpty ? "Continue" : cur.instruction
        dirBannerDist.text = fmtDist(userLocation.distance(from: curEnd))
    }

    // MARK: - Reroute (off route > 50m for 8 seconds)
    private func scheduleReroute(from location: CLLocation) {
        rerouteTimer?.invalidate()
        rerouteTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            guard let self = self, self.isNavigating else { return }
            print("🔄 Rerouting...")
            self.fetchRoute(from: location.coordinate, to: self.call.coordinate) { steps, polyline, duration, distance in
                self.routeSteps = steps; self.currentStepIndex = 0
                self.currentPolyline?.map = nil
                polyline?.map = self.mapView; self.currentPolyline = polyline
                self.etaLabel.text = "ETA: \(duration)"; self.distanceLabel.text = distance
            }
        }
    }

    private func isOffRoute(userLocation: CLLocation) -> Bool {
        guard let path = currentPolyline?.path else { return false }
        var minDist = Double.greatestFiniteMagnitude
        for i in 0..<path.count() {
            let pt  = path.coordinate(at: i)
            let loc = CLLocation(latitude: pt.latitude, longitude: pt.longitude)
            minDist = min(minDist, userLocation.distance(from: loc))
        }
        return minDist > 50
    }

    // MARK: - Navigation Start / Stop
    @objc private func navigateTapped() {
        guard call.hasLocation, let loc = userLocation else { return }
        isNavigating = true; currentStepIndex = 0

        UIView.animate(withDuration: 0.25) { self.directionBanner.isHidden = false }

        if let first = routeSteps.first {
            dirBannerIcon.text = maneuverIcon(first.maneuver, instruction: first.instruction)
            dirBannerText.text = first.instruction.isEmpty ? "Head toward \(call.address)" : first.instruction
            dirBannerDist.text = fmtDist(first.distanceM)
        }

        var cfg = navigateButton.configuration
        cfg?.title = "■  Stop Navigation"; cfg?.baseBackgroundColor = .systemRed
        navigateButton.configuration = cfg
        navigateButton.removeTarget(self, action: #selector(navigateTapped), for: .touchUpInside)
        navigateButton.addTarget(self, action: #selector(stopNavigation), for: .touchUpInside)

        if cardIsVisible { toggleCard() }
        updateDrivingCamera(location: loc, heading: lastHeading)
    }

    @objc private func stopNavigation() {
        isNavigating = false; rerouteTimer?.invalidate()
        UIView.animate(withDuration: 0.25) { self.directionBanner.isHidden = true }

        // Return to overview
        if let path = currentPolyline?.path {
            let bounds = GMSCoordinateBounds(path: path)
            let update = GMSCameraUpdate.fit(bounds, with: UIEdgeInsets(top: 80, left: 40, bottom: cardHeight + 40, right: 40))
            mapView.animate(with: update)
        }

        var cfg = navigateButton.configuration
        cfg?.title = "▶  Start Navigation"; cfg?.baseBackgroundColor = .systemBlue
        navigateButton.configuration = cfg
        navigateButton.removeTarget(self, action: #selector(stopNavigation), for: .touchUpInside)
        navigateButton.addTarget(self, action: #selector(navigateTapped), for: .touchUpInside)

        if !cardIsVisible { toggleCard() }
    }

    // MARK: - Helpers
    private func maneuverIcon(_ maneuver: String, instruction: String) -> String {
        switch maneuver {
        case "turn-left", "turn-sharp-left":    return "⬅️"
        case "turn-right", "turn-sharp-right":  return "➡️"
        case "turn-slight-left":                return "↖️"
        case "turn-slight-right":               return "↗️"
        case "uturn-left", "uturn-right":       return "↩️"
        case "roundabout-left", "roundabout-right": return "🔄"
        case "merge":                           return "🔀"
        case "ramp-left":                       return "↙️"
        case "ramp-right":                      return "↘️"
        case "fork-left":                       return "↙️"
        case "fork-right":                      return "↘️"
        case "ferry":                           return "⛴️"
        case "straight":                        return "⬆️"
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

    private func flashBanner() {
        UIView.animate(withDuration: 0.15, animations: { self.directionBanner.alpha = 0.3 }) { _ in
            UIView.animate(withDuration: 0.2) { self.directionBanner.alpha = 1 }
        }
    }

    private func makeDivider() -> UIView {
        let v = UIView(); v.backgroundColor = UIColor(white: 0.2, alpha: 1)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true; return v
    }

    // MARK: - Actions
    @objc private func openInGoogleMaps() {
        guard call.hasLocation else {
            // Fallback to address search if no GPS coordinates
            let encoded = call.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "comgooglemaps://?q=\(encoded)"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else if let url = URL(string: "https://maps.google.com/?q=\(encoded)") {
                UIApplication.shared.open(url)
            }
            return
        }
        let lat = call.lat; let lng = call.lng
        let gmapsURL  = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")
        let webURL    = URL(string: "https://maps.google.com/?daddr=\(lat),\(lng)&directionsmode=driving")
        if let url = gmapsURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = webURL {
            UIApplication.shared.open(url)
        }
    }

    @objc private func hospitalRoutesTapped() {
        navigationController?.pushViewController(HospitalRoutesViewController(call: call), animated: true)
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = call.address
        var c = copyButton.configuration; c?.title = "✅  Copied!"; copyButton.configuration = c
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            var r = self?.copyButton.configuration; r?.title = "📋  Copy Address"
            self?.copyButton.configuration = r
        }
    }

    @objc private func backTapped() {
        if isNavigating { stopNavigation() }
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - CLLocationManagerDelegate
extension CallDetailViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              location.horizontalAccuracy > 0,
              location.horizontalAccuracy < 50 else { return }

        let isFirst  = (userLocation == nil)
        userLocation = location

        if isFirst {
            print("📍 GPS fix ±\(Int(location.horizontalAccuracy))m")
            drawRoute(from: location)
        }

        if isNavigating {
            updateDrivingCamera(location: location, heading: lastHeading)
            updateStep(userLocation: location)
            if isOffRoute(userLocation: location) { scheduleReroute(from: location) }
            else { rerouteTimer?.invalidate() }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        lastHeading = newHeading.trueHeading
        if isNavigating, let loc = userLocation {
            updateDrivingCamera(location: loc, heading: lastHeading)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }
}

// MARK: - GMSMapViewDelegate
extension CallDetailViewController: GMSMapViewDelegate {}

// MARK: - Google Step Model
struct GoogleStep {
    let instruction: String
    let maneuver:    String
    let endLocation: CLLocationCoordinate2D
    let distanceM:   Double
}
