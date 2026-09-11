import 'dart:io' show Platform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import '../apple_auth.dart';
import '../cal_sync.dart';
import '../google_auth.dart';
import 'calendar_screen.dart';
import '../kuklabs/auth_messages.dart';
import '../kuklabs/auth_tokens.dart';
import '../kuklabs/product_brand.dart';
import '../theme/app_theme.dart';

enum _Mode { signIn, signUp, verify }

/// Kuklabs universal authentication screen (docs/kuklabs/ — one shared shell for
/// every Kuklabs app; matches APPROVED_LOGIN_REFERENCE.png and the exact sizes
/// in KUKLABS_DESIGN_TOKENS.json). Only the product icon, name, tagline and
/// accent are product-specific (from ProductBrand); layout, content, Google
/// branding, typography and error policy are shared and must not be forked.
///
/// Identity is the ONE Kuklabs Account (shared auth.* endpoints on kuklabs.com);
/// no separate auth/user store. Google uses the SSO deep-link flow.
class CalendarLoginScreen extends StatefulWidget {
  const CalendarLoginScreen({super.key});
  @override
  State<CalendarLoginScreen> createState() => _CalendarLoginScreenState();
}

class _CalendarLoginScreenState extends State<CalendarLoginScreen> {
  final _name = TextEditingController();
  final _identity = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _googleEnabled = false; // server has Google OAuth configured (probed)
  bool _appleEnabled = false; // Sign in with Apple: shown on iOS/macOS (set in initState)
  bool _obscure = true;
  bool _acceptedTerms = false;
  String? _error;
  String? _notice;

  late final TapGestureRecognizer _termsTap =
      TapGestureRecognizer()..onTap = () => _openUrl(ProductBrand.termsUrl);
  late final TapGestureRecognizer _privacyTap =
      TapGestureRecognizer()..onTap = () => _openUrl(ProductBrand.privacyUrl);

  static const String _hostedLoginUrl = 'https://www.kuklabs.com/login';

  @override
  void initState() {
    super.initState();
    _probeSocial();
  }

  /// Reveal the Google button as soon as the server reports OAuth is configured.
  /// Retries a few times so a cold-start network miss (or credentials enabled
  /// server-side after the app opened) doesn't leave the button hidden — once
  /// enabled, it stays. Cheap GET; stops on the first positive result.
  Future<void> _probeSocial() async {
    // Sign in with Apple: shown on iOS/macOS (the native sheet is always
    // available on iOS 13+, and Apple requires the button when other social
    // logins exist) — no server probe needed.
    if ((Platform.isIOS || Platform.isMacOS) && mounted) {
      setState(() => _appleEnabled = true);
    }
    // Google button: revealed once the server reports OAuth is configured. Retry
    // a few times so a cold-start miss doesn't leave it hidden; once on, it stays.
    for (var i = 0; i < 5 && mounted && !_googleEnabled; i++) {
      bool ok = false;
      try {
        ok = await CalSync.instance.googleEnabled();
      } catch (_) {/* offline / transient — retry below */}
      if (!mounted) return;
      if (ok) {
        setState(() => _googleEnabled = true);
        return;
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _identity.dispose();
    _phone.dispose();
    _password.dispose();
    _otp.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  // Always give the user a way off the login screen: pop when it was pushed
  // (the normal drawer path), otherwise fall back to the calendar so the back
  // arrow / system-back can never leave them stuck here.
  void _exit() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      // Hard rule: raw server text never reaches the UI.
      if (mounted) setState(() => _error = AuthMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _looksLikeEmail(String s) => s.contains('@') && s.contains('.');
  bool _strongPassword(String s) =>
      s.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(s) && RegExp(r'\d').hasMatch(s);

  Future<void> _signIn() async {
    final id = _identity.text.trim();
    if (id.isEmpty) {
      setState(() => _error = AuthMessages.emptyIdentity);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = AuthMessages.emptyPassword);
      return;
    }
    await _run(() async {
      await CalSync.instance.login(id, _password.text);
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _signUp() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    final id = _identity.text.trim();
    if (id.isEmpty) {
      setState(() => _error = AuthMessages.emptyIdentity);
      return;
    }
    if (!_looksLikeEmail(id)) {
      setState(() => _error = AuthMessages.invalidEmail);
      return;
    }
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = AuthMessages.invalidPhone);
      return;
    }
    if (!_strongPassword(_password.text)) {
      setState(() => _error = AuthMessages.weakPassword);
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = AuthMessages.termsRequired);
      return;
    }
    await _run(() async {
      await CalSync.instance.register(
        name: _name.text.trim(),
        email: id,
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        setState(() {
          _mode = _Mode.verify;
          _notice = 'We emailed a 6-digit code to $id';
        });
      }
    });
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length != 6) {
      setState(() => _error = AuthMessages.otpInvalid);
      return;
    }
    await _run(() async {
      await CalSync.instance.verifyOtp(_identity.text.trim(), _otp.text.trim());
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _resend() async {
    await _run(() async {
      await CalSync.instance.resendOtp(_identity.text.trim());
      if (mounted) setState(() => _notice = 'A new code has been sent.');
    });
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* no browser available */}
  }

  void _switchMode(_Mode m) => setState(() {
        _mode = m;
        _error = null;
        _notice = null;
      });

  // ── Building blocks (token-exact) ───────────────────────────────────────
  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.placeholder, fontSize: AuthTokens.inputTextSize),
        prefixIcon: Icon(icon, size: 22, color: AppColors.textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthTokens.authControlRadius),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthTokens.authControlRadius),
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AuthTokens.authControlRadius)),
      );

  Widget _field(TextField child) =>
      SizedBox(height: AuthTokens.inputHeight, child: child);

  Widget _identityField() => _field(TextField(
        controller: _identity,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(fontSize: AuthTokens.inputTextSize, color: AppColors.textPrimary),
        decoration: _dec('Mobile Number or Email', Icons.smartphone_outlined),
      ));

  Widget _passwordField({required VoidCallback onSubmit}) => _field(TextField(
        controller: _password,
        obscureText: _obscure,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(fontSize: AuthTokens.inputTextSize, color: AppColors.textPrimary),
        onSubmitted: (_) => onSubmit(),
        decoration: _dec(
          'Password',
          Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textMuted, size: 22),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ));

  Widget _primaryButton(String label, VoidCallback onTap) => SizedBox(
        height: AuthTokens.buttonHeight,
        child: FilledButton(
          onPressed: _busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AuthTokens.authControlRadius)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: AuthTokens.primaryButtonTextSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
        ),
      );

  Widget _tabs() {
    Widget tab(String label, _Mode m) {
      final active = _mode == m || (m == _Mode.signUp && _mode == _Mode.verify);
      return Expanded(
        child: InkWell(
          onTap: _busy ? null : () => _switchMode(m),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? AppColors.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AuthTokens.tabLabelSize,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: AuthTokens.tabsHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AuthTokens.authControlRadius),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(children: [tab('Login', _Mode.signIn), tab('Sign Up', _Mode.signUp)]),
    );
  }

  // Continue with Google (Kuklabs SSO deep-link flow) + official multi-colour
  // logo. Rendered only when the server reports OAuth is configured.
  // Sign in with Apple (Apple HIG button). Cancel = silent; other failures map
  // through the friendly catalogue like every other auth error.
  Future<void> _signInApple() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await AppleAuth.instance.signIn();
      if (mounted) Navigator.pop(context, true);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        setState(() => _error = AuthMessages.friendly(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _socialBlock() {
    if (!_googleEnabled && !_appleEnabled) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        _orDivider(),
        const SizedBox(height: 20),
        if (_googleEnabled)
          SizedBox(
            height: AuthTokens.googleButtonHeight,
            child: OutlinedButton(
              onPressed: _busy ? null : () => GoogleAuth.instance.signIn(),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AuthTokens.authControlRadius)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GoogleGLogo(size: 20),
                  SizedBox(width: 12),
                  Text('Continue with Google',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        if (_appleEnabled) ...[
          if (_googleEnabled) const SizedBox(height: 12),
          SizedBox(
            height: AuthTokens.googleButtonHeight,
            child: SignInWithAppleButton(
              onPressed: () {
                if (!_busy) _signInApple();
              },
              height: AuthTokens.googleButtonHeight,
              borderRadius: BorderRadius.circular(AuthTokens.authControlRadius),
              style: Theme.of(context).brightness == Brightness.dark
                  ? SignInWithAppleButtonStyle.white
                  : SignInWithAppleButtonStyle.black,
            ),
          ),
        ],
      ],
    );
  }

  Widget _orDivider() => SizedBox(
        height: AuthTokens.orDividerHeight,
        child: Row(children: [
          Expanded(child: Divider(color: AppColors.borderSubtle)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ),
          Expanded(child: Divider(color: AppColors.borderSubtle)),
        ]),
      );

  Widget _legal() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text.rich(
          TextSpan(
            style: TextStyle(
                fontSize: AuthTokens.legalTextSize, color: AppColors.textMuted, height: 1.5),
            children: [
              const TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(
                text: 'Terms of Use',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                recognizer: _termsTap,
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                recognizer: _privacyTap,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      );

  // ── Forms ───────────────────────────────────────────────────────────────
  List<Widget> _signInForm() => [
        _identityField(),
        const SizedBox(height: 12),
        _passwordField(onSubmit: _signIn),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _openUrl(_hostedLoginUrl),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            child: Text('Forgot Password?',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 12),
        _primaryButton('Login', _signIn),
      ];

  List<Widget> _signUpForm() => [
        _field(TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontSize: AuthTokens.inputTextSize, color: AppColors.textPrimary),
          decoration: _dec('Full Name', Icons.person_outline),
        )),
        const SizedBox(height: 12),
        _identityField(),
        const SizedBox(height: 12),
        _field(TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontSize: AuthTokens.inputTextSize, color: AppColors.textPrimary),
          decoration: _dec('Mobile Number (with country code)', Icons.call_outlined),
        )),
        const SizedBox(height: 12),
        _passwordField(onSubmit: _signUp),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  'I am 18 or older and accept the Terms of Use & Privacy Policy.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _primaryButton('Create Account', _signUp),
      ];

  List<Widget> _verifyForm() => [
        _field(TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 10, color: AppColors.textPrimary),
          decoration: _dec('••••••', Icons.mark_email_read_outlined).copyWith(counterText: ''),
          onSubmitted: (_) => _verify(),
        )),
        const SizedBox(height: 14),
        _primaryButton('Verify & Continue', _verify),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _resend,
            child: Text('Resend code',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final tagline = _mode == _Mode.verify
        ? 'Enter the 6-digit code we emailed to finish setting up your account.'
        : ProductBrand.tagline;
    return PopScope(
      // When this screen is the root (can't pop), intercept the system/gesture
      // back and route to the calendar instead of leaving the user stuck.
      canPop: Navigator.of(context).canPop(),
      onPopInvoked: (didPop) {
        if (!didPop) _exit();
      },
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textSecondary),
                onPressed: _exit,
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AuthTokens.horizontalPadding, 24, AuthTokens.horizontalPadding, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AuthTokens.contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: AuthTokens.productIcon,
                          height: AuthTokens.productIcon,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AuthTokens.productIconRadius),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.28),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 46),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Welcome to',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: AuthTokens.welcomeSize,
                              height: AuthTokens.welcomeHeight,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: ProductBrand.nameDark, style: TextStyle(color: AppColors.textPrimary)),
                            TextSpan(text: ProductBrand.nameAccent, style: TextStyle(color: AppColors.primary)),
                          ]),
                          style: const TextStyle(
                              fontSize: AuthTokens.productNameSize,
                              height: AuthTokens.productNameHeight,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(tagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: AuthTokens.taglineSize,
                              height: AuthTokens.taglineHeight,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 24),
                      if (_mode != _Mode.verify) ...[
                        _tabs(),
                        const SizedBox(height: 20),
                      ],
                      ...switch (_mode) {
                        _Mode.signIn => _signInForm(),
                        _Mode.signUp => _signUpForm(),
                        _Mode.verify => _verifyForm(),
                      },
                      if (_notice != null) ...[
                        const SizedBox(height: 14),
                        Text(_notice!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.danger, fontSize: 13)),
                      ],
                      if (_mode != _Mode.verify) _socialBlock(),
                      const SizedBox(height: 24),
                      _legal(),
                      const SizedBox(height: 16),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Powered by '),
                          TextSpan(text: 'Kuklabs', style: TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: AuthTokens.poweredBySize, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
