import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'cal_sync.dart';
import 'google_auth.dart';
import 'notifications.dart';
import 'screens/calendar_screen.dart';

/// Kuk Calendar — standalone personal calendar. Offline-first; optionally signs
/// in with your Kuklabs account (the same login as KukTask / KukKeep) to sync
/// events across devices and apps via the shared backend at kuklabs.com.
void main() async {
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
}

class KukCalendarApp extends StatelessWidget {
  const KukCalendarApp({super.key});
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
