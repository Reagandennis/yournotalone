import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_index.dart';

/// The needs a person picked as their reasons for using the app (at
/// onboarding, or later in Settings), stored on their profile as
/// `goals: ['sleep', 'anxious']`.
const goalKey = 'goals';

/// What onboarding and Settings offer as reasons, in that order.
const goalChoices = [
  Need.sleep,
  Need.anxious,
  Need.stressed,
  Need.low,
  Need.urges,
  Need.focus,
];

/// [user] is only for tests; the app always reads the signed-in user.
Set<Need> userGoals([User? user]) {
  final account = user ?? Supabase.instance.client.auth.currentUser;
  final raw = account?.userMetadata?[goalKey];
  if (raw is! List) return const {};
  final byName = Need.values.asNameMap();
  return {
    for (final name in raw)
      if (byName[name] != null) byName[name]!,
  };
}

/// Saves the goals on the profile. Never throws: they only shape what's
/// suggested.
Future<void> saveGoals(Set<Need> goals) async {
  try {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {
          goalKey: [for (final g in goals) g.name],
        },
      ),
    );
  } catch (_) {
    // Suggestions just fall back to the defaults.
  }
}

/// [Need.values] with the person's goals first, keeping the usual order
/// otherwise.
List<Need> needsInGoalOrder(Set<Need> goals) => [
  for (final n in Need.values)
    if (goals.contains(n)) n,
  for (final n in Need.values)
    if (!goals.contains(n)) n,
];
