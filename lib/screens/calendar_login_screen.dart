import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../cal_sync.dart';
import '../theme/app_theme.dart';

enum _Mode { signIn, signUp, verify }

/// Kuklabs standard authentication screen (KUKLABS_IDENTITY.md §15).
///
/// Same layout as every Kuklabs app (KukKeep / KukTask / …): product icon →
/// "Welcome to" → product wordmark → tagline → Login / Sign Up tabs → form →
/// primary action → OR → Continue with Google → Terms & Privacy → Powered by
/// Kuklabs. Only the product icon, name, tagline and accent change per app.
///
/// Identity is the ONE Kuklabs Account (shared `auth.*` endpoints on
/// kuklabs.com — the same account as KukTask / KukKeep). This screen never
/// creates a separate user store; sign-up is fully in-app via email OTP.
class CalendarLoginScreen extends StatefulWidget {
  const CalendarLoginScreen({super.key});
  @override
  State<CalendarLoginScreen> createState() => _CalendarLoginScreenState();
}

class _CalendarLoginScreenState extends State<CalendarLoginScreen> {
  final _name = TextEditingController();
  final _identity = TextEditingController(); // email (login) / email (signup)
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _obscure = true;
  bool _acceptedTerms = false;
  String? _error;
  String? _notice;

  late final TapGestureRecognizer _termsTap =
      TapGestureRecognizer()..onTap = () => _openUrl(_termsUrl);
  late final TapGestureRecognizer _privacyTap =
      TapGestureRecognizer()..onTap = () => _openUrl(_privacyUrl);

  static const String _termsUrl = 'https://kuklabs.com/terms';
  static const String _privacyUrl = 'https://kuklabs.com/privacy';
  // Separate-repo apps may hand off to the hosted Kuklabs login for Google
  // (KUKLABS_IDENTITY.md §1). Native in-app Google (deep-link token return) is
  // a follow-up infra task; until then this opens the shared account login.
  static const String _hostedLoginUrl = 'https://kuklabs.com/login';

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

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (_identity.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password');
      return;
    }
    await _run(() async {
      await CalSync.instance.login(_identity.text.trim(), _password.text);
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _signUp() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (_identity.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _password.text.isEmpty) {
      setState(() => _error = 'Fill in all the fields');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error =
          'Please confirm you are 18+ and accept the Terms & Privacy Policy');
      return;
    }
    await _run(() async {
      await CalSync.instance.register(
        name: _name.text.trim(),
        email: _identity.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        setState(() {
          _mode = _Mode.verify;
          _notice = 'We emailed a 6-digit code to ${_identity.text.trim()}';
        });
      }
    });
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email');
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
      if (mounted) setState(() => _notice = 'A new code has been sent');
    });
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {/* no browser available */}
  }

  Future<void> _continueWithGoogle() async {
    await _openUrl(_hostedLoginUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Continue with Google in the browser, then sign in here with the same Kuklabs account.'),
      ));
    }
  }

  void _switchMode(_Mode m) => setState(() {
        _mode = m;
        _error = null;
        _notice = null;
      });

  // ── Building blocks ─────────────────────────────────────────────────────
  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.placeholder, fontSize: 16),
        prefixIcon: Icon(icon, size: 22, color: AppColors.textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _identityField() => TextField(
        controller: _identity,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: _dec('Mobile Number or Email', Icons.smartphone_outlined),
      );

  Widget _passwordField({required VoidCallback onSubmit}) => TextField(
        controller: _password,
        obscureText: _obscure,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
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
      );

  Widget _primaryButton(String label, VoidCallback onTap) => SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: _busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      );

  Widget _tabs() {
    Widget tab(String label, _Mode m) {
      final active = _mode == m || (m == _Mode.signUp && _mode == _Mode.verify);
      return Expanded(
        child: InkWell(
          onTap: _busy ? null : () => _switchMode(m),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
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
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(children: [tab('Login', _Mode.signIn), tab('Sign Up', _Mode.signUp)]),
    );
  }

  Widget _googleButton() => SizedBox(
        height: 54,
        child: OutlinedButton(
          onPressed: _busy ? null : _continueWithGoogle,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                child: const Text('G',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4285F4))),
              ),
              const SizedBox(width: 10),
              const Text('Continue with Google',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      );

  Widget _orDivider() => Row(children: const [
        Expanded(child: Divider(color: AppColors.borderSubtle)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ),
        Expanded(child: Divider(color: AppColors.borderSubtle)),
      ]);

  Widget _legal() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
            children: [
              const TextSpan(text: 'By continuing, you agree to our '),
              TextSpan(
                text: 'Terms of Use',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                recognizer: _termsTap,
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
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
        const SizedBox(height: 14),
        _passwordField(onSubmit: _signIn),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _openUrl(_hostedLoginUrl),
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
            child: const Text('Forgot Password?',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 12),
        _primaryButton('Login', _signIn),
      ];

  List<Widget> _signUpForm() => [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          decoration: _dec('Full Name', Icons.person_outline),
        ),
        const SizedBox(height: 14),
        _identityField(),
        const SizedBox(height: 14),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          decoration: _dec('Mobile Number (with country code)', Icons.call_outlined),
        ),
        const SizedBox(height: 14),
        _passwordField(onSubmit: _signUp),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
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
            const Expanded(
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
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 10, color: AppColors.textPrimary),
          decoration: _dec('••••••', Icons.mark_email_read_outlined).copyWith(counterText: ''),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 14),
        _primaryButton('Verify & Continue', _verify),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _resend,
            child: const Text('Resend code',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final tagline = _mode == _Mode.verify
        ? 'Enter the 6-digit code we emailed to finish setting up your account.'
        : 'Events, reminders & schedules — synced with your Kuklabs account.';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Product app icon (calendar tile).
                      Center(
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.28),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.calendar_month_rounded,
                              color: Colors.white, size: 50),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Welcome to',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(
                          const TextSpan(children: [
                            TextSpan(
                                text: 'Kuk',
                                style: TextStyle(color: AppColors.textPrimary)),
                            TextSpan(
                                text: 'Calendar',
                                style: TextStyle(color: AppColors.primary)),
                          ]),
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1.1),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(tagline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, color: AppColors.textSecondary, height: 1.45)),
                      const SizedBox(height: 28),
                      if (_mode != _Mode.verify) ...[
                        _tabs(),
                        const SizedBox(height: 22),
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
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                      ],
                      if (_mode != _Mode.verify) ...[
                        const SizedBox(height: 22),
                        _orDivider(),
                        const SizedBox(height: 22),
                        _googleButton(),
                      ],
                      const SizedBox(height: 26),
                      _legal(),
                      const SizedBox(height: 18),
                      const Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Powered by '),
                          TextSpan(
                              text: 'Kuklabs',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
