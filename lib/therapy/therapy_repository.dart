import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
import '../support/crisis_resources.dart';
import 'session_format.dart';

/// What a session costs when the server can't say: before migration 0031
/// (`therapy_price_quote()`) is applied, or offline. The database prices
/// each request itself, by the client's country (0031), so this is only
/// ever copy — the '*' row of `therapy_prices`.
const therapySessionPriceCents = 2000;

/// What Paystack charges for a session at that price: the Paystack account
/// settles in Kenyan shillings, so its page shows this. Keep in step with
/// CHARGE_AMOUNT in supabase/functions/paystack-payment, which charges it
/// for sessions booked before 0031.
const therapySessionChargeMinor = 260000;
const therapySessionChargeCurrency = 'KES';

/// How a session can be paid for on the Paystack page — only the channels
/// switched on for the Paystack account (Settings → Preferences → Payment
/// channels). Add card and Apple Pay here (`therapyPaymentMethods` in the
/// ARB files) once Paystack activates them.

/// How far ahead a session can still be cancelled from the app, with a
/// refund. Later than this — or not joining at all — isn't refunded. The
/// database enforces the same cutoff (`therapy_cancel_notice()`, 0019).
const therapyCancelNotice = Duration(hours: 24);

/// The policy in one breath, shown wherever someone is about to pay, is
/// `therapyCancellationPolicy` in the ARB files: keep it in step with this.

/// How early a call opens, and how long past its scheduled end it stays
/// open. The session-token Edge Function enforces the same window.
const sessionEarlyJoin = Duration(minutes: 10);
const sessionLateGrace = Duration(minutes: 30);

/// What someone can ask for help with. Therapists' specialties use the same
/// names, so the care team can see who fits a request. These are stored as
/// they are; [therapyTopicLabel] is how each one reads on screen.
const therapyTopics = [
  'Anxiety & stress',
  'Low mood',
  'Relationships',
  'Grief & loss',
  'Addiction & recovery',
  'Not sure yet',
];

/// A stored topic (or specialty) in the language the app is showing; one
/// that isn't in [therapyTopics] is shown as it was written.
String therapyTopicLabel(AppLocalizations l10n, String topic) =>
    switch (topic) {
      'Anxiety & stress' => l10n.therapyTopicAnxietyStress,
      'Low mood' => l10n.therapyTopicLowMood,
      'Relationships' => l10n.therapyTopicRelationships,
      'Grief & loss' => l10n.therapyTopicGriefLoss,
      'Addiction & recovery' => l10n.therapyTopicAddictionRecovery,
      'Not sure yet' => l10n.therapyTopicNotSure,
      _ => topic,
    };

/// "$20", "£45", "Ksh 2,600", "€49.50": an amount in minor units (cents,
/// pence) with its currency's sign, or its ISO code for one without a sign
/// here; thousands grouped, and cents only when there are some. Matches
/// `therapy_price_label()` (migration 0031), which writes the emails,
/// except that dollars stay "$" rather than "US$".
String formatPrice(int cents, [String currency = 'USD']) {
  final code = currency.trim().toUpperCase();
  final symbol = switch (code) {
    'USD' => '\$',
    'GBP' => '£',
    'EUR' => '€',
    'KES' => 'Ksh ',
    'UGX' => 'USh ',
    'TZS' => 'TSh ',
    'NGN' => '₦',
    'ZAR' => 'R',
    'CAD' => 'CA\$',
    'AUD' => 'A\$',
    _ => '$code ',
  };
  final whole = '${cents.abs() ~/ 100}'.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => ',',
  );
  final fraction = cents.abs() % 100;
  final amount =
      fraction == 0 ? whole : '$whole.${'$fraction'.padLeft(2, '0')}';
  return '${cents < 0 ? '-' : ''}$symbol$amount';
}

/// What a session costs the signed-in person, from `therapy_price_quote()`
/// (migration 0031): the price shown, in their currency, and what Paystack
/// charges for it. Both depend on the country they've chosen; with none,
/// the price for everywhere without its own applies.
class TherapyPriceQuote {
  const TherapyPriceQuote({
    required this.country,
    required this.canChange,
    required this.currency,
    required this.priceMinor,
    required this.chargeCurrency,
    required this.chargeMinor,
    this.pricedCountries = const [],
    this.fromServer = true,
  });

  factory TherapyPriceQuote.fromJson(Map<String, dynamic> json) {
    final country = json['country'];
    return TherapyPriceQuote(
      country: country is String && country.isNotEmpty ? country : null,
      canChange: json['can_change'] == true,
      currency: json['currency'] as String? ?? 'USD',
      priceMinor:
          (json['price_minor'] as num?)?.toInt() ?? therapySessionPriceCents,
      chargeCurrency:
          json['charge_currency'] as String? ?? therapySessionChargeCurrency,
      chargeMinor:
          (json['charge_minor'] as num?)?.toInt() ?? therapySessionChargeMinor,
      pricedCountries: [
        for (final code in json['priced_countries'] as List? ?? const [])
          if (code is String) code,
      ],
    );
  }

  /// Today's price, for when the server can't be asked: nothing about the
  /// person's country is known, and there's nothing to change.
  static const fallback = TherapyPriceQuote(
    country: null,
    canChange: false,
    currency: 'USD',
    priceMinor: therapySessionPriceCents,
    chargeCurrency: therapySessionChargeCurrency,
    chargeMinor: therapySessionChargeMinor,
    fromServer: false,
  );

  /// The ISO code of the country prices are for, or null until one is
  /// chosen.
  final String? country;

  /// False once they've paid for a session: from then on only the care
  /// team can change their country.
  final bool canChange;
  final String currency;
  final int priceMinor;
  final String chargeCurrency;
  final int chargeMinor;

  /// Countries with a price of their own; everywhere else gets the default.
  final List<String> pricedCountries;

  /// False for [fallback].
  final bool fromServer;

  String get priceLabel => formatPrice(priceMinor, currency);
  String get chargeLabel => formatPrice(chargeMinor, chargeCurrency);

  /// Whether [request] was priced the way this quote says.
  bool matches(TherapyRequest request) =>
      request.priceCents == priceMinor &&
      request.currency.toUpperCase() == currency.toUpperCase();
}

/// The quote [call] (the `therapy_price_quote()` RPC) answers, or
/// [TherapyPriceQuote.fallback] when there's none to be had: the function
/// isn't there yet (PostgREST's PGRST202, before 0031), the phone is
/// offline, or the answer can't be read.
@visibleForTesting
Future<TherapyPriceQuote> readPriceQuote(Future<Object?> Function() call) async {
  try {
    final data = await call().timeout(const Duration(seconds: 15));
    return TherapyPriceQuote.fromJson(Map<String, dynamic>.from(data as Map));
  } on PostgrestException catch (e) {
    if (e.code != 'PGRST202' && e.code != '42883') {
      // Not the expected "not there yet": worth knowing about.
      unawaited(Sentry.captureException(e));
    }
    return TherapyPriceQuote.fallback;
  } catch (e) {
    debugPrint('Therapy price quote unavailable: $e');
    return TherapyPriceQuote.fallback;
  }
}

/// The phone's country as an ISO code: the one picked on the crisis screen,
/// else the first of the phone's locales that names a country. Null when
/// none does.
String? deviceCountry() {
  final crisis = crisisCountry();
  if (crisis != null) return crisis;
  for (final locale in PlatformDispatcher.instance.locales) {
    final code = locale.countryCode?.toUpperCase();
    // Skips numeric regions like es-419 (Latin America).
    if (code != null && RegExp(r'^[A-Z]{2}$').hasMatch(code)) return code;
  }
  return null;
}

/// The price to show, never failing: the server's quote, else
/// [TherapyPriceQuote.fallback]. The first time — no country chosen yet,
/// and still free to choose — it quietly sets the phone's country
/// ([detectCountry]), so the price is the local one from the start.
Future<TherapyPriceQuote> loadTherapyPriceQuote(
  TherapyRepository repository, {
  String? Function() detectCountry = deviceCountry,
}) async {
  final TherapyPriceQuote quote;
  try {
    quote = await repository.fetchPriceQuote();
  } catch (_) {
    return TherapyPriceQuote.fallback;
  }
  if (!quote.fromServer || quote.country != null || !quote.canChange) {
    return quote;
  }
  final String? detected;
  try {
    detected = detectCountry();
  } catch (_) {
    return quote;
  }
  if (detected == null) return quote;
  try {
    return await repository
        .setPriceCountry(detected)
        .timeout(const Duration(seconds: 15));
  } catch (e) {
    // Shown with the default price; tried again next time.
    debugPrint('Couldn\'t set the therapy price country: $e');
    return quote;
  }
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
    this.chargeMinor,
    this.chargeCurrency,
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
        chargeMinor: (row['charge_minor'] as num?)?.toInt(),
        chargeCurrency: row['charge_currency'] as String?,
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

  /// What Paystack charges for it (migration 0031); null on sessions booked
  /// before then, which are charged [therapySessionChargeMinor].
  final int? chargeMinor;
  final String? chargeCurrency;

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

  /// What the Paystack page will show, e.g. "Ksh 2,600".
  String get chargeLabel => chargeMinor == null
      ? formatPrice(therapySessionChargeMinor, therapySessionChargeCurrency)
      : formatPrice(chargeMinor!, chargeCurrency ?? therapySessionChargeCurrency);

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

  String get message {
    final l10n = currentL10n();
    return switch (code) {
      'too_early' => opensAt == null
          ? l10n.sessionErrorTooEarly
          : l10n.sessionErrorTooEarlyAt(formatTime(opensAt!)),
      'session_over' => l10n.sessionErrorOver,
      'payment_required' => l10n.sessionErrorPaymentRequired,
      'not_confirmed' => l10n.sessionErrorNotConfirmed,
      'not_found' => l10n.sessionErrorNotFound,
      'no_payment_found' => l10n.sessionErrorNoPaymentFound,
      'not_payable' => l10n.sessionErrorNotPayable,
      'checkout_failed' => l10n.sessionErrorCheckoutFailed,
      'email_required' => l10n.sessionErrorEmailRequired,
      'not_configured' => l10n.sessionErrorNotConfigured,
      'invalid_token' || 'missing_token' => l10n.sessionErrorSignedOut,
      _ => l10n.sessionErrorGeneric,
    };
  }

  @override
  String toString() => 'SessionAccessException($code)';
}

/// How a finished session reads in a list, for clients and staff alike.
String sessionOutcomeLabel(TherapyRequest request) {
  final l10n = currentL10n();
  return switch (request.status) {
    'completed' when request.wasMissed => l10n.sessionOutcomeMissed,
    'completed' => l10n.sessionOutcomeCompleted,
    'cancelled' when request.didNotHappen => l10n.sessionOutcomeDidNotHappen,
    'cancelled' when request.closeReason == 'unpaid' =>
      l10n.sessionOutcomeNotPaid,
    'cancelled' when request.submittedAt == null => l10n.sessionOutcomeNotSent,
    _ => l10n.sessionOutcomeCancelled,
  };
}

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

  /// What a session costs this person ([TherapyPriceQuote]). Never fails:
  /// before migration 0031, offline, or signed out it's
  /// [TherapyPriceQuote.fallback], today's price.
  Future<TherapyPriceQuote> fetchPriceQuote() async {
    if (_client.auth.currentUser == null) return TherapyPriceQuote.fallback;
    return readPriceQuote(() => _client.rpc('therapy_price_quote'));
  }

  /// Sets the country this person's sessions are priced for (an ISO code)
  /// and returns the new quote. Once they've paid for a session the
  /// database refuses a different country with a [PostgrestException]
  /// (P0001) whose message is written for people.
  Future<TherapyPriceQuote> setPriceCountry(String country) async {
    if (_client.auth.currentUser == null) throw StateError('Not signed in');
    final data = await _client.rpc(
      'therapy_set_country',
      params: {'p_country': country.toUpperCase()},
    );
    return TherapyPriceQuote.fromJson(Map<String, dynamic>.from(data as Map));
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

  /// Opens a Paystack checkout for this session and returns the page to
  /// pay on, or null when the session turns out to be paid already.
  Future<Uri?> startCheckout(String requestId) async {
    final data = await invokeSessionFunction(
      _client,
      'paystack-payment',
      requestId,
      extra: {'action': 'start'},
    );
    final url = data['authorization_url'];
    return url is String ? Uri.parse(url) : null;
  }

  /// Asks the server to find the Paystack payment for this session.
  Future<void> confirmPayment(String requestId) async {
    await invokeSessionFunction(_client, 'paystack-payment', requestId);
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
  String requestId, {
  Map<String, Object?> extra = const {},
}) async {
  if (client.auth.currentUser == null) throw StateError('Not signed in');
  try {
    final response = await client.functions
        .invoke(function, body: {'request_id': requestId, ...extra});
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
