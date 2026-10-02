import 'package:flutter/material.dart';

import '../brand.dart';
import '../therapy/session_format.dart';
import '../therapy/session_widgets.dart';
import '../therapy/therapy_repository.dart';
import 'care_repository.dart';
import 'care_widgets.dart';
import 'request_detail_screen.dart';
import 'therapist_editor_screen.dart';

enum _RequestFilter { toMatch, upcoming, past }

/// The care team's desk: every therapy request, from waiting to be matched
/// through to finished, and the therapists they're matched with.
class CareDashboardScreen extends StatefulWidget {
  const CareDashboardScreen({super.key, this.repository, this.clock});

  final CareRepository? repository;

  /// Injectable so tests control how long requests have been waiting.
  final DateTime Function()? clock;

  @override
  State<CareDashboardScreen> createState() => _CareDashboardScreenState();
}

class _CareDashboardScreenState extends State<CareDashboardScreen> {
  late final _repo = widget.repository ?? CareRepository();
  List<AdminTherapyRequest>? _requests;
  List<AdminTherapist> _therapists = const [];
  String? _error;
  var _filter = _RequestFilter.toMatch;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await _repo.listRequests();
      final therapists = await _repo.listTherapists();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _therapists = therapists;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            careErrorMessage(e, 'Couldn\'t load — check your connection.'));
      }
    }
  }

  Future<void> _openRequest(AdminTherapyRequest item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(item: item, repository: _repo),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openTherapist(AdminTherapist? therapist) async {
    final feedback = [
      if (therapist != null)
        for (final item in _requests ?? const <AdminTherapyRequest>[])
          if (item.request.therapistId == therapist.profile.id &&
              item.clientRating != null)
            item,
    ];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TherapistEditorScreen(
          therapist: therapist,
          repository: _repo,
          feedback: feedback,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final requests = _requests;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Care team'),
          bottom: TabBar(
            labelColor: c.ink,
            unselectedLabelColor: c.textMuted,
            indicatorColor: c.ink,
            labelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Requests'), Tab(text: 'Therapists')],
          ),
        ),
        body: requests == null
            ? _error != null
                ? LoadFailed(
                    message: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      _load();
                    },
                  )
                : const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [_requestsTab(requests), _therapistsTab()],
              ),
      ),
    );
  }

  Widget _requestsTab(List<AdminTherapyRequest> all) {
    final c = context.brand;
    // Oldest first: whoever has waited longest is next.
    final toMatch = [
      for (final item in all)
        if (item.request.isPending) item,
    ]..sort((a, b) => a.request.createdAt.compareTo(b.request.createdAt));
    final upcoming = [
      for (final item in all)
        if (item.request.isConfirmed) item,
    ]..sort((a, b) => (a.request.scheduledAt ?? a.request.createdAt)
        .compareTo(b.request.scheduledAt ?? b.request.createdAt));
    final past = [
      for (final item in all)
        if (!item.request.isActive) item,
    ];
    final (shown, empty) = switch (_filter) {
      _RequestFilter.toMatch => (toMatch, 'Nobody is waiting to be matched.'),
      _RequestFilter.upcoming => (upcoming, 'No sessions booked.'),
      _RequestFilter.past =>
        (past, 'Finished and cancelled sessions show up here.'),
    };
    final now = _now();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (filter, label, count) in [
                (_RequestFilter.toMatch, 'To match', toMatch.length),
                (_RequestFilter.upcoming, 'Upcoming', upcoming.length),
                (_RequestFilter.past, 'Past', past.length),
              ])
                ChoicePill(
                  label: '$label · $count',
                  selected: _filter == filter,
                  onTap: () => setState(() => _filter = filter),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                empty,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textMuted),
              ),
            )
          else
            for (final item in shown)
              _RequestTile(
                item: item,
                now: now,
                onTap: () => _openRequest(item),
              ),
        ],
      ),
    );
  }

  Widget _therapistsTab() {
    final c = context.brand;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          ElevatedButton.icon(
            onPressed: () => _openTherapist(null),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add a therapist'),
          ),
          const SizedBox(height: 16),
          if (_therapists.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                'No therapists yet. Add one to start matching requests.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.textMuted),
              ),
            )
          else
            for (final therapist in _therapists)
              _TherapistTile(
                therapist: therapist,
                onTap: () => _openTherapist(therapist),
              ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.item,
    required this.now,
    required this.onTap,
  });

  final AdminTherapyRequest item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final request = item.request;
    var lineColor = c.textMuted;
    final String line;
    if (request.isPending) {
      final hours = now.difference(request.createdAt).inHours;
      line = hours < 1
          ? 'Asked just now'
          : hours < 48
              ? 'Waiting ${hours}h'
              : 'Waiting ${hours ~/ 24} days';
      // Clients are told to expect a match within a day.
      if (hours >= 20) lineColor = c.red;
    } else if (request.isConfirmed && request.scheduledAt != null) {
      final ended = request.hasElapsedAt(now);
      line = '${item.therapistName ?? 'Therapist'} · '
          '${formatDateTime(request.scheduledAt!)}'
          '${ended ? ' · Not finished' : ''}';
      // Someone should tap Finish before the server closes it out.
      if (ended) lineColor = c.red;
    } else {
      line = '${sessionOutcomeLabel(request)} · '
          '${formatDate(request.scheduledAt ?? request.createdAt)}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.clientLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.topic,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        line,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: lineColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    paymentBadge(request, refunded: item.refundedAt != null),
                    if (request.isCompleted && item.clientRating != null) ...[
                      const SizedBox(height: 6),
                      StarRow(rating: item.clientRating!.toDouble(), size: 12),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TherapistTile extends StatelessWidget {
  const _TherapistTile({required this.therapist, required this.onTap});

  final AdminTherapist therapist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final profile = therapist.profile;
    final rating = profile.ratingAverage;
    final stats = [
      '${therapist.upcomingSessions} upcoming',
      '${therapist.completedSessions} completed',
      if (rating != null)
        '★ ${rating.toStringAsFixed(1)} (${profile.ratingCount})',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                TherapistAvatar(
                  name: profile.fullName,
                  photoUrl: profile.photoUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                          ),
                          if (!profile.active) ...[
                            const SizedBox(width: 6),
                            const StatusBadge('Inactive'),
                          ],
                        ],
                      ),
                      if (profile.title != null)
                        Text(
                          profile.title!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.textMuted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        stats,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                        ),
                      ),
                      if (!therapist.hasAccount) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Not signed in yet — ${therapist.email}',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: c.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
