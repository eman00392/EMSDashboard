import UIKit
import MapKit
import Combine

class MainDashboardViewController: UIViewController {

    // MARK: - Properties
    private var cancellables        = Set<AnyCancellable>()
    private var hospitals:          [HospitalResult] = []
    private var callHistory:        [EMSCallRecord]  = []

    // MARK: - UI
    private let scrollView          = UIScrollView()
    private let contentStack        = UIStackView()

    // Header
    private let titleLabel          = UILabel()
    private let statusDot           = UIView()
    private let statusLabel         = UILabel()

    // Call card
    private let callCard            = UIView()
    private let noCallView          = UIView()
    private let activeCallView      = UIView()
    private let problemLabel        = UILabel()
    private let addressLabel        = UILabel()
    private let crossLabel          = UILabel()
    private let patientLabel        = UILabel()
    private let openDetailButton    = UIButton()
    private let notesView           = AddressNotesView()
    private let cityLabel           = UILabel()
    private let unitsDetailLabel    = UILabel()
    private let mutualAidBanner     = UIView()
    private let mutualAidLabel      = UILabel()

    // Hospital section
    private let hospitalSection     = UIView()
    private let hospitalHeader      = UILabel()
    private let hospitalStack       = UIStackView()
    private let hospitalSpinner     = UIActivityIndicatorView(style: .medium)

    // History section
    private let historySection      = UIView()
    private let historyStack        = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        setupScrollView()
        buildHeader()
        buildCallCard()
        buildHospitalSection()
        buildHistorySection()
        buildFooter()
        observeData()
        loadHistory()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        loadHistory()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Scroll View

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis      = .vertical
        contentStack.spacing   = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let cg = scrollView.contentLayoutGuide
        let fg = scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: cg.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: cg.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: cg.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: cg.trailingAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: fg.widthAnchor, constant: -32)
        ])
    }

    // MARK: - Header

    private func buildHeader() {
        titleLabel.text      = "🚑  EMS DASHBOARD"
        titleLabel.font      = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = UIColor(white: 0.5, alpha: 1)

        statusDot.backgroundColor    = .systemRed
        statusDot.layer.cornerRadius = 5
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.widthAnchor.constraint(equalToConstant: 10).isActive  = true
        statusDot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        statusLabel.text      = "DISCONNECTED"
        statusLabel.font      = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .systemRed

        let dotRow = UIStackView(arrangedSubviews: [statusDot, statusLabel])
        dotRow.axis = .horizontal; dotRow.spacing = 6; dotRow.alignment = .center

        let leftCol = UIStackView(arrangedSubviews: [titleLabel, dotRow])
        leftCol.axis = .vertical; leftCol.spacing = 4

        let contactsBtn = UIButton(type: .system)
        contactsBtn.setTitle("📋 CONTACTS", for: .normal)
        contactsBtn.titleLabel?.font   = .systemFont(ofSize: 12, weight: .semibold)
        contactsBtn.tintColor          = .systemCyan
        contactsBtn.backgroundColor    = UIColor(white: 0.15, alpha: 1)
        contactsBtn.layer.cornerRadius = 8
        contactsBtn.contentEdgeInsets  = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        contactsBtn.addTarget(self, action: #selector(openContacts), for: .touchUpInside)

        let logoutBtn = UIButton(type: .system)
        logoutBtn.setTitle("🔒 LOGOUT", for: .normal)
        logoutBtn.titleLabel?.font   = .systemFont(ofSize: 12, weight: .semibold)
        logoutBtn.tintColor          = .systemRed
        logoutBtn.backgroundColor    = UIColor(red: 0.2, green: 0.07, blue: 0.07, alpha: 1)
        logoutBtn.layer.cornerRadius = 8
        logoutBtn.contentEdgeInsets  = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        logoutBtn.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        let btnRow = UIStackView(arrangedSubviews: [contactsBtn, logoutBtn])
        btnRow.axis = .horizontal; btnRow.spacing = 8; btnRow.alignment = .center

        let header = UIStackView(arrangedSubviews: [leftCol, UIView(), btnRow])
        header.axis = .horizontal; header.alignment = .center
        contentStack.addArrangedSubview(header)
    }

    // MARK: - Call Card

    private func buildCallCard() {
        callCard.backgroundColor    = UIColor(white: 0.1, alpha: 1)
        callCard.layer.cornerRadius = 20
        callCard.layer.borderWidth  = 1
        callCard.layer.borderColor  = UIColor(white: 0.2, alpha: 1).cgColor

        let tap = UITapGestureRecognizer(target: self, action: #selector(openCallDetail))
        callCard.addGestureRecognizer(tap)

        buildNoCallView()
        buildActiveCallView()

        // Stack the two states vertically inside the card
        // Only one is visible at a time — isHidden removes it from layout
        let cardStack = UIStackView(arrangedSubviews: [noCallView, activeCallView])
        cardStack.axis = .vertical
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        callCard.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: callCard.topAnchor),
            cardStack.bottomAnchor.constraint(equalTo: callCard.bottomAnchor),
            cardStack.leadingAnchor.constraint(equalTo: callCard.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: callCard.trailingAnchor)
        ])

        activeCallView.isHidden = true
        noCallView.isHidden     = false

        contentStack.addArrangedSubview(callCard)
    }

    private func buildNoCallView() {
        let icon = UILabel()
        icon.text = "📡"; icon.font = .systemFont(ofSize: 48); icon.textAlignment = .center

        let lbl = UILabel()
        lbl.text      = "MONITORING ACTIVE911"
        lbl.font      = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        lbl.textColor = UIColor(white: 0.35, alpha: 1); lbl.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [icon, lbl])
        stack.axis = .vertical; stack.spacing = 8; stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        noCallView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: noCallView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: noCallView.centerYAnchor),
            noCallView.heightAnchor.constraint(equalToConstant: 140)
        ])
    }

    private func buildActiveCallView() {
        // Red bar
        let redBar = UIView()
        redBar.backgroundColor = .systemRed
        redBar.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.text = "● LAST CALL"
        badge.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        badge.textColor = .white
        badge.translatesAutoresizingMaskIntoConstraints = false

        redBar.addSubview(badge)

        // Call info labels
        problemLabel.font          = .systemFont(ofSize: 26, weight: .heavy)
        problemLabel.textColor     = .white
        problemLabel.numberOfLines = 2

        addressLabel.font          = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        addressLabel.textColor     = UIColor(white: 0.55, alpha: 1)
        addressLabel.numberOfLines = 2

        crossLabel.font          = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        crossLabel.textColor     = UIColor(white: 0.45, alpha: 1)
        crossLabel.numberOfLines = 1
        crossLabel.isHidden      = true

        patientLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        patientLabel.textColor     = .systemYellow
        patientLabel.numberOfLines = 1
        patientLabel.isHidden      = true

        // City / Town label — pill badge, not full width
        cityLabel.font            = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        cityLabel.textColor       = .white
        cityLabel.numberOfLines   = 1
        cityLabel.textAlignment   = .center
        cityLabel.layer.cornerRadius = 8
        cityLabel.clipsToBounds   = true
        cityLabel.isHidden        = true
        // Padding via attributed string approach — set in showActiveCall

        // Units detail label
        unitsDetailLabel.font          = .systemFont(ofSize: 13, weight: .regular)
        unitsDetailLabel.textColor     = UIColor(white: 0.6, alpha: 1)
        unitsDetailLabel.numberOfLines = 3
        unitsDetailLabel.isHidden      = true

        // Mutual Aid Banner
        mutualAidBanner.backgroundColor    = UIColor(red: 0.5, green: 0.3, blue: 0.0, alpha: 1)
        mutualAidBanner.layer.cornerRadius = 8
        mutualAidBanner.isHidden           = true

        mutualAidLabel.font          = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        mutualAidLabel.textColor     = .white
        mutualAidLabel.textAlignment = .center
        mutualAidLabel.translatesAutoresizingMaskIntoConstraints = false
        mutualAidBanner.addSubview(mutualAidLabel)
        NSLayoutConstraint.activate([
            mutualAidLabel.topAnchor.constraint(equalTo: mutualAidBanner.topAnchor, constant: 6),
            mutualAidLabel.bottomAnchor.constraint(equalTo: mutualAidBanner.bottomAnchor, constant: -6),
            mutualAidLabel.leadingAnchor.constraint(equalTo: mutualAidBanner.leadingAnchor, constant: 12),
            mutualAidLabel.trailingAnchor.constraint(equalTo: mutualAidBanner.trailingAnchor, constant: -12)
        ])

        // Button
        var btnCfg = UIButton.Configuration.filled()
        btnCfg.title               = "▶  Open Details & Navigate"
        btnCfg.baseBackgroundColor = .systemBlue
        btnCfg.cornerStyle         = .large
        btnCfg.contentInsets       = NSDirectionalEdgeInsets(top: 13, leading: 0, bottom: 13, trailing: 0)
        openDetailButton.configuration = btnCfg
        openDetailButton.addTarget(self, action: #selector(openCallDetail), for: .touchUpInside)

        let div = UIView()
        div.backgroundColor = UIColor(white: 0.2, alpha: 1)
        div.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // Wrap cityLabel in a leading-aligned container so it doesn't stretch full width
        let cityRow = UIStackView(arrangedSubviews: [cityLabel, UIView()])
        cityRow.axis = .horizontal; cityRow.spacing = 0; cityRow.alignment = .center

        let infoStack = UIStackView(arrangedSubviews: [
            cityRow,
            mutualAidBanner,
            addressLabel, crossLabel, problemLabel,
            div,
            unitsDetailLabel,
            patientLabel,
            notesView,
            openDetailButton
        ])
        infoStack.axis      = .vertical
        infoStack.spacing   = 8
        infoStack.alignment = .fill
        infoStack.setCustomSpacing(4,  after: cityLabel)
        infoStack.setCustomSpacing(6,  after: mutualAidBanner)
        infoStack.setCustomSpacing(4,  after: addressLabel)
        infoStack.setCustomSpacing(10, after: crossLabel)
        infoStack.setCustomSpacing(12, after: problemLabel)
        infoStack.setCustomSpacing(10, after: div)
        infoStack.setCustomSpacing(8,  after: unitsDetailLabel)
        infoStack.setCustomSpacing(14, after: patientLabel)
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        // Wrap redBar + infoStack in a vertical stack — sizes from content
        let outerStack = UIStackView(arrangedSubviews: [redBar, infoStack])
        outerStack.axis = .vertical
        outerStack.spacing = 0
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        activeCallView.addSubview(outerStack)

        NSLayoutConstraint.activate([
            redBar.heightAnchor.constraint(equalToConstant: 36),

            badge.leadingAnchor.constraint(equalTo: redBar.leadingAnchor, constant: 16),
            badge.centerYAnchor.constraint(equalTo: redBar.centerYAnchor),

            outerStack.topAnchor.constraint(equalTo: activeCallView.topAnchor),
            outerStack.bottomAnchor.constraint(equalTo: activeCallView.bottomAnchor),
            outerStack.leadingAnchor.constraint(equalTo: activeCallView.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: activeCallView.trailingAnchor)
        ])

        // Add padding to infoStack via layout margins
        infoStack.isLayoutMarginsRelativeArrangement = true
        infoStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }

    // MARK: - Hospital Section

    private func buildHospitalSection() {
        hospitalSection.isHidden = true

        hospitalHeader.text      = "🏥  NEAREST HOSPITALS"
        hospitalHeader.font      = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        hospitalHeader.textColor = UIColor(white: 0.45, alpha: 1)

        hospitalSpinner.color = .systemGray; hospitalSpinner.hidesWhenStopped = true

        let hdrRow = UIStackView(arrangedSubviews: [hospitalHeader, UIView(), hospitalSpinner])
        hdrRow.axis = .horizontal; hdrRow.alignment = .center

        hospitalStack.axis = .vertical; hospitalStack.spacing = 8; hospitalStack.alignment = .fill

        let section = UIStackView(arrangedSubviews: [hdrRow, hospitalStack])
        section.axis = .vertical; section.spacing = 10
        section.translatesAutoresizingMaskIntoConstraints = false
        hospitalSection.addSubview(section)

        NSLayoutConstraint.activate([
            section.topAnchor.constraint(equalTo: hospitalSection.topAnchor),
            section.bottomAnchor.constraint(equalTo: hospitalSection.bottomAnchor),
            section.leadingAnchor.constraint(equalTo: hospitalSection.leadingAnchor),
            section.trailingAnchor.constraint(equalTo: hospitalSection.trailingAnchor)
        ])
        contentStack.addArrangedSubview(hospitalSection)
    }

    private func loadHospitals(for call: EMSCall) {
        guard call.hasLocation else { return }
        hospitalSection.isHidden = false
        hospitalSpinner.startAnimating()
        hospitalStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        HospitalFinder.shared.findNearestHospitals(near: call.coordinate) { [weak self] results in
            guard let self = self else { return }
            self.hospitalSpinner.stopAnimating()
            self.hospitals = results
            if results.isEmpty {
                let lbl = UILabel(); lbl.text = "No hospitals found nearby"
                lbl.font = .systemFont(ofSize: 13); lbl.textColor = .systemGray
                self.hospitalStack.addArrangedSubview(lbl)
            } else {
                results.enumerated().forEach { i, h in
                    let card = self.hospitalCard(h, tag: i)
                    self.hospitalStack.addArrangedSubview(card)
                }
            }
        }
    }

    private func hospitalCard(_ hospital: HospitalResult, tag: Int) -> UIView {
        let card = UIButton()
        card.backgroundColor    = UIColor(white: 0.1, alpha: 1)
        card.layer.cornerRadius = 12
        card.layer.borderWidth  = 1
        card.layer.borderColor  = UIColor(white: 0.18, alpha: 1).cgColor
        card.tag = tag
        card.addTarget(self, action: #selector(hospitalTapped(_:)), for: .touchUpInside)

        let nameL = UILabel(); nameL.text = hospital.name
        nameL.font = .systemFont(ofSize: 14, weight: .semibold); nameL.textColor = .white

        let addrL = UILabel(); addrL.text = hospital.address
        addrL.font = .systemFont(ofSize: 12); addrL.textColor = .systemGray

        let etaL = UILabel(); etaL.text = hospital.etaString
        etaL.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        etaL.textColor = UIColor(white: 0.5, alpha: 1); etaL.textAlignment = .right

        let left = UIStackView(arrangedSubviews: [nameL, addrL])
        left.axis = .vertical; left.spacing = 2

        let row = UIStackView(arrangedSubviews: [left, UIView(), etaL])
        row.axis = .horizontal; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }

    // MARK: - History Section

    private func buildHistorySection() {
        let hdr = UILabel(); hdr.text = "🕐  RECENT CALLS"
        hdr.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        hdr.textColor = UIColor(white: 0.45, alpha: 1)

        let clearBtn = UIButton(type: .system)
        clearBtn.setTitle("Clear", for: .normal); clearBtn.tintColor = .systemGray
        clearBtn.titleLabel?.font = .systemFont(ofSize: 12)
        clearBtn.addTarget(self, action: #selector(clearHistory), for: .touchUpInside)

        let hdrRow = UIStackView(arrangedSubviews: [hdr, UIView(), clearBtn])
        hdrRow.axis = .horizontal; hdrRow.alignment = .center

        historyStack.axis = .vertical; historyStack.spacing = 8; historyStack.alignment = .fill

        let section = UIStackView(arrangedSubviews: [hdrRow, historyStack])
        section.axis = .vertical; section.spacing = 10
        section.translatesAutoresizingMaskIntoConstraints = false
        historySection.addSubview(section)

        NSLayoutConstraint.activate([
            section.topAnchor.constraint(equalTo: historySection.topAnchor),
            section.bottomAnchor.constraint(equalTo: historySection.bottomAnchor),
            section.leadingAnchor.constraint(equalTo: historySection.leadingAnchor),
            section.trailingAnchor.constraint(equalTo: historySection.trailingAnchor)
        ])
        contentStack.addArrangedSubview(historySection)
    }

    private func loadHistory() {
        callHistory = CallHistoryManager.shared.loadRecords()
        historyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if callHistory.isEmpty {
            let lbl = UILabel(); lbl.text = "No call history yet"
            lbl.font = .systemFont(ofSize: 13); lbl.textColor = .systemGray
            historyStack.addArrangedSubview(lbl)
        } else {
            callHistory.forEach { historyStack.addArrangedSubview(historyCard($0)) }
        }
    }

    private func historyCard(_ record: EMSCallRecord) -> UIView {
        // Use UIButton — reliably tappable inside scroll views
        let card = UIButton(type: .system)
        card.backgroundColor    = UIColor(white: 0.09, alpha: 1)
        card.layer.cornerRadius = 12
        card.layer.borderWidth  = 1
        card.layer.borderColor  = UIColor(white: 0.15, alpha: 1).cgColor

        // Store record index so handler can look it up
        if let idx = callHistory.firstIndex(where: {
            $0.call.address == record.call.address && $0.call.problem == record.call.problem
        }) {
            card.tag = idx
        }
        card.addTarget(self, action: #selector(historyCardTapped(_:)), for: .touchUpInside)

        // Dim on highlight
        card.addTarget(self, action: #selector(historyCardHighlight(_:)), for: .touchDown)
        card.addTarget(self, action: #selector(historyCardUnhighlight(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        let hProb = UILabel(); hProb.text = record.call.problem
        hProb.font = .systemFont(ofSize: 14, weight: .semibold)
        hProb.textColor = UIColor(white: 0.85, alpha: 1)
        hProb.isUserInteractionEnabled = false

        let hAddr = UILabel(); hAddr.text = record.call.address
        hAddr.font = .systemFont(ofSize: 12); hAddr.textColor = .systemGray
        hAddr.isUserInteractionEnabled = false

        let hTime = UILabel(); hTime.text = record.formattedTime
        hTime.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        hTime.textColor = UIColor(white: 0.4, alpha: 1); hTime.textAlignment = .right
        hTime.isUserInteractionEnabled = false

        let hAgo = UILabel(); hAgo.text = record.timeAgoString
        hAgo.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        hAgo.textColor = UIColor(white: 0.35, alpha: 1); hAgo.textAlignment = .right
        hAgo.isUserInteractionEnabled = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor(white: 0.3, alpha: 1)
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.isUserInteractionEnabled = false

        let rightCol = UIStackView(arrangedSubviews: [hTime, hAgo])
        rightCol.axis = .vertical; rightCol.alignment = .trailing; rightCol.spacing = 2
        rightCol.isUserInteractionEnabled = false

        let leftCol = UIStackView(arrangedSubviews: [hProb, hAddr])
        leftCol.axis = .vertical; leftCol.spacing = 2
        leftCol.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [leftCol, UIView(), rightCol, chevron])
        row.axis = .horizontal; row.alignment = .center; row.spacing = 8
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }

    @objc private func historyCardTapped(_ sender: UIButton) {
        guard sender.tag < callHistory.count else { return }
        let record = callHistory[sender.tag]
        let vc = CallDetailViewController(call: record.call)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func historyCardHighlight(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) { sender.backgroundColor = UIColor(white: 0.16, alpha: 1) }
    }

    @objc private func historyCardUnhighlight(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15) { sender.backgroundColor = UIColor(white: 0.09, alpha: 1) }
    }

    // MARK: - Footer

    private func buildFooter() {
        let div = UIView()
        div.backgroundColor = UIColor(white: 0.15, alpha: 1)
        div.heightAnchor.constraint(equalToConstant: 1).isActive = true
        contentStack.addArrangedSubview(div)

        let appLbl = UILabel(); appLbl.text = "🚑  EMS Dashboard"
        appLbl.font = .systemFont(ofSize: 13, weight: .semibold)
        appLbl.textColor = UIColor(white: 0.5, alpha: 1); appLbl.textAlignment = .center

        let byLbl = UILabel(); byLbl.text = "Created by"
        byLbl.font = .systemFont(ofSize: 11)
        byLbl.textColor = UIColor(white: 0.3, alpha: 1); byLbl.textAlignment = .center

        let coLbl = UILabel(); coLbl.text = "EMBTech LLC"
        coLbl.font = .systemFont(ofSize: 15, weight: .bold)
        coLbl.textColor = UIColor(white: 0.7, alpha: 1); coLbl.textAlignment = .center

        // Change Password button
        let changePwBtn = UIButton(type: .system)
        changePwBtn.setTitle("🔑  Change Password", for: .normal)
        changePwBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        changePwBtn.tintColor        = UIColor(white: 0.5, alpha: 1)
        changePwBtn.addTarget(self, action: #selector(openChangePassword), for: .touchUpInside)
        contentStack.addArrangedSubview(changePwBtn)

        let webBtn = UIButton(type: .system)
        webBtn.setTitle("🌐  embtech.llc", for: .normal)
        webBtn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        webBtn.tintColor = .systemBlue
        webBtn.addTarget(self, action: #selector(openWebsite), for: .touchUpInside)

        let mailBtn = UIButton(type: .system)
        mailBtn.setTitle("✉️  ceo@embtech.llc", for: .normal)
        mailBtn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        mailBtn.tintColor = .systemBlue
        mailBtn.addTarget(self, action: #selector(openEmail), for: .touchUpInside)

        let footer = UIStackView(arrangedSubviews: [appLbl, byLbl, coLbl, webBtn, mailBtn])
        footer.axis = .vertical; footer.spacing = 6; footer.alignment = .center
        contentStack.addArrangedSubview(footer)
    }

    // MARK: - Data Observation

    private func observeData() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshNotes),
            name: NSNotification.Name("EMSNotesUpdated"),
            object: nil
        )

        CallDataModel.shared.$currentCall
            .receive(on: DispatchQueue.main)
            .sink { [weak self] call in self?.handleCallUpdate(call) }
            .store(in: &cancellables)

        CallDataModel.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in self?.updateConnectionStatus(connected) }
            .store(in: &cancellables)
    }

    private func handleCallUpdate(_ call: EMSCall?) {
        guard let call = call else {
            showNoCall()
            hospitalSection.isHidden = true
                LiveActivityManager.shared.endActivity()
            loadHistory()
            return
        }
        showActiveCall(call)
        loadHospitals(for: call)
        LiveActivityManager.shared.startActivity(for: call)
    }

    private func updateConnectionStatus(_ connected: Bool) {
        statusDot.backgroundColor = connected ? .systemGreen : .systemRed
        statusLabel.text          = connected ? "CONNECTED" : "DISCONNECTED"
        statusLabel.textColor     = connected ? .systemGreen : .systemRed
    }

    // MARK: - Card States

    private func showNoCall() {
        activeCallView.isHidden = true
        noCallView.isHidden     = false
        callCard.layer.borderColor = UIColor(white: 0.2, alpha: 1).cgColor
    }

    private func showActiveCall(_ call: EMSCall) {
        problemLabel.text   = call.displayProblem
        addressLabel.text   = call.address
        crossLabel.text     = call.cross.isEmpty ? "" : "Cross: \(call.cross)"
        crossLabel.isHidden = call.cross.isEmpty

        // Origin label — same logic as web dashboard
        // MutualAid=purple, Pelham=green, Scarsdale=orange, Eastchester=blue
        let origin = call.callOrigin
        cityLabel.text     = "  🚑 " + call.originLabel + "  "
        cityLabel.isHidden = false
        switch origin {
        case .mutualAid:
            cityLabel.backgroundColor = UIColor(red: 0.47, green: 0.21, blue: 0.73, alpha: 1)
            cityLabel.textColor       = .white
        case .pelham:
            cityLabel.backgroundColor = call.isMutualAid
                ? UIColor(red: 0.47, green: 0.21, blue: 0.73, alpha: 1)
                : UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1)
            cityLabel.textColor       = .white
        case .scarsdale:
            cityLabel.backgroundColor = UIColor(red: 0.8, green: 0.35, blue: 0.0, alpha: 1)
            cityLabel.textColor       = .white
        case .eastchester, .unknown:
            cityLabel.backgroundColor = UIColor(red: 0.14, green: 0.35, blue: 0.75, alpha: 1)
            cityLabel.textColor       = .white
        }
        cityLabel.layer.cornerRadius = 8
        cityLabel.clipsToBounds      = true

        // Units — one per line
        let lines = call.unitLines
        if !lines.isEmpty {
            unitsDetailLabel.text     = lines.map { "🚒  \($0)" }.joined(separator: "\n")
            unitsDetailLabel.isHidden = false
        } else {
            unitsDetailLabel.isHidden = true
        }

        // Mutual Aid Banner
        if call.isMutualAid {
            mutualAidLabel.text      = "⚠️  MUTUAL AID"
            mutualAidBanner.isHidden = false
        } else {
            mutualAidBanner.isHidden = true
        }

        let patient = call.patientSummary
        patientLabel.isHidden = (patient == "No patient info")
        patientLabel.text     = patient == "No patient info" ? "" : "🧑‍⚕️  \(patient)"

        // Address Notes
        notesView.configure(with: AddressNotesManager.shared.notes(for: call.address))

        noCallView.isHidden     = true
        activeCallView.isHidden = false
        callCard.layer.borderColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
    }


    // MARK: - Actions

    @objc private func refreshNotes() {
        guard let call = CallDataModel.shared.currentCall else { return }
        notesView.configure(with: AddressNotesManager.shared.notes(for: call.address))
    }

    @objc private func openCallDetail() {
        guard let call = CallDataModel.shared.currentCall else { return }
        let startTime = CallDataModel.shared.activeCallDispatchTime ?? Date()
        let vc = CallDetailViewController(call: call, dispatchStartTime: startTime)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func logoutTapped() {
        let alert = UIAlertController(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { _ in
            AuthManager.shared.logout {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let delegate    = windowScene.delegate as? SceneDelegate else { return }
                delegate.showLogin()
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func openContacts() {
        navigationController?.pushViewController(ContactsViewController(), animated: true)
    }

    @objc private func hospitalTapped(_ sender: UIButton) {
        guard sender.tag < hospitals.count else { return }
        HospitalFinder.shared.navigate(to: hospitals[sender.tag])
    }

    @objc private func clearHistory() {
        CallHistoryManager.shared.clearHistory()
        loadHistory()
    }

    @objc private func openWebsite() {
        if let url = URL(string: "https://embtech.llc") { UIApplication.shared.open(url) }
    }

    @objc private func openChangePassword() {
        navigationController?.pushViewController(ChangePasswordViewController(), animated: true)
    }

    @objc private func openEmail() {
        if let url = URL(string: "mailto:ceo@embtech.llc") { UIApplication.shared.open(url) }
    }
}
