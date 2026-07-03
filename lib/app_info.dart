import 'package:package_info_plus/package_info_plus.dart';

/// Cached "v1.2.3 (45)" string read from the installed package, so the login
/// screen and drawer footer always show the real shipped version/build.
String? _cached;

Future<String> appVersionString() async {
  if (_cached != null) return _cached!;
  try {
    final info = await PackageInfo.fromPlatform();
    _cached = 'v${info.version} (${info.buildNumber})';
  } catch (_) {
    _cached = '';
  }
  return _cached!;
}
