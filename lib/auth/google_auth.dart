import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// OAuth client IDs from the app's Google Cloud project (497109017811).
/// These are public identifiers, not secrets — they ship inside the binary.
///
/// Both mobile platforms send [_webClientId] as the `serverClientId`, which is
/// what ends up as the `aud` claim of the ID token Android returns; iOS
/// returns a token with [_iosClientId] as its audience instead. Supabase only
/// accepts a token whose audience it recognises, so *both* must stay listed
/// under Authentication → Providers → Google → "Authorized Client IDs".
///
/// The Android client ID
/// (497109017811-4eb9kqc2tpsu3mh84gq0e19rmjjeb6un) is deliberately absent:
/// Android identifies the app by package name plus signing-key SHA-1, so the
/// ID never appears in code — but the client must exist in the Cloud console
/// with the SHA-1 of every keystore the app is signed with (debug, upload,
/// and Play App Signing), or sign-in fails on device.
const _webClientId =
    '497109017811-so8kopsij12akf28engc1fu9rfhbp2rm.apps.googleusercontent.com';
const _iosClientId =
    '497109017811-nm4kb8gspio91adb3tudjfbslvinkcjs.apps.googleusercontent.com';

/// Signs in with Google and trades the resulting ID token for a Supabase
/// session.
///
/// There is no separate sign-up: Supabase creates the user on their first
/// Google sign-in and matches them by email on every one after, so the same
/// call backs the button on both the login and the signup screen.
abstract final class GoogleAuth {
  /// Guards against a second `initialize()` — the plugin subscribes to its
  /// platform event stream each time, so calling it twice double-delivers.
  static Future<void>? _initialization;

  static Future<void> _ensureInitialized() {
    // Only Apple platforms take a client ID; on Android it is ignored, and
    // passing it would misleadingly suggest otherwise.
    final isApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return _initialization ??= GoogleSignIn.instance.initialize(
      clientId: isApple ? _iosClientId : null,
      serverClientId: _webClientId,
    );
  }

  /// Opens the Google account sheet and, on success, signs the user into
  /// Supabase.
  ///
  /// Returns true once the Supabase session exists, and false when the user
  /// dismissed the sheet without picking an account — the one outcome that
  /// isn't worth an error message. Anything else throws.
  static Future<bool> signIn() async {
    await _ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AuthException(
        'Google sign-in isn\'t available on this device.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
    } on GoogleSignInException catch (e) {
      // Logged before anything is decided, because Android's Credential
      // Manager reports a real configuration failure — a signing-key SHA-1
      // that isn't registered, say — as a plain cancellation, indistinguishable
      // from the user dismissing the sheet. Staying quiet is right for a
      // dismissal, so this line is the only place the true reason surfaces.
      debugPrint('Google sign-in ended (${e.code.name}): ${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthException(_messageFor(e));
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException(
        'Google didn\'t return a sign-in token. Please try again.',
      );
    }

    // Strictly optional: lets Supabase read the profile Google already
    // consented to. Authentication is done by this point, so a failure here
    // must never sink the sign-in — this call has its own ways to fail (no
    // prior authorization to reuse, or the provider simply refusing) and the
    // ID token alone is enough to establish the session.
    String? accessToken;
    try {
      final authorization = await account.authorizationClient
          .authorizationForScopes(const ['email', 'profile']);
      accessToken = authorization?.accessToken;
    } catch (e) {
      debugPrint('Google authorization skipped, continuing without it: $e');
    }

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return true;
  }

  /// Clears the cached Google account so the next sign-in starts from the
  /// account picker rather than silently reusing the last one.
  ///
  /// Best-effort: a user who only ever used email and password has no Google
  /// state to clear, and failing to clear it must never block logging out.
  static Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google sign-out skipped: $e');
    }
  }

  /// Turns a plugin failure into something a user can act on. The raw
  /// [GoogleSignInException.description] is developer-facing text about client
  /// configuration, so the caller logs it rather than showing it.
  static String _messageFor(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in didn\'t finish. Please try again.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in isn\'t set up correctly for this app.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in isn\'t available on this device.',
      GoogleSignInExceptionCode.userMismatch =>
        'That\'s a different Google account than the one expected.',
      GoogleSignInExceptionCode.unknownError =>
        'Couldn\'t sign in with Google. Please try again.',
    };
  }
}
