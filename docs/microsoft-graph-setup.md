# Microsoft 365 / Graph Setup Guide

When R U Free integrates directly with Microsoft 365 and Outlook calendars via the Microsoft Graph API. This guide walks you through registering an Azure application to enable calendar auto-import.

---

## 1. Overview & Architecture

- **Public Client with PKCE:** Uses OAuth 2.0 Authorization Code Flow with PKCE. **No client secret exists** anywhere in the client code or on any server.
- **Read-Only Scope:** Requests delegated `Calendars.Read` access only. It cannot create, edit, or delete calendar events.
- **No-Data-Stored Model:** Only the OAuth refresh token is saved (in platform secure storage). Access tokens remain in memory. Calendar data is only written as lessons if the user explicitly confirms import.

---

## 2. Azure App Registration (5 Minutes)

You can create an application registration for free with any Microsoft personal, work, or student account:

1. Navigate to the **[Microsoft Entra Admin Center](https://entra.microsoft.com)**.
2. In the sidebar, expand **Identity** → **Applications** → click **App registrations**.
3. Click **New registration**:
   - **Name:** `When R U Free` (or your preferred name).
   - **Supported account types:** Select **"Accounts in any organizational directory (Any Microsoft Entra ID tenant - Multitenant) and personal Microsoft accounts (e.g. Skype, Xbox)"**.
   - **Redirect URI:** Leave blank for now.
   - Click **Register**.
4. In the app overview, click **Authentication** (left sidebar):
   - Under **Platform configurations**, click **Add a platform** → select **Mobile and desktop applications**.
   - In the **Redirect URIs** field, enter:
     ```text
     whenrufree://auth
     ```
   - Click **Configure**.
5. Click **API permissions** (left sidebar):
   - By default, `User.Read` is already added.
   - Click **Add a permission** → select **Microsoft Graph** → select **Delegated permissions**.
   - Search for `Calendars.Read` → check the box → click **Add permissions**.
6. Navigate back to **Overview**:
   - Copy the **Application (client) ID** (a standard UUID string like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).

---

## 3. Connecting in the App

### Option A: In-App Setup (Runtime)
1. Open When R U Free.
2. Navigate to **Settings** → tap **Import from Microsoft 365**.
3. In the setup step, paste your **Application (client) ID**.
4. Tap **Save & continue**.
5. Tap **Connect Microsoft** — your system browser will open for authentication.
6. Grant consent and return to the app.

### Option B: Build-Time Default
If building a release for your student group or organization, you can pre-configure the client ID:
1. Open `lib/config/graph_config.dart`.
2. Set:
   ```dart
   const String kBundledClientId = 'YOUR-AZURE-CLIENT-ID-HERE';
   ```
3. Rebuild the app with `flutter build apk` or `flutter run`.

---

## 4. Platform Redirect Configurations

Native platform configurations for `whenrufree://auth` are already configured in this repository:

- **Android:** Handled in `android/app/src/main/AndroidManifest.xml` via `<intent-filter>` with scheme `whenrufree` and host `auth`.
- **iOS:** Handled in `ios/Runner/Info.plist` under `CFBundleURLTypes` with URL scheme `whenrufree`.
- **macOS:** Handled in `macos/Runner/Info.plist` with URL scheme `whenrufree`.
- **Windows / Linux:** If system deep links are not routed, the import screen provides a manual **"Paste redirect URL"** fallback where you can paste the full browser address bar URL after logging in.

---

## 5. Revoking Access

To disconnect at any time:
1. Open **Settings** → tap **Import from Microsoft 365** → tap **Disconnect** in the top bar. This immediately deletes the refresh token from secure storage.
2. To revoke organizational consent completely, visit [Microsoft My Apps](https://myapps.microsoft.com) and remove permissions.
