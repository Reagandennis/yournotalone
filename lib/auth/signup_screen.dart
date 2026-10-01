import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import '../legal/legal_content.dart';
import '../legal/legal_screen.dart';
import 'apple_auth.dart';
import 'apple_button.dart';
import 'auth_gate.dart';
import 'auth_redirect.dart';
import 'auth_ui.dart';
import 'google_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _awaitingConfirm = false;
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(termsOfService);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(privacyPolicy);
    // When the confirmation link reopens the app on this device, the deep
    // link signs the user in — skip the "come back and log in" step.
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted || !_awaitingConfirm) return;
      if (state.event == AuthChangeEvent.signedIn && state.session != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => postAuthDestination()),
        );
      }
    });
  }

  void _openLegal(LegalDoc doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalScreen(doc: doc)),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {'full_name': _name.text.trim()},
        emailRedirectTo: authRedirectUrl,
      );
      Sentry.metrics.count('auth.sign_up.email', 1);
      if (!mounted) return;
      if (res.session != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => postAuthDestination()),
        );
      } else {
        // Email confirmation is on: the account exists but needs verifying.
        setState(() => _awaitingConfirm = true);
      }
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingConfirm) {
      return AuthScaffold(
        title: 'Confirm your email',
        subtitle: 'We sent a confirmation link to verify it\'s really you. '
            'Tap the link, then come back and log in.',
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0x143764CD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                size: 40,
                color: Brand.blue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _email.text.trim(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Back to log in'),
          ),
        ],
      );
    }

    return AuthScaffold(
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Already have an account?',
            style: TextStyle(fontSize: 14, color: Brand.textMuted),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Log in'),
          ),
        ],
      ),
      title: 'Create your account',
      subtitle: 'A calmer mind starts here. It only takes a minute.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _name,
                label: 'Full name',
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _confirm,
                label: 'Confirm password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    v != _password.text ? 'Passwords don\'t match' : null,
              ),
              const SizedBox(height: 26),
              AuthSubmitButton(
                label: 'Create account',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const AuthDivider(),
        const SizedBox(height: 24),
        // Placed above the legal notice on purpose: signing up through
        // Apple or Google is still creating an account, so the same terms
        // apply.
        if (AppleAuth.isSupported) ...[
          const AppleAuthButton(),
          const SizedBox(height: 12),
        ],
        const GoogleAuthButton(),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            text: 'By creating an account you agree to our ',
            children: [
              TextSpan(
                text: 'Terms of Service',
                recognizer: _termsTap,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Brand.blue,
                ),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                recognizer: _privacyTap,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Brand.blue,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Brand.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
