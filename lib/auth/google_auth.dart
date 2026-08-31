import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// OAuth client IDs from the Google Cloud console, for the same project whose
/// client IDs are listed on Supabase → Authentication → Providers → Google.
///
/// These are public identifiers, not secrets — Google expects them to ship
/// inside the app binary. Android has no entry here on purpose: it is
/// identified by package name + signing SHA-1 against the Android OAuth
/// client, which is never named in code.
const _webClientId =
    '497109017811-so8kopsij12akf28engc1fu9rfhbp2rm.apps.googleusercontent.com';
const _iosClientId =
    '497109017811-nm4kb8gspio91adb3tudjfbslvinkcjs.apps.googleusercontent.com';

/// Whether to offer the Google button at all. Uses [defaultTargetPlatform]
/// rather than `dart:io` so the web build still compiles.
bool get googleSignInAvailable =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool _initialized = false;

Future<void> _ensureInitialized() async {
  if (_initialized) return;
  await GoogleSignIn.instance.initialize(
    clientId: defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
    serverClientId: _webClientId,
  );
  _initialized = true;
}

/// Runs the native Google flow and trades the resulting ID token for a
/// Supabase session.
///
/// Returns false if the user dismissed the account picker, so callers can
/// stay quiet instead of showing an error.
Future<bool> signInWithGoogle() async {
  await _ensureInitialized();

  if (!GoogleSignIn.instance.supportsAuthenticate()) {
    throw const AuthException('Google sign-in is not available on this device.');
  }

  final GoogleSignInAccount account;
  try {
    account = await GoogleSignIn.instance.authenticate(
      scopeHint: const ['email', 'profile'],
    );
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) return false;
    throw AuthException(e.description ?? 'Google sign-in failed.');
  }

  // Only the ID token is needed: it already carries email, name and picture,
  // and asking for an access token would add a second consent sheet.
  final idToken = account.authentication.idToken;
  if (idToken == null) {
    throw const AuthException('Google did not return an ID token.');
  }

  await Supabase.instance.client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
  );

  await _fillMissingProfileFields(account);
  return true;
}

/// Forgets the Google account so the next sign-in shows the picker again.
/// Never throws — this runs alongside the real Supabase sign-out.
Future<void> signOutFromGoogle() async {
  if (!googleSignInAvailable || !_initialized) return;
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {
    // A failure here only means the picker may be skipped next time.
  }
}

/// Supabase copies the Google ID token's claims into `user_metadata`, but
/// under Google's key names. The app reads `full_name` and `avatar_url`
/// (see `firstNameOf` in home_ui.dart), so backfill those without ever
/// overwriting values the user has set themselves.
Future<void> _fillMissingProfileFields(GoogleSignInAccount account) async {
  final auth = Supabase.instance.client.auth;
  final metadata = auth.currentUser?.userMetadata ?? const <String, dynamic>{};

  bool blank(String key) => (metadata[key] as String?)?.trim().isEmpty ?? true;

  final patch = <String, dynamic>{};
  if (blank('full_name')) {
    final name = (metadata['name'] as String?) ?? account.displayName;
    if (name != null && name.trim().isNotEmpty) {
      patch['full_name'] = name.trim();
    }
  }
  if (blank('avatar_url')) {
    final photo = (metadata['picture'] as String?) ?? account.photoUrl;
    if (photo != null && photo.isNotEmpty) {
      patch['avatar_url'] = photo;
    }
  }
  if (patch.isEmpty) return;

  await auth.updateUser(UserAttributes(data: patch));
}
