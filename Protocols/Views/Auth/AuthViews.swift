import SwiftUI

private enum AuthScreen {
    case welcome
    case phone
    case email
}

struct AuthRootView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var screen = AuthScreen.welcome

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                switch screen {
                case .welcome:
                    WelcomeAuthView(
                        continueWithPhone: { transition(to: .phone) },
                        continueWithEmail: { transition(to: .email) }
                    )
                case .phone:
                    PhoneAuthView(back: { transition(to: .welcome) })
                case .email:
                    EmailAuthView(back: { transition(to: .welcome) })
                }
            }
        }
        .tint(AppTheme.accent)
    }

    private func transition(to nextScreen: AuthScreen) {
        withAnimation(.snappy(duration: 0.24)) {
            screen = nextScreen
        }
    }
}

private struct WelcomeAuthView: View {
    @EnvironmentObject private var authManager: AuthManager

    let continueWithPhone: () -> Void
    let continueWithEmail: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 28)

                VStack(alignment: .leading, spacing: 22) {
                    BrandMark()
                        .scaleEffect(1.45, anchor: .leading)
                        .frame(width: 86, height: 86, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Protocols")
                            .font(.system(size: 44, weight: .black, design: .default))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Your GLP-1 and peptide companion for doses, titration, progress, and tolerability.")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 12) {
                    Button(action: continueWithPhone) {
                        Label("Continue with Phone", systemImage: "message.fill")
                    }
                    .buttonStyle(AuthPrimaryButtonStyle())
                    .disabled(!authManager.isConfigured)

                    Button(action: continueWithEmail) {
                        Label("Continue with Email", systemImage: "envelope.fill")
                    }
                    .buttonStyle(AuthSecondaryButtonStyle())
                    .disabled(!authManager.isConfigured)
                }

                if let configurationMessage = authManager.configurationMessage {
                    AuthMessageView(message: configurationMessage, style: .warning)
                }

                AppPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Secure by design")
                            .font(.headline.weight(.semibold))

                        Text("Authentication sessions are managed by Supabase Auth and stored in the iOS Keychain.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(24)
        }
    }
}

private struct PhoneAuthView: View {
    @EnvironmentObject private var authManager: AuthManager

    let back: () -> Void

    @State private var selectedCountry = CountryDialCode.defaultCountry
    @State private var phoneNumber = ""
    @State private var sentPhoneNumber: String?
    @State private var code = ""
    @State private var message: String?
    @State private var messageStyle = AuthMessageStyle.warning
    @State private var isWorking = false
    @State private var remainingSeconds = 0
    @State private var cooldownTask: Task<Void, Never>?
    @FocusState private var isCodeFieldFocused: Bool

    private var normalizedPhone: String {
        selectedCountry.code + phoneNumber.filter(\.isNumber)
    }

    private var canSendCode: Bool {
        phoneNumber.filter(\.isNumber).count >= 7 && !isWorking
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AuthHeader(
                    title: sentPhoneNumber == nil ? "Phone Login" : "Verify Code",
                    subtitle: sentPhoneNumber == nil ? "Enter your mobile number and we will send a one-time passcode." : "Enter the 6-digit code sent by SMS.",
                    back: back
                )

                if let sentPhoneNumber {
                    otpPanel(phone: sentPhoneNumber)
                } else {
                    phonePanel
                }

                if let message {
                    AuthMessageView(message: message, style: messageStyle)
                }
            }
            .padding(20)
        }
        .onDisappear {
            cooldownTask?.cancel()
        }
    }

    private var phonePanel: some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mobile Number")
                    .font(.headline.weight(.semibold))

                HStack(spacing: 10) {
                    Menu {
                        Picker("Country code", selection: $selectedCountry) {
                            ForEach(CountryDialCode.options) { country in
                                Text("\(country.flag) \(country.name) \(country.code)")
                                    .tag(country)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedCountry.flag)
                            Text(selectedCountry.code)
                                .fontWeight(.bold)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 52)
                        .background(AppTheme.elevatedStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    TextField("Phone number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(AppTheme.elevatedStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onChange(of: phoneNumber) { _, newValue in
                            phoneNumber = newValue.filter { $0.isNumber || $0 == " " || $0 == "-" || $0 == "(" || $0 == ")" }
                        }
                }

                Button {
                    Task { await sendCode() }
                } label: {
                    if isWorking {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Label("Send Code", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(AuthPrimaryButtonStyle())
                .disabled(!canSendCode)
            }
        }
    }

    private func otpPanel(phone: String) -> some View {
        AppPanel {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phone)
                        .font(.headline.weight(.bold))

                    Text("Paste or type the code. Verification starts automatically once all 6 digits are present.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ZStack {
                    HStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { index in
                            OTPDigitBox(
                                value: digit(at: index),
                                isActive: isCodeFieldFocused && index == activeDigitIndex
                            )
                        }
                    }

                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .foregroundStyle(.clear)
                        .accentColor(.clear)
                        .tint(.clear)
                        .opacity(0.01)
                        .frame(height: 58)
                        .focused($isCodeFieldFocused)
                        .accessibilityLabel("Verification code")
                        .onChange(of: code) { _, newValue in
                            let sanitized = String(newValue.filter(\.isNumber).prefix(6))
                            if sanitized != newValue {
                                code = sanitized
                                return
                            }

                            if sanitized.count == 6 && !isWorking {
                                Task { await verifyCode() }
                            }
                        }
                }

                Button {
                    Task { await verifyCode() }
                } label: {
                    if isWorking {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Label("Verify Code", systemImage: "checkmark.shield.fill")
                    }
                }
                .buttonStyle(AuthPrimaryButtonStyle())
                .disabled(code.count != 6 || isWorking)

                Button {
                    Task { await resendCode(phone: phone) }
                } label: {
                    Label(resendTitle, systemImage: "arrow.clockwise")
                }
                .buttonStyle(AuthSecondaryButtonStyle())
                .disabled(remainingSeconds > 0 || isWorking)
            }
        }
        .onAppear {
            if remainingSeconds == 0 {
                startCooldown()
            }
            isCodeFieldFocused = true
        }
    }

    private var resendTitle: String {
        remainingSeconds > 0 ? "Resend in \(remainingSeconds)s" : "Resend Code"
    }

    private func digit(at index: Int) -> String {
        guard index < code.count else { return "" }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[stringIndex])
    }

    private var activeDigitIndex: Int {
        min(code.count, 5)
    }

    private func sendCode() async {
        isWorking = true
        message = nil
        let phone = normalizedPhone
        let result = await authManager.sendPhoneOTP(to: phone)
        isWorking = false
        handle(result)

        if result.isSuccess {
            sentPhoneNumber = phone
            code = ""
            startCooldown()
        }
    }

    private func verifyCode() async {
        guard let sentPhoneNumber, code.count == 6 else { return }
        isWorking = true
        message = nil
        let result = await authManager.verifyPhoneOTP(phone: sentPhoneNumber, code: code)
        isWorking = false
        handle(result)
    }

    private func resendCode(phone: String) async {
        isWorking = true
        message = nil
        let result = await authManager.resendPhoneOTP(to: phone)
        isWorking = false
        handle(result)

        if result.isSuccess {
            code = ""
            startCooldown()
        }
    }

    private func handle(_ result: AuthActionResult) {
        message = result.message
        messageStyle = result.isSuccess ? .success : .warning
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        remainingSeconds = 60
        cooldownTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    remainingSeconds = max(0, remainingSeconds - 1)
                }

                let isDone = await MainActor.run { remainingSeconds == 0 }
                if isDone {
                    break
                }
            }
        }
    }
}

private struct EmailAuthView: View {
    @EnvironmentObject private var authManager: AuthManager

    let back: () -> Void

    @State private var mode = EmailAuthMode.login
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var messageStyle = AuthMessageStyle.warning
    @State private var isWorking = false

    private var isEmailValid: Bool {
        email.range(
            of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private var isPasswordValid: Bool {
        password.count >= 8
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AuthHeader(
                    title: "Email Access",
                    subtitle: "Use email and password when SMS is not available or preferred.",
                    back: back
                )

                AppPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Mode", selection: $mode) {
                            ForEach(EmailAuthMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Email address", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.emailAddress)
                                .font(.headline)
                                .padding(.horizontal, 14)
                                .frame(height: 52)
                                .background(AppTheme.elevatedStrong)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            SecureField("Password", text: $password)
                                .textContentType(mode == .login ? .password : .newPassword)
                                .font(.headline)
                                .padding(.horizontal, 14)
                                .frame(height: 52)
                                .background(AppTheme.elevatedStrong)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ValidationRow(isValid: isEmailValid, text: "Valid email format")
                            ValidationRow(isValid: isPasswordValid, text: "Password is at least 8 characters")
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            if isWorking {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Label(mode.buttonTitle, systemImage: mode == .login ? "lock.open.fill" : "person.crop.circle.badge.plus")
                            }
                        }
                        .buttonStyle(AuthPrimaryButtonStyle())
                        .disabled(!isEmailValid || !isPasswordValid || isWorking)
                    }
                }

                if let message {
                    AuthMessageView(message: message, style: messageStyle)
                }
            }
            .padding(20)
        }
    }

    private func submit() async {
        isWorking = true
        message = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: AuthActionResult

        switch mode {
        case .login:
            result = await authManager.signInWithEmail(email: trimmedEmail, password: password)
        case .signup:
            result = await authManager.signUpWithEmail(email: trimmedEmail, password: password)
        }

        isWorking = false
        message = result.message
        messageStyle = result.isSuccess ? .success : .warning
    }
}

private struct AuthHeader: View {
    let title: String
    let subtitle: String
    let back: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 40, height: 40)
                    .background(AppTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.largeTitle.weight(.black))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OTPDigitBox: View {
    let value: String
    let isActive: Bool

    var body: some View {
        Text(value)
            .font(.title2.weight(.black))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(AppTheme.elevatedStrong)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor, lineWidth: isActive ? 2 : 1)
            }
    }

    private var borderColor: Color {
        if isActive { return AppTheme.accent }
        return value.isEmpty ? AppTheme.divider : AppTheme.accent.opacity(0.85)
    }
}

private struct ValidationRow: View {
    let isValid: Bool
    let text: String

    var body: some View {
        Label(text, systemImage: isValid ? "checkmark.circle.fill" : "circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isValid ? AppTheme.accent : AppTheme.textSecondary)
    }
}

private enum EmailAuthMode: String, CaseIterable, Identifiable {
    case login
    case signup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login: "Log In"
        case .signup: "Sign Up"
        }
    }

    var buttonTitle: String {
        switch self {
        case .login: "Log In"
        case .signup: "Create Account"
        }
    }
}

private struct CountryDialCode: Identifiable, Hashable {
    let id: String
    let name: String
    let code: String
    let flag: String

    static let defaultCountry = CountryDialCode(id: "US", name: "United States", code: "+1", flag: "US")

    static let options = [
        CountryDialCode.defaultCountry,
        CountryDialCode(id: "CA", name: "Canada", code: "+1", flag: "CA"),
        CountryDialCode(id: "GB", name: "United Kingdom", code: "+44", flag: "GB"),
        CountryDialCode(id: "AU", name: "Australia", code: "+61", flag: "AU"),
        CountryDialCode(id: "DE", name: "Germany", code: "+49", flag: "DE"),
        CountryDialCode(id: "FR", name: "France", code: "+33", flag: "FR"),
        CountryDialCode(id: "MX", name: "Mexico", code: "+52", flag: "MX")
    ]
}

enum AuthMessageStyle {
    case warning
    case success
}

struct AuthMessageView: View {
    let message: String
    let style: AuthMessageStyle

    var body: some View {
        AppPanel(padding: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(style == .success ? AppTheme.accent : AppTheme.warning)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AuthPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.86 : 1) : 0.45)
    }
}

struct AuthSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(AppTheme.elevated)
            .foregroundStyle(AppTheme.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.divider)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.76 : 1) : 0.45)
    }
}
