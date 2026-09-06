/// Microsoft 365 / Graph configuration.
///
/// No Azure app? The app still works: manual entry stays, and the import
/// screen offers a demo preview + exact setup steps. To go live:
///   1. https://entra.microsoft.com → App registrations → New registration.
///   2. Supported account types: "Accounts in any organizational directory
///      and personal Microsoft accounts".
///   3. Redirect URI → "Mobile and desktop applications" → add
///      `whenrufree://auth` (must match [kGraphRedirectUri] exactly).
///   4. API permissions → add DELEGATED `Calendars.Read` (+ default
///      `openid profile offline_access`), grant admin consent if required.
///   5. Copy the "Application (client) ID" into the app: Settings → Import
///      from Microsoft 365 → paste it (stored on-device only), or paste it
///      into [kBundledClientId] below before building.
///
/// Public-client PKCE is used, so NO client secret exists anywhere.
library;

/// Tenant: `common` (any work/school/personal account), or a tenant id.
const String kGraphTenantId = 'common';

/// Must be registered in the Azure app AND in native manifests/plists
/// (already applied in this repo: Android intent-filter, iOS/macOS URL
/// scheme). Windows/Linux use the paste-the-redirect-URL fallback.
const String kGraphRedirectUri = 'whenrufree://auth';

/// Minimal scopes: identity + refresh + read calendars only.
const List<String> kGraphScopes = [
  'openid',
  'profile',
  'offline_access',
  'Calendars.Read',
];

/// Optional build-time default. Blank on purpose — the user can paste their
/// client ID at runtime (Settings → Microsoft 365), stored in
/// SharedPreferences. Either source enables the flow.
const String kBundledClientId = '';

const String kGraphAuthorityHost = 'login.microsoftonline.com';
const String kGraphApiHost = 'graph.microsoft.com';
