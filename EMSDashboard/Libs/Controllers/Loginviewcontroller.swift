import UIKit

// MARK: - Login View Controller
// Shown on first launch or after being logged out / kicked.
// Credentials are validated against the server.

class LoginViewController: UIViewController {

    // MARK: - UI
    private let logoLabel       = UILabel()
    private let subtitleLabel   = UILabel()
    private let cardView        = UIView()
    private let usernameField   = UITextField()
    private let passwordField   = UITextField()
    private let loginButton     = UIButton()
    private let spinner         = UIActivityIndicatorView(style: .medium)
    private let errorLabel      = UILabel()
    private let versionLabel    = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        setupUI()

        // Dismiss keyboard on tap
        view.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        )

        // Listen for force logout
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForceLogout),
            name: .userForcedLogout,
            object: nil
        )
    }

    // MARK: - UI Setup

    private func setupUI() {

        // ── Logo ──
        logoLabel.text          = "🚑"
        logoLabel.font          = .systemFont(ofSize: 64)
        logoLabel.textAlignment = .center

        subtitleLabel.text          = "EMS DASHBOARD"
        subtitleLabel.font          = UIFont.monospacedSystemFont(ofSize: 16, weight: .bold)
        subtitleLabel.textColor     = UIColor(white: 0.6, alpha: 1)
        subtitleLabel.textAlignment = .center

        let logoStack = UIStackView(arrangedSubviews: [logoLabel, subtitleLabel])
        logoStack.axis = .vertical; logoStack.spacing = 8; logoStack.alignment = .center
        logoStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoStack)

        // ── Login Card ──
        cardView.backgroundColor    = UIColor(white: 0.11, alpha: 1)
        cardView.layer.cornerRadius = 20
        cardView.layer.borderWidth  = 1
        cardView.layer.borderColor  = UIColor(white: 0.22, alpha: 1).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardView)

        // Username
        styleTextField(usernameField, placeholder: "Username", isSecure: false)
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType     = .no
        usernameField.returnKeyType          = .next
        usernameField.delegate               = self

        // Password
        styleTextField(passwordField, placeholder: "Password", isSecure: true)
        passwordField.returnKeyType = .done
        passwordField.delegate      = self

        // Error label
        errorLabel.font          = .systemFont(ofSize: 13, weight: .regular)
        errorLabel.textColor     = .systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 2
        errorLabel.isHidden      = true

        // Login button
        var config = UIButton.Configuration.filled()
        config.title               = "Sign In"
        config.baseBackgroundColor = .systemRed
        config.cornerStyle         = .large
        config.contentInsets       = NSDirectionalEdgeInsets(top: 15, leading: 0, bottom: 15, trailing: 0)
        loginButton.configuration  = config
        loginButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        // Spinner
        spinner.color            = .white
        spinner.hidesWhenStopped = true

        let fieldStack = UIStackView(arrangedSubviews: [
            usernameField, passwordField, errorLabel, loginButton, spinner
        ])
        fieldStack.axis      = .vertical
        fieldStack.spacing   = 14
        fieldStack.alignment = .fill
        fieldStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(fieldStack)

        // Version / credit
        versionLabel.text          = "Created by EMBTech LLC"
        versionLabel.font          = .systemFont(ofSize: 11, weight: .regular)
        versionLabel.textColor     = UIColor(white: 0.25, alpha: 1)
        versionLabel.textAlignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(versionLabel)

        // ── Constraints ──
        NSLayoutConstraint.activate([
            logoStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoStack.bottomAnchor.constraint(equalTo: cardView.topAnchor, constant: -40),

            cardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            fieldStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            fieldStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24),
            fieldStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            fieldStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func styleTextField(_ field: UITextField, placeholder: String, isSecure: Bool) {
        field.backgroundColor        = UIColor(white: 0.15, alpha: 1)
        field.textColor              = .white
        field.layer.cornerRadius     = 10
        field.layer.borderWidth      = 1
        field.layer.borderColor      = UIColor(white: 0.25, alpha: 1).cgColor
        field.isSecureTextEntry      = isSecure
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true

        // Padding
        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 50))
        field.leftView      = pad
        field.leftViewMode  = .always
        field.rightView     = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 50))
        field.rightViewMode = .always

        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(white: 0.4, alpha: 1)]
        )
    }

    // MARK: - Actions

    @objc private func loginTapped() {
        guard let username = usernameField.text?.trimmingCharacters(in: .whitespaces),
              let password = passwordField.text,
              !username.isEmpty, !password.isEmpty else {
            showError("Please enter your username and password")
            return
        }

        setLoading(true)

        AuthManager.shared.login(username: username, password: password) { [weak self] result in
            guard let self = self else { return }
            self.setLoading(false)

            switch result {
            case .success:
                self.proceedToDashboard()
            case .failure(let error):
                self.showError(error.localizedDescription ?? "Login failed")
            }
        }
    }

    private func proceedToDashboard() {
        guard let windowScene = view.window?.windowScene,
              let delegate    = windowScene.delegate as? SceneDelegate else { return }
        delegate.showDashboard()
    }

    @objc private func handleForceLogout() {
        showError("⚠️ Your account has been logged out by an administrator")
        usernameField.text = ""
        passwordField.text = ""
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        loginButton.isEnabled = !loading
        loading ? spinner.startAnimating() : spinner.stopAnimating()
        loginButton.alpha = loading ? 0.6 : 1.0
    }

    private func showError(_ message: String) {
        errorLabel.text    = message
        errorLabel.isHidden = false

        UIView.animate(withDuration: 0.1, animations: {
            self.cardView.transform = CGAffineTransform(translationX: -8, y: 0)
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                self.cardView.transform = CGAffineTransform(translationX: 8, y: 0)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    self.cardView.transform = .identity
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameField {
            passwordField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            loginTapped()
        }
        return true
    }
}
