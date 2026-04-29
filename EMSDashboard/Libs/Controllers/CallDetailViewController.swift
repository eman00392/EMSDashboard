import UIKit
import MapKit
import CoreLocation

class CallDetailViewController: UIViewController {

    // MARK: - Properties
    let call: EMSCall
    private var userLocation: CLLocation?
    private let locationManager = CLLocationManager()

    // MARK: - UI
    private let mapView              = MKMapView()
    private let bottomCard           = UIView()
    private let pullHandle           = UIButton()
    private var cardIsVisible        = true
    private var cardBottomConstraint: NSLayoutConstraint!
    private var cardHeight: CGFloat  = 0

    private let etaLabel             = UILabel()
    private let distanceLabel        = UILabel()
    private let problemLabel         = UILabel()
    private let addressLabel         = UILabel()
    private let crossLabel           = UILabel()
    private let patientLabel         = UILabel()

    private let notesView            = AddressNotesView()

    // Navigation buttons
    private let googleMapsButton     = UIButton()
    private let appleMapsButton      = UIButton()
    private let wazeMapsButton       = UIButton()
    private let hospitalRoutesButton = UIButton()
    private let copyButton           = UIButton()

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
        setupMap()
        setupBottomCard()
        setupPullHandle()
        startLocationManager()

        // Load address notes
        notesView.configure(with: AddressNotesManager.shared.notes(for: call.address))
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshNotes),
            name: NSNotification.Name("EMSNotesUpdated"),
            object: nil
        )
    }

    @objc private func refreshNotes() {
        notesView.configure(with: AddressNotesManager.shared.notes(for: call.address))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if cardHeight == 0 { cardHeight = bottomCard.bounds.height }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Location
    private func startLocationManager() {
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
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

    // MARK: - Map (static — shows call location + route line)
    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.mapType           = .standard
        mapView.showsUserLocation = true
        mapView.showsTraffic      = true
        mapView.showsCompass      = true
        mapView.delegate          = self
        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        if call.hasLocation {
            let pin        = MKPointAnnotation()
            pin.coordinate = call.coordinate
            pin.title      = call.problem
            pin.subtitle   = call.address
            mapView.addAnnotation(pin)
            mapView.setRegion(MKCoordinateRegion(
                center: call.coordinate,
                latitudinalMeters: 1500,
                longitudinalMeters: 1500
            ), animated: false)
        }
    }

    // Draw route once we have user location
    private func drawRoute(from origin: CLLocation) {
        guard call.hasLocation else { return }
        let req           = MKDirections.Request()
        req.source        = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        req.destination   = MKMapItem(placemark: MKPlacemark(coordinate: call.coordinate))
        req.transportType = .automobile
        MKDirections(request: req).calculate { [weak self] response, _ in
            guard let self = self, let route = response?.routes.first else { return }
            self.mapView.addOverlay(route.polyline, level: .aboveRoads)
            self.mapView.setVisibleMapRect(
                route.polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: self.cardHeight + 40, right: 40),
                animated: true
            )
            let mins  = Int(route.expectedTravelTime / 60)
            let miles = route.distance / 1609.34
            self.etaLabel.text      = "ETA: ~\(mins) min"
            self.etaLabel.textColor = .systemGreen
            self.distanceLabel.text = String(format: "%.1f mi", miles)
        }
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
        etaLabel.text      = "📍 Getting location..."
        etaLabel.font      = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        etaLabel.textColor = UIColor(white: 0.5, alpha: 1)
        distanceLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        distanceLabel.textColor = UIColor(white: 0.5, alpha: 1)
        distanceLabel.textAlignment = .right
        let etaRow = UIStackView(arrangedSubviews: [etaLabel, UIView(), distanceLabel])
        etaRow.axis = .horizontal

        // Address
        addressLabel.text      = call.address
        addressLabel.font      = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        addressLabel.textColor = UIColor(white: 0.5, alpha: 1)
        addressLabel.numberOfLines = 2

        // Cross
        crossLabel.font      = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        crossLabel.textColor = UIColor(white: 0.4, alpha: 1)
        crossLabel.isHidden  = call.cross.isEmpty
        crossLabel.text      = call.cross.isEmpty ? "" : "Cross: \(call.cross)"

        // Problem
        problemLabel.text      = call.displayProblem
        problemLabel.font      = .systemFont(ofSize: 22, weight: .heavy)
        problemLabel.textColor = .systemRed
        problemLabel.numberOfLines = 2

        // Patient
        let patient = call.patientSummary
        patientLabel.font      = .systemFont(ofSize: 13, weight: .semibold)
        patientLabel.textColor = .systemYellow
        patientLabel.isHidden  = (patient == "No patient info")
        patientLabel.text      = patient == "No patient info" ? "" : "🧑‍⚕️  \(patient)"

        // ── Navigation section header ──
        let navHeader = UILabel()
        navHeader.text      = "NAVIGATE TO SCENE"
        navHeader.font      = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        navHeader.textColor = UIColor(white: 0.4, alpha: 1)

        // ── Google Maps ──
        styleNavButton(googleMapsButton,
                       title: "Open in Google Maps",
                       icon: "car.fill",
                       bg: UIColor(red: 0.13, green: 0.37, blue: 0.18, alpha: 1),
                       tint: UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1))
        googleMapsButton.addTarget(self, action: #selector(openGoogleMaps), for: .touchUpInside)

        // ── Apple Maps ──
        styleNavButton(appleMapsButton,
                       title: "Open in Apple Maps",
                       icon: "map.fill",
                       bg: UIColor(red: 0.1, green: 0.25, blue: 0.45, alpha: 1),
                       tint: UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1))
        appleMapsButton.addTarget(self, action: #selector(openAppleMaps), for: .touchUpInside)

        // ── Waze ──
        styleNavButton(wazeMapsButton,
                       title: "Open in Waze",
                       icon: "location.fill",
                       bg: UIColor(red: 0.35, green: 0.28, blue: 0.0, alpha: 1),
                       tint: UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1))
        wazeMapsButton.addTarget(self, action: #selector(openWaze), for: .touchUpInside)

        // Nav buttons in a 3-column grid row
        let navRow = UIStackView(arrangedSubviews: [googleMapsButton, appleMapsButton, wazeMapsButton])
        navRow.axis = .horizontal; navRow.spacing = 8; navRow.distribution = .fillEqually

        // ── Hospital Routes ──
        var hospCfg = UIButton.Configuration.filled()
        hospCfg.title               = "🏥  Hospital Routes"
        hospCfg.baseBackgroundColor = UIColor(red: 0.1, green: 0.35, blue: 0.55, alpha: 1)
        hospCfg.cornerStyle         = .large
        hospCfg.contentInsets       = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
        hospitalRoutesButton.configuration = hospCfg
        hospitalRoutesButton.addTarget(self, action: #selector(hospitalRoutesTapped), for: .touchUpInside)

        // ── Copy ──
        var copyCfg = UIButton.Configuration.tinted()
        copyCfg.title               = "📋  Copy Address"
        copyCfg.baseForegroundColor = .systemGray
        copyCfg.baseBackgroundColor = UIColor(white: 0.15, alpha: 1)
        copyCfg.cornerStyle         = .large
        copyCfg.contentInsets       = NSDirectionalEdgeInsets(top: 11, leading: 0, bottom: 11, trailing: 0)
        copyButton.configuration = copyCfg
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)

        let infoStack = UIStackView(arrangedSubviews: [
            etaRow, makeDivider(),
            addressLabel, crossLabel, problemLabel, patientLabel,
            notesView,
            makeDivider(),
            navHeader, navRow,
            hospitalRoutesButton, copyButton
        ])
        infoStack.axis      = .vertical
        infoStack.spacing   = 10
        infoStack.alignment = .fill
        infoStack.setCustomSpacing(4,  after: addressLabel)
        infoStack.setCustomSpacing(10, after: crossLabel)
        infoStack.setCustomSpacing(14, after: makeDivider())
        infoStack.setCustomSpacing(6,  after: navHeader)
        infoStack.setCustomSpacing(8,  after: navRow)
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        bottomCard.addSubview(infoStack)

        NSLayoutConstraint.activate([
            infoStack.topAnchor.constraint(equalTo: bottomCard.topAnchor, constant: 20),
            infoStack.bottomAnchor.constraint(equalTo: bottomCard.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            infoStack.leadingAnchor.constraint(equalTo: bottomCard.leadingAnchor, constant: 20),
            infoStack.trailingAnchor.constraint(equalTo: bottomCard.trailingAnchor, constant: -20)
        ])
    }

    private func styleNavButton(_ btn: UIButton, title: String, icon: String, bg: UIColor, tint: UIColor) {
        var cfg = UIButton.Configuration.filled()
        cfg.title               = title
        cfg.image               = UIImage(systemName: icon)
        cfg.imagePlacement      = .top
        cfg.imagePadding        = 6
        cfg.baseBackgroundColor = bg
        cfg.baseForegroundColor = tint
        cfg.cornerStyle         = .large
        cfg.contentInsets       = NSDirectionalEdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4)
        btn.configuration = cfg
        btn.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        btn.titleLabel?.numberOfLines = 2
        btn.titleLabel?.textAlignment = .center
    }

    // MARK: - Navigation Actions

    @objc private func openGoogleMaps() {
        let lat = call.lat; let lng = call.lng
        let addr = call.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try app first, fall back to web
        let appURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")
        let webURL = URL(string: "https://maps.google.com/?daddr=\(lat),\(lng)&directionsmode=driving")
        let addrURL = URL(string: "https://maps.google.com/?daddr=\(addr)&directionsmode=driving")

        if let url = appURL, call.hasLocation, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if call.hasLocation, let url = webURL {
            UIApplication.shared.open(url)
        } else if let url = addrURL {
            UIApplication.shared.open(url)
        }
    }

    @objc private func openAppleMaps() {
        if call.hasLocation {
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: call.coordinate))
            mapItem.name = call.address
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
        } else {
            // Address-based fallback
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(call.address) { placemarks, _ in
                guard let placemark = placemarks?.first else { return }
                let mkPlacemark = MKPlacemark(placemark: placemark)
                let mapItem     = MKMapItem(placemark: mkPlacemark)
                mapItem.name    = self.call.address
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            }
        }
    }

    @objc private func openWaze() {
        let addr = call.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let lat = call.lat; let lng = call.lng

        // Waze deep link
        let appURL = call.hasLocation
            ? URL(string: "waze://?ll=\(lat),\(lng)&navigate=yes")
            : URL(string: "waze://?q=\(addr)&navigate=yes")
        let webURL = call.hasLocation
            ? URL(string: "https://waze.com/ul?ll=\(lat),\(lng)&navigate=yes")
            : URL(string: "https://waze.com/ul?q=\(addr)&navigate=yes")

        if let url = appURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = webURL {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Other Actions

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
        navigationController?.popViewController(animated: true)
    }

    private func makeDivider() -> UIView {
        let v = UIView(); v.backgroundColor = UIColor(white: 0.2, alpha: 1)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true; return v
    }
}

// MARK: - CLLocationManagerDelegate
extension CallDetailViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              location.horizontalAccuracy > 0,
              location.horizontalAccuracy < 100,
              userLocation == nil else { return }
        userLocation = location
        drawRoute(from: location)
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - MKMapViewDelegate
extension CallDetailViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
        let r = MKPolylineRenderer(polyline: polyline)
        r.strokeColor = .systemBlue; r.lineWidth = 5; r.lineCap = .round; r.lineJoin = .round
        return r
    }
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        let pin = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "call")
        pin.markerTintColor = .systemRed
        pin.glyphImage      = UIImage(systemName: "cross.fill")
        pin.canShowCallout  = true
        return pin
    }
}
