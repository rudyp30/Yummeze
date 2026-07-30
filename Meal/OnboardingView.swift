import SwiftUI
import PhotosUI

/// Create-profile screen, shown once after sign-in when the user has no profile
/// row yet. Optional avatar, a display name (prefilled from the email local
/// part), and a username with live availability checking. Finishing inserts the
/// profile and flips the app to `.ready`.
struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Environment(SessionStore.self) private var session

    @State private var displayName = ""
    @State private var username = ""

    @State private var pickerItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var avatarData: Data?

    @State private var availability: Availability = .idle
    @State private var checkTask: Task<Void, Never>?

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private enum Availability: Equatable { case idle, invalid, checking, available, taken, error }

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFormatValid: Bool {
        username.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    private var canContinue: Bool {
        !trimmedName.isEmpty && availability == .available && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                avatarPicker
                nameField
                usernameField
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(theme.errorText)
                        .multilineTextAlignment(.center)
                }
                AuthPrimaryButton(title: "Continue", isLoading: isSubmitting, isEnabled: canContinue) {
                    Task { await submit() }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .tint(theme.accent)
        .scrollDismissesKeyboard(.interactively)
        .onAppear(perform: prefillName)
        .onChange(of: pickerItem) { _, item in loadAvatar(item) }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Create your profile")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.base)
            Text("This is how friends will see you on Yummeze.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Avatar

    private var avatarPicker: some View {
        VStack(spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    Circle().fill(theme.accent)
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(theme.onAccent)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(theme.accentText)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(theme.onAccent)
                        )
                        .overlay(Circle().stroke(theme.background, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(avatarImage == nil ? "Add a photo" : "Change photo")

            Text("Add a photo (optional)")
                .font(.footnote)
                .foregroundStyle(theme.secondaryText)
        }
    }

    // MARK: Name

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            AuthFieldLabel("Name")
            TextField("", text: $displayName, prompt: Text("Your name").foregroundStyle(theme.faded))
                .textContentType(.name)
                .foregroundStyle(theme.base)
                .authFieldBackground(theme)
        }
    }

    // MARK: Username

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            AuthFieldLabel("Username")
            HStack(spacing: 4) {
                Text("@")
                    .font(.body)
                    .foregroundStyle(theme.secondaryText)
                TextField("", text: $username, prompt: Text("username").foregroundStyle(theme.faded))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(theme.base)
                Spacer(minLength: 8)
                availabilityBadge
            }
            .authFieldBackground(theme)
            .onChange(of: username) { _, raw in handleUsernameChange(raw) }

            Text(availability == .invalid
                 ? "Use 3–20 letters, numbers, or underscores."
                 : "Letters, numbers, and underscores. This is how friends find you.")
                .font(.caption)
                .foregroundStyle(availability == .invalid ? theme.errorText : theme.faded)
        }
    }

    @ViewBuilder private var availabilityBadge: some View {
        switch availability {
        case .checking:
            HStack(spacing: 5) {
                ProgressView().controlSize(.small)
                Text("Checking").font(.caption).foregroundStyle(theme.secondaryText)
            }
            .accessibilityLabel("Checking availability")
        case .available:
            Label("Available", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.accentText)
        case .taken:
            Label("Taken", systemImage: "xmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.errorText)
        case .error:
            Text("Try again").font(.caption).foregroundStyle(theme.secondaryText)
        case .idle, .invalid:
            EmptyView()
        }
    }

    // MARK: Logic

    private func prefillName() {
        guard trimmedName.isEmpty else { return }
        if let local = session.signedInEmail?.split(separator: "@").first {
            displayName = String(local)
        }
    }

    private func handleUsernameChange(_ raw: String) {
        let cleaned = raw.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        if cleaned != raw { username = cleaned; return }   // re-enters onChange
        scheduleAvailabilityCheck()
    }

    /// Debounced availability check: waits ~400ms after typing stops, cancelling
    /// any in-flight check, so we don't hammer the server on every keystroke.
    private func scheduleAvailabilityCheck() {
        checkTask?.cancel()
        guard isFormatValid else {
            availability = username.isEmpty ? .idle : .invalid
            return
        }
        availability = .checking
        let name = username
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }
            do {
                let free = try await session.isUsernameAvailable(name)
                if !Task.isCancelled && name == username {
                    availability = free ? .available : .taken
                }
            } catch {
                if !Task.isCancelled && name == username { availability = .error }
            }
        }
    }

    private func loadAvatar(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                avatarImage = image
                avatarData = ImageStore.jpegData(from: image)
            }
        }
    }

    private func submit() async {
        guard canContinue else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            var avatarURL: String?
            if let avatarData {
                avatarURL = try await session.uploadAvatar(avatarData)
            }
            try await session.completeOnboarding(
                username: username,
                displayName: trimmedName,
                avatarURL: avatarURL
            )
            // Success flips the app phase; this screen is torn down.
        } catch ProfileError.usernameTaken {
            availability = .taken
            errorMessage = "That username was just taken — try another."
            isSubmitting = false
        } catch {
            errorMessage = "Something went wrong. Please try again."
            isSubmitting = false
        }
    }
}
