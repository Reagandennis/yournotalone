import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import 'auth_gate.dart';
import 'auth_ui.dart';

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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
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
      );
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
        const SizedBox(height: 18),
        const Text(
          'By creating an account you agree to our Terms of Service '
          'and Privacy Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Brand.textMuted, height: 1.5),
        ),
        const SizedBox(height: 18),
        Wrap(
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
      ],
    );
  }
}
