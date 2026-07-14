import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'cal_sync.dart';
import 'google_auth.dart';
import 'notifications.dart';
import 'observability.dart';
import 'screens/calendar_screen.dart';

/// Kuk Calendar — standalone personal calendar. Offline-first; optionally signs
/// in with your Kuklabs account (the same login as KukTask / KukKeep) to sync
/// events across devices and apps via the shared backend at kuklabs.com.
void main() {
  // Run inside a guarded zone so uncaught errors are captured, not lost (OBS-1).
  Observability.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await CalSync.instance.load();
    } catch (_) {/* offline / not signed in */}
    // Fire-and-forget: sets up the notification channel/permission and
    // re-schedules event reminders (e.g. after a reboot cleared the alarms).
    Reminders.rescheduleAll();
    // Listen for the kukcalendar://auth deep link (Google SSO return).
    GoogleAuth.instance.init();
    runApp(const KukCalendarApp());
  });
}

class KukCalendarApp extends StatefulWidget {
  const KukCalendarApp({super.key});
  @override
  State<KukCalendarApp> createState() => _KukCalendarAppState();
}

class _KukCalendarAppState extends State<KukCalendarApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Roll the reminder window forward every time the app is foregrounded, so
    // reminders beyond the last-scheduled horizon get armed even if the user
    // rarely opens a specific screen (NOTIF-1).
    if (state == AppLifecycleState.resumed) {
      Reminders.rescheduleAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kuk Calendar',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: GoogleAuth.navigatorKey,
      scaffoldMessengerKey: GoogleAuth.messengerKey,
      home: const CalendarScreen(),
    );
  }
}
