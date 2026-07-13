/// Approved friendly error catalogue (docs/kuklabs/KUKLABS_AUTH_CONTENT_TEMPLATES
/// .json → messages). Hard rule: raw server text / JSON / stack traces must
/// NEVER reach the UI — every failure is mapped to one of these safe messages.
class AuthMessages {
  AuthMessages._();

  static const String genericSignInError =
      "We couldn't sign you in. Check your email or mobile number and password, then try again.";
  static const String invalidEmail = 'Enter a valid email address.';
  static const String invalidPhone =
      'Enter a valid mobile number for the selected country.';
  static const String emptyIdentity =
      'Enter your email address or mobile number.';
  static const String emptyPassword = 'Enter your password.';
  static const String weakPassword =
      'Use at least 8 characters with at least one letter and one number.';
  static const String termsRequired =
      'Review and accept the Terms of Use and Privacy Policy to continue.';
  static const String otpInvalid =
      "That verification code isn't correct. Check it and try again.";
  static const String otpExpired =
      'That verification code has expired. Request a new code.';
  static const String offline =
      "You're offline. Check your internet connection and try again.";
  static const String serverError =
      'Something went wrong on our side. Please try again in a moment.';
  static const String genericFallback =
      "We couldn't complete that action. Please try again.";

  /// Map any thrown error to a safe, friendly message. Inspects the raw text
  /// only to CLASSIFY it; the raw text itself is never returned to the UI.
  static String friendly(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').toLowerCase();
    if (raw.contains('internet') ||
        raw.contains('offline') ||
        raw.contains('reach the server') ||
        raw.contains('socket') ||
        raw.contains('timeout') ||
        raw.contains('network')) {
      return offline;
    }
    if (raw.contains('invalid email or password') ||
        raw.contains('invalid email') ||
        raw.contains('unauthorized') ||
        raw.contains('incorrect') ||
        raw.contains('login failed')) {
      return genericSignInError;
    }
    if (raw.contains('expired')) return otpExpired;
    if (raw.contains('otp') || raw.contains('verification code') || raw.contains('code')) {
      return otpInvalid;
    }
    if (raw.contains('two-factor') || raw.contains('2fa') || raw.contains('mfa')) {
      return 'Two-step verification is on for this account. Please sign in on the web first.';
    }
    if (raw.contains('already registered') || raw.contains('conflict')) {
      return 'That email is already registered. Try signing in instead.';
    }
    if (raw.contains('server') || raw.contains('500') || raw.contains('unavailable')) {
      return serverError;
    }
    return genericFallback;
  }
}
