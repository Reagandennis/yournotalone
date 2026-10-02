import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import 'auth_redirect.dart';
import 'auth_ui.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _email.text.trim(),
        redirectTo: authRedirectUrl,
      );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    if (_sent) {
      return AuthScaffold(
        title: 'Check your inbox',
        subtitle: 'If an account exists for that address, the reset link is '
            'already on its way.',
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
                Icons.mark_email_read_outlined,
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
            child: const Text('Back to log in'),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _sent = false),
              child: const Text('Try another email'),
            ),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'Enter the email you signed up with and we\'ll send you a '
          'link to set a new password.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: validateEmail,
              ),
              const SizedBox(height: 26),
              AuthSubmitButton(
                label: 'Send reset link',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
