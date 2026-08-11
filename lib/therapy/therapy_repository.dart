import 'package:supabase_flutter/supabase_flutter.dart';

/// A request for a private session with a licensed therapist.
class TherapyRequest {
  const TherapyRequest({
    required this.id,
    required this.topic,
    required this.availability,
    required this.note,
    required this.status,
    required this.isFreeSession,
    required this.scheduledAt,
    required this.createdAt,
  });

  final String id;
  final String topic;
  final List<String> availability;
  final String? note;

  /// One of: pending, confirmed, completed, cancelled.
  final String status;
  final bool isFreeSession;

  /// Set by the care team once a time is agreed.
  final DateTime? scheduledAt;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';

  /// Still moving forward — shown as the current session up top.
  bool get isActive => isPending || isConfirmed;
}

/// Supabase-backed storage for therapy session requests.
class TherapyRepository {
  final _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<List<TherapyRequest>> fetchRequests() async {
    final rows = await _client
        .from('therapy_requests')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        TherapyRequest(
          id: row['id'] as String,
          topic: row['topic'] as String,
          availability: [...(row['availability'] as List? ?? []).cast<String>()],
          note: row['note'] as String?,
          status: row['status'] as String,
          isFreeSession: row['is_free_session'] as bool,
          scheduledAt: row['scheduled_at'] == null
              ? null
              : DateTime.parse(row['scheduled_at'] as String).toLocal(),
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        ),
    ];
  }

  /// The first session someone actually books is on us; a cancelled
  /// request doesn't use up the offer.
  bool isFreeSessionAvailable(List<TherapyRequest> requests) =>
      requests.every((r) => r.status == 'cancelled');

  Future<void> requestSession({
    required String topic,
    List<String> availability = const [],
    String? note,
  }) async {
    final free = isFreeSessionAvailable(await fetchRequests());
    await _client.from('therapy_requests').insert({
      'user_id': _userId,
      'topic': topic,
      'availability': availability,
      if (note != null && note.isNotEmpty) 'note': note,
      'is_free_session': free,
    });
  }

  Future<void> cancelRequest(String id) => _client
      .from('therapy_requests')
      .update({'status': 'cancelled'}).eq('id', id);
}
