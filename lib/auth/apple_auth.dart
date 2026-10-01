import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signs in with Apple and trades the resulting identity token for a
/// Supabase session. iOS only: Android would need Apple's web flow (a
/// Services ID and a client secret that expires every six months), and
/// Android users already have Google.
///
/// Like Google, there is no separate sign-up — Supabase creates the user on
/// their first Apple sign-in. The audience of Apple's token is the bundle ID,
/// so `com.techgetafrica.yournotalone` must stay listed under Authentication →
/// Providers → Apple → "Client IDs" in Supabase.
abstract final class AppleAuth {
  /// Whether to offer the button at all.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Opens Apple's sign-in sheet and, on success, signs the user into
  /// Supabase.
  ///
  /// Returns true once the Supabase session exists, and false when the user
  /// dismissed the sheet. Anything else throws.
  static Future<bool> signIn() async {
    // Apple embeds whatever nonce it is given in the identity token; Supabase
    // hashes the raw one we hand it and checks they match, so a token lifted
    // from somewhere else can't be replayed.
    final rawNonce = _randomNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('Apple sign-in ended (${e.code.name}): ${e.message}');
      if (e.code == AuthorizationErrorCode.canceled) return false;
      throw AuthException(_messageFor(e));
    } on SignInWithAppleNotSupportedException {
      throw const AuthException(
        'Sign in with Apple isn\'t available on this device.',
      );
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException(
        'Apple didn\'t return a sign-in token. Please try again.',
      );
    }

    final auth = Supabase.instance.client.auth;
    final response = await auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    Sentry.metrics.count('auth.sign_in.apple', 1);

    // Neither of these may sink a sign-in that has already succeeded.
    await _saveName(response.user, credential);
    unawaited(_storeRefreshToken(credential.authorizationCode));
    return true;
  }

  /// Apple hands over the user's name on their very first sign-in only, and
  /// never puts it in the identity token — so it is saved now or never. An
  /// existing name is left alone: it may have been edited in the profile.
  static Future<void> _saveName(
    User? user,
    AuthorizationCredentialAppleID credential,
  ) async {
    final fullName = [credential.givenName, credential.familyName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (fullName.isEmpty) return;

    final existing = (user?.userMetadata?['full_name'] as String?)?.trim();
    if (existing != null && existing.isNotEmpty) return;

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': fullName}),
      );
    } catch (e, stack) {
      debugPrint('Saving the Apple name failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: stack));
    }
  }

  /// Hands the one-time authorization code to the `apple-token` Edge
  /// Function, which swaps it for a refresh token and keeps it, so that
  /// deleting the account can revoke the app's access with Apple — an App
  /// Store requirement. The code lapses after five minutes, hence now.
  static Future<void> _storeRefreshToken(String authorizationCode) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'apple-token',
        body: {'authorizationCode': authorizationCode},
      );
      if (response.status != 200) {
        throw StateError('apple-token returned ${response.status}');
      }
    } catch (e, stack) {
      debugPrint('Storing the Apple refresh token failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: stack));
    }
  }

  static String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Turns a native failure into something a user can act on.
  ///
  /// `unknown` is what iOS reports when the device isn't signed into an
  /// Apple Account, and also when the build lacks the Sign in with Apple
  /// entitlement — the native message rides along in brackets so a tester
  /// can tell which.
  static String _messageFor(SignInWithAppleAuthorizationException e) {
    final message = switch (e.code) {
      AuthorizationErrorCode.unknown =>
        'Couldn\'t sign in with Apple. Check that this device is signed in '
            'to an Apple Account in Settings, then try again.',
      _ => 'Couldn\'t sign in with Apple. Please try again, or use your '
          'email instead.',
    };
    var detail = e.message.trim();
    if (detail.isEmpty) return message;
    if (detail.length > 140) detail = '${detail.substring(0, 140)}…';
    return '$message ($detail)';
  }
}
