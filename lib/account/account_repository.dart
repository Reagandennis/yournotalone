import 'package:supabase_flutter/supabase_flutter.dart';

/// Deleting an account, in the two parts it has to happen in.
///
/// Removing an `auth.users` row needs the service_role key, which never
/// ships in a client — so the app records the request in
/// `deletion_requests` first, then asks the `delete-account` Edge Function
/// to do the work. If the function call fails, the recorded request is the
/// work queue (see supabase/account_ops.sql), so nobody's request is ever
/// silently dropped.
class AccountRepository {
  AccountRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    return user;
  }

  /// Files the request and carries out the deletion. Throws
  /// [DeletionNotRecorded] when even the request couldn't be filed (so
  /// nothing will happen unless they try again), anything else when it was
  /// filed but the deletion didn't finish (the request stays on file).
  Future<void> deleteAccount() async {
    final user = _user;
    try {
      await _client.from('deletion_requests').insert({
        'user_id': user.id,
        'user_email': user.email,
      });
    } catch (e) {
      throw DeletionNotRecorded(e);
    }

    final response = await _client.functions.invoke('delete-account');
    if (response.status != 200) {
      throw StateError('Deletion did not complete (${response.status})');
    }
  }
}

/// The deletion request couldn't be filed (typically offline): nothing is
/// on file, so telling them it is would be untrue.
class DeletionNotRecorded implements Exception {
  const DeletionNotRecorded(this.cause);

  final Object cause;

  @override
  String toString() => 'DeletionNotRecorded($cause)';
}
