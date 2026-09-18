import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../therapy/therapy_repository.dart';

/// What the signed-in person can do beyond being a client. Both roles come
/// from their confirmed email (see migration 0009), so they're looked up,
/// never stored in the app.
class CareRoles {
  const CareRoles({this.isAdmin = false, this.therapistId, this.therapistName});

  static const none = CareRoles();

  final bool isAdmin;
  final String? therapistId;
  final String? therapistName;

  bool get isTherapist => therapistId != null;
}

/// A therapy request as the care team sees it: who asked, who they were
/// matched with, and how both sides rated it.
class AdminTherapyRequest {
  const AdminTherapyRequest({
    required this.request,
    required this.clientId,
    this.clientName,
    this.clientEmail,
    this.therapistName,
    this.paidAt,
    this.refundedAt,
    this.clientJoinedAt,
    this.therapistJoinedAt,
    this.clientRating,
    this.clientComment,
    this.therapistRating,
    this.therapistComment,
    this.therapistFlags = const [],
  });

  factory AdminTherapyRequest.fromRow(Map<String, dynamic> row) =>
      AdminTherapyRequest(
        request: TherapyRequest.fromRow(row),
        clientId: row['client_id'] as String,
        clientName: row['client_name'] as String?,
        clientEmail: row['client_email'] as String?,
        therapistName: row['therapist_name'] as String?,
        paidAt: row['paid_at'] == null
            ? null
            : DateTime.parse(row['paid_at'] as String).toLocal(),
        refundedAt: row['refunded_at'] == null
            ? null
            : DateTime.parse(row['refunded_at'] as String).toLocal(),
        clientJoinedAt: row['client_joined_at'] == null
            ? null
            : DateTime.parse(row['client_joined_at'] as String).toLocal(),
        therapistJoinedAt: row['therapist_joined_at'] == null
            ? null
            : DateTime.parse(row['therapist_joined_at'] as String).toLocal(),
        clientRating: (row['client_rating'] as num?)?.toInt(),
        clientComment: row['client_comment'] as String?,
        therapistRating: (row['therapist_rating'] as num?)?.toInt(),
        therapistComment: row['therapist_comment'] as String?,
        therapistFlags:
            [...(row['therapist_flags'] as List? ?? const []).cast<String>()],
      );

  final TherapyRequest request;
  final String clientId;
  final String? clientName;
  final String? clientEmail;
  final String? therapistName;
  final DateTime? paidAt;

  /// When Google Play refunded an in-app payment for this session. The
  /// session is unpaid again from then, unless the care team changed it.
  final DateTime? refundedAt;

  /// When each side first asked to join the call, if they did.
  final DateTime? clientJoinedAt;
  final DateTime? therapistJoinedAt;
  final int? clientRating;
  final String? clientComment;
  final int? therapistRating;
  final String? therapistComment;
  final List<String> therapistFlags;

  String get clientLabel => clientName ?? clientEmail ?? 'Client';
}

/// A therapist as the care team manages them.
class AdminTherapist {
  const AdminTherapist({
    required this.profile,
    required this.email,
    required this.hasAccount,
    this.upcomingSessions = 0,
    this.completedSessions = 0,
  });

  factory AdminTherapist.fromRow(Map<String, dynamic> row) => AdminTherapist(
        profile: TherapistProfile.fromRow(
          row,
          ratingAverage: (row['rating_average'] as num?)?.toDouble(),
          ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
        ),
        email: row['email'] as String? ?? '',
        hasAccount: row['has_account'] as bool? ?? false,
        upcomingSessions: (row['upcoming_sessions'] as num?)?.toInt() ?? 0,
        completedSessions: (row['completed_sessions'] as num?)?.toInt() ?? 0,
      );

  final TherapistProfile profile;

  /// The address they sign in with.
  final String email;

  /// Whether someone has signed in with [email] and confirmed it. Until then
  /// they can be matched but can't see or join their sessions.
  final bool hasAccount;
  final int upcomingSessions;
  final int completedSessions;
}

/// Flags a therapist can raise about a session, with how they're shown.
const therapistFlagLabels = {
  'no_show': 'Didn\'t show up',
  'late': 'Joined late',
  'follow_up': 'Needs a follow-up',
  'safety_concern': 'Safety concern',
};

/// A session as its therapist sees it: the client's first name and what
/// they asked for, never their contact details.
class TherapistSession {
  const TherapistSession({
    required this.id,
    required this.status,
    required this.topic,
    required this.availability,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.paymentStatus,
    required this.isFreeSession,
    this.note,
    this.clientFirstName,
    this.clientSummary,
    this.completedAt,
    this.closeReason,
    this.clientJoinedAt,
    this.myRating,
    this.myComment,
    this.myFlags = const [],
  });

  factory TherapistSession.fromRow(Map<String, dynamic> row) =>
      TherapistSession(
        id: row['id'] as String,
        status: row['status'] as String,
        topic: row['topic'] as String,
        availability:
            [...(row['availability'] as List? ?? const []).cast<String>()],
        note: row['note'] as String?,
        scheduledAt: row['scheduled_at'] == null
            ? null
            : DateTime.parse(row['scheduled_at'] as String).toLocal(),
        durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 50,
        paymentStatus: row['payment_status'] as String? ?? 'not_required',
        isFreeSession: row['is_free_session'] as bool? ?? false,
        clientFirstName: row['client_first_name'] as String?,
        clientSummary: row['client_summary'] as String?,
        completedAt: row['completed_at'] == null
            ? null
            : DateTime.parse(row['completed_at'] as String).toLocal(),
        closeReason: row['close_reason'] as String?,
        clientJoinedAt: row['client_joined_at'] == null
            ? null
            : DateTime.parse(row['client_joined_at'] as String).toLocal(),
        myRating: (row['my_rating'] as num?)?.toInt(),
        myComment: row['my_comment'] as String?,
        myFlags: [...(row['my_flags'] as List? ?? const []).cast<String>()],
      );

  final String id;
  final String status;
  final String topic;
  final List<String> availability;
  final String? note;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final String paymentStatus;
  final bool isFreeSession;
  final String? clientFirstName;
  final String? clientSummary;
  final DateTime? completedAt;

  /// Set when the server closed the session (see TherapyRequest.closeReason).
  final String? closeReason;
  final DateTime? clientJoinedAt;
  final int? myRating;
  final String? myComment;
  final List<String> myFlags;

  String get clientLabel => clientFirstName ?? 'Your client';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get paymentSettled => paymentStatus != 'unpaid';
  bool get clientMissed => isCompleted && closeReason == 'client_no_show';

  /// Cancelled by the server because the call never happened.
  bool get didNotHappen => isCancelled &&
      (closeReason == 'nobody_joined' || closeReason == 'therapist_no_show');

  JoinState joinStateAt(DateTime now) => isConfirmed
      ? sessionJoinState(now,
          scheduledAt: scheduledAt, durationMinutes: durationMinutes)
      : JoinState.notScheduled;

  /// A session can be finished once it has started.
  bool canFinishAt(DateTime now) =>
      isConfirmed && scheduledAt != null && !now.isBefore(scheduledAt!);
}

/// What to show a staff member for a failed action. Messages raised by the
/// database functions are written for people, so they're passed through.
String careErrorMessage(Object error, String fallback) => switch (error) {
      PostgrestException(:final message) when message.isNotEmpty => message,
      SessionAccessException() => error.message,
      StateError() => 'You\'ve been signed out. Please log in again.',
      _ => fallback,
    };

/// Supabase-backed access for the care team and therapists. Every call is
/// checked server-side; a client calling these just gets refused.
class CareRepository {
  final _client = Supabase.instance.client;

  Future<CareRoles> fetchRoles() async {
    if (_client.auth.currentUser == null) return CareRoles.none;
    try {
      final data = await _client.rpc('my_care_roles');
      final roles = Map<String, dynamic>.from(data as Map);
      return CareRoles(
        isAdmin: roles['is_admin'] == true,
        therapistId: roles['therapist_id'] as String?,
        therapistName: roles['therapist_name'] as String?,
      );
    } catch (e) {
      debugPrint('Care roles lookup failed: $e');
      return CareRoles.none;
    }
  }

  // ── Admin ──────────────────────────────────────────────────────────

  Future<List<AdminTherapyRequest>> listRequests() async {
    final rows = await _client.rpc('admin_list_therapy_requests') as List;
    return [
      for (final row in rows)
        AdminTherapyRequest.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<List<AdminTherapist>> listTherapists() async {
    final rows = await _client.rpc('admin_list_therapists') as List;
    return [
      for (final row in rows)
        AdminTherapist.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<String> saveTherapist({
    String? id,
    required String fullName,
    required String email,
    String? title,
    String? credentials,
    String? bio,
    List<String> specialties = const [],
    List<String> languages = const [],
    int? yearsExperience,
    String? photoUrl,
    bool active = true,
  }) async {
    final saved = await _client.rpc('admin_save_therapist', params: {
      'p_id': id,
      'p_full_name': fullName,
      'p_email': email,
      'p_title': title,
      'p_credentials': credentials,
      'p_bio': bio,
      'p_specialties': specialties,
      'p_languages': languages,
      'p_years_experience': yearsExperience,
      'p_photo_url': photoUrl,
      'p_active': active,
    });
    return saved as String;
  }

  /// Uploads a profile photo to the public therapist-photos bucket and
  /// returns its URL.
  Future<String> uploadTherapistPhoto(Uint8List bytes, {String? therapistId}) async {
    final name = therapistId ?? 'new-${DateTime.now().microsecondsSinceEpoch}';
    final path = '$name.jpg';
    await _client.storage.from('therapist-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    // The path is reused across uploads, so bust the image cache.
    final url = _client.storage.from('therapist-photos').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> matchRequest(
    String requestId, {
    required String therapistId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    await _client.rpc('admin_match_therapy_request', params: {
      'p_request_id': requestId,
      'p_therapist_id': therapistId,
      'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'p_duration_minutes': durationMinutes,
    });
  }

  /// paid, waived or unpaid — for payments taken outside the app.
  Future<void> setPayment(String requestId, String paymentStatus) async {
    await _client.rpc('admin_set_therapy_payment', params: {
      'p_request_id': requestId,
      'p_payment_status': paymentStatus,
    });
  }

  Future<void> cancelRequest(String requestId) async {
    await _client.rpc('admin_cancel_therapy_request',
        params: {'p_request_id': requestId});
  }

  // ── Therapist ──────────────────────────────────────────────────────

  Future<List<TherapistSession>> listMySessions() async {
    final rows = await _client.rpc('therapist_list_sessions') as List;
    return [
      for (final row in rows)
        TherapistSession.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }

  /// Ends the session (or edits the note on one already ended).
  Future<void> completeSession(String requestId, String summary) async {
    await _client.rpc('complete_therapy_session', params: {
      'p_request_id': requestId,
      'p_summary': summary,
    });
  }

  Future<void> rateClient(
    String requestId, {
    required int rating,
    String? comment,
    List<String> flags = const [],
  }) async {
    await _client.rpc('rate_therapy_session', params: {
      'p_request_id': requestId,
      'p_rating': rating,
      'p_comment': comment,
      'p_flags': flags,
    });
  }

  Future<SessionCredentials> joinSession(String requestId) =>
      fetchSessionCredentials(_client, requestId);
}
