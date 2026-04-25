import UIKit

// MARK: - Contacts View Controller

class ContactsViewController: UIViewController {

    // MARK: - UI
    private let scrollView   = UIScrollView()
    private let contentStack = UIStackView()
    private var searchBar    = UISearchBar()
    private var allCards: [(view: UIView, searchText: String)] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        setupNavBar()
        setupSearchBar()
        setupScrollView()
        buildContacts()
        buildFooter()
    }

    // MARK: - Nav Bar

    private func setupNavBar() {
        title = "CONTACTS"

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        ]
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.isHidden = false

        let back = UIBarButtonItem(
            title: "◀  Dashboard",
            style: .plain,
            target: self,
            action: #selector(backTapped)
        )
        back.tintColor = .systemRed
        navigationItem.leftBarButtonItem = back
        navigationItem.hidesBackButton  = true
    }

    // MARK: - Search Bar

    private func setupSearchBar() {
        searchBar.placeholder    = "Search contacts..."
        searchBar.barStyle       = .black
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor      = .systemRed
        searchBar.delegate       = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        if let tf = searchBar.value(forKey: "searchField") as? UITextField {
            tf.textColor       = .white
            tf.backgroundColor = UIColor(white: 0.15, alpha: 1)
            tf.attributedPlaceholder = NSAttributedString(
                string: "Search contacts...",
                attributes: [.foregroundColor: UIColor(white: 0.4, alpha: 1)]
            )
        }

        view.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])
    }

    // MARK: - Scroll View

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical  = true
        scrollView.keyboardDismissMode   = .onDrag
        view.addSubview(scrollView)

        contentStack.axis      = .vertical
        contentStack.spacing   = 20
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let cg = scrollView.contentLayoutGuide
        let fg = scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: cg.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: cg.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: cg.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: cg.trailingAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: fg.widthAnchor, constant: -32)
        ])
    }

    // MARK: - Build Contacts

    private func buildContacts() {
        allCards.removeAll()
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for group in HospitalConfig.shared.groupedContacts {
            let header       = UILabel()
            header.text      = group.category.rawValue
            header.font      = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            header.textColor = UIColor(white: 0.45, alpha: 1)
            contentStack.addArrangedSubview(header)
            contentStack.setCustomSpacing(8, after: header)

            for contact in group.contacts {
                let info = group.category == .hospital
                    ? HospitalConfig.shared.info(for: contact.name)
                    : nil

                let card = info != nil
                    ? makeHospitalContactCard(contact: contact, info: info)
                    : makeContactCard(contact: contact)

                let searchText = "\(contact.name) \(contact.phone) \(info?.doorCode ?? "") \(info?.notes ?? "")".lowercased()
                allCards.append((view: card, searchText: searchText))
                contentStack.addArrangedSubview(card)
            }
            contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews.last ?? UIView())
        }
    }

    // MARK: - Footer

    private func buildFooter() {
        let divider = UIView()
        divider.backgroundColor = UIColor(white: 0.15, alpha: 1)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        contentStack.addArrangedSubview(divider)

        let container = UIView()

        // App name
        let appLabel       = UILabel()
        appLabel.text      = "🚑  EMS Dashboard"
        appLabel.font      = .systemFont(ofSize: 13, weight: .semibold)
        appLabel.textColor = UIColor(white: 0.5, alpha: 1)
        appLabel.textAlignment = .center

        // Created by
        let createdLabel       = UILabel()
        createdLabel.text      = "Created by"
        createdLabel.font      = .systemFont(ofSize: 11, weight: .regular)
        createdLabel.textColor = UIColor(white: 0.3, alpha: 1)
        createdLabel.textAlignment = .center

        // Company name
        let companyLabel       = UILabel()
        companyLabel.text      = "EMBTech LLC"
        companyLabel.font      = .systemFont(ofSize: 15, weight: .bold)
        companyLabel.textColor = UIColor(white: 0.7, alpha: 1)
        companyLabel.textAlignment = .center

        // Website button
        let websiteBtn = UIButton(type: .system)
        websiteBtn.setTitle("🌐  embtech.llc", for: .normal)
        websiteBtn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        websiteBtn.tintColor        = .systemBlue
        websiteBtn.addTarget(self, action: #selector(openWebsite), for: .touchUpInside)

        // Email button
        let emailBtn = UIButton(type: .system)
        emailBtn.setTitle("✉️  ceo@embtech.llc", for: .normal)
        emailBtn.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        emailBtn.tintColor        = .systemBlue
        emailBtn.addTarget(self, action: #selector(openEmail), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            appLabel,
            createdLabel,
            companyLabel,
            websiteBtn,
            emailBtn
        ])
        stack.axis      = .vertical
        stack.spacing   = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        contentStack.addArrangedSubview(container)
    }

    // MARK: - Hospital Contact Card

    private func makeHospitalContactCard(contact: EmergencyContact, info: HospitalInfo?) -> UIView {
        let card = UIView()
        card.backgroundColor    = UIColor(white: 0.1, alpha: 1)
        card.layer.cornerRadius = 14
        card.layer.borderWidth  = 1
        card.layer.borderColor  = UIColor(white: 0.18, alpha: 1).cgColor

        let nameLabel       = UILabel()
        nameLabel.text      = contact.name
        nameLabel.font      = .systemFont(ofSize: 15, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2

        let phoneBtn = makeCallButton(phone: contact.phone, color: .systemGreen)

        let topRow = UIStackView(arrangedSubviews: [nameLabel, phoneBtn])
        topRow.axis = .horizontal; topRow.alignment = .center; topRow.spacing = 8

        var rows: [UIView] = [topRow]

        if let info = info, !info.doorCode.isEmpty {
            rows.append(makeDivider())
            rows.append(makeLabelValueRow(
                label: "🚪 Door Code",
                value: info.doorCode,
                valueColor: .systemYellow,
                valueFont: UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
            ))
        }

        if let info = info, !info.notes.isEmpty {
            let notesLabel       = UILabel()
            notesLabel.text      = info.notes
            notesLabel.font      = .systemFont(ofSize: 11, weight: .regular)
            notesLabel.textColor = UIColor(white: 0.45, alpha: 1)
            notesLabel.numberOfLines = 2
            rows.append(notesLabel)
        }

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical; stack.spacing = 10; stack.alignment = .fill
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

    // MARK: - Standard Contact Card

    private func makeContactCard(contact: EmergencyContact) -> UIView {
        let card = UIView()
        card.backgroundColor    = UIColor(white: 0.1, alpha: 1)
        card.layer.cornerRadius = 14
        card.layer.borderWidth  = 1
        card.layer.borderColor  = UIColor(white: 0.18, alpha: 1).cgColor

        let nameLabel       = UILabel()
        nameLabel.text      = contact.name
        nameLabel.font      = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2

        let phoneBtn = makeCallButton(phone: contact.phone, color: categoryColor(contact.category))

        let row = UIStackView(arrangedSubviews: [nameLabel, phoneBtn])
        row.axis = .horizontal; row.alignment = .center; row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14)
        ])
        return card
    }

    // MARK: - Helpers

    private func makeCallButton(phone: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(phone, for: .normal)
        btn.titleLabel?.font   = UIFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        btn.tintColor          = color
        btn.backgroundColor    = color.withAlphaComponent(0.12)
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets  = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        btn.setContentHuggingPriority(.required, for: .horizontal)
        btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        btn.accessibilityValue = phone
        btn.addTarget(self, action: #selector(callTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func makeLabelValueRow(label: String, value: String, valueColor: UIColor, valueFont: UIFont) -> UIView {
        let l       = UILabel(); l.text = label
        l.font      = .systemFont(ofSize: 12); l.textColor = UIColor(white: 0.45, alpha: 1)
        l.setContentHuggingPriority(.required, for: .horizontal)

        let v       = UILabel(); v.text = value; v.font = valueFont
        v.textColor = valueColor; v.textAlignment = .right
        v.isUserInteractionEnabled = true
        v.accessibilityValue = value
        v.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyDoorCode(_:))))

        let row = UIStackView(arrangedSubviews: [l, UIView(), v])
        row.axis = .horizontal; row.alignment = .center; row.spacing = 8
        return row
    }

    private func makeDivider() -> UIView {
        let v = UIView(); v.backgroundColor = UIColor(white: 0.18, alpha: 1)
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true; return v
    }

    private func categoryColor(_ cat: ContactCategory) -> UIColor {
        switch cat {
        case .hospital: return .systemGreen
        case .police:   return .systemBlue
        case .fire:     return .systemOrange
        case .other:    return .systemGray
        }
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = "  \(message)  "
        toast.font = .systemFont(ofSize: 13, weight: .semibold)
        toast.textColor = .white
        toast.backgroundColor = UIColor(white: 0.2, alpha: 0.95)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 10; toast.clipsToBounds = true
        toast.alpha = 1
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.heightAnchor.constraint(equalToConstant: 40)
        ])
        UIView.animate(withDuration: 0.3, delay: 1.5) { toast.alpha = 0 } completion: { _ in toast.removeFromSuperview() }
    }

    // MARK: - Actions

    @objc private func callTapped(_ sender: UIButton) {
        guard let phone = sender.accessibilityValue else { return }
        let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let url = URL(string: "tel://\(digits)") else { return }
        let alert = UIAlertController(title: "Call \(phone)?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Call", style: .default) { _ in UIApplication.shared.open(url) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func copyDoorCode(_ sender: UITapGestureRecognizer) {
        guard let label = sender.view as? UILabel, let code = label.accessibilityValue else { return }
        UIPasteboard.general.string = code
        let orig = label.textColor
        UIView.animate(withDuration: 0.1) { label.textColor = .white }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            UIView.animate(withDuration: 0.2) { label.textColor = orig }
        }
        showToast("✅ Code copied: \(code)")
    }

    @objc private func openWebsite() {
        guard let url = URL(string: "https://embtech.llc") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func openEmail() {
        guard let url = URL(string: "mailto:ceo@embtech.llc") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Search

    private func filterContacts(query: String) {
        let lower = query.lowercased().trimmingCharacters(in: .whitespaces)
        for item in allCards {
            item.view.isHidden = lower.isEmpty ? false : !item.searchText.contains(lower)
        }
    }
}

// MARK: - UISearchBarDelegate

extension ContactsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterContacts(query: searchText)
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
