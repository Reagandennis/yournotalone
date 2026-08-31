import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';

/// Layout shared by all auth screens: the pillars mark up top, a heading
/// underlined by the [PillarStripe], a muted subtitle, then the form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              children: [
                SizedBox(
                  height: 44,
                  child: canPop
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: const BackChip(),
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                Center(
                  child: Image.asset('assets/brand/pillars.png', height: 96),
                ),
                const SizedBox(height: 36),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Brand.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 30),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BackChip extends StatelessWidget {
  const BackChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Brand.border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => Navigator.of(context).maybePop(),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 17, color: Brand.ink),
        ),
      ),
    );
  }
}

/// Text field used across the auth forms; handles the password
/// show/hide toggle internally.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(
        fontSize: 15,
        color: Brand.ink,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, size: 21),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 21,
                ),
              )
            : null,
      ),
    );
  }
}

/// Full-width primary button that swaps its label for a spinner while a
/// request is in flight.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: loading
          ? ElevatedButton.styleFrom(disabledBackgroundColor: Brand.ink)
          : null,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}

/// A hairline rule either side of a muted "or", separating the email form
/// from the social buttons.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    const line = Expanded(child: Divider(color: Brand.border, height: 1));
    return const Row(
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(fontSize: 13, color: Brand.textMuted),
          ),
        ),
        line,
      ],
    );
  }
}

/// Outlined counterpart to [AuthSubmitButton], carrying the Google mark.
/// Deliberately white rather than filled so it reads as secondary next to
/// the dark primary action.
class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Brand.ink,
        disabledForegroundColor: Brand.textMuted,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: Brand.border, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Brand.ink,
              ),
            )
          : Row(
              // Shrink-wrap and let the label ellipsize so the row survives
              // narrow screens and large text scale factors.
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/brand/google_g.svg',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
    );
  }
}

/// Shows an auth failure as a snackbar, in plain words.
void showAuthError(BuildContext context, Object error) {
  final message = error is AuthException
      ? error.message
      : 'Something went wrong. Please try again.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email';
  if (!_emailRe.hasMatch(v)) return 'Enter a valid email address';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter your password';
  if (v.length < 8) return 'Use at least 8 characters';
  return null;
}
