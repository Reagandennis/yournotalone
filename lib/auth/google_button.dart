import 'package:flutter/material.dart';

import '../brand.dart';
import 'auth_gate.dart';
import 'auth_ui.dart';
import 'google_auth.dart';

/// "Continue with Google" — the same button on both the login and the signup
/// screen, because Google sign-in is one flow that creates the account when
/// it doesn't exist yet.
class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({super.key});

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final signedIn = await GoogleAuth.signIn();
      if (!mounted) return;
      if (signedIn) {
        // Signed in for good: nothing behind this should lead back to a form.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => postAuthDestination()),
          (_) => false,
        );
        return; // On the way out — leave _loading alone.
      }
      // Dismissed the sheet: fall through and re-enable the button.
    } catch (e) {
      if (mounted) showAuthError(context, e);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    // Google's own button colours for light and dark themes, not the app's:
    // the brand guidelines fix them. The G keeps its colours in both.
    final dark = c.isDark;
    return OutlinedButton(
      onPressed: _loading ? null : _signIn,
      style: OutlinedButton.styleFrom(
        backgroundColor: dark ? const Color(0xFF131314) : Colors.white,
        foregroundColor:
            dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
        disabledForegroundColor: c.textMuted,
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(
          color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: _loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: c.textMuted,
              ),
            )
          // Scales down rather than overflowing when the label runs wide —
          // a narrow phone at a large text scale, say.
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/brand/google_g.png',
                    height: 20,
                    width: 20,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 12),
                  const Text('Continue with Google'),
                ],
              ),
            ),
    );
  }
}
