import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'cal_sync.dart';

/// iOS push notifications via Firebase Cloud Messaging.
///
/// Best-effort by design: every failure is swallowed so push can never break the
/// calendar. Firebase is initialised on **iOS only** — the app bundles
/// GoogleService-Info.plist for iOS and has no Android google-services.json, so
/// calling `Firebase.initializeApp()` on Android would throw. Local event
/// reminders (`notifications.dart`) are independent and unaffected.
///
/// The FCM registration token is stored server-side via
/// `CalSync.registerFcmToken` (the shared `kuk_fcm_tokens` path, same as
/// KukTask), so this device becomes reachable by the shared push pipeline.
class Push {
  Push._();
  static bool _inited = false;

  /// Initialise Firebase + FCM (iOS only), request permission, and register the
  /// token. Safe to call more than once — subsequent calls are no-ops.
  static Future<void> init() async {
    if (_inited || !Platform.isIOS) return;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.instance.onTokenRefresh.listen(_register);
      await syncToken();
      _inited = true;
    } catch (_) {/* push unavailable — the app still works */}
  }

  /// (Re)register the current FCM token. Call after a fresh sign-in too, once the
  /// session and personal workspace exist.
  static Future<void> syncToken() async {
    if (!Platform.isIOS) return;
    try {
      // iOS: the APNs token must resolve before FCM can mint a registration
      // token; getToken() returns null until it does.
      await FirebaseMessaging.instance.getAPNSToken();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _register(token);
    } catch (_) {/* not ready yet — retried on refresh / next launch */}
  }

  static Future<void> _register(String token) async {
    try {
      await CalSync.instance.registerFcmToken(token, platform: 'ios');
    } catch (_) {/* not signed in / offline — retried on next launch or sign-in */}
  }
}
