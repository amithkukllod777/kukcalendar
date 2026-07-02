import 'package:flutter/material.dart';
import '../app_info.dart';
import '../cal_sync.dart';
import '../theme/app_theme.dart';

enum _Mode { signIn, signUp, verify }

/// Sign in or create a KukLabs account to back up and sync the calendar.
/// Optional — the app works fully offline without an account.
///
/// Sign-up is fully in-app: create account → a 6-digit code is emailed →
/// verify → signed in (the workspace is auto-created on first sync).
class CalendarLoginScreen extends StatefulWidget {
  const CalendarLoginScreen({super.key});
  @override
  State<CalendarLoginScreen> createState() => _CalendarLoginScreenState();
}

class _CalendarLoginScreenState extends State<CalendarLoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _obscure = true;
  bool _acceptedTerms = false;
  String? _error;
  String? _notice;
  String _version = '';

  @override
  void initState() {
    super.initState();
    appVersionString().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _otp.dispose();
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
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password');
      return;
    }
    await _run(() async {
      await CalSync.instance.login(_email.text.trim(), _password.text);
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _signUp() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (_email.text.trim().isEmpty ||
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
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
      );
      if (mounted) {
        setState(() {
          _mode = _Mode.verify;
          _notice = 'We emailed a 6-digit code to ${_email.text.trim()}';
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
      await CalSync.instance.verifyOtp(_email.text.trim(), _otp.text.trim());
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _resend() async {
    await _run(() async {
      await CalSync.instance.resendOtp(_email.text.trim());
      if (mounted) setState(() => _notice = 'A new code has been sent');
    });
  }

  Widget _emailField() => TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: const InputDecoration(
            labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
      );

  Widget _passwordField({required void Function() onSubmit}) => TextField(
        controller: _password,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        onSubmitted: (_) => onSubmit(),
      );

  Widget _primaryButton(String label, Future<void> Function() onTap) =>
      FilledButton(
        onPressed: _busy ? null : onTap,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label),
      );

  List<Widget> _signInForm() => [
        _emailField(),
        const SizedBox(height: 12),
        _passwordField(onSubmit: _signIn),
        const SizedBox(height: 20),
        _primaryButton('Sign in', _signIn),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _mode = _Mode.signUp;
                    _error = null;
                    _notice = null;
                  }),
          child: const Text('New here? Create an account'),
        ),
      ];

  List<Widget> _signUpForm() => [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 12),
        _emailField(),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '+91 98765 43210',
              prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 12),
        _passwordField(onSubmit: _signUp),
        const SizedBox(height: 4),
        CheckboxListTile(
          value: _acceptedTerms,
          onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'I am 18 or older and accept the Terms & Privacy Policy (kuklabs.com/terms)',
            style: TextStyle(fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 8),
        _primaryButton('Create account', _signUp),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _mode = _Mode.signIn;
                    _error = null;
                    _notice = null;
                  }),
          child: const Text('Already have an account? Sign in'),
        ),
      ];

  List<Widget> _verifyForm() => [
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
          decoration: const InputDecoration(
              labelText: 'Verification code', counterText: ''),
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 20),
        _primaryButton('Verify & sign in', _verify),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Resend code'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.signIn => 'Sign in',
      _Mode.signUp => 'Create account',
      _Mode.verify => 'Verify your email',
    };
    final subtitle = switch (_mode) {
      _Mode.signIn =>
        'Sign in to back up your calendar and keep it in sync on all your devices. The app works offline without an account.',
      _Mode.signUp =>
        'Create a free account to back up your calendar and keep it in sync on all your devices.',
      _Mode.verify => 'Enter the 6-digit code we emailed you to finish setting up your account.',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.calendar_month, size: 56, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Kuk Calendar',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ...switch (_mode) {
            _Mode.signIn => _signInForm(),
            _Mode.signUp => _signUpForm(),
            _Mode.verify => _verifyForm(),
          },
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Text(_notice!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          if (_version.isNotEmpty)
            Text('Kuk Calendar $_version',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
