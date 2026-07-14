import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  // Kuklabs SSO Google flow (KUKLABS_IDENTITY.md §3): open in the browser, the
  // server deep-links back to kukcalendar://auth with a one-time code.
  static const String googleStartUrl =
      '$base/api/auth/google/start?app=kukcalendar';
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    // Don't throw on non-2xx; we parse the tRPC error envelope ourselves.
    validateStatus: (_) => true,
  ));

  String? _token;
  int? _companyId;
  String? userName;

  // SEC-1: the Bearer session token lives in Keystore-backed secure storage,
  // never plaintext SharedPreferences. Non-secret values (active company id,
  // display name, last-account key) stay in SharedPreferences.
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  bool get isLoggedIn => _token != null;
  int? get companyId => _companyId;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _companyId = p.getInt('kc_company');
    userName = p.getString('kc_user');
    _token = await _secure.read(key: 'kc_token');
    // One-time migration: a token written by an older build sits in plaintext
    // prefs — move it into secure storage and scrub the plaintext copy.
    final legacy = p.getString('kc_token');
    if (legacy != null) {
      _token ??= legacy;
      await _secure.write(key: 'kc_token', value: legacy);
      await p.remove('kc_token');
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (_token != null) await _secure.write(key: 'kc_token', value: _token!);
    if (_companyId != null) await p.setInt('kc_company', _companyId!);
    if (userName != null) await p.setString('kc_user', userName!);
  }

  /// End the session (token + active company) WITHOUT touching locally-cached
  /// events — used when the token merely expired (401), so the same user can
  /// sign back in without losing un-synced changes.
  Future<void> _clearSession() async {
    _token = null;
    _companyId = null;
    userName = null;
    await _secure.delete(key: 'kc_token');
    final p = await SharedPreferences.getInstance();
    await p.remove('kc_company');
    await p.remove('kc_user');
  }

  /// Explicit user logout: end the session AND wipe local calendar data so the
  /// next account signed in on this device can't see or re-sync the previous
  /// user's events/tasks/calendars (DATA-1). Default lists re-seed on next use.
  Future<void> logout() async {
    await _clearSession();
    final p = await SharedPreferences.getInstance();
    await p.remove('kc_account');
    await AppDb.instance.clearLocalData();
  }

  /// Finalize a successful sign-in. If a DIFFERENT Kuklabs account than the last
  /// one on this device signs in, wipe the previous user's local data first so
  /// nothing leaks or merges across accounts (DATA-1) — this also covers the
  /// 401-expiry → sign-in-as-someone-else path. Then persist + bootstrap.
  Future<void> _onSignedIn(String token, String? name, String? accountKey) async {
    final p = await SharedPreferences.getInstance();
    final prev = p.getString('kc_account');
    if (prev != null && accountKey != null && prev != accountKey) {
      await AppDb.instance.clearLocalData();
    }
    _token = token;
    userName = (name ?? '').trim();
    if (accountKey != null && accountKey.isNotEmpty) {
      await p.setString('kc_account', accountKey);
    }
    await _save();
    await _ensureCompany();
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
      // Token expired/invalid — drop the SESSION only (not local data) so the
      // same user can re-authenticate without losing un-synced events.
      _clearSession();
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
    final acct = (data['user']?['id'] ?? email).toString();
    await _onSignedIn(
        token.toString(), data['user']?['name']?.toString(), acct);
  }

  // ── Google (Kuklabs SSO deep-link flow) ──
  /// Whether this deployment has Google OAuth configured (hide button if not).
  Future<bool> googleEnabled() async {
    try {
      final res = await _dio
          .getUri(Uri.parse('$base/api/auth/google/status'))
          .timeout(const Duration(seconds: 6));
      final b = _asJson(res.data);
      return b is Map && b['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Trade the one-time deep-link code for the same Bearer session token
  /// directLogin issues, then bootstrap the workspace.
  Future<void> googleExchange(String code) async {
    final res = await _dio.getUri(
        Uri.parse('$base/api/auth/google/app-exchange?code=${Uri.encodeComponent(code)}'));
    final b = _asJson(res.data);
    final token = b is Map ? b['token'] : null;
    if (token == null) {
      final msg = (b is Map ? b['error'] : null)?.toString();
      throw Exception((msg == null || msg.isEmpty)
          ? 'Google sign-in failed. Please try again.'
          : msg);
    }
    final acct = (b['id'] ?? b['email'] ?? b['name'])?.toString();
    await _onSignedIn(token.toString(), b['name']?.toString(), acct);
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
    final acct = (data['user']?['id'] ?? email).toString();
    await _onSignedIn(
        token.toString(), data['user']?['name']?.toString(), acct);
  }

  /// Re-send the sign-up verification code.
  Future<void> resendOtp(String email) async {
    await _mutate('auth.resendOtp', {'email': email});
  }

  Future<void> _ensureCompany() async {
    try {
      // One Kuklabs Personal Workspace: resolve (or lazily create) the caller's
      // single account-level personal workspace on the shared backend. This is the
      // SAME workspace KukTask/KukKeep resolve, so personal events/tasks/notes stay
      // together and NEVER land in an arbitrary business company. We no longer scan
      // company.list or fall back to list.first — the server returns a deterministic id.
      final ws = await _mutate('workspace.getOrCreatePersonal', {});
      final id = ws is Map ? ws['id'] : null;
      if (id is int) {
        _companyId = id;
        await _save();
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
