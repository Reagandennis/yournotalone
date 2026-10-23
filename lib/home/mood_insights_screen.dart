import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../billing/pricing_copy.dart';
import '../brand.dart';
import '../practice/feeling_store.dart';
import '../practice/practice_repository.dart';
import 'home_ui.dart';
import 'mood_insights.dart';
import 'mood_repository.dart';

/// Opens the insights for Premium members; shows the upgrade sheet
/// otherwise. Every way in goes through here.
void openMoodInsights(BuildContext context, {required String source}) {
  if (!isPremiumUser()) {
    showUpgradeSheet(
      context,
      source: source,
      title: 'Insights are part of Premium',
      message:
          'See how your practice, your week and your moods connect — '
          'and $introOffer.',
    );
    return;
  }
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const MoodInsightsScreen()));
}

/// What the check-ins, practice and post-session answers say together.
/// Premium only.
class MoodInsightsScreen extends StatefulWidget {
  const MoodInsightsScreen({
    super.key,
    this.moods,
    this.practice,
    this.feelings,
  });

  /// Injectable for tests.
  final MoodRepository? moods;
  final PracticeRepository? practice;
  final Future<List<FeelingRecord>> Function()? feelings;

  @override
  State<MoodInsightsScreen> createState() => _MoodInsightsScreenState();
}

class _MoodInsightsScreenState extends State<MoodInsightsScreen> {
  late final Future<List<Insight>> _insights = _load();

  Future<List<Insight>> _load() async {
    final results = await Future.wait([
      (widget.moods ?? MoodRepository())
          .fetchHistory(days: 90)
          .catchError((_) => <MoodEntry>[]),
      (widget.practice ?? PracticeRepository())
          .fetchRecent(days: 90)
          .catchError((_) => <PracticeSession>[]),
      (widget.feelings ?? FeelingStore.instance.recent)(),
    ]);
    return moodInsights(
      moods: results[0] as List<MoodEntry>,
      sessions: results[1] as List<PracticeSession>,
      feelings: results[2] as List<FeelingRecord>,
      now: DateTime.now(),
    );
  }

  Widget _card(Insight insight) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.tint(insight.color, 0.07),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.chip, shape: BoxShape.circle),
              child: Icon(
                insight.icon,
                size: 20,
                color: c.accent(insight.color),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.detail,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textMuted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: FutureBuilder<List<Insight>>(
              future: _insights,
              builder: (context, snapshot) => ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: BackChip(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your insights',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const PillarStripe(),
                  const SizedBox(height: 14),
                  Text(
                    'From your check-ins, practice and how sessions left '
                    'you, over the last 90 days.',
                    style: TextStyle(
                      fontSize: 14,
                      color: c.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.data?.isEmpty ?? true)
                    Text(
                      'Not enough to go on yet. Check in each day and '
                      'answer the question at the end of a session — '
                      'insights start appearing within a week or two.',
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textMuted,
                        height: 1.5,
                      ),
                    )
                  else
                    for (final insight in snapshot.data!) _card(insight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
