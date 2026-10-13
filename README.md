# Yummeze

A native iOS app for logging and sharing meals with the people you like. Photograph a meal, tag it, caption it, and it lands in a photo-forward feed. Older meals roll off into a calendar archive you can scroll back through.

Built with SwiftUI, SwiftData, and Supabase.

<p align="center">
  <img src="https://github.com/user-attachments/assets/784c4287-3c73-4c55-b1ae-301307ce6839" width="150" alt="Feed">
  <img src="https://github.com/user-attachments/assets/07776603-3f9a-4bb0-8edb-d377d14bf521" width="150" alt="New meal sheet">
  <img src="https://github.com/user-attachments/assets/7a9d1827-7c6c-45a8-9072-8c33e393b819" width="150" alt="Calendar archive">
  <img src="https://github.com/user-attachments/assets/abacc89e-c15e-4a55-a5a4-e39d462b0b4e" width="150" alt="Profile and stats">
</p>

## Try it

The app ships in **demo mode**, so you can clone and run it without an account, a backend, or any credentials. Sign-in is skipped entirely and your profile is stored on-device.

**You'll need** Xcode 26 or later, and an iOS 26.2+ simulator runtime.

```bash
git clone https://github.com/rudyp30/Yummeze.git
cd Yummeze
open Meal.xcodeproj
```

Then pick any iPhone simulator and hit Run. Swift Package Manager resolves the dependencies on first open — give it a minute.

First launch drops you at profile creation (pick a name, a username, optionally a photo — every username is available in demo mode), and then you're in the app. Your profile sticks around between launches; **Settings → Reset profile** starts you over.

> **Camera capture only works on a physical device.** The simulator has no camera, so the capture sheet offers "Choose from Library" only — drag any image into the simulator to add it to the photo library first.

## Features

- **Feed**: photo-forward cards bounded to today and yesterday, grouped under sticky day headers. Multi-photo posts get a swipeable carousel.
- **Capture**: up to 10 photos per meal from camera or library, a meal category, a backdatable timestamp, and a caption.
- **Calendar archive**: a custom month grid where each day shows colored dots for the categories logged that day. Tap a day to read it back chronologically.
- **Categories**: breakfast, lunch, dinner, sweet treat, snack, drink, each with its own color and custom icon.
- **Profile**: display name, username, and avatar, editable from Settings.
- **Theming**: every color in the app comes from a `Theme` palette injected through the environment, not from system semantic colors. Adding a palette is data, not code.
- **Accessibility**: VoiceOver labels that collapse the decorative bits (calendar dots become a spoken summary), correct traits, 44pt targets, reduce-motion support.

## Stack

| | |
|---|---|
| UI | SwiftUI (iOS 26.2+), no storyboards |
| Persistence | SwiftData — meals live on-device |
| Backend | Supabase — auth, a `profiles` table, avatar storage |
| Photos | PhotosUI, plus a `UIViewControllerRepresentable` camera bridge |
| Images | ImageIO downsampling with an `NSCache` layer |
| Concurrency | `async`/`await`, `AsyncStream`, `@Observable` |

## Architecture

**Backends sit behind protocols.** `AuthProviding` and `ProfileProviding` describe everything the app needs from a backend. `SessionStore` and every view depend only on those — never on Supabase types. There are two complete implementations of each: the real Supabase one and the local demo one. That boundary is what makes demo mode a one-line switch rather than a fork.

**One source of truth for identity.** `SessionStore` owns a phase — `.loading`, `.signedOut`, `.needsProfile`, `.ready(Profile)` — and `RootView` switches on it to decide what the whole app shows. Launch resolution maps *(has session?, has profile?)* onto a phase, with a retry and a defined fallback so a network blip can't strand you on a spinner.

**Photos are files, not blobs.** Images are downscaled to a ~1080px master before they ever touch disk; the SwiftData model stores only filenames. On load, ImageIO decodes straight to display size off the main thread and caches by filename + pixel size, so the feed stays smooth however many meals pile up.

**Queries are bounded.** The feed's `@Query` predicate is scoped to today + yesterday, and the calendar builds a fresh month-scoped query per month, so no view ever loads the whole table.

### Layout

```
Meal/
├── YummezeApp.swift        App entry, theme + session injection
├── RootView.swift          Phase → screen
├── RootTabView.swift       Tab shell with the raised Add button
│
├── SessionStore.swift      Identity state machine
├── AuthService.swift       AuthProviding + the Supabase implementation
├── ProfileService.swift    ProfileProviding + the Supabase implementation
├── DemoMode.swift          The demo-mode switch
├── DemoServices.swift      Local, on-device implementations of both
│
├── WelcomeView.swift       Email entry  ┐
├── CodeEntryView.swift     6-digit code ├ real auth flow (skipped in demo mode)
├── AuthUI.swift            Shared auth components ┘
├── OnboardingView.swift    Profile creation
│
├── MealFeedView.swift      Today + yesterday
├── MealCard.swift          One post
├── MealCaptureView.swift   New meal sheet
├── CalendarView.swift      Month grid + day detail
├── ProfileView.swift       Profile tab
├── SettingsView.swift      Appearance, profile, account
│
├── Meal.swift              SwiftData model + MealType
├── Profile.swift           Cloud profile model
├── ImageStore.swift        Save / downsample / cache / delete
├── Theme.swift             Palettes, WCAG contrast helpers
│
├── AvatarView.swift        Circular avatar with monogram fallback
├── LoadedImage.swift       Async, right-sized photo loading
├── MealTypeIcon.swift      Category glyph
├── CameraPicker.swift      UIImagePickerController bridge
└── Supabase{Manager,Config}.swift   Shared client + connection details
```

## Demo mode

`Meal/DemoMode.swift` holds a single flag:

```swift
enum DemoMode {
    static let isEnabled = true
}
```

While it's `true`, `SessionStore` is built with `DemoAuthService` and `DemoProfileService` instead of the Supabase pair. The app is permanently "signed in" as one local user, the profile lives in `UserDefaults`, and avatars are written to the app's Documents directory. Nothing touches the network. The real auth path is untouched and still compiles — it just isn't the one that gets picked.

### Running it against a real backend

Flip the flag to `false` and point `Meal/SupabaseConfig.swift` at your own Supabase project. You'll need email OTP enabled in Auth settings, a `profiles` table, and a public `avatars` storage bucket.

The shape the code expects, derived from `ProfileService`:

```sql
create table profiles (
  id           uuid primary key references auth.users on delete cascade,
  username     text unique not null,
  display_name text not null,
  avatar_url   text,
  created_at   timestamptz not null default now()
);
```

Row Level Security does the real access control: users may only write their own row, and the storage policies on `avatars` key off the first path segment of the object path, which is the user's id. Usernames are stored lowercased and compared that way.

> The anon key in `SupabaseConfig.swift` is public by design — it's meant to ship in the client, and RLS is what protects the data. The `service_role` key must never go in the app.

## Status

A personal project, still in progress. Worth knowing:

- Meals are **local to each device**. Profiles are cloud-backed; the shared-feed sync layer is designed for (the model already carries an `authorID`) but not built.
- Like and comment buttons are UI placeholders for the planned social layer.
- No test suite yet.
- One theme is finished — the palette system supports more, including a dark one, and they're next.
- Not on the App Store.
