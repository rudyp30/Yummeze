import SwiftUI
import Combine

/// The 6-digit code screen. The six boxes are purely a display of a SINGLE
/// backing string — one hidden numeric field (with `.oneTimeCode` so iOS can
/// autofill the code from the email) receives all input. That keeps SMS/mail
/// autofill and paste working, which per-box fields break.
struct CodeEntryView: View {
    let email: String

    @Environment(\.theme) private var theme
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var secondsLeft = 30
    @FocusState private var fieldFocused: Bool

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let digitCount = 6

    var body: some View {
        VStack(spacing: 0) {
            backBar
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
            AuthPrimaryButton(title: "Verify", isLoading: isVerifying, isEnabled: code.count == digitCount) {
                Task { await verify() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(tick) { _ in if secondsLeft > 0 { secondsLeft -= 1 } }
        .onAppear { fieldFocused = true }
    }

    // MARK: Back

    private var backBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.accentText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.accent.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "envelope")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(theme.accentText)
                )
                .accessibilityHidden(true)
                .padding(.bottom, 6)

            Text("Check your email")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.base)

            Text("Enter the 6-digit code we sent to\n\(Text(email).fontWeight(.semibold).foregroundStyle(theme.base))")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)

            codeBoxes
                .padding(.top, 20)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(theme.errorText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 24)
            }

            resendControl
                .padding(.top, 18)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Code boxes (display of `code`, backed by one hidden field)

    private var codeBoxes: some View {
        ZStack {
            // The real input: near-invisible, but present so it can hold focus,
            // receive keyboard input, and be targeted by one-time-code autofill.
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($fieldFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityLabel("6-digit verification code")
                .onChange(of: code) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(digitCount))
                    if digits != newValue { code = digits; return }
                    errorMessage = nil
                    if digits.count == digitCount { Task { await verify() } }
                }

            HStack(spacing: 8) {
                ForEach(0..<digitCount, id: \.self) { index in
                    box(at: index)
                }
            }
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { fieldFocused = true }
    }

    private func box(at index: Int) -> some View {
        let chars = Array(code)
        let filled = index < chars.count
        let isNext = index == chars.count && fieldFocused
        let active = filled || isNext
        return RoundedRectangle(cornerRadius: 10)
            .fill(theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? theme.accent : theme.base.opacity(0.15),
                            lineWidth: active ? 1.5 : 0.5)
            )
            .frame(width: 44, height: 54)
            .overlay(
                Text(filled ? String(chars[index]) : "")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.base)
            )
    }

    // MARK: Resend

    @ViewBuilder private var resendControl: some View {
        if secondsLeft > 0 {
            Text("Resend code in 0:\(String(format: "%02d", secondsLeft))")
                .font(.subheadline)
                .foregroundStyle(theme.faded)
        } else {
            Button {
                Task { await resend() }
            } label: {
                Text("Resend code")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.accentText)
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("Resend code")
        }
    }

    // MARK: Actions

    private func verify() async {
        guard code.count == digitCount, !isVerifying else { return }
        fieldFocused = false
        isVerifying = true
        errorMessage = nil
        do {
            try await session.verifyCode(code, email: email)
            // Success flips the app phase; RootView tears this screen down.
        } catch {
            errorMessage = "That code didn't work. Double-check it and try again."
            code = ""
            isVerifying = false
            fieldFocused = true
        }
    }

    private func resend() async {
        do {
            try await session.sendCode(to: email)
            secondsLeft = 30
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't resend the code. Try again in a moment."
        }
    }
}
