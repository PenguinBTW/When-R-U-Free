/// Cloud backend switch.
///
/// The app is local-first: everything works offline via SharedPreferences.
/// To enable the shared cloud backend (Firebase Auth + Firestore):
///   1. Ask the project owner for a free Firebase project (Spark plan is
///      enough: Authentication + Firestore, no billing required).
///   2. Run `flutterfire configure` (or paste the values into
///      `lib/firebase_options.dart`).
///   3. Set [kCloudBackendEnabled] to true.
///   4. Add the platform files (`google-services.json` / `GoogleService-Info.plist`).
///
/// Until then the app compiles and runs fully offline and the Firestore sync
/// layer simply stays dormant.
const bool kCloudBackendEnabled = false;

/// Firestore collection layout (used once the backend is enabled):
///   users/{uid}                 -> { displayName, friendCode, college, updatedAt }
///   users/{uid}/lessons/{id}    -> { subject, weekday, startMin, endMin, location }
///   friendships/{code}          -> { ownerUid, displayName }  (lookup by friend code)
const String kUsersCollection = 'users';
const String kLessonsSubcollection = 'lessons';
