# When-R-U-Free
A simple app to find when friends at sixth form / college / uni are free to hang out between lessons — making scattered timetables easy to compare so shared breaks become study sessions (or actual breaks).

### This App is licensed using the Vio License:
**What this means:**
This is the source code for When R U Free. If you just want to use the app, please download the official version.

**Downloads coming soon**

⚠️ For Developers & Contributors: This project is Source Available.

You may fork this repo to view the code, learn, and contribute fixes.

You may not distribute compiled binaries (APKs/IPAs) of this app.

Please read the [Vio License](./LICENSE.md) carefully before forking.

---

## What the app does (working now)

**Timetable entry — two ways**
- **Manual:** Mon–Sun tabs, add/edit/delete lessons (subject, day, start/end, room), overlap warnings, swipe-to-delete, sample loader.
- **Microsoft 365 import:** Settings → *Import from Microsoft 365* → sign in with Microsoft (read-only calendar access) → **pick a username** → review the week's classes with ticks → Import. Duplicates are skipped automatically. Works with a free Azure app registration (setup below); a demo preview mode lets you try the flow with no setup.

**Find shared gaps**
- **Home** — greeting, who's free right now, next all-free slot today, best meetups of the week (ranked), your lessons + busy overrides today.
- **Week** — day picker + 30-minute heatmap (how many of the group are free per slot); tap any row for a per-person breakdown + "copy plan for group chat".

**Gap notifications** 🔔
- First launch asks: *"Get pinged before shared breaks?"* — then you get a heads-up naming who else is free, X minutes before each shared gap (configurable 0–30 min, Settings → Gap alerts, with a test button).
- Fully on-device (no server needed); schedules rebuild automatically whenever timetables, friends, busy blocks, or settings change.

**"I'm actually busy then"**
- Any shared gap (Home, Week) has an *I'm actually busy then* button → creates a one-off busy override for that date. Overrides carve time out of gaps and notifications without touching your weekly timetable. Manage them via Timetable → ⛔ icon.

**Share timetables offline**
- Timetable → *Share my timetable* produces a `WRF1-…` text code for any chat app. Friends → *Import a shared timetable* pastes it and adds that friend with their **real** lessons (or merges into your own timetable if it's your code). No account, no cloud.

**Storage: local-first, cloud-ready**
- Everything persists on-device — no account, works offline.
- `lib/config/cloud_config.dart` + `lib/firebase_options.dart` (blank keys on purpose) + `lib/data/cloud/firestore_data_store.dart` (anonymous Auth + Firestore push/pull + friend-code lookup) are fully written and dormant. Paste keys → flip one flag → sync activates.

**Optional thin server** (`server/`, Express)
- `GET /health`, `POST /api/overlap` (same algorithm in JS). The Graph token-swap endpoint is a stub kept for reference — the app uses direct PKCE (public client, no secret exists anywhere), so the server is not needed for Microsoft sync.

## Run it

```bash
cd whenrufree
flutter pub get
flutter run          # or: flutter run -d chrome / windows / <device>
flutter test         # 29 tests (unit + widget)
flutter analyze      # clean
flutter build apk --debug   # verified building
```

## Tech stack

Flutter (Material 3, Provider) · SharedPreferences (local-first) · flutter_local_notifications (gap alerts) · Microsoft Graph via hand-rolled OAuth PKCE (http + app_links + flutter_secure_storage — refresh token only, no-data-stored) · Firebase Auth + Firestore (wired, keys blank) · Node/Express stub (`server/`)

## Project layout

```
whenrufree/lib/
  main.dart                 bootstrap (+ dormant Firebase init, notification init)
  firebase_options.dart     BLANK keys — paste real ones here
  config/cloud_config.dart  kCloudBackendEnabled flag + Firestore schema docs
  config/graph_config.dart  Microsoft client/redirect/scope config + Azure steps
  models/                   lesson, busy_block, user_profile (+friend codes),
                            friend, free_slot
  services/                 availability_service (recurring + date-aware),
                            notification_service, timetable_share,
                            sample_data, graph/{graph_auth, graph_calendar}
  data/                     app_store (state + persistence), cloud/firestore_data_store
  ui/                       app shell + onboarding, 6 screens,
                            editor/detail/busy/share sheets
  utils/time_fmt.dart
server/                     optional Express backend (overlap API + Graph stub)
android|ios|macos           OAuth redirect scheme (whenrufree://auth) +
                            notification permissions already applied
```

## Microsoft 365 setup (free, ~5 min, once)

1. https://entra.microsoft.com → **App registrations** → New registration (personal MS account is fine).
2. Supported account types: **"Accounts in any organizational directory and personal Microsoft accounts"**.
3. **Authentication** → Add platform → **Mobile and desktop applications** → add redirect URI exactly: `whenrufree://auth`
4. **API permissions** → Add → Microsoft Graph → **Delegated** → `Calendars.Read` (openid/profile/offline_access are default).
5. Copy the **Application (client) ID** → in the app: Settings → *Import from Microsoft 365* → paste it → Save & continue → Connect Microsoft.
6. That's it — sign in, pick a username, tick classes, Import.

Notes: Android/iOS/macOS redirect handling is already configured in this repo. On Windows/Linux the wizard offers a paste-the-redirect-URL fallback. To revoke: disconnect in the app (deletes the refresh key) and/or remove consent at https://myapps.microsoft.com.

## ☁️ Action needed: free cloud database

**Please create one free Firebase project (Spark plan — no billing) so friend codes work across devices:**

1. Go to https://console.firebase.google.com → Add project (any name, e.g. `when-r-u-free`), disable Gemini/Analytics if offered.
2. **Authentication** → Sign-in method → enable **Anonymous**.
3. **Firestore Database** → Create database → **production mode**, region closest to users (e.g. `eur3`) → then **Rules** tab, paste:
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{db}/documents {
       match /users/{uid} {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.uid == uid;
         match /lessons/{id} {
           allow read: if request.auth != null;
           allow write: if request.auth != null && request.auth.uid == uid;
         }
       }
     }
   }
   ```
4. Project settings → **Your apps** → add **Android** (package `com.example.whenrufree` — or your real one), **iOS** if needed, and **Web** → download `google-services.json` / `GoogleService-Info.plist` + copy the web config values.
5. Send me: the `google-services.json`, `GoogleService-Info.plist`, and the web `firebaseConfig` object (or just run `flutterfire configure` yourself and push the regenerated `lib/firebase_options.dart`).

**I will then:** drop the files in, set `kCloudBackendEnabled = true`, and verify cross-device friend-code lookup. Nothing else changes — the sync code is already written and waiting.
