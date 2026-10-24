# When-R-U-Free 🕒👥

> **Find when friends at sixth form, college, or university are free to hang out between lessons.**  
> Turn scattered, confusing timetables into clear, shared breaks — study sessions, coffee runs, or actual downtime.

[![Flutter](https://img.shields.io/badge/Flutter-3.38.5-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.4-0175C2?logo=dart)](https://dart.dev)
[![License: PolyForm Small Business](https://img.shields.io/badge/License-PolyForm_Small_Business_1.0.0-blue.svg)](LICENSE.md)
[![Tests](https://img.shields.io/badge/Tests-58%20Passing-brightgreen.svg)](whenrufree/test)
[![Analysis](https://img.shields.io/badge/Analysis-Clean-brightgreen.svg)](whenrufree)

---

## ⚡ What is When-R-U-Free?

Comparing weekly timetables with friends is usually a mess of screenshots, group chat confusion, and missed free periods. **When R U Free** solves this with a **local-first, privacy-focused** app that calculates exactly when you and your friends share breaks.

- **100% Usable Offline:** No accounts, passwords, or cloud servers required. Your timetable stays on your phone.
- **Zero-Friction Sharing:** Transfer timetables instantly using optical **QR codes** or portable **chat text codes**.
- **Calendar Auto-Import:** Sign in with your school or university **Microsoft 365 / Outlook** account to pull your classes straight in with read-only PKCE security.
- **Smart Group Availability:** Carves out busy periods and intersects your free time with friends in real-time.

---

## 🚀 Key Features (Ready & Working Today)

| Feature | Description |
| :--- | :--- |
| **🏠 Live "Free Now" Dashboard** | Home screen with real-time status chips showing who is free right now and when their next lesson starts (*"Jess (till 14:30)"*), next all-free break, and ranked weekly meetups. |
| **📅 Proportional Week Timeline** | Adaptive visual blocks that scale proportionally with duration; collapses non-relevant busy periods into compact skip dividers. |
| **🔍 Shared Break Inspection** | Tap any break to see a member-by-member tally (free vs in class), a 1-tap **"Copy plan for group chat"** button, and an override trigger. |
| **⛔ "I'm Actually Busy Then"** | One-off calendar date overrides that carve time out of shared gaps for doctor visits or errands without altering your recurring weekly timetable. |
| **📲 Offline P2P Sharing** | Generate full timetable QR codes or Base64 text codes; scan using the built-in camera scanner with instant preview. |
| **🎓 Microsoft 365 Import** | Direct OAuth 2.0 PKCE sign-in pulling weekly calendar events, automatically skipping all-day/free events, splitting overnight classes, and converting timezones. |
| **🔔 On-Device Break Alerts** | Background notifications scheduled locally on your device 0–30 minutes before shared breaks, naming who else is free. |
| **👥 Group Management** | Name-based friend rosters with individual include/exclude toggle switches, manual friend timetable editing, and demo friend presets. |
| **💾 Backup & Restore** | Full local JSON backup export (clipboard & system share sheet) and one-tap restore. |

---

## 📚 Documentation

Detailed technical documentation and guides are available in the [`docs/`](docs/README.md) directory:

- 🏗️ **[Architecture & Design](docs/architecture.md):** Local-first philosophy, state management with Provider, persistence, and security model.
- 📱 **[Features & User Guide](docs/features.md):** Detailed walkthrough of all 12 implemented features and UI flows.
- 📐 **[Availability Algorithm](docs/availability-algorithm.md):** Technical explanation of interval carving, mutual intersection, grouped adaptive blocks, and ranking.
- 🔑 **[Microsoft 365 Setup Guide](docs/microsoft-graph-setup.md):** How to register a free Azure client ID, configure permissions, and test using demo mode.
- ☁️ **[Cloud Sync & Firebase Guide](docs/cloud-sync-setup.md):** Explanation of the dormant cloud sync layer, Firestore rules, and activation steps.
- 🛠️ **[Development & Testing Guide](docs/development.md):** Setup instructions, test suite execution, building releases, and companion server info.
- 📜 **[Changelog](CHANGELOG.md):** Comprehensive release notes and version history ([archive](docs/changelog/README.md)).

---

## 🏁 Quick Start

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.10.4`)

### Run the App
```bash
# Navigate to the Flutter project
cd whenrufree

# Fetch dependencies
flutter pub get

# Run on your default device, connected phone, or emulator
flutter run

# Or run specifically on desktop or browser:
flutter run -d chrome
flutter run -d windows
```

### Run Tests & Analysis
```bash
# Run all 58 unit & widget tests
flutter test

# Run static analysis (clean, 0 warnings)
flutter analyze
```

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev) (Material 3, Dart 3)
- **State & Storage:** [Provider](https://pub.dev/packages/provider) + [SharedPreferences](https://pub.dev/packages/shared_preferences) (local-first JSON persistence)
- **Secure Storage:** [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (OAuth refresh token encryption)
- **Scanning & Codes:** [mobile_scanner](https://pub.dev/packages/mobile_scanner) + [qr_flutter](https://pub.dev/packages/qr_flutter)
- **Notifications:** [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) + [timezone](https://pub.dev/packages/timezone)
- **Calendar API:** Direct OAuth 2.0 PKCE via `http` + `app_links` to Microsoft Graph (`/v1.0/me/calendarview`)
- **Cloud Backend (Dormant):** Firebase Auth (anonymous) + Cloud Firestore (ready for activation)
- **Companion Server:** Node.js + Express (optional helper in `server/`)

---

## 📂 Project Structure

```text
When-R-U-Free/
├── docs/                       # Architecture, feature, setup, & algorithm guides
│   ├── architecture.md
│   ├── features.md
│   ├── availability-algorithm.md
│   ├── microsoft-graph-setup.md
│   ├── cloud-sync-setup.md
│   ├── development.md
│   └── changelog/              # Archived version release notes
├── server/                     # Optional Node/Express server (overlap API)
├── whenrufree/                 # Primary Flutter Application
│   ├── lib/
│   │   ├── config/             # Cloud flags and Microsoft Graph settings
│   │   ├── data/               # AppStore state management & Firestore data store
│   │   ├── models/             # Lesson, Friend, BusyBlock, FreeSlot, UserProfile
│   │   ├── services/           # Availability engine, notifications, sharing, Graph API
│   │   ├── ui/                 # Screens, dialogs, bottom sheets, & custom widgets
│   │   ├── utils/              # Timeline builder & time formatting helpers
│   │   ├── firebase_options.dart # Blank template options (safe for public git)
│   │   └── main.dart           # App bootstrap
│   └── test/                   # Comprehensive unit & widget test suite (58 tests)
├── CHANGELOG.md                # Project changelog
└── LICENSE.md                  # PolyForm Small Business License 1.0.0
```

---

## 📄 License

This project is licensed under the **PolyForm Small Business License 1.0.0** — see the [LICENSE.md](LICENSE.md) file for details.

> **Required Notice:** Copyright Vio (PenguinBTW).
