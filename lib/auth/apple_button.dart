import 'package:flutter/material.dart';

import 'apple_auth.dart';
import 'auth_gate.dart';
import 'auth_ui.dart';

/// "Continue with Apple" — on both the login and the signup screen, like
/// [GoogleAuthButton], and the same size so neither outranks the other
/// (App Store guideline 4.8). Black with a white logo and label, as Apple's
/// Human Interface Guidelines ask. The screens show it only where
/// [AppleAuth.isSupported].
class AppleAuthButton extends StatefulWidget {
  const AppleAuthButton({super.key});

  @override
  State<AppleAuthButton> createState() => _AppleAuthButtonState();
}

class _AppleAuthButtonState extends State<AppleAuthButton> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final signedIn = await AppleAuth.signIn();
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
    return FilledButton(
      onPressed: _loading ? null : _signIn,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black,
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(56),
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
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white70,
              ),
            )
          : const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apple, size: 22),
                  SizedBox(width: 10),
                  Text('Continue with Apple'),
                ],
              ),
            ),
    );
  }
}
