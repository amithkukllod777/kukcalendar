import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'cal_sync.dart';

/// Sign in with Apple (native flow). Runs Apple's system sheet, then trades the
/// returned identity token for the shared Kuklabs session (same account as
/// email/password + Google). Apple only releases the user's name on the FIRST
/// authorization, so it's forwarded to the server then.
class AppleAuth {
  AppleAuth._();
  static final AppleAuth instance = AppleAuth._();

  /// Present the Apple sheet and complete sign-in. Throws on failure; a user
  /// cancel throws SignInWithAppleAuthorizationException(code: canceled), which
  /// the caller treats as a no-op (no error toast).
  Future<void> signIn() async {
    final cred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final idToken = cred.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Apple sign-in failed. Please try again.');
    }
    final name = [cred.givenName, cred.familyName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ')
        .trim();
    await CalSync.instance.appleExchange(
      idToken,
      name: name.isEmpty ? null : name,
      email: cred.email,
    );
  }
}
