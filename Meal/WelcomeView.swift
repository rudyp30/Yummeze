import SwiftUI

/// The signed-out landing screen: brand, tagline, and an email field. Sending a
/// code pushes the code-entry screen. Owns the NavigationStack for that push.
struct WelcomeView: View {
    @Environment(\.theme) private var theme
    @Environment(SessionStore.self) private var session

    @State private var email = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var codeEmail: String?     // non-nil drives the push
    @FocusState private var emailFocused: Bool

    private var isValidEmail: Bool {
        email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                brand
                Spacer(minLength: 0)
                emailSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .tint(theme.accent)
            .navigationDestination(item: $codeEmail) { address in
                CodeEntryView(email: address)
            }
        }
    }

    // MARK: Brand

    private var brand: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 22)
                .fill(theme.accent)
                .frame(width: 76, height: 76)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(theme.onAccent)
                )
                .accessibilityHidden(true)
            Text("Yummeze")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(theme.base)
            Text("Share what you're eating with your favorite people.")
                .font(.callout)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Email

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            AuthFieldLabel("Email")
            // `verbatim:` so the email-shaped placeholder isn't parsed as markdown
            // and auto-linked (which would render it as a blue link, ignoring the color).
            TextField("", text: $email, prompt: Text(verbatim: "you@email.com").foregroundStyle(theme.faded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .submitLabel(.continue)
                .foregroundStyle(theme.base)
                .focused($emailFocused)
                .onSubmit { if isValidEmail { Task { await sendCode() } } }
                .authFieldBackground(theme)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.errorText)
                    .padding(.top, 2)
            }

            AuthPrimaryButton(title: "Continue", isLoading: isSending, isEnabled: isValidEmail) {
                Task { await sendCode() }
            }
            .padding(.top, 8)

            Text("We'll email you a code to sign in. No password needed.")
                .font(.caption2)
                .foregroundStyle(theme.faded)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private func sendCode() async {
        guard isValidEmail, !isSending else { return }
        emailFocused = false
        isSending = true
        errorMessage = nil
        let address = email.trimmingCharacters(in: .whitespaces)
        do {
            try await session.sendCode(to: address)
            codeEmail = address
        } catch {
            errorMessage = "Couldn't send a code. Check the address and your connection, then try again."
        }
        isSending = false
    }
}
