import UIKit

class ChangePasswordViewController: UIViewController {

    // MARK: - UI
    private let scrollView       = UIScrollView()
    private let contentStack     = UIStackView()
    private let currentField     = UITextField()
    private let newField         = UITextField()
    private let confirmField     = UITextField()
    private let saveButton       = UIButton()
    private let statusLabel      = UILabel()
    private let spinner          = UIActivityIndicatorView(style: .medium)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        setupNavBar()
        setupScrollView()
        buildForm()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - Nav Bar
    private func setupNavBar() {
        title = "CHANGE PASSWORD"
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
        navigationItem.leftBarButtonItem = back
        navigationItem.hidesBackButton   = true
    }

    // MARK: - Scroll View
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical  = true
        scrollView.keyboardDismissMode   = .onDrag
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

            contentStack.topAnchor.constraint(equalTo: cg.topAnchor, constant: 32),
            contentStack.bottomAnchor.constraint(equalTo: cg.bottomAnchor, constant: -40),
            contentStack.leadingAnchor.constraint(equalTo: cg.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: cg.trailingAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: fg.widthAnchor, constant: -48)
        ])
    }

    // MARK: - Form
    private func buildForm() {

        // Icon + title
        let icon = UILabel(); icon.text = "🔑"; icon.font = .systemFont(ofSize: 48); icon.textAlignment = .center
        let sub  = UILabel(); sub.text = "Update your login password"
        sub.font = .systemFont(ofSize: 14); sub.textColor = UIColor(white: 0.4, alpha: 1); sub.textAlignment = .center

        contentStack.addArrangedSubview(icon)
        contentStack.addArrangedSubview(sub)
        contentStack.setCustomSpacing(32, after: sub)

        // Fields
        buildFieldGroup(label: "Current Password", field: currentField, placeholder: "Enter current password", isSecure: true, returnKey: .next)
        buildFieldGroup(label: "New Password",     field: newField,     placeholder: "At least 6 characters",  isSecure: true, returnKey: .next)
        buildFieldGroup(label: "Confirm Password", field: confirmField, placeholder: "Repeat new password",     isSecure: true, returnKey: .done)

        currentField.delegate = self
        newField.delegate     = self
        confirmField.delegate = self

        // Status label
        statusLabel.font          = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden      = true
        contentStack.addArrangedSubview(statusLabel)

        // Save button
        var cfg = UIButton.Configuration.filled()
        cfg.title               = "Update Password"
        cfg.baseBackgroundColor = .systemBlue
        cfg.cornerStyle         = .large
        cfg.contentInsets       = NSDirectionalEdgeInsets(top: 15, leading: 0, bottom: 15, trailing: 0)
        saveButton.configuration = cfg
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(saveButton)

        // Spinner
        spinner.color = .white; spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: saveButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])

        // Requirements hint
        let hint = UILabel()
        hint.text          = "Password must be at least 6 characters"
        hint.font          = .systemFont(ofSize: 11)
        hint.textColor     = UIColor(white: 0.3, alpha: 1)
        hint.textAlignment = .center
        contentStack.addArrangedSubview(hint)
    }

    private func buildFieldGroup(label: String, field: UITextField, placeholder: String, isSecure: Bool, returnKey: UIReturnKeyType) {
        let lbl       = UILabel()
        lbl.text      = label
        lbl.font      = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        lbl.textColor = UIColor(white: 0.4, alpha: 1)

        field.backgroundColor        = UIColor(white: 0.12, alpha: 1)
        field.textColor              = .white
        field.isSecureTextEntry      = isSecure
        field.returnKeyType          = returnKey
        field.autocapitalizationType = .none
        field.autocorrectionType     = .no
        field.layer.cornerRadius     = 12
        field.layer.borderWidth      = 1
        field.layer.borderColor      = UIColor(white: 0.2, alpha: 1).cgColor
        field.heightAnchor.constraint(equalToConstant: 52).isActive = true
        field.attributedPlaceholder  = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(white: 0.35, alpha: 1)]
        )

        // Left padding
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 52))
        field.leftView = pad; field.leftViewMode = .always

        let group = UIStackView(arrangedSubviews: [lbl, field])
        group.axis = .vertical; group.spacing = 6
        contentStack.addArrangedSubview(group)
    }

    // MARK: - Save
    @objc private func saveTapped() {
        dismissKeyboard()
        let current = currentField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let new     = newField.text ?? ""
        let confirm = confirmField.text ?? ""

        // Validate
        guard !current.isEmpty else { showStatus("Enter your current password", isError: true); return }
        guard new.count >= 6   else { showStatus("New password must be at least 6 characters", isError: true); return }
        guard new == confirm   else { showStatus("New passwords don't match", isError: true); return }
        guard new != current   else { showStatus("New password must be different", isError: true); return }

        setLoading(true)

        guard let url   = URL(string: "\(AuthManager.shared.serverURL)/auth/change-password"),
              let token = AuthManager.shared.token else {
            showStatus("Not logged in", isError: true); setLoading(false); return
        }

        var req        = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)",     forHTTPHeaderField: "Authorization")
        req.httpBody   = try? JSONSerialization.data(withJSONObject: [
            "currentPassword": current,
            "newPassword":     new
        ])

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)

                if let error = error {
                    self.showStatus("Network error: \(error.localizedDescription)", isError: true); return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { self.showStatus("Invalid response from server", isError: true); return }

                if let success = json["success"] as? Bool, success {
                    self.showStatus("✅ Password updated successfully!", isError: false)
                    self.currentField.text = ""
                    self.newField.text     = ""
                    self.confirmField.text = ""
                    // Auto-dismiss after 1.5s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.navigationController?.popViewController(animated: true)
                    }
                } else {
                    let msg = json["error"] as? String ?? "Failed to update password"
                    self.showStatus(msg, isError: true)
                }
            }
        }.resume()
    }

    // MARK: - Helpers
    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text      = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
        statusLabel.isHidden  = false

        if isError {
            UIView.animate(withDuration: 0.1, animations: { self.contentStack.transform = CGAffineTransform(translationX: -8, y: 0) }) { _ in
                UIView.animate(withDuration: 0.1, animations: { self.contentStack.transform = CGAffineTransform(translationX: 8, y: 0) }) { _ in
                    UIView.animate(withDuration: 0.1) { self.contentStack.transform = .identity }
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        saveButton.isEnabled  = !loading
        saveButton.alpha      = loading ? 0 : 1
        loading ? spinner.startAnimating() : spinner.stopAnimating()
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }
    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        scrollView.contentInset.bottom = frame.height + 20
    }
    @objc private func keyboardWillHide(_ n: Notification) {
        scrollView.contentInset.bottom = 0
    }
}

// MARK: - UITextFieldDelegate
extension ChangePasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == currentField      { newField.becomeFirstResponder() }
        else if textField == newField     { confirmField.becomeFirstResponder() }
        else                             { textField.resignFirstResponder(); saveTapped() }
        return true
    }
}
