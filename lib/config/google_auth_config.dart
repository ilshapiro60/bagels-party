/// OAuth **Web application** client ID from Firebase Console → Project settings →
/// Your apps → Web (or Google Cloud → APIs & Services → Credentials).
///
/// - **Android / iOS:** passed as [GoogleSignIn.initialize] `serverClientId` so
///   Google returns an `id_token` for [FirebaseAuth].
/// - **Web:** passed as `clientId` (required by `google_sign_in_web`).
const String kGoogleWebClientId =
    '1073924094679-k3evsri0r53cvh5v9ostl74vr8e6168l.apps.googleusercontent.com';
