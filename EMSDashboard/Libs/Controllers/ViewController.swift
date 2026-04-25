import UIKit
import Combine
import MapKit

// MARK: - iPhone Main Screen
// Shows the same live data as the CarPlay screen

class ViewController: UIViewController {

    private var cancellables = Set<AnyCancellable>()

    // MARK: - UI Elements

    private let connectionDot: UIView = {
        let v = UIView()
        v.backgroundColor = .systemRed
        v.layer.cornerRadius = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let connectionLabel: UILabel = {
        let l = UILabel()
        l.text = "Disconnected"
        l.font = .systemFont(ofSize: 13, weight: .medium)
        l.textColor = .systemGray
        return l
    }()

    private let noCallLabel: UILabel = {
        let l = UILabel()
        l.text = "No Active Call"
        l.font = .systemFont(ofSize: 24, weight: .semibold)
        l.textColor = .systemGray
        l.textAlignment = .center
        return l
    }()

    private let callCard: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.12, alpha: 1)
        v.layer.cornerRadius = 16
        v.isHidden = true
        return v
    }()

    private let problemLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 28, weight: .heavy)
        l.textColor = .systemRed
        l.textAlignment = .center
        l.numberOfLines = 2
        return l
    }()

    private let addressLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 2
        return l
    }()

    private let unitsLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.textColor = .systemGray
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let patientLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.textColor = .systemYellow
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let navigateButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "🗺  Navigate to Scene"
        config.baseBackgroundColor = .systemBlue
        config.cornerStyle = .large
        let b = UIButton(configuration: config)
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "EMS Dashboard"
        view.backgroundColor = .black
        navigationController?.navigationBar.barStyle = .black
        navigationController?.navigationBar.tintColor = .white
        
        setupLayout()
        observeData()
        
    }


    // MARK: - Layout

    private func setupLayout() {

        // Connection status bar
        let connectionRow = UIStackView(arrangedSubviews: [connectionDot, connectionLabel])
        connectionRow.axis = .horizontal
        connectionRow.spacing = 8
        connectionRow.alignment = .center

        // Call card inner stack
        let cardStack = UIStackView(arrangedSubviews: [
            problemLabel, addressLabel, divider(), unitsLabel, patientLabel, navigateButton
        ])
        cardStack.axis = .vertical
        cardStack.spacing = 12
        cardStack.alignment = .fill
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        callCard.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: callCard.topAnchor, constant: 20),
            cardStack.bottomAnchor.constraint(equalTo: callCard.bottomAnchor, constant: -20),
            cardStack.leadingAnchor.constraint(equalTo: callCard.leadingAnchor, constant: 20),
            cardStack.trailingAnchor.constraint(equalTo: callCard.trailingAnchor, constant: -20)
        ])

        // Root stack
        let rootStack = UIStackView(arrangedSubviews: [connectionRow, noCallLabel, callCard])
        rootStack.axis = .vertical
        rootStack.spacing = 24
        rootStack.alignment = .fill
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        navigateButton.addTarget(self, action: #selector(navigateTapped), for: .touchUpInside)
    }

    private func divider() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.25, alpha: 1)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    // MARK: - Data Observation

    private func observeData() {
        CallDataModel.shared.$currentCall
            .receive(on: DispatchQueue.main)
            .sink { [weak self] call in self?.updateUI(call: call) }
            .store(in: &cancellables)

        CallDataModel.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.connectionDot.backgroundColor = connected ? .systemGreen : .systemRed
                self?.connectionLabel.text = connected ? "Connected to Server" : "Disconnected"
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Updates

    private func updateUI(call: EMSCall?) {
        guard let call = call else {
            noCallLabel.isHidden = false
            callCard.isHidden = true
            NotificationManager.shared.clearBadge()
            return
        }

        noCallLabel.isHidden = true
        callCard.isHidden = false
        problemLabel.text = call.problem.uppercased()
        addressLabel.text = call.address
        unitsLabel.text = "🚒 " + (call.units.isEmpty ? "No units assigned" : call.units)
        patientLabel.text = "🧑‍⚕️ " + call.patientSummary
    }

    // MARK: - Navigate Button

    @objc private func navigateTapped() {
        guard let call = CallDataModel.shared.currentCall, call.hasLocation else {
            let alert = UIAlertController(
                title: "No Location",
                message: "This call has no GPS coordinates available.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: call.coordinate))
        mapItem.name = call.address
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
