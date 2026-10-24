# Development & Testing Guide

This guide contains everything you need to build, test, and contribute to **When R U Free**.

---

## 1. Prerequisites & Environment

- **Flutter SDK:** Version `3.10.4` or higher (tested with Dart `3.10.4`+ and Flutter `3.38.5`).
- **Target Toolchains:**
  - **Android:** Android Studio / Android SDK (API level 34+ recommended).
  - **iOS / macOS:** Xcode 15+ (on macOS).
  - **Windows:** Visual Studio 2022 with C++ desktop development workload.
  - **Linux:** `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`.
  - **Web:** Chrome or any modern Chromium-based browser.

---

## 2. Project Structure

```text
When-R-U-Free/
├── docs/                      # Architectural & setup documentation
├── server/                    # Optional Node.js Express companion server
│   ├── package.json
│   └── src/index.js
└── whenrufree/                # Primary Flutter application
    ├── lib/
    │   ├── config/            # Cloud & Microsoft Graph configuration
    │   ├── data/              # State store (AppStore) & Firestore layer
    │   ├── models/            # Lesson, Friend, BusyBlock, FreeSlot, Profile
    │   ├── services/          # Availability, notifications, sharing, Graph API
    │   ├── ui/                # Material 3 screens & bottom sheets
    │   ├── utils/             # Timeline & time formatting utilities
    │   ├── firebase_options.dart
    │   └── main.dart
    └── test/                  # Unit and widget test suite
```

---

## 3. Running Locally

### Clone and Get Dependencies
```bash
cd whenrufree
flutter pub get
```

### Launch on Your Device or Emulator
```bash
# Run on connected phone or default desktop target
flutter run

# Run on Chrome
flutter run -d chrome

# Run on Windows desktop
flutter run -d windows
```

---

## 4. Testing Suite

The repository contains a comprehensive suite of **58 unit and widget tests** covering:
- Mathematical interval intersection, carving, and boundary merging (`availability_test.dart`).
- Date-aware one-off busy override carving and upcoming gap projection (`busy_test.dart`).
- Pure JSON parsing, timezone conversions, and overnight event splitting for Microsoft Graph (`graph_test.dart`).
- Offline friend CRUD, name deduplication, demo dataset toggling, and app mode switching (`offline_test.dart`).
- UI overflow, responsiveness, and safe scrolling across all bottom sheets (`overflow_test.dart`).
- Timetable encoding/decoding and payload compression safety for QR scanning (`share_test.dart`).
- Proportional timeline visual block generation (`timeline_test.dart`).
- App shell onboarding navigation flow (`widget_test.dart`).

### Execute All Tests
```bash
cd whenrufree
flutter test
```

### Run Static Analysis
```bash
cd whenrufree
flutter analyze
```

---

## 5. Building for Production

### Android APK
```bash
cd whenrufree
flutter build apk --release
```
The compiled APK will be output to `build/app/outputs/flutter-apk/app-release.apk`.

### Web
```bash
cd whenrufree
flutter build web --release
```

---

## 6. Optional Express Server (`server/`)

The repository includes an optional Node/Express companion service (`server/`):
- Exposes `GET /health` and `POST /api/overlap` (runs the same interval intersection algorithm in JavaScript).
- Kept for reference or headless integration; the Flutter client computes all availability on-device and does not require this server to run.

To run the server:
```bash
cd server
npm install
npm start
```
Default port: `3000`.
