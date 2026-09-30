import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_format.dart';

/// What a session costs. The database holds the real price
/// (`therapy_session_price_cents()` in migration 0009) and stamps it on each
/// request; this is only for copy shown before a request exists.
const therapySessionPriceCents = 2000;

/// How far ahead a session can still be cancelled from the app, with a
/// refund. Later than this — or not joining at all — isn't refunded. The
/// database enforces the same cutoff (`therapy_cancel_notice()`, 0019).
const therapyCancelNotice = Duration(hours: 24);

/// The policy in one breath, shown wherever someone is about to pay.
const therapyCancellationPolicy =
    'Cancel in the app up to 24 hours before your session for a full '
    'refund. A session cancelled later than that, or not joined, isn\'t '
    'refunded.';

/// How early a call opens, and how long past its scheduled end it stays
/// open. The session-token Edge Function enforces the same window.
const sessionEarlyJoin = Duration(minutes: 10);
const sessionLateGrace = Duration(minutes: 30);

/// What someone can ask for help with. Therapists' specialties use the same
/// names, so the care team can see who fits a request.
const therapyTopics = [
  'Anxiety & stress',
  'Low mood',
  'Relationships',
  'Grief & loss',
  'Addiction & recovery',
  'Not sure yet',
];

/// "$20"; cents only when there are some.
String formatPrice(int cents, [String currency = 'USD']) {
  final symbol = currency == 'USD' ? '\$' : '$currency ';
  final amount = cents % 100 == 0
      ? '${cents ~/ 100}'
      : (cents / 100).toStringAsFixed(2);
  return '$symbol$amount';
}

/// Where a session's call stands at a given moment.
enum JoinState { notScheduled, tooEarly, open, over }

JoinState sessionJoinState(
  DateTime now, {
  required DateTime? scheduledAt,
  required int durationMinutes,
}) {
  if (scheduledAt == null) return JoinState.notScheduled;
  final opens = scheduledAt.subtract(sessionEarlyJoin);
  final closes = scheduledAt
      .add(Duration(minutes: durationMinutes))
      .add(sessionLateGrace);
  if (now.isBefore(opens)) return JoinState.tooEarly;
  if (now.isAfter(closes)) return JoinState.over;
  return JoinState.open;
}

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

List<String> _strings(Object? value) =>
    [...(value as List? ?? const []).cast<String>()];

/// A request for a private session with a licensed therapist, and — once
/// the care team matches it — the session itself.
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
    this.submittedAt,
    this.therapistId,
    this.durationMinutes = 50,
    this.priceCents = 0,
    this.currency = 'USD',
    this.paymentStatus = 'not_required',
    this.clientSummary,
    this.completedAt,
    this.closeReason,
  });

  factory TherapyRequest.fromRow(Map<String, dynamic> row) => TherapyRequest(
        id: row['id'] as String,
        topic: row['topic'] as String,
        availability: _strings(row['availability']),
        note: row['note'] as String?,
        status: row['status'] as String,
        isFreeSession: row['is_free_session'] as bool,
        scheduledAt: _time(row['scheduled_at']),
        createdAt: _time(row['created_at'])!,
        submittedAt: _time(row['submitted_at']),
        therapistId: row['therapist_id'] as String?,
        durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 50,
        priceCents: (row['price_cents'] as num?)?.toInt() ?? 0,
        currency: row['currency'] as String? ?? 'USD',
        paymentStatus: row['payment_status'] as String? ?? 'not_required',
        clientSummary: row['client_summary'] as String?,
        completedAt: _time(row['completed_at']),
        closeReason: row['close_reason'] as String?,
      );

  final String id;
  final String topic;
  final List<String> availability;
  final String? note;

  /// One of: awaiting_payment, pending, confirmed, completed, cancelled.
  /// A request starts as a draft (awaiting_payment) that only its owner
  /// sees; paying for it sends it to the care team (pending).
  final String status;

  /// Always false for requests made since migration 0019; kept so older
  /// rows still read correctly.
  final bool isFreeSession;

  /// Set by the care team when they match the request with a therapist.
  final DateTime? scheduledAt;
  final DateTime createdAt;

  /// When the paid request reached the care team; null for a draft.
  final DateTime? submittedAt;
  final String? therapistId;
  final int durationMinutes;
  final int priceCents;
  final String currency;

  /// One of: unpaid, paid, waived (not_required on rows from before 0019).
  final String paymentStatus;

  /// The therapist's note for the client, written when the session ends.
  final String? clientSummary;
  final DateTime? completedAt;

  /// Why the server closed this session itself (migration 0016), or null
  /// when a person did. One of: auto_completed, client_no_show,
  /// therapist_no_show, nobody_joined, unpaid.
  final String? closeReason;

  /// Saved but not paid for yet, so the care team hasn't seen it.
  bool get isAwaitingPayment => status == 'awaiting_payment';
  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';

  /// With the care team or booked — what the dashboard counts as open.
  bool get isActive => isPending || isConfirmed;

  /// What the client sees as their current request: a draft they still
  /// have to pay for, or a session on its way.
  bool get isCurrent => isAwaitingPayment || isActive;

  bool get needsPayment => paymentStatus == 'unpaid';

  /// Completed without the client ever joining the call.
  bool get wasMissed => isCompleted && closeReason == 'client_no_show';

  /// Closed because the call never happened (nobody, or only the client,
  /// turned up).
  bool get didNotHappen => status == 'cancelled' &&
      (closeReason == 'nobody_joined' || closeReason == 'therapist_no_show');

  /// The call window has closed and it's now up to the therapist or the
  /// server (within a couple of hours) to close it out.
  bool hasElapsedAt(DateTime now) =>
      isConfirmed && joinStateAt(now) == JoinState.over;

  /// A draft or an unmatched request can always be cancelled (the care
  /// team refunds a paid one). A booked session can be cancelled up to
  /// [therapyCancelNotice] before it starts; after that the database
  /// refuses, and the session isn't refunded if it's missed.
  bool canCancelAt(DateTime now) {
    if (!isCurrent) return false;
    if (!isConfirmed || scheduledAt == null) return true;
    return now.isBefore(scheduledAt!.subtract(therapyCancelNotice));
  }

  /// Booked, paid, and inside the no-refund window.
  bool isLockedInAt(DateTime now) =>
      isConfirmed && !canCancelAt(now) && !needsPayment;

  String get priceLabel => formatPrice(priceCents, currency);

  JoinState joinStateAt(DateTime now) => isConfirmed
      ? sessionJoinState(now,
          scheduledAt: scheduledAt, durationMinutes: durationMinutes)
      : JoinState.notScheduled;
}

/// What a client sees about the therapist they've been matched with.
class TherapistProfile {
  const TherapistProfile({
    required this.id,
    required this.fullName,
    this.title,
    this.credentials,
    this.bio,
    this.specialties = const [],
    this.languages = const [],
    this.yearsExperience,
    this.photoUrl,
    this.active = true,
    this.ratingAverage,
    this.ratingCount = 0,
  });

  factory TherapistProfile.fromRow(
    Map<String, dynamic> row, {
    double? ratingAverage,
    int ratingCount = 0,
  }) =>
      TherapistProfile(
        id: row['id'] as String,
        fullName: row['full_name'] as String,
        title: row['title'] as String?,
        credentials: row['credentials'] as String?,
        bio: row['bio'] as String?,
        specialties: _strings(row['specialties']),
        languages: _strings(row['languages']),
        yearsExperience: (row['years_experience'] as num?)?.toInt(),
        photoUrl: row['photo_url'] as String?,
        active: row['active'] as bool? ?? true,
        ratingAverage: ratingAverage,
        ratingCount: ratingCount,
      );

  final String id;
  final String fullName;
  final String? title;
  final String? credentials;
  final String? bio;
  final List<String> specialties;
  final List<String> languages;
  final int? yearsExperience;
  final String? photoUrl;
  final bool active;

  /// Only present once there are enough ratings to show one.
  final double? ratingAverage;
  final int ratingCount;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;
}

/// Everything needed to join a session's video call.
class SessionCredentials {
  const SessionCredentials({
    required this.url,
    required this.token,
    required this.role,
    required this.endsAt,
  });

  final String url;
  final String token;

  /// client or therapist.
  final String role;
  final DateTime endsAt;
}

/// Why joining a call or confirming a payment was refused, from the Edge
/// Function's error code.
class SessionAccessException implements Exception {
  const SessionAccessException(this.code, {this.opensAt});

  final String code;
  final DateTime? opensAt;

  String get message => switch (code) {
        'too_early' => opensAt == null
            ? 'The session isn\'t open yet.'
            : 'You can join from ${formatTime(opensAt!)} — 10 minutes '
                'before the start.',
        'session_over' => 'This session\'s time has passed.',
        'payment_required' =>
          'This session needs to be paid for before you can join.',
        'not_confirmed' => 'This session isn\'t confirmed yet.',
        'not_found' => 'We couldn\'t find that session.',
        'no_payment_found' =>
          'We couldn\'t find your payment yet. If you were charged, try '
              'again in a minute.',
        'not_payable' =>
          'This request can\'t be paid for any more — start a new one.',
        'not_configured' =>
          'This isn\'t switched on yet. Please contact us.',
        'invalid_token' ||
        'missing_token' =>
          'You\'ve been signed out. Please log in again.',
        _ => 'Something went wrong — check your connection and try again.',
      };

  @override
  String toString() => 'SessionAccessException($code)';
}

/// How a finished session reads in a list, for clients and staff alike.
String sessionOutcomeLabel(TherapyRequest request) => switch (request.status) {
      'completed' when request.wasMissed => 'Missed',
      'completed' => 'Completed',
      'cancelled' when request.didNotHappen => 'Didn\'t happen',
      'cancelled' when request.closeReason == 'unpaid' => 'Not paid',
      'cancelled' when request.submittedAt == null => 'Not sent',
      _ => 'Cancelled',
    };

/// Supabase-backed storage for a client's therapy sessions.
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
    return [for (final row in rows) TherapyRequest.fromRow(row)];
  }

  /// Saves a request as a draft. Nothing reaches the care team until it's
  /// paid for ([SessionPayments.pay]); the database moves it on itself.
  Future<TherapyRequest> requestSession({
    required String topic,
    List<String> availability = const [],
    String? note,
  }) async {
    final row = await _client
        .from('therapy_requests')
        .insert({
          'user_id': _userId,
          'topic': topic,
          'availability': availability,
          if (note != null && note.isNotEmpty) 'note': note,
        })
        .select()
        .single();
    return TherapyRequest.fromRow(row);
  }

  Future<void> cancelRequest(String id) => _client
      .from('therapy_requests')
      .update({'status': 'cancelled'}).eq('id', id);

  /// Profiles for these therapists, with an average rating where there are
  /// enough ratings to show one.
  Future<Map<String, TherapistProfile>> fetchTherapists(
      Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const {};
    final rows =
        await _client.from('therapists').select().inFilter('id', unique);
    final summaries =
        await _client.rpc('therapist_rating_summaries') as List<dynamic>;
    final ratings = {
      for (final s in summaries) s['therapist_id'] as String: s as Map,
    };
    return {
      for (final row in rows)
        row['id'] as String: TherapistProfile.fromRow(
          row,
          ratingAverage:
              (ratings[row['id']]?['rating_average'] as num?)?.toDouble(),
          ratingCount:
              (ratings[row['id']]?['rating_count'] as num?)?.toInt() ?? 0,
        ),
    };
  }

  /// The star ratings this person has given, by session id.
  Future<Map<String, int>> fetchMyRatings() async {
    final rows = await _client
        .from('therapy_ratings')
        .select('request_id, rating')
        .eq('author_id', _userId)
        .eq('author_role', 'client');
    return {
      for (final row in rows)
        row['request_id'] as String: (row['rating'] as num).toInt(),
    };
  }

  Future<void> rateSession(
    String requestId, {
    required int rating,
    String? comment,
  }) async {
    await _client.rpc('rate_therapy_session', params: {
      'p_request_id': requestId,
      'p_rating': rating,
      'p_comment': comment,
    });
  }

  Future<SessionCredentials> joinSession(String requestId) =>
      fetchSessionCredentials(_client, requestId);

  /// Asks the server to find the in-app purchase for this session.
  Future<void> confirmPayment(String requestId) async {
    await invokeSessionFunction(_client, 'confirm-session-payment', requestId);
    Sentry.metrics.count('therapy.payment_confirmed', 1);
  }
}

/// Shared by clients and therapists: the server checks which one is asking.
Future<SessionCredentials> fetchSessionCredentials(
  SupabaseClient client,
  String requestId,
) async {
  final data =
      await invokeSessionFunction(client, 'session-token', requestId);
  return SessionCredentials(
    url: data['url'] as String,
    token: data['token'] as String,
    role: data['role'] as String,
    endsAt: DateTime.parse(data['ends_at'] as String).toLocal(),
  );
}

/// Calls one of the session Edge Functions, turning its error codes into
/// [SessionAccessException]s.
Future<Map<String, dynamic>> invokeSessionFunction(
  SupabaseClient client,
  String function,
  String requestId,
) async {
  if (client.auth.currentUser == null) throw StateError('Not signed in');
  try {
    final response = await client.functions
        .invoke(function, body: {'request_id': requestId});
    return Map<String, dynamic>.from(response.data as Map);
  } on FunctionException catch (e) {
    final details = e.details;
    final code = details is Map ? details['error'] as String? : null;
    final opensAt = details is Map && details['opens_at'] is String
        ? DateTime.parse(details['opens_at'] as String).toLocal()
        : null;
    throw SessionAccessException(code ?? 'unavailable', opensAt: opensAt);
  }
}
