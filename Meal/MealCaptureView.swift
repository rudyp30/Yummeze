import SwiftUI
import SwiftData
import PhotosUI

struct MealCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    /// A picked/taken photo with a stable id, so the gallery can remove cleanly
    /// regardless of source (library or camera).
    private struct SelectedPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @State private var photos: [SelectedPhoto] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var mealType: MealType = .lunch
    @State private var timestamp: Date = .now
    @State private var caption = ""
    @State private var showingSourceDialog = false
    @State private var showingCamera = false
    @State private var showingLibrary = false

    private let maxPhotos = 10

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    photoArea
                    typeChips
                    whenPicker
                    captionField
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(theme.background)
            .navigationTitle("New Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(photos.isEmpty)
                }
            }
            .tint(theme.accent)
            .photosPicker(
                isPresented: $showingLibrary,
                selection: $pickerItems,
                maxSelectionCount: maxPhotos,
                matching: .images
            )
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    if photos.count < maxPhotos {
                        photos.append(SelectedPhoto(image: image))
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await loadFromLibrary(items) }
            }
        }
    }

    // MARK: Photos

    @ViewBuilder private var photoArea: some View {
        Group {
            if photos.isEmpty {
                Button { showingSourceDialog = true } label: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.card)
                        .frame(height: 280)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill").font(.largeTitle)
                                Text("Add a photo").font(.headline)
                            }
                            .foregroundStyle(theme.secondaryText)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    TabView {
                        ForEach(photos) { photo in
                            Color.clear
                                .frame(height: 280)
                                .overlay {
                                    Image(uiImage: photo.image)
                                        .resizable()
                                        .scaledToFill()
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(alignment: .topTrailing) { removeButton(photo) }
                        }
                    }
                    .frame(height: 280)
                    .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))

                    if photos.count < maxPhotos {
                        Button { showingSourceDialog = true } label: {
                            Label("Add more photos", systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .confirmationDialog("Add a photo", isPresented: $showingSourceDialog, titleVisibility: .visible) {
            // Camera is unavailable on the Simulator, so only offer it on a real device.
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showingCamera = true }
            }
            Button("Choose from Library") { showingLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func removeButton(_ photo: SelectedPhoto) -> some View {
        Button {
            photos.removeAll { $0.id == photo.id }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.35))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove photo")
    }

    // MARK: Type / when / caption

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MealType.allCases) { type in
                    let selected = type == mealType
                    let color = theme.color(for: type)
                    Button {
                        mealType = type
                    } label: {
                        HStack(spacing: 6) {
                            MealTypeIcon(type: type, size: 16)
                            Text(type.displayName).font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .foregroundStyle(selected ? color.readableText : theme.base)
                        .background(selected ? color : theme.card, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(theme.secondaryText.opacity(selected ? 0 : 0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var whenPicker: some View {
        DatePicker(
            "When",
            selection: $timestamp,
            in: ...Date.now,
            displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.compact)
        .foregroundStyle(theme.base)
        .padding()
        .background(theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private var captionField: some View {
        TextField("Add a description to your Yummeze!", text: $caption, axis: .vertical)
            .lineLimit(2...4)
            .padding()
            .foregroundStyle(theme.base)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Actions

    /// Loads a library multi-selection into `photos` (capped at `maxPhotos`),
    /// then clears the picker selection so the next session starts fresh.
    private func loadFromLibrary(_ items: [PhotosPickerItem]) async {
        var loaded: [SelectedPhoto] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                loaded.append(SelectedPhoto(image: ui))
            }
        }
        let room = maxPhotos - photos.count
        if room > 0 { photos.append(contentsOf: loaded.prefix(room)) }
        pickerItems = []
    }

    private func save() {
        guard !photos.isEmpty else { return }
        let filenames = photos.compactMap { ImageStore.save($0.image) }
        guard !filenames.isEmpty else { return }
        let meal = Meal(
            mealType: mealType,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: timestamp,
            imageFilenames: filenames
        )
        context.insert(meal)
        dismiss()
    }
}
