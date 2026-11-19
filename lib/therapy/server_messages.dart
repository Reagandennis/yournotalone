import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';

/// The database's refusals are written for people, in English
/// (`raise exception … using errcode = 'P0001'`). These are the ones a
/// client can meet, in their language; anything else is shown as written,
/// which is still better than a generic error.
String serverMessage(AppLocalizations l10n, PostgrestException error) {
  final message = error.message;
  bool starts(String text) => message.startsWith(text);
  if (starts('You already have a session on the way')) {
    return l10n.therapyServerOpenSession;
  }
  if (starts('That\'s as many requests as we can take')) {
    return l10n.therapyServerDailyLimit;
  }
  if (starts('We\'re getting a lot of requests')) return l10n.therapyServerBusy;
  if (starts('Sessions can be cancelled in the app up to 24 hours')) {
    return l10n.therapyServerLateCancel;
  }
  if (starts('This session has already started')) {
    return l10n.therapyServerStarted;
  }
  if (starts('Your country is set from your first session')) {
    return l10n.therapyServerCountryLocked;
  }
  if (starts('Your country comes from')) {
    return l10n.therapyServerCountryDetected;
  }
  return message;
}
