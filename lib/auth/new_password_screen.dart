import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
import 'auth_gate.dart';
import 'auth_ui.dart';

/// Shown when a password-recovery link reopens the app. The link itself
/// already signed the user in; here they just choose the new password.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  /// Whether one is on screen, so a second recovery event (the same link
  /// delivered twice) doesn't stack another on top.
  static bool get isShowing => _NewPasswordScreenState._open > 0;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  static int _open = 0;

  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _open++;
  }

  @override
  void dispose() {
    _open--;
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.authPasswordUpdated)));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => postAuthDestination()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthScaffold(
      title: l10n.authNewPasswordTitle,
      subtitle: l10n.authNewPasswordSubtitle,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _password,
                label: l10n.authNewPassword,
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
                label: l10n.authSavePassword,
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
