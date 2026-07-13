import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cal_sync.dart';
import 'screens/calendar_screen.dart';

/// "Continue with Google" for Kuk Calendar — the Kuklabs SSO deep-link flow
/// (KUKLABS_IDENTITY.md §3, same pattern as KukTask / KukKeep).
///
/// The app opens `kuklabs.com/api/auth/google/start?app=kukcalendar` in the
/// external browser; after Google finishes, the server deep-links back to
/// `kukcalendar://auth?code=<one-time>`. We trade that code for the same Bearer
/// session token directLogin issues, so it's the ONE Kuklabs Account. No SHA-1
/// / keystore registration and no Play Services — the flow never touches the
/// native Google SDK, so it works on our CI's ephemeral debug signing too.
class GoogleAuth {
  GoogleAuth._();
  static final GoogleAuth instance = GoogleAuth._();

  /// Set on the MaterialApp so a deep link can navigate from outside any screen.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static Future<bool>? _enabledFut;

  /// Cached availability probe — hides the Google button on deployments that
  /// don't have OAuth credentials configured (one network call per app run).
  static Future<bool> enabled() =>
      _enabledFut ??= CalSync.instance.googleEnabled();

  StreamSubscription<Uri>? _sub;
  String? _lastCode; // codes are one-time; never exchange the same one twice
  bool _busy = false;

  /// Start listening for the kukcalendar://auth deep link. Fire-and-forget from
  /// main() — a failure here only means the Google button can't complete.
  Future<void> init() async {
    if (_sub != null) return;
    try {
      final links = AppLinks();
      try {
        final initial = await links.getInitialLink(); // app cold-started by link
        if (initial != null) _handle(initial);
      } catch (_) {}
      _sub = links.uriLinkStream.listen(_handle, onError: (_) {});
    } catch (_) {/* plugin unavailable — email login keeps working */}
  }

  /// Open the Google sign-in page in the external browser.
  Future<void> signIn() async {
    try {
      final ok = await launchUrl(Uri.parse(CalSync.googleStartUrl),
          mode: LaunchMode.externalApplication);
      if (!ok) _toast('Could not open the browser.');
    } catch (_) {
      _toast('Could not open the browser.');
    }
  }

  Future<void> _handle(Uri uri) async {
    if (uri.scheme != 'kukcalendar' || uri.host != 'auth') return;
    final err = uri.queryParameters['error'] ?? '';
    if (err.isNotEmpty) {
      _toast('Google sign-in was cancelled.');
      return;
    }
    final code = uri.queryParameters['code'] ?? '';
    if (code.isEmpty || code == _lastCode || _busy) return;
    _lastCode = code;
    _busy = true;
    try {
      await CalSync.instance.googleExchange(code);
      // Re-enter the calendar fresh so it reflects the signed-in account and
      // pulls the cloud events (CalendarScreen.initState → _initSync).
      final nav = navigatorKey.currentState;
      nav?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CalendarScreen()),
        (r) => false,
      );
      _toast('Signed in with Google');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _busy = false;
    }
  }

  void _toast(String m) =>
      messengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));
}

/// The official multi-colour Google "G" mark (canonical geometry), rendered
/// from an inline SVG so it looks right with no bundled asset.
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 20});
  final double size;

  static const String _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
      '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
      '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
      '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
      '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_svg, width: size, height: size);
}
