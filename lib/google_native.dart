import 'package:google_sign_in/google_sign_in.dart';
import 'cal_sync.dart';

/// Native Google Sign-In for iOS.
///
/// Runs Google's native account sheet, gets the ID token, and trades it for the
/// shared Kuklabs session via `/api/auth/google/native-exchange` — the SAME One
/// Kuklabs Account as the deep-link flow (server keys both on `google:<sub>`).
/// The iOS OAuth client id comes from the bundled GoogleService-Info.plist
/// (google_sign_in reads it natively), so nothing is hardcoded here.
///
/// Android keeps the browser deep-link flow (`google_auth.dart`) — this native
/// path is iOS-only.
class GoogleNativeAuth {
  GoogleNativeAuth._();
  static final GoogleNativeAuth instance = GoogleNativeAuth._();

  final GoogleSignIn _google = GoogleSignIn(scopes: const ['email', 'profile']);

  /// Present the Google sheet and complete sign-in. Returns false if the user
  /// cancelled (no error to surface); throws on a genuine failure.
  Future<bool> signIn() async {
    // Sign out first so the account picker always shows, rather than silently
    // re-using the last account.
    await _google.signOut().catchError((_) => null);
    final account = await _google.signIn();
    if (account == null) return false; // user cancelled the sheet
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google sign-in failed. Please try again.');
    }
    await CalSync.instance.googleNativeExchange(
      idToken,
      name: account.displayName,
      email: account.email,
    );
    return true;
  }
}
