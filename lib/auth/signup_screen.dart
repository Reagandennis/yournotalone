import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
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

  /// "By creating an account you agree to our Terms of Service and Privacy
  /// Policy.", with the two documents as links wherever the language puts
  /// them in the sentence.
  List<InlineSpan> _agreement(AppLocalizations l10n, BrandColors c) {
    const termsMark = '\u0001', privacyMark = '\u0002';
    final sentence = l10n.authSignupAgreement(termsMark, privacyMark);
    final link = TextStyle(fontWeight: FontWeight.w600, color: c.blue);
    final spans = <InlineSpan>[];
    final parts = sentence.split(RegExp('(?=[$termsMark$privacyMark])|'
        '(?<=[$termsMark$privacyMark])'));
    for (final part in parts) {
      if (part == termsMark) {
        spans.add(TextSpan(
          text: l10n.authTermsOfService,
          recognizer: _termsTap,
          style: link,
        ));
      } else if (part == privacyMark) {
        spans.add(TextSpan(
          text: l10n.authPrivacyPolicy,
          recognizer: _privacyTap,
          style: link,
        ));
      } else if (part.isNotEmpty) {
        spans.add(TextSpan(text: part));
      }
    }
    return spans;
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
    final c = context.brand;
    final l10n = context.l10n;
    if (_awaitingConfirm) {
      return AuthScaffold(
        title: l10n.authConfirmEmailTitle,
        subtitle: l10n.authConfirmEmailSubtitle,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: c.tint(Pillars.blue, 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_unread_outlined,
                size: 40,
                color: c.blue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _email.text.trim(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.authBackToLogIn),
          ),
        ],
      );
    }

    return AuthScaffold(
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.authHaveAccount,
            style: TextStyle(fontSize: 14, color: c.textMuted),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.authLogIn),
          ),
        ],
      ),
      title: l10n.authSignupTitle,
      subtitle: l10n.authSignupSubtitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _name,
                label: l10n.authFullName,
                icon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.authNameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _email,
                label: l10n.authEmail,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _password,
                label: l10n.authPassword,
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                validator: validatePassword,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _confirm,
                label: l10n.authConfirmPassword,
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    v != _password.text ? l10n.authPasswordsDontMatch : null,
              ),
              const SizedBox(height: 26),
              AuthSubmitButton(
                label: l10n.authCreateAccount,
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
          TextSpan(children: _agreement(l10n, c)),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: c.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
