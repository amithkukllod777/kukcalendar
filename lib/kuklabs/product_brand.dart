import 'package:flutter/material.dart';

/// Product-specific configuration for Kuk Calendar. This is the ONLY place the
/// per-product values (icon, name, tagline, accent) live — everything else in
/// the auth/profile shell comes from the shared Kuklabs standard
/// (docs/kuklabs/). See REPO_INTEGRATION_GUIDE.md.
class ProductBrand {
  ProductBrand._();

  static const String productId = 'kukcalendar';
  static const String productName = 'KukCalendar';
  static const String shortName = 'Calendar';
  static const String packageId = 'com.kuklabs.calendar';

  /// Wordmark split for the two-tone product name ("Kuk" + accent "Calendar").
  static const String nameDark = 'Kuk';
  static const String nameAccent = 'Calendar';

  static const String tagline =
      'Events, reminders & schedules — synced with your Kuklabs account.';

  // Approved product accent (accent-600) + dark-mode shade.
  static const Color accent = Color(0xFF2868F0);
  static const Color accentDark = Color(0xFF5B8CFF);

  static const String termsUrl = 'https://kuklabs.com/terms';
  static const String privacyUrl = 'https://kuklabs.com/privacy';
  static const String supportUrl = 'https://kuklabs.com/support';

  static const String versionDisplayFormat = 'Version {version} (Build {build})';
}
