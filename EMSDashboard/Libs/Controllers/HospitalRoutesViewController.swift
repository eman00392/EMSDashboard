import UIKit
import MapKit
import CoreLocation

// MARK: - Hospital Routes View Controller
// Shows 6 hardcoded hospitals sorted by distance.
// Navigation opens Google Maps, Apple Maps, or Waze.

class HospitalRoutesViewController: UIViewController {

    // MARK: - Properties
    private let call: EMSCall
    private var hospitals:   [HospitalResult] = []
    private var userLocation: CLLocation?
    private let locationManager = CLLocationManager()

    // MARK: - UI
    private let mapView      = MKMapView()
    private let spinner      = UIActivityIndicatorView(style: .medium)
    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()
    private let statusLabel  = UILabel()
    private let hospitalStack = UIStackView()
    private var mapHeightConstraint: NSLayoutConstraint!

    // MARK: - Init
    init(call: EMSCall) { self.call = call; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        setupNavBar()
        setupMap()
        setupScrollView()
        buildHeader()
        buildHospitalSection()
        startLocationManager()
        loadHospitals()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Location
    private func startLocationManager() {
        locationManager.delegate        = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
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

    // MARK: - Map (static overview)
    private func setupMap() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.mapType           = .standard
        mapView.showsUserLocation = true
        mapView.showsTraffic      = true
        mapView.showsCompass      = true
        mapView.delegate          = self
        view.addSubview(mapView)

        mapHeightConstraint = mapView.heightAnchor.constraint(equalToConstant: 220)
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

        if call.hasLocation {
            let pin = MKPointAnnotation(); pin.coordinate = call.coordinate; pin.title = call.problem
            mapView.addAnnotation(pin)
            mapView.setRegion(MKCoordinateRegion(center: call.coordinate, latitudinalMeters: 20000, longitudinalMeters: 20000), animated: false)
        }
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
        let a = UILabel(); a.text = call.address
        a.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        a.textColor = UIColor(white: 0.5, alpha: 1); a.numberOfLines = 2
        let s = UIStackView(arrangedSubviews: [p, a]); s.axis = .vertical; s.spacing = 4
        contentStack.addArrangedSubview(s)
    }

    private func buildHospitalSection() {
        let hdr = UILabel(); hdr.text = "🏥  SELECT HOSPITAL"
        hdr.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        hdr.textColor = UIColor(white: 0.45, alpha: 1)

        statusLabel.text = "Loading hospitals..."
        statusLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = UIColor(white: 0.4, alpha: 1); statusLabel.textAlignment = .center

        hospitalStack.axis = .vertical; hospitalStack.spacing = 12; hospitalStack.alignment = .fill

        let sec = UIStackView(arrangedSubviews: [hdr, statusLabel, hospitalStack])
        sec.axis = .vertical; sec.spacing = 10
        contentStack.addArrangedSubview(sec)
    }

    // MARK: - Load Hospitals
    private func loadHospitals() {
        HospitalFinder.shared.findNearestHospitals(near: call.coordinate) { [weak self] results in
            guard let self = self else { return }
            self.hospitals = results
            self.spinner.stopAnimating()
            self.statusLabel.isHidden = true
            results.forEach { self.hospitalStack.addArrangedSubview(self.makeHospitalCard($0)) }
            self.addHospitalPinsToMap(results)
        }
    }

    // MARK: - Hospital Card
    private func makeHospitalCard(_ hospital: HospitalResult) -> UIView {
        let info = HospitalConfig.shared.info(for: hospital.name)

        let card = UIView()
        card.backgroundColor    = UIColor(white: 0.1, alpha: 1)
        card.layer.cornerRadius = 16
        card.layer.borderWidth  = 1
        card.layer.borderColor  = UIColor(white: 0.18, alpha: 1).cgColor

        // Name
        let nameL = UILabel(); nameL.text = hospital.name
        nameL.font = .systemFont(ofSize: 15, weight: .bold); nameL.textColor = .white; nameL.numberOfLines = 2

        // Distance
        let distL = UILabel(); distL.text = hospital.distanceString
        distL.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        distL.textColor = UIColor(white: 0.5, alpha: 1); distL.textAlignment = .right
        distL.setContentHuggingPriority(.required, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [nameL, distL])
        topRow.axis = .horizontal; topRow.spacing = 8; topRow.alignment = .center

        var rows: [UIView] = [topRow]

        // Phone
        if let phone = info?.phone, !phone.isEmpty {
            let btn = UIButton(type: .system)
            btn.setTitle("📞  \(phone)", for: .normal)
            btn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
            btn.tintColor = .systemGreen; btn.contentHorizontalAlignment = .left
            btn.accessibilityValue = phone
            btn.addTarget(self, action: #selector(callHospital(_:)), for: .touchUpInside)
            rows.append(btn)
        }

        // Door code
        if let code = info?.doorCode, !code.isEmpty {
            let l = UILabel(); l.text = "🚪 Door Code:"
            l.font = .systemFont(ofSize: 12); l.textColor = UIColor(white: 0.45, alpha: 1)
            l.setContentHuggingPriority(.required, for: .horizontal)
            let v = UILabel(); v.text = code
            v.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            v.textColor = .systemYellow; v.textAlignment = .right
            let row = UIStackView(arrangedSubviews: [l, UIView(), v])
            row.axis = .horizontal; row.alignment = .center; row.spacing = 8
            rows.append(row)
        }

        // Notes
        if let notes = info?.notes, !notes.isEmpty {
            let n = UILabel(); n.text = notes; n.font = .systemFont(ofSize: 11)
            n.textColor = UIColor(white: 0.45, alpha: 1); n.numberOfLines = 2
            rows.append(n)
        }

        rows.append(makeDivider())

        // ── Navigation buttons ──
        let navLabel = UILabel(); navLabel.text = "NAVIGATE"
        navLabel.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .bold)
        navLabel.textColor = UIColor(white: 0.35, alpha: 1)
        rows.append(navLabel)

        let gBtn = makeMapButton(title: "Google Maps", icon: "car.fill",
                                  bg: UIColor(red: 0.13, green: 0.37, blue: 0.18, alpha: 1),
                                  tint: UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1))
        let aBtn = makeMapButton(title: "Apple Maps", icon: "map.fill",
                                  bg: UIColor(red: 0.1, green: 0.25, blue: 0.45, alpha: 1),
                                  tint: UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1))
        let wBtn = makeMapButton(title: "Waze", icon: "location.fill",
                                  bg: UIColor(red: 0.35, green: 0.28, blue: 0.0, alpha: 1),
                                  tint: UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1))

        // Tag hospital onto buttons via accessibilityLabel
        let tag = hospital.name
        gBtn.accessibilityLabel = "google|\(tag)"
        aBtn.accessibilityLabel = "apple|\(tag)"
        wBtn.accessibilityLabel = "waze|\(tag)"
        gBtn.addTarget(self, action: #selector(navButtonTapped(_:)), for: .touchUpInside)
        aBtn.addTarget(self, action: #selector(navButtonTapped(_:)), for: .touchUpInside)
        wBtn.addTarget(self, action: #selector(navButtonTapped(_:)), for: .touchUpInside)

        let navRow = UIStackView(arrangedSubviews: [gBtn, aBtn, wBtn])
        navRow.axis = .horizontal; navRow.spacing = 8; navRow.distribution = .fillEqually
        rows.append(navRow)

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical; stack.spacing = 8; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }

    private func makeMapButton(title: String, icon: String, bg: UIColor, tint: UIColor) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title               = title
        cfg.image               = UIImage(systemName: icon)
        cfg.imagePlacement      = .top
        cfg.imagePadding        = 5
        cfg.baseBackgroundColor = bg
        cfg.baseForegroundColor = tint
        cfg.cornerStyle         = .large
        cfg.contentInsets       = NSDirectionalEdgeInsets(top: 10, leading: 4, bottom: 10, trailing: 4)
        let btn = UIButton(); btn.configuration = cfg
        btn.titleLabel?.font            = .systemFont(ofSize: 11, weight: .semibold)
        btn.titleLabel?.numberOfLines   = 1
        btn.titleLabel?.textAlignment   = .center
        return btn
    }

    // MARK: - Map Pins
    private func addHospitalPinsToMap(_ results: [HospitalResult]) {
        if call.hasLocation {
            let pin = MKPointAnnotation(); pin.coordinate = call.coordinate; pin.title = call.problem
            mapView.addAnnotation(pin)
        }
        for h in results {
            let pin = MKPointAnnotation(); pin.coordinate = h.coordinate; pin.title = h.name
            mapView.addAnnotation(pin)
        }
        // Fit map to show all pins
        var coords = results.map { $0.coordinate }
        if call.hasLocation { coords.append(call.coordinate) }
        let rects = coords.map { MKMapRect(origin: MKMapPoint($0), size: MKMapSize(width: 1, height: 1)) }
        if let first = rects.first {
            let all = rects.dropFirst().reduce(first) { $0.union($1) }
            mapView.setVisibleMapRect(all, edgePadding: UIEdgeInsets(top: 30, left: 20, bottom: 30, right: 20), animated: true)
        }
        spinner.stopAnimating()
    }

    // MARK: - Navigation Button Handler
    @objc private func navButtonTapped(_ sender: UIButton) {
        guard let label = sender.accessibilityLabel else { return }
        let parts = label.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return }
        let app      = String(parts[0])
        let hospName = String(parts[1])
        guard let hospital = hospitals.first(where: { $0.name == hospName }) else { return }

        switch app {
        case "google": openGoogleMaps(to: hospital)
        case "apple":  openAppleMaps(to: hospital)
        case "waze":   openWaze(to: hospital)
        default: break
        }
    }

    private func openGoogleMaps(to hospital: HospitalResult) {
        let lat = hospital.coordinate.latitude
        let lng = hospital.coordinate.longitude
        let appURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")
        let webURL = URL(string: "https://maps.google.com/?daddr=\(lat),\(lng)&directionsmode=driving")
        if let url = appURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = webURL {
            UIApplication.shared.open(url)
        }
    }

    private func openAppleMaps(to hospital: HospitalResult) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: hospital.coordinate))
        mapItem.name = hospital.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func openWaze(to hospital: HospitalResult) {
        let lat = hospital.coordinate.latitude
        let lng = hospital.coordinate.longitude
        let appURL = URL(string: "waze://?ll=\(lat),\(lng)&navigate=yes")
        let webURL = URL(string: "https://waze.com/ul?ll=\(lat),\(lng)&navigate=yes")
        if let url = appURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = webURL {
            UIApplication.shared.open(url)
        }
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

    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    private func makeDivider() -> UIView {
        let v = UIView(); v.backgroundColor = UIColor(white: 0.18, alpha: 1)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true; return v
    }
}

// MARK: - CLLocationManagerDelegate
extension HospitalRoutesViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, userLocation == nil else { return }
        userLocation = location
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways { locationManager.startUpdatingLocation() }
    }
}

// MARK: - MKMapViewDelegate
extension HospitalRoutesViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        let pin = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
        pin.canShowCallout  = true
        pin.markerTintColor = annotation.title == call.problem ? .systemRed : .systemGreen
        pin.glyphImage      = annotation.title == call.problem
            ? UIImage(systemName: "cross.fill")
            : UIImage(systemName: "h.square.fill")
        return pin
    }
}
