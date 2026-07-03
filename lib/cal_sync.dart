import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'db_calendar.dart';

/// Lightweight tRPC-over-HTTP client for cross-app personal calendar sync.
///
/// Uses the SHARED KukLabs backend + account (the same `auth.directLogin` that
/// KukTask and KukKeep use), so signing in with the same email makes Kuk
/// Calendar / KukTask / KukKeep share one login. Personal events sync via the
/// `calendar.pull` / `calendar.push` procedures. Token is a Bearer header; the
/// active company is the `x-company-id` header. Prefs are namespaced `kc_`.
class CalSync {
  CalSync._();
  static final CalSync instance = CalSync._();

  static const String base = 'https://kuklabs.com';
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    // Don't throw on non-2xx; we parse the tRPC error envelope ourselves.
    validateStatus: (_) => true,
  ));

  String? _token;
  int? _companyId;
  String? userName;

  bool get isLoggedIn => _token != null;
  int? get companyId => _companyId;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('kc_token');
    _companyId = p.getInt('kc_company');
    userName = p.getString('kc_user');
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (_token != null) await p.setString('kc_token', _token!);
    if (_companyId != null) await p.setInt('kc_company', _companyId!);
    if (userName != null) await p.setString('kc_user', userName!);
  }

  Future<void> logout() async {
    _token = null;
    _companyId = null;
    userName = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('kc_token');
    await p.remove('kc_company');
    await p.remove('kc_user');
  }

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_token != null) 'authorization': 'Bearer $_token',
        if (_companyId != null) 'x-company-id': '$_companyId',
      };

  dynamic _unwrap(dynamic body) {
    final entry = body is List ? body[0] : body;
    if (entry is Map && entry['error'] != null) {
      final msg = entry['error']?['json']?['message'] ??
          entry['error']?['message'] ??
          'Request failed';
      throw Exception(msg.toString());
    }
    return entry?['result']?['data']?['json'];
  }

  // Network failures (no internet / DNS / timeout) surface as a short, human
  // message instead of a raw DioException dump.
  static const String _offlineMsg =
      'Could not reach the server. Please check your internet connection and try again.';

  Future<dynamic> _query(String proc, [Map<String, dynamic>? input]) async {
    final payload = Uri.encodeComponent(jsonEncode({'0': {'json': input}}));
    final uri = Uri.parse('$base/api/trpc/$proc?batch=1&input=$payload');
    final Response res;
    try {
      res = await _dio.getUri(uri, options: Options(headers: _headers));
    } on DioException {
      throw Exception(_offlineMsg);
    }
    return _handle(res);
  }

  Future<dynamic> _mutate(String proc, Map<String, dynamic> input) async {
    final uri = Uri.parse('$base/api/trpc/$proc?batch=1');
    final Response res;
    try {
      res = await _dio.postUri(uri,
          data: jsonEncode({'0': {'json': input}}),
          options: Options(headers: _headers));
    } on DioException {
      throw Exception(_offlineMsg);
    }
    return _handle(res);
  }

  dynamic _handle(Response res) {
    if (res.statusCode == 401) {
      // Token expired/invalid — drop it so the UI shows "Sign in" again.
      _token = null;
      logout();
      throw Exception('Session expired — please sign in again.');
    }
    return _unwrap(_asJson(res.data));
  }

  // Dio auto-decodes JSON bodies to Map/List; only decode if it's still a
  // String, and never let a non-JSON error page surface a raw FormatException.
  dynamic _asJson(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      if (data.trim().isEmpty) return null;
      try {
        return jsonDecode(data);
      } catch (_) {
        throw Exception('Unexpected server response. Please try again.');
      }
    }
    return data;
  }

  // ── Auth ──
  Future<void> login(String email, String password) async {
    final data =
        await _mutate('auth.directLogin', {'email': email, 'password': password});
    if (data is Map && data['mfaRequired'] == true) {
      throw Exception(
          'Two-factor is enabled. Please sign in on the web first.');
    }
    final token = data is Map ? data['token'] : null;
    if (token == null) throw Exception('Login failed');
    _token = token.toString();
    userName = (data['user']?['name'] ?? '').toString();
    await _save();
    await _ensureCompany();
  }

  /// Create a new KukLabs account (step 1) — the server emails a 6-digit
  /// verification code to [email]; complete with [verifyOtp].
  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _mutate('auth.directRegister', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'acceptedTerms': true,
    });
  }

  /// Complete sign-up (step 2): verify the emailed code. On success the
  /// account is active and we are signed in (token + workspace ready).
  Future<void> verifyOtp(String email, String otp) async {
    final data = await _mutate('auth.verifyOtp', {'email': email, 'otp': otp});
    final token = data is Map ? data['token'] : null;
    if (token == null) throw Exception('Verification failed');
    _token = token.toString();
    userName = (data['user']?['name'] ?? '').toString();
    await _save();
    await _ensureCompany();
  }

  /// Re-send the sign-up verification code.
  Future<void> resendOtp(String email) async {
    await _mutate('auth.resendOtp', {'email': email});
  }

  String _slugify(String name) {
    final b = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '${b.isEmpty ? 'calendar' : b}-$suffix';
  }

  Future<void> _ensureCompany() async {
    try {
      var list = await _query('company.list');
      // Brand-new account with no workspace → create a free one (silent),
      // mirroring KukKeep/KukTask so sync works on first sign-in.
      if (list is! List || list.isEmpty) {
        final nm = (userName?.trim().isNotEmpty == true) ? userName! : 'My Calendar';
        try {
          await _mutate('company.create', {
            'name': nm,
            'slug': _slugify(nm),
            'phone': '0000000',
            'productType': 'tasks',
            'signupModule': 'calendar',
          });
        } catch (_) {/* fall through to re-list */}
        list = await _query('company.list');
      }
      if (list is List && list.isNotEmpty) {
        final id = (list.first as Map)['id'];
        if (id is int) {
          _companyId = id;
          await _save();
        }
      }
    } catch (_) {/* keep going; sync will surface errors */}
  }

  // ── Sync ──
  /// Push local changes, then pull remote → merge. Returns a short status.
  Future<String> syncNow() async {
    if (!isLoggedIn) return 'Not signed in';
    if (_companyId == null) await _ensureCompany();

    final dirty = await AppDb.instance.getDirtyEvents();
    if (dirty.isNotEmpty) {
      final res = await _mutate('calendar.push', {'events': dirty});
      final mapping = (res is Map ? res['mapping'] : null);
      if (mapping is List) {
        await AppDb.instance.markEventsPushed(
            mapping.map((m) => Map<String, dynamic>.from(m as Map)).toList());
      }
    }

    final remote = await _query('calendar.pull');
    if (remote is List) {
      await AppDb.instance.applyRemoteEvents(
          remote.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    }
    return 'Synced';
  }
}
