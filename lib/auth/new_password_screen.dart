import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password updated.')));
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
    return AuthScaffold(
      title: 'Choose a new password',
      subtitle: 'You\'re verified — set the password you\'ll use to log in '
          'from now on.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _password,
                label: 'New password',
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
                label: 'Save password',
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
