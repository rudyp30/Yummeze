import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(SessionStore.self) private var session
    @AppStorage("selectedThemeID") private var selectedThemeID = Theme.cozyCream.id

    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var showingSourceDialog = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var showingSignOutConfirm = false
    @State private var pickerItem: PhotosPickerItem?

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                appearanceSection
                profileSection
                accountSection
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accent)
        .disabled(isWorking)
        .overlay { if isWorking { workingOverlay } }
        .confirmationDialog("Profile photo", isPresented: $showingSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showingCamera = true }
            }
            Button("Choose from Library") { showingLibrary = true }
            if session.avatarURL != nil {
                Button("Remove Photo", role: .destructive) {
                    run { try await session.removeAvatar() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingLibrary, selection: $pickerItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in saveAvatar(image) }
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    saveAvatar(ui)
                }
                pickerItem = nil
            }
        }
        .alert("Display name", isPresented: $editingName) {
            TextField("Name", text: $nameDraft)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                run { try await session.updateDisplayName(name) }
            }
        }
        .alert("Couldn't save", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .confirmationDialog("Sign out of Yummeze?", isPresented: $showingSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                run { try await session.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private var workingOverlay: some View {
        ZStack {
            theme.base.opacity(0.08).ignoresSafeArea()
            ProgressView()
                .tint(theme.accent)
                .padding(20)
                .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel("Saving")
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("Appearance")
            VStack(spacing: 0) {
                ForEach(Theme.all) { palette in
                    themeRow(palette)
                    rowDivider
                }
                Text("More themes coming soon")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func themeRow(_ palette: Theme) -> some View {
        Button {
            selectedThemeID = palette.id
        } label: {
            HStack(spacing: 10) {
                swatch(palette)
                Text(palette.name)
                    .font(.subheadline)
                    .foregroundStyle(theme.base)
                Spacer()
                if palette.id == selectedThemeID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(palette.name)
        .accessibilityAddTraits(palette.id == selectedThemeID ? [.isButton, .isSelected] : .isButton)
    }

    private func swatch(_ palette: Theme) -> some View {
        HStack(spacing: 3) {
            chip(palette.background)
            chip(palette.accent)
            chip(palette.sweetTreat)
        }
    }

    private func chip(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("Profile")
            VStack(spacing: 0) {
                Button {
                    nameDraft = session.displayName
                    editingName = true
                } label: {
                    settingRow(label: "Display name") {
                        Text(session.displayName).foregroundStyle(theme.secondaryText)
                        chevron
                    }
                }
                .buttonStyle(.plain)

                rowDivider

                Button {
                    showingSourceDialog = true
                } label: {
                    settingRow(label: "Photo") {
                        avatarThumb
                        chevron
                    }
                }
                .buttonStyle(.plain)

                if let username = session.username {
                    rowDivider
                    settingRow(label: "Username") {
                        Text("@\(username)").foregroundStyle(theme.secondaryText)
                    }
                }
            }
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var avatarThumb: some View {
        AvatarView(urlString: session.avatarURL, initial: session.initial, diameter: 26)
    }

    // MARK: Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle("Account")
            Button {
                showingSignOutConfirm = true
            } label: {
                HStack {
                    Text("Sign out")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.errorText)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel("Sign out")
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: Bits

    private func settingRow<Trailing: View>(
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.base)
            Spacer()
            trailing()
                .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.secondaryText.opacity(0.5))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(theme.secondaryText)
            .padding(.horizontal, 4)
    }

    private var rowDivider: some View {
        Rectangle().fill(theme.secondaryText.opacity(0.1)).frame(height: 0.5).padding(.leading, 14)
    }

    // MARK: Actions

    /// Runs a cloud write with a working indicator and surfaces any failure in
    /// the error alert. Keeps every networked settings action consistent.
    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            isWorking = true
            defer { isWorking = false }
            do { try await work() }
            catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
        }
    }

    private func saveAvatar(_ image: UIImage) {
        guard let data = ImageStore.jpegData(from: image) else {
            errorMessage = "Couldn't process that photo."
            return
        }
        run { try await session.changeAvatar(data) }
    }
}
