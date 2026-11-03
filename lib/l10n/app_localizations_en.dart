// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get somethingWentWrongTitle => 'Something went wrong here.';

  @override
  String get somethingWentWrongBody =>
      'Go back and try again — nothing you saved is affected.';

  @override
  String get appearanceSystem => 'Match my phone';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageSystemDefaultHint => 'Follows your phone\'s language.';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonBack => 'Back';

  @override
  String get commonStop => 'Stop';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonChange => 'Change';

  @override
  String get commonDelete => 'Delete';

  @override
  String onboardingWelcomeTitle(String name) {
    return 'Welcome, $name';
  }

  @override
  String get onboardingWelcomeFriend => 'friend';

  @override
  String get onboardingWelcomeStory =>
      'It\'s Greek for \"you\'re not alone\" — the promise this app is built on. Like the four pillars in our logo, support stands strongest side by side. Whatever you\'re carrying, from today you don\'t carry it by yourself.';

  @override
  String get onboardingFeatureMoodTitle => 'Mood tracking & journaling';

  @override
  String get onboardingFeatureMoodBenefit =>
      'Check in with yourself daily and put feelings into words, in a space that\'s completely private.';

  @override
  String get onboardingFeatureMeditationTitle =>
      'Guided meditations & breathing';

  @override
  String get onboardingFeatureMeditationBenefit =>
      'Short guided sessions that steady your breath and quiet a racing mind.';

  @override
  String get onboardingFeatureSoundsTitle => 'Wellbeing sounds';

  @override
  String get onboardingFeatureSoundsBenefit =>
      'Soundscapes for focus, sleep, and calming down — whenever you need to reset.';

  @override
  String get onboardingFeatureInsightsTitle => 'Progress insights & reminders';

  @override
  String get onboardingFeatureInsightsBenefit =>
      'See your patterns over time and get gentle nudges that keep you going.';

  @override
  String get onboardingFeatureRecoveryTitle => 'Addiction recovery tools';

  @override
  String get onboardingFeatureRecoveryBenefit =>
      'Practical resources for fighting addiction — one day at a time.';

  @override
  String get onboardingFeatureTherapyTitle => 'Real human therapy';

  @override
  String get onboardingFeatureTherapyBenefit =>
      'Talk with a licensed therapist in private one-on-one sessions, right from the app.';

  @override
  String get onboardingFeaturesTitle => 'Here to hold you up';

  @override
  String get onboardingFeaturesIntro =>
      'A quick look at what\'s inside — and how each piece helps you feel better, day by day.';

  @override
  String get onboardingCheckinSteady => 'Doing okay';

  @override
  String get onboardingCheckinSteadyDetail =>
      'I\'m here to keep my balance and build good habits.';

  @override
  String get onboardingCheckinStressed => 'Stressed or low lately';

  @override
  String get onboardingCheckinStressedDetail =>
      'Work, life, or my mood has been weighing on me.';

  @override
  String get onboardingCheckinStruggling => 'Struggling';

  @override
  String get onboardingCheckinStrugglingDetail =>
      'It\'s been heavy for a while and I could use support.';

  @override
  String get onboardingCheckinDarkPlace => 'In a dark place';

  @override
  String get onboardingCheckinDarkPlaceDetail =>
      'I\'m going through something serious right now.';

  @override
  String get onboardingCheckinTitle => 'How are you feeling these days?';

  @override
  String get onboardingCheckinIntro =>
      'This helps us point you to the right kind of support first. It stays private, and you can change it anytime.';

  @override
  String get onboardingGoalsTitle => 'What would help most?';

  @override
  String get onboardingGoalsHint => 'Pick any. We\'ll put these first for you.';

  @override
  String get onboardingNotificationsSessionsTitle => 'Your therapy sessions';

  @override
  String get onboardingNotificationsSessionsDetail =>
      'When you\'re matched, if the time moves, and ten minutes before the call — so a paid session is never missed.';

  @override
  String get onboardingNotificationsRemindersTitle => 'Reminders you choose';

  @override
  String get onboardingNotificationsRemindersDetail =>
      'A morning check-in, evening pages, a wind-down. Each one is a switch in Settings; none is on until you say.';

  @override
  String get onboardingNotificationsNothingElseTitle => 'Nothing else';

  @override
  String get onboardingNotificationsNothingElseDetail =>
      'No marketing, no streak guilt, no \"we miss you\". If it isn\'t about your care, it isn\'t sent.';

  @override
  String get onboardingNotificationsTurnOn => 'Turn on notifications';

  @override
  String get onboardingNotificationsMaybeLater => 'Maybe later';

  @override
  String get onboardingNotificationsTitle => 'Don\'t miss what matters';

  @override
  String get onboardingNotificationsIntro =>
      'Your phone will ask once. Here\'s exactly what a yes means.';

  @override
  String get onboardingTherapyCrisisTrailing =>
      ' This app can\'t replace emergency care.';

  @override
  String get onboardingTherapyYes => 'I\'d like that';

  @override
  String get onboardingTherapyNo => 'Not right now';

  @override
  String get onboardingTherapyTitle => 'You don\'t have to do this alone';

  @override
  String get onboardingTherapyIntro =>
      'Some seasons are too heavy to carry with an app alone — and that\'s exactly why we work with real people. yournotalone offers private one-on-one sessions with licensed therapists, right from here.';

  @override
  String onboardingTherapyPrice(String price) {
    return 'A real therapist, $price a session';
  }

  @override
  String get onboardingTherapyHowItWorks =>
      'One session at a time, no subscription. You pay when you book, from Talk to a therapist on your Home screen, and our care team matches you within a day.';

  @override
  String get billingIntroOffer => 'you can try it free first';

  @override
  String get billingIntroOfferSentence =>
      'Every plan starts with a free trial.';

  @override
  String get billingErrorNotAllowed =>
      'Purchases aren\'t allowed on this device.';

  @override
  String get billingErrorPending =>
      'Your payment is pending — premium unlocks once it clears.';

  @override
  String get billingErrorNetwork =>
      'Network trouble — check your connection and try again.';

  @override
  String get billingErrorAlreadyOwned =>
      'This store account already has a subscription. Sign in with the account you bought it with, or contact support.';

  @override
  String get billingErrorGeneric =>
      'The purchase didn\'t go through. Please try again.';

  @override
  String get billingTrialChannelName => 'Subscription';

  @override
  String get billingTrialChannelDescription =>
      'A heads-up before a free trial ends';

  @override
  String get billingStoreAppStore => 'the App Store';

  @override
  String get billingStoreGooglePlay => 'Google Play';

  @override
  String get billingTrialReminderTitle => 'Your Premium trial ends soon';

  @override
  String billingTrialReminderBody(String date, String store) {
    return 'From $date it continues at the plan price. Keep it, or cancel any time in $store.';
  }

  @override
  String get paywallHardWeeksHeadline => 'Support for the hard weeks';

  @override
  String get paywallHardWeeksDetail =>
      'Somewhere to put the day down, every day: guided meditations for the nights that won\'t settle, a journal that keeps up, and a record of how the weeks actually go — so the next hard one is easier to see coming.';

  @override
  String get paywallStressedHeadline => 'Somewhere to put it down';

  @override
  String get paywallStressedDetail =>
      'Ten minutes that are yours: breathing for the middle of a bad afternoon, sounds to fall asleep to, and a journal that keeps up — with a record of how the weeks actually go.';

  @override
  String get paywallSteadyHeadline => 'Keep the good days coming';

  @override
  String get paywallSteadyDetail =>
      'The habits that keep you steady, all in one place: every meditation and sound, an unlimited journal, and a record of how the weeks actually go.';

  @override
  String billingTrialDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String billingTrialWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String billingTrialMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String billingTrialYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get billingSuffixWeek => '/week';

  @override
  String get billingSuffixMonth => '/month';

  @override
  String get billingSuffixYear => '/year';

  @override
  String get paywallTimelineToday => 'Today';

  @override
  String get paywallTimelineTodayDetail =>
      'Full access to everything in Premium.';

  @override
  String paywallTimelineDay(int day) {
    return 'Day $day';
  }

  @override
  String get paywallTimelineReminderDetail =>
      'We remind you that the trial is about to end.';

  @override
  String paywallTimelineChargeDetail(String price) {
    return '$price starts. Cancel any time before and pay nothing.';
  }

  @override
  String get paywallRowMeditations => 'Guided meditations & breathing';

  @override
  String get paywallRowJournaling => 'Journaling';

  @override
  String get paywallRowMoodHistory => 'Mood history & progress';

  @override
  String get paywallRowSounds => 'Wellbeing sounds — focus, sleep, calm';

  @override
  String get paywallRowPrompts => 'Journal prompts';

  @override
  String get paywallRowRecovery => 'Recovery tracking & insights';

  @override
  String get paywallRowCheckins => 'Daily mood check-ins';

  @override
  String get paywallRowReminders => 'Daily reminders';

  @override
  String get paywallRowUrgeSurfing => 'Urge surfing, any time';

  @override
  String get paywallCellUnlimited => 'Unlimited';

  @override
  String paywallCellFree(int count) {
    return '$count free';
  }

  @override
  String paywallCellAll(int count) {
    return 'All $count';
  }

  @override
  String paywallCellEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get paywallAlreadyPremium =>
      'You already have Premium — everything is unlocked.';

  @override
  String get paywallPurchasesUnavailable =>
      'Purchases aren\'t available on this device yet — you can upgrade later from Settings.';

  @override
  String get paywallNotActivated =>
      'Purchase completed, but premium didn\'t activate. Try \"Restore purchases\", or contact support.';

  @override
  String get paywallNoPurchases => 'No previous purchases found.';

  @override
  String get paywallPlanWeekly => 'Weekly';

  @override
  String get paywallPlanMonthly => 'Monthly';

  @override
  String get paywallPlanYearly => 'Yearly';

  @override
  String get paywallPerWeek => 'per week';

  @override
  String get paywallPerMonth => 'per month';

  @override
  String get paywallPerYear => 'per year';

  @override
  String get paywallTrustTherapists => 'Licensed therapists';

  @override
  String get paywallTrustPrivate => 'Private by design';

  @override
  String get paywallTrustCancel => 'Cancel anytime';

  @override
  String paywallSave(int percent) {
    return 'SAVE $percent%';
  }

  @override
  String get paywallColumnFree => 'Free';

  @override
  String get paywallColumnPremium => 'Premium';

  @override
  String get paywallShowLess => 'Show less';

  @override
  String get paywallSeeEverything => 'See everything';

  @override
  String get paywallTerms => 'Terms of Use';

  @override
  String get paywallPrivacy => 'Privacy Policy';

  @override
  String paywallTryFreeFor(String trial) {
    return 'Try free for $trial';
  }

  @override
  String paywallStartPremiumPrice(String price) {
    return 'Start Premium — $price';
  }

  @override
  String get paywallStartPremium => 'Start Premium';

  @override
  String paywallThenPriceCancelAnytime(String price) {
    return 'then $price · cancel anytime';
  }

  @override
  String paywallPriceCancelAnytime(String price) {
    return '$price · cancel anytime';
  }

  @override
  String get paywallCancelAnytime => 'Cancel anytime';

  @override
  String get paywallContinueFree => 'Continue with Free';

  @override
  String get paywallMaybeLater => 'Maybe later';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallTherapyNote =>
      'Therapy sessions are available to everyone and booked separately.';

  @override
  String get authOr => 'or';

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get authEmailRequired => 'Enter your email';

  @override
  String get authEmailInvalid => 'Enter a valid email address';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String authPasswordTooShort(int count) {
    return 'Use at least $count characters';
  }

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authGoogleUnavailable =>
      'Google sign-in isn\'t available on this device.';

  @override
  String get authGoogleNoToken =>
      'Google didn\'t return a sign-in token. Please try again.';

  @override
  String get authGoogleInterrupted =>
      'Google couldn\'t finish signing you in. Please try again, or use your email instead.';

  @override
  String get authGoogleMisconfigured =>
      'Google sign-in isn\'t set up correctly for this app.';

  @override
  String get authGoogleWrongAccount =>
      'That\'s a different Google account than the one expected.';

  @override
  String get authGoogleFailed =>
      'Couldn\'t sign in with Google. Please try again.';

  @override
  String get authAppleUnavailable =>
      'Sign in with Apple isn\'t available on this device.';

  @override
  String get authAppleNoToken =>
      'Apple didn\'t return a sign-in token. Please try again.';

  @override
  String get authAppleNoAccount =>
      'Couldn\'t sign in with Apple. Check that this device is signed in to an Apple Account in Settings, then try again.';

  @override
  String get authAppleFailed =>
      'Couldn\'t sign in with Apple. Please try again, or use your email instead.';

  @override
  String get authNewHere => 'New here?';

  @override
  String get authCreateAnAccount => 'Create an account';

  @override
  String get authLoginTitle => 'Welcome back';

  @override
  String get authLoginSubtitle =>
      'You are not alone. Log in to pick up right where you left off.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authLogIn => 'Log in';

  @override
  String get authConfirmEmailTitle => 'Confirm your email';

  @override
  String get authConfirmEmailSubtitle =>
      'We sent a confirmation link to verify it\'s really you. Tap the link, then come back and log in.';

  @override
  String get authBackToLogIn => 'Back to log in';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authSignupTitle => 'Create your account';

  @override
  String get authSignupSubtitle =>
      'A calmer mind starts here. It only takes a minute.';

  @override
  String get authFullName => 'Full name';

  @override
  String get authNameRequired => 'Enter your name';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authPasswordsDontMatch => 'Passwords don\'t match';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String authSignupAgreement(String terms, String privacy) {
    return 'By creating an account you agree to our $terms and $privacy.';
  }

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authPasswordUpdated => 'Password updated.';

  @override
  String get authNewPasswordTitle => 'Choose a new password';

  @override
  String get authNewPasswordSubtitle =>
      'You\'re verified — set the password you\'ll use to log in from now on.';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authSavePassword => 'Save password';

  @override
  String get authCheckInboxTitle => 'Check your inbox';

  @override
  String get authCheckInboxSubtitle =>
      'If an account exists for that address, the reset link is already on its way.';

  @override
  String get authTryAnotherEmail => 'Try another email';

  @override
  String get authResetTitle => 'Reset password';

  @override
  String get authResetSubtitle =>
      'Enter the email you signed up with and we\'ll send you a link to set a new password.';

  @override
  String get authSendResetLink => 'Send reset link';

  @override
  String get shellTabHome => 'Home';

  @override
  String get shellTabExplore => 'Explore';

  @override
  String get shellTabSettings => 'Settings';

  @override
  String get profileCameraUnavailable =>
      'The camera isn\'t available right now.';

  @override
  String get profileLibraryUnavailable => 'Couldn\'t open your photo library.';

  @override
  String get profileChooseFromLibrary => 'Choose from library';

  @override
  String get profileTakePhoto => 'Take a photo';

  @override
  String get profileRemovePhoto => 'Remove photo';

  @override
  String get profileUpdated => 'Profile updated.';

  @override
  String profilePhotoSaveFailed(String error) {
    return 'Couldn\'t save your photo: $error';
  }

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileChangePhoto => 'Change photo';

  @override
  String get profileAddPhoto => 'Add a photo';

  @override
  String get profileYourName => 'Your name';

  @override
  String get profileEmailFixed => 'Your email can\'t be changed here.';

  @override
  String get profileSaveChanges => 'Save changes';

  @override
  String get therapyPaymentMethods => 'M-Pesa or Airtel Money';

  @override
  String get therapyCancellationPolicy =>
      'Cancel in the app up to 24 hours before your session for a full refund. A session cancelled later than that, or not joined, isn\'t refunded.';

  @override
  String get therapyTopicAnxietyStress => 'Anxiety & stress';

  @override
  String get therapyTopicLowMood => 'Low mood';

  @override
  String get therapyTopicRelationships => 'Relationships';

  @override
  String get therapyTopicGriefLoss => 'Grief & loss';

  @override
  String get therapyTopicAddictionRecovery => 'Addiction & recovery';

  @override
  String get therapyTopicNotSure => 'Not sure yet';

  @override
  String get sessionErrorTooEarly => 'The session isn\'t open yet.';

  @override
  String sessionErrorTooEarlyAt(String time) {
    return 'You can join from $time — 10 minutes before the start.';
  }

  @override
  String get sessionErrorOver => 'This session\'s time has passed.';

  @override
  String get sessionErrorPaymentRequired =>
      'This session needs to be paid for before you can join.';

  @override
  String get sessionErrorNotConfirmed => 'This session isn\'t confirmed yet.';

  @override
  String get sessionErrorNotFound => 'We couldn\'t find that session.';

  @override
  String get sessionErrorNoPaymentFound =>
      'We couldn\'t find your payment yet. If you were charged, try again in a minute.';

  @override
  String get sessionErrorNotPayable =>
      'This request can\'t be paid for any more — start a new one.';

  @override
  String get sessionErrorCheckoutFailed =>
      'We couldn\'t open the payment page — please try again in a moment.';

  @override
  String get sessionErrorEmailRequired =>
      'Add an email address to your account to pay for a session.';

  @override
  String get sessionErrorNotConfigured =>
      'This isn\'t switched on yet. Please contact us.';

  @override
  String get sessionErrorSignedOut =>
      'You\'ve been signed out. Please log in again.';

  @override
  String get sessionErrorGeneric =>
      'Something went wrong — check your connection and try again.';

  @override
  String get sessionOutcomeMissed => 'Missed';

  @override
  String get sessionOutcomeCompleted => 'Completed';

  @override
  String get sessionOutcomeDidNotHappen => 'Didn\'t happen';

  @override
  String get sessionOutcomeNotPaid => 'Not paid';

  @override
  String get sessionOutcomeNotSent => 'Not sent';

  @override
  String get sessionOutcomeCancelled => 'Cancelled';

  @override
  String get therapySlotWeekdayMornings => 'Weekday mornings';

  @override
  String get therapySlotWeekdayAfternoons => 'Weekday afternoons';

  @override
  String get therapySlotWeekdayEvenings => 'Weekday evenings';

  @override
  String get therapySlotWeekends => 'Weekends';

  @override
  String get therapyRequestNoCharge =>
      'Your request is with our care team — there\'s no charge for your sessions.';

  @override
  String get therapyNoteTooLong =>
      'That note is too long — please keep it under 1000 characters.';

  @override
  String get therapyRequestSendFailed =>
      'Couldn\'t send your request — check your connection.';

  @override
  String get therapyDiscardTitle => 'Discard this request?';

  @override
  String get therapyDiscardBody =>
      'Nothing has been paid, so there\'s nothing to refund. You can start again whenever you like.';

  @override
  String get therapyDiscardAction => 'Discard';

  @override
  String get therapyCancelSessionTitle => 'Cancel this session?';

  @override
  String therapyCancelSessionBody(String price) {
    return 'We\'ll let your therapist know and refund your $price in full, since it\'s more than 24 hours away. You can book again whenever you\'re ready.';
  }

  @override
  String get therapyCancelSessionAction => 'Cancel session';

  @override
  String get therapyCancelRequestTitle => 'Cancel this request?';

  @override
  String therapyCancelRequestBody(String price) {
    return 'We haven\'t matched you yet, so your $price is refunded in full. You can book again whenever you\'re ready.';
  }

  @override
  String get therapyCancelRequestAction => 'Cancel request';

  @override
  String get therapyKeepIt => 'Keep it';

  @override
  String get therapyCancelFailed => 'Couldn\'t cancel — check your connection.';

  @override
  String get therapyPaymentReceivedRequest =>
      'Payment received — your request is with our care team and your receipt is on its way by email.';

  @override
  String get therapyPaymentReceived =>
      'Payment received — your receipt is on its way by email.';

  @override
  String get therapyPaymentPending =>
      'Your payment is going through. If it isn\'t confirmed in a minute, tap \"Check payment\".';

  @override
  String get therapyPaymentUnavailable =>
      'We couldn\'t open the payment page on this device — please try again later.';

  @override
  String get therapyPaymentFailed =>
      'The payment didn\'t go through. Please try again.';

  @override
  String get therapyPaymentFoundRequest =>
      'Payment found — your request is with our care team.';

  @override
  String get therapyPaymentFound => 'Payment found — you\'re all set.';

  @override
  String get therapyCheckFailed => 'Couldn\'t check — try again in a moment.';

  @override
  String get therapyYourTherapist => 'Your therapist';

  @override
  String get therapyRateTitle => 'How was your session?';

  @override
  String get therapyRateSubtitle => 'Your rating helps us match people well.';

  @override
  String therapyRateSubtitleNamed(String name) {
    return 'Your rating helps us match people well. $name never sees it on its own — only an average.';
  }

  @override
  String get therapyRateComment =>
      'Anything you\'d like to tell us? (optional)';

  @override
  String get therapyRateFailed =>
      'Couldn\'t send your rating — check your connection.';

  @override
  String get therapyRateThanks => 'Thank you — that helps.';

  @override
  String get therapyNotesFromTherapist => 'Notes from your therapist';

  @override
  String therapyNotesFrom(String name) {
    return 'Notes from $name';
  }

  @override
  String get therapyNoNotes => 'No notes for this session.';

  @override
  String get therapyRateSession => 'Rate this session';

  @override
  String get therapyYouRatedIt => 'You rated it';

  @override
  String get therapyChangeRating => 'Change your rating';

  @override
  String therapyStepNumbered(int number, String title) {
    return '$number. $title';
  }

  @override
  String get therapyStepPayTitle => 'Tell us what you need, and pay';

  @override
  String therapyStepPayDetail(String price) {
    return 'A topic, the times that suit you, and $price — paid securely in the app. Nothing is sent until it\'s paid.';
  }

  @override
  String get therapyStepMatchTitle => 'We match you';

  @override
  String get therapyStepMatchDetail =>
      'A licensed therapist and a time, usually within a day.';

  @override
  String get therapyStepTalkTitle => 'You talk';

  @override
  String get therapyStepTalkDetail =>
      'A private video call, right here in the app.';

  @override
  String get therapyPointLicensedTitle => 'Licensed therapists';

  @override
  String get therapyPointLicensedDetail =>
      'Qualified practitioners, not volunteers or chatbots.';

  @override
  String get therapyPointPrivateTitle => 'Private';

  @override
  String get therapyPointPrivateDetail =>
      'What you say in a session stays between you and them. Calls aren\'t recorded.';

  @override
  String get therapyPointOneAtATimeTitle => 'One session at a time';

  @override
  String get therapyPointOneAtATimeDetail =>
      'No subscription. Cancel up to 24 hours before for a full refund — after that, or if you don\'t join, the session isn\'t refunded.';

  @override
  String therapyOfferTitle(String price) {
    return 'Sessions are $price, paid when you book';
  }

  @override
  String therapyOfferDetail(String methods, String charge) {
    return 'Pay securely by $methods through Paystack (charged as $charge) and your request goes straight to our care team. You get a receipt by email. No subscription.';
  }

  @override
  String get therapyFocusQuestion => 'What would you like to focus on?';

  @override
  String get therapyWhenQuestion => 'When could you meet?';

  @override
  String get therapyNoteLabel =>
      'Anything your therapist should know? (optional)';

  @override
  String therapyPayAndRequest(String price) {
    return 'Pay $price and request a session';
  }

  @override
  String therapyBookingFootnote(String policy) {
    return 'We\'ll match you with a licensed therapist and a time, usually within a day, and email you when your session is booked. $policy';
  }

  @override
  String get therapyPriceFirstFree => 'First session — free';

  @override
  String therapyPricePaid(String price) {
    return '$price — paid, receipt emailed';
  }

  @override
  String get therapyPriceWaived => 'No charge for this session';

  @override
  String therapyPriceToSend(String price) {
    return '$price — pay to send your request';
  }

  @override
  String therapyPriceNeeded(String price) {
    return '$price — payment needed';
  }

  @override
  String get therapyAlmostThereTitle => 'Almost there';

  @override
  String get therapyAlmostThereDetail =>
      'Your request is saved but hasn\'t reached our care team yet. It\'s sent the moment your session is paid for.';

  @override
  String get therapyReceivedTitle => 'Request received';

  @override
  String get therapyReceivedDetail =>
      'We\'re finding the right licensed therapist for you — usually within a day. We\'ll email you when your session is booked.';

  @override
  String get therapyMatchedTitle => 'You\'re matched';

  @override
  String get therapyMatchedDetail =>
      'Pay for your session to confirm your place.';

  @override
  String get therapyConfirmedTitle => 'Session confirmed';

  @override
  String get therapyConfirmedDetail =>
      'Everything\'s set. Join right here when it\'s time.';

  @override
  String get therapyNotificationsOffReminder =>
      'Notifications are off, so you won\'t get the ten-minute reminder for this session.';

  @override
  String get therapyNotificationsOffMatch =>
      'Notifications are off, so you won\'t hear when you\'re matched.';

  @override
  String therapyWhenAndLength(String when, int minutes) {
    return '$when · $minutes min';
  }

  @override
  String get therapyLateCancelNote =>
      'Your session is less than 24 hours away, so it can no longer be cancelled here. If you can\'t make it, reply to your booking email — a missed or late-cancelled session isn\'t refunded.';

  @override
  String get therapyPaymentVerifying => 'Your payment is being verified';

  @override
  String therapyPayToSend(String price) {
    return '$price to send your request';
  }

  @override
  String therapyPayToConfirm(String price) {
    return '$price to confirm your session';
  }

  @override
  String get therapyPaymentVerifyingDetail =>
      'Paystack has your payment. Don\'t pay again — your request goes through as soon as it\'s found.';

  @override
  String therapyPayDetailRequest(String methods, String charge, String policy) {
    return 'Pay securely by $methods through Paystack (charged as $charge) and your request goes straight to our care team, with a receipt by email. $policy';
  }

  @override
  String therapyPayDetailSession(String methods, String charge) {
    return 'Pay securely by $methods through Paystack (charged as $charge). The Join button unlocks as soon as it\'s paid.';
  }

  @override
  String get therapyCheckPayment => 'Check payment';

  @override
  String therapyPayPrice(String price) {
    return 'Pay $price';
  }

  @override
  String get therapyAlreadyPaid => 'Already paid? Check again';

  @override
  String get therapyJoinOpensSoon =>
      'The call opens 10 minutes before the start.';

  @override
  String get therapyJoinOverUnpaid =>
      'This session\'s time has passed without payment. It\'ll be cancelled shortly, and you can book again after that.';

  @override
  String get therapyJoinOver =>
      'This session\'s time has passed. It closes out on its own within a couple of hours: if it went ahead, any note from your therapist appears under Past sessions; if it didn\'t happen, you\'ll be able to book again.';

  @override
  String get therapyJoinNeedsPayment =>
      'The call opens once your session is paid for.';

  @override
  String get therapyJoinReady =>
      'Find a quiet, private spot — you\'ll need your camera and microphone.';

  @override
  String get therapyJoinSession => 'Join session';

  @override
  String therapyPastWithTherapist(String name, String date) {
    return '$name · $date';
  }

  @override
  String get therapyRate => 'Rate';

  @override
  String get therapyTitle => 'Talk to a therapist';

  @override
  String get therapyLoadFailed => 'Couldn\'t load — check your connection.';

  @override
  String get therapyHeadline => 'You don\'t have to do this alone';

  @override
  String get therapyIntro =>
      'Private one-on-one sessions with licensed therapists, right from here. Tell us a little about what you need and we\'ll match you with the right person.';

  @override
  String get therapyPastSessions => 'Past sessions';

  @override
  String get therapyCrisisTrailing =>
      ' This app can\'t replace emergency care.';

  @override
  String get therapyCheckoutOffline =>
      'We can\'t reach our server right now — we\'ll keep checking.';

  @override
  String get therapyCheckoutNotFound =>
      'We haven\'t seen your payment yet. If you\'ve just paid, give it a few seconds.';

  @override
  String therapyCheckoutHint(String methods) {
    return 'Finish paying on the Paystack page — by $methods. This closes by itself once your payment is in.';
  }

  @override
  String get therapyCheckoutTitle => 'Waiting for your payment';

  @override
  String get therapyIvePaid => 'I\'ve paid';

  @override
  String sessionStarsSemantic(String rating) {
    return '$rating out of 5 stars';
  }

  @override
  String sessionStarTooltip(int stars) {
    return '$stars out of 5';
  }

  @override
  String sessionRatingAndCount(String rating, int count) {
    return '$rating · $count';
  }

  @override
  String sessionRatingFrom(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
    );
    return '$rating from $_temp0';
  }

  @override
  String sessionYearsExperience(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years of experience',
      one: '1 year of experience',
    );
    return '$_temp0';
  }

  @override
  String get sessionSendRating => 'Send rating';

  @override
  String get callMicUnavailable =>
      'Your microphone isn\'t available. You can allow it in your phone\'s settings for this app.';

  @override
  String get callCameraUnavailable =>
      'Your camera isn\'t available. You can allow it in your phone\'s settings for this app.';

  @override
  String get callMicAndCameraUnavailable =>
      'Your microphone and camera isn\'t available. You can allow it in your phone\'s settings for this app.';

  @override
  String get callSignedOut => 'You\'ve been signed out. Please log in again.';

  @override
  String get callConnectFailed =>
      'Couldn\'t connect to the session — check your connection and try again.';

  @override
  String get callConnecting => 'Connecting to your session…';

  @override
  String get callJoinFailedTitle => 'Couldn\'t join';

  @override
  String get callEndedTitle => 'The call has ended';

  @override
  String get callEndedDetail =>
      'If you were cut off, you can rejoin while the session is still on.';

  @override
  String get callRejoin => 'Rejoin';

  @override
  String callWaitingFor(String name) {
    return 'Waiting for $name to join…';
  }

  @override
  String get callConnected => 'Connected';

  @override
  String callEndsAt(String time) {
    return 'Session ends at $time';
  }

  @override
  String get callMute => 'Mute';

  @override
  String get callUnmute => 'Unmute';

  @override
  String get callCameraOff => 'Turn camera off';

  @override
  String get callCameraOn => 'Turn camera on';

  @override
  String get callSwitchCamera => 'Switch camera';

  @override
  String get callLeave => 'Leave';

  @override
  String get callCameraIsOff => 'Camera is off';

  @override
  String get callNotHereYet => 'Not here yet';

  @override
  String callInSessionWith(String name) {
    return 'In a session with $name';
  }

  @override
  String get callTapToReturn => 'Tap to come back to the call.';

  @override
  String get callChannelName => 'Therapy session in progress';

  @override
  String get callChannelDescription =>
      'Shown while you\'re in a session, so the call keeps running when you switch apps.';

  @override
  String get notificationReasonSession =>
      'We\'ll tell you the moment you\'re matched with a therapist, if your session moves, and ten minutes before it starts — so you don\'t miss a session you\'ve paid for.';

  @override
  String get notificationReasonTherapist =>
      'You\'ll be told when a session is booked with you, if it changes, and ten minutes before it starts.';

  @override
  String get notificationReasonReminders =>
      'Reminders are notifications: without permission the phone can\'t show them.';

  @override
  String get notificationReasonOnboarding =>
      'Session bookings, a nudge before each session starts, and the daily reminders you choose. Nothing else.';

  @override
  String get notificationOffTitle => 'Notifications are off';

  @override
  String notificationOffBody(String reason) {
    return '$reason\n\nThey\'re switched off for this app at the moment. You can turn them on in your phone\'s settings — it takes a few seconds.';
  }

  @override
  String get notificationOpenSettings => 'Open settings';

  @override
  String get notificationTurnOn => 'Turn on';

  @override
  String get notificationSessionsChannel => 'Therapy sessions';

  @override
  String get notificationSessionsChannelDescription =>
      'Bookings, changes and reminders for your sessions';

  @override
  String get notificationYourTherapist => 'your therapist';

  @override
  String get notificationYourClient => 'your client';

  @override
  String get notificationBookedTime => 'the booked time';

  @override
  String notificationMatchedTitle(String who) {
    return 'You\'re matched with $who';
  }

  @override
  String notificationMatchedBodyUnpaid(String when, int minutes, String price) {
    return '$when · $minutes min. Pay $price in the app to confirm your place.';
  }

  @override
  String notificationMatchedBodyPaid(String when, int minutes) {
    return '$when · $minutes min. You\'re all set.';
  }

  @override
  String notificationNewSessionTitle(String who) {
    return 'New session with $who';
  }

  @override
  String notificationNewSessionBody(String when, int minutes) {
    return '$when · $minutes min.';
  }

  @override
  String notificationNewSessionBodyUnpaid(String when, int minutes) {
    return '$when · $minutes min. Waiting for the client to pay.';
  }

  @override
  String get notificationChangedTitle => 'Your session has changed';

  @override
  String notificationChangedBody(String when, String who, int minutes) {
    return 'Now $when with $who · $minutes min.';
  }

  @override
  String get notificationUpdatedTitle => 'Session updated';

  @override
  String notificationUpdatedBody(String who, String when, int minutes) {
    return 'With $who, now $when · $minutes min.';
  }

  @override
  String get notificationCancelledTitle => 'Session cancelled';

  @override
  String notificationCancelledBody(String who, String when) {
    return 'Your session with $who on $when has been cancelled.';
  }

  @override
  String get notificationMissedTitle => 'You missed your session';

  @override
  String notificationMissedBody(String who, String when) {
    return '$who was in the call on $when but you didn\'t join, so this session isn\'t refunded. You can book again in the app.';
  }

  @override
  String notificationReminderClientTitle(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Your session starts in $minutes minutes',
      one: 'Your session starts in 1 minute',
      zero: 'Your session is starting now',
    );
    return '$_temp0';
  }

  @override
  String notificationReminderClientBodyUnpaid(
    String hasTime,
    String who,
    String time,
  ) {
    String _temp0 = intl.Intl.selectLogic(hasTime, {
      'yes': 'With $who at $time — pay in the app to join.',
      'other': 'With $who — pay in the app to join.',
    });
    return '$_temp0';
  }

  @override
  String notificationReminderClientBody(
    String hasTime,
    String who,
    String time,
  ) {
    String _temp0 = intl.Intl.selectLogic(hasTime, {
      'yes': 'With $who at $time. Open the app to join.',
      'other': 'With $who. Open the app to join.',
    });
    return '$_temp0';
  }

  @override
  String notificationReminderTherapistTitle(int minutes, String who) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Session with $who starts in $minutes minutes',
      one: 'Session with $who starts in 1 minute',
      zero: 'Session with $who is starting now',
    );
    return '$_temp0';
  }

  @override
  String notificationReminderTherapistBodyUnpaid(String hasTime, String time) {
    String _temp0 = intl.Intl.selectLogic(hasTime, {
      'yes': 'Starts at $time. The client hasn\'t paid yet.',
      'other': 'Starts. The client hasn\'t paid yet.',
    });
    return '$_temp0';
  }

  @override
  String notificationReminderTherapistBody(String hasTime, String time) {
    String _temp0 = intl.Intl.selectLogic(hasTime, {
      'yes': 'Starts at $time. Open My sessions to join.',
      'other': 'Starts. Open My sessions to join.',
    });
    return '$_temp0';
  }

  @override
  String get notificationGenericTitle => 'Therapy session update';

  @override
  String get notificationGenericBody => 'Open the app for details.';

  @override
  String get remindersCheckinLabel => 'Morning check-in';

  @override
  String get remindersCheckinDescription =>
      'A ten-second pulse on how you\'re doing. Opens the check-in.';

  @override
  String get remindersCheckinTitle => 'How are you feeling today?';

  @override
  String get remindersCheckinBody =>
      'Take ten seconds to check in with yourself.';

  @override
  String get remindersPledgeLabel => 'Daily pledge';

  @override
  String get remindersPledgeDescription => 'Start the day by claiming it.';

  @override
  String get remindersPledgeTitle => 'A new day, on your terms';

  @override
  String get remindersPledgeBody => 'Make today\'s pledge — one day at a time.';

  @override
  String get remindersJournalLabel => 'Evening pages';

  @override
  String get remindersJournalDescription =>
      'A quiet minute for your journal. Opens your prompts.';

  @override
  String get remindersJournalTitle => 'A quiet minute for your journal';

  @override
  String get remindersJournalBody =>
      'Put today into words — even a few lines count.';

  @override
  String get remindersWindDownLabel => 'Wind-down';

  @override
  String get remindersWindDownDescription =>
      'A nudge to slow down. Opens your wind-down plan.';

  @override
  String get remindersWindDownTitle => 'Time to slow down';

  @override
  String get remindersWindDownBody =>
      'Your wind-down plan is ready — tap to start.';

  @override
  String get remindersChannelName => 'Daily reminders';

  @override
  String get remindersChannelDescription => 'Gentle daily nudges you asked for';

  @override
  String get remindersSetFailed =>
      'Couldn\'t set the reminder — fully restart the app and try again.';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersIntro =>
      'Gentle daily nudges, only if you want them — tap a time to change it.';

  @override
  String get remindersFootnote =>
      'Reminders are scheduled on this device and arrive even when the app is closed. Times may shift a few minutes to save battery.';

  @override
  String crisisCouldNotOpen(String target) {
    return 'Couldn\'t open $target';
  }

  @override
  String get crisisWhereAreYou => 'Where are you?';

  @override
  String crisisCallEmergency(String number) {
    return 'Call $number';
  }

  @override
  String get crisisEmergencyHint =>
      'If you are in immediate danger, this comes first.';

  @override
  String crisisCallLine(String phone) {
    return 'Call $phone';
  }

  @override
  String crisisTextLine(String keyword, String number) {
    return 'Text $keyword to $number';
  }

  @override
  String crisisOpenSite(String host) {
    return 'Open $host';
  }

  @override
  String get crisisTitle => 'Help right now';

  @override
  String get crisisIntro =>
      'You do not have to explain yourself well, or be in enough trouble to deserve it. Any of these will pick up.';

  @override
  String get crisisSomewhereElse => 'Somewhere else';

  @override
  String get crisisNotEmergencyCare =>
      'This app can\'t replace emergency care. When the moment has passed, a licensed therapist here can help you work through what led to it.';

  @override
  String get crisisBookSession => 'Book a session';

  @override
  String get crisisFooterLink => 'In crisis or immediate danger? Get help now';

  @override
  String get crisisFooterRest => ' — real numbers, one tap.';

  @override
  String heavyDayCouldNotCall(String number) {
    return 'Couldn\'t call $number';
  }

  @override
  String get heavyDayTitle => 'That sounds like a heavy day.';

  @override
  String get heavyDayBody =>
      'You don\'t have to carry it on your own. A licensed therapist here will listen — \$20 a session, booked in a minute.';

  @override
  String get heavyDayRightNow => 'If you need someone right now';

  @override
  String get heavyDayEmergency => 'Emergency';

  @override
  String get heavyDayMoreHelp => 'More ways to get help';

  @override
  String legalLastUpdated(String date) {
    return 'Last updated: $date';
  }

  @override
  String get faqSectionUsingApp => 'Using the app';

  @override
  String get faqWhatIsQ => 'What is yournotalone?';

  @override
  String get faqWhatIsA =>
      'You\'re not alone — that\'s the name and the idea. It\'s a wellbeing companion for the moments between the hard ones. Check in with your mood, keep a private journal, follow guided meditations and breathing exercises, unwind with calming sounds, track your recovery, and reach a licensed therapist when you need one.';

  @override
  String get faqSubstituteQ =>
      'Is the app a substitute for therapy or medical care?';

  @override
  String get faqSubstituteA =>
      'No. The app supports your wellbeing, but it doesn\'t diagnose or treat anything, and it\'s not emergency care. If you\'re in crisis or immediate danger, call your local emergency number right away.';

  @override
  String get faqRemindersQ => 'How do daily reminders work?';

  @override
  String get faqRemindersA =>
      'Go to Settings → Reminders & notifications to switch on gentle nudges — a morning check-in, a daily pledge, evening pages, and a wind-down. You choose the times, and reminders are scheduled on your phone; they never leave your device.';

  @override
  String get faqSectionBilling => 'Premium & billing';

  @override
  String get faqPremiumQ => 'What do I get with Premium?';

  @override
  String get faqPremiumA =>
      'Every room in the house: the full meditation library, all calming sounds and breathing exercises, unlimited journaling, and the complete recovery toolkit. Plans usually start with a free trial — the price is always shown before you subscribe.';

  @override
  String get faqCancelSubQ => 'How do I cancel my subscription?';

  @override
  String faqCancelSubA(String store) {
    String _temp0 = intl.Intl.selectLogic(store, {
      'apple':
          'Subscriptions are billed by Apple, so you cancel in your App Store subscription settings — deleting the app doesn\'t cancel it. You keep Premium until the end of the period you\'ve paid for.',
      'other':
          'Subscriptions are billed by Google, so you cancel in your Google Play subscription settings — deleting the app doesn\'t cancel it. You keep Premium until the end of the period you\'ve paid for.',
    });
    return '$_temp0';
  }

  @override
  String get faqWrongPlanQ =>
      'I\'m a subscriber, but the app says I\'m on the Free plan.';

  @override
  String faqWrongPlanA(String store) {
    String _temp0 = intl.Intl.selectLogic(store, {
      'apple':
          'Make sure you\'re signed in to the same Apple Account you subscribed with, then tap Settings → Restore purchases. If it still doesn\'t unlock, email us and we\'ll sort it out.',
      'other':
          'Make sure you\'re signed in to the same Google account you subscribed with, then tap Settings → Restore purchases. If it still doesn\'t unlock, email us and we\'ll sort it out.',
    });
    return '$_temp0';
  }

  @override
  String get faqRefundQ => 'Can I get a refund?';

  @override
  String faqRefundA(String store) {
    String _temp0 = intl.Intl.selectLogic(store, {
      'apple':
          'Refunds for subscriptions are handled by Apple under its policies — request one from your App Store purchase history. If you get stuck, write to us and we\'ll point you the right way.',
      'other':
          'Refunds for subscriptions are handled by Google under its policies — request one from your Google Play order history. If you get stuck, write to us and we\'ll point you the right way.',
    });
    return '$_temp0';
  }

  @override
  String get faqSectionTherapy => 'Therapy sessions';

  @override
  String get faqBookQ => 'How do I book a therapy session?';

  @override
  String get faqBookA =>
      'Open Talk to a therapist, tell us what you\'d like to talk about and when suits you, and send the request. Our care team matches you with a licensed therapist and a time — usually within a day — and you\'ll see who and when in the app and by email.';

  @override
  String get faqCostQ => 'How much does a session cost, and when do I pay?';

  @override
  String get faqCostA =>
      'Each session is \$20, paid securely in the app when you book — that\'s what sends your request to our care team, and you get a receipt by email straight away. No subscription; you book one session at a time.';

  @override
  String get faqMoveQ => 'What if I need to cancel or move my session?';

  @override
  String get faqMoveA =>
      'You can cancel in the app up to 24 hours before your session and you\'ll be refunded in full. To move it, reply to your booking email at least 24 hours before and we\'ll rebook you. A session cancelled later than that, or one you don\'t join, isn\'t refunded — your therapist has set that time aside for you. If we or your therapist have to cancel, you\'re refunded in full.';

  @override
  String get faqHowSessionsQ => 'How do sessions work?';

  @override
  String get faqHowSessionsA =>
      'They\'re private video calls, right in the app. The Join button appears 10 minutes before the start, and you\'ll need your camera and microphone. Calls aren\'t recorded.';

  @override
  String get faqRemindedQ => 'Will I be reminded?';

  @override
  String get faqRemindedA =>
      'Yes. You\'ll get an email and a phone notification when you\'re matched, if anything changes, and 10 minutes before your session. Phone notifications can arrive a little later than the emails.';

  @override
  String get faqCancelSessionQ => 'Can I cancel a session?';

  @override
  String get faqCancelSessionA =>
      'Yes. You can cancel a request, or a matched session you haven\'t paid for, from the same screen. To cancel a paid session, contact us before it starts and we\'ll refund you.';

  @override
  String get faqWhoQ => 'Who are the therapists?';

  @override
  String get faqWhoA =>
      'Licensed mental-health professionals. Our care team matches you based on what you share in your request, so you don\'t have to scroll through directories while you\'re struggling. Once you\'re matched, you can see their profile — credentials, experience and what they specialise in.';

  @override
  String get faqRateQ => 'Can I rate my session?';

  @override
  String get faqRateA =>
      'Yes — after a session, tap it under Past sessions. Your therapist never sees your rating on its own, only an average across several people.';

  @override
  String get faqSectionPrivacy => 'Privacy & your data';

  @override
  String get faqJournalQ => 'Who can read my journal?';

  @override
  String get faqJournalA =>
      'Only you. Your entries are protected by row-level security, which means only your signed-in account can retrieve them — our team doesn\'t read them.';

  @override
  String get faqSellDataQ => 'Do you sell my data or show ads?';

  @override
  String get faqSellDataA =>
      'Never. No ads, no analytics trackers, no data brokers. We collect only what the app needs to work — the Privacy Policy in Settings spells out every detail.';

  @override
  String get faqDeleteQ => 'How do I delete my account and data?';

  @override
  String get faqDeleteA =>
      'Settings → Delete account removes your profile, journal, moods, recovery data, and therapy sessions permanently. You can also email us from your registered address and we\'ll do it for you. Deletion can\'t be undone.';

  @override
  String get faqSectionAccount => 'Your account';

  @override
  String get faqProfileQ => 'How do I change my name or profile photo?';

  @override
  String get faqProfileA =>
      'Settings → Edit profile. Tap the photo to take a new one, choose from your library, or remove it.';

  @override
  String get faqPasswordQ => 'How do I change my password?';

  @override
  String get faqPasswordA =>
      'Settings → Change password sends a secure reset link to your email. Follow the link, choose a new password, and log back in.';

  @override
  String get faqEmailCopied => 'Email address copied.';

  @override
  String get faqStillNeedHelp => 'Still need help?';

  @override
  String faqWriteToUs(String email) {
    return 'Write to us at $email — tap to copy.';
  }

  @override
  String get faqTitle => 'FAQ';

  @override
  String get faqIntro =>
      'Quick answers to the questions we hear most. Tap a question to open it.';

  @override
  String get careClientFallback => 'Client';

  @override
  String get careYourClientFallback => 'Your client';

  @override
  String get careFlagNoShow => 'Didn\'t show up';

  @override
  String get careFlagLate => 'Joined late';

  @override
  String get careFlagFollowUp => 'Needs a follow-up';

  @override
  String get careFlagSafety => 'Safety concern';

  @override
  String get careSignedOut => 'You\'ve been signed out. Please log in again.';

  @override
  String get carePaymentFree => 'Free';

  @override
  String get carePaymentRefunded => 'Refunded';

  @override
  String get carePaymentUnpaid => 'Unpaid';

  @override
  String get carePaymentPaid => 'Paid';

  @override
  String get carePaymentWaived => 'Waived';

  @override
  String get careCouldNotLoad => 'Couldn\'t load — check your connection.';

  @override
  String get careDashboardTitle => 'Care team';

  @override
  String get careTabRequests => 'Requests';

  @override
  String get careTabTherapists => 'Therapists';

  @override
  String get careEmptyToMatch => 'Nobody is waiting to be matched.';

  @override
  String get careEmptyUpcoming => 'No sessions booked.';

  @override
  String get careEmptyPast => 'Finished and cancelled sessions show up here.';

  @override
  String careFilterToMatch(int count) {
    return 'To match · $count';
  }

  @override
  String careFilterUpcoming(int count) {
    return 'Upcoming · $count';
  }

  @override
  String careFilterPast(int count) {
    return 'Past · $count';
  }

  @override
  String get careAddTherapist => 'Add a therapist';

  @override
  String get careNoTherapists =>
      'No therapists yet. Add one to start matching requests.';

  @override
  String get careAskedJustNow => 'Asked just now';

  @override
  String careWaitingHours(int hours) {
    return 'Waiting ${hours}h';
  }

  @override
  String careWaitingDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Waiting $days days',
    );
    return '$_temp0';
  }

  @override
  String get careTherapistFallback => 'Therapist';

  @override
  String careBookedLine(String therapist, String when) {
    return '$therapist · $when';
  }

  @override
  String careBookedLineNotFinished(String therapist, String when) {
    return '$therapist · $when · Not finished';
  }

  @override
  String carePastLine(String outcome, String date) {
    return '$outcome · $date';
  }

  @override
  String careStatUpcoming(int count) {
    return '$count upcoming';
  }

  @override
  String careStatCompleted(int count) {
    return '$count completed';
  }

  @override
  String get careInactive => 'Inactive';

  @override
  String careNotSignedInYet(String email) {
    return 'Not signed in yet — $email';
  }

  @override
  String get careMatchCouldNotLoadTherapists =>
      'Couldn\'t load therapists — check your connection.';

  @override
  String get careMatchTimePassed => 'That time has already passed.';

  @override
  String get careMatchCouldNotBook => 'Couldn\'t book — check your connection.';

  @override
  String get careMatchTitleNew => 'Match request';

  @override
  String get careMatchTitleChange => 'Change booking';

  @override
  String get careMatchFlexible => 'Flexible';

  @override
  String get careMatchTherapistHeader => 'Therapist';

  @override
  String get careMatchNoTherapists =>
      'No active therapists yet. Add one from the Therapists tab first.';

  @override
  String get careMatchWhenHeader => 'When';

  @override
  String get careMatchPickDate => 'Pick a date';

  @override
  String get careMatchPickTime => 'Pick a time';

  @override
  String get careMatchTimeZoneNote =>
      'In this phone\'s time zone. The client and therapist see it in theirs.';

  @override
  String get careMatchLengthHeader => 'Length';

  @override
  String careMatchMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get careMatchBook => 'Book session';

  @override
  String get careMatchSaveChanges => 'Save changes';

  @override
  String get careMatchFootFree =>
      'The client and therapist are emailed the details. This is the client\'s free first session.';

  @override
  String careMatchFootPays(String price) {
    return 'The client and therapist are emailed the details. The client pays $price in the app before they can join.';
  }

  @override
  String get careMatchFoot =>
      'The client and therapist are emailed the details.';

  @override
  String get careMatchSpecialises => 'Specialises in this';

  @override
  String get careMatchNotSignedIn =>
      'Not signed in yet — they can\'t join until they do';

  @override
  String get careDetailFailed => 'That didn\'t work — check your connection.';

  @override
  String get careDetailBooked =>
      'Booked — the client and therapist have been emailed.';

  @override
  String get careCancelSessionTitle => 'Cancel this session?';

  @override
  String get careCancelRequestTitle => 'Cancel this request?';

  @override
  String get careCancelSessionBody =>
      'The client and therapist are emailed that it\'s cancelled.';

  @override
  String get careCancelSessionPaidBody =>
      'The client and therapist are emailed that it\'s cancelled. They\'ve paid, so refund them in the Paystack dashboard (Play Console for older in-app payments).';

  @override
  String get careCancelRequestBody =>
      'The client can request again whenever they like.';

  @override
  String get careCancelSessionAction => 'Cancel session';

  @override
  String get careCancelRequestAction => 'Cancel request';

  @override
  String get careCancelled => 'Cancelled.';

  @override
  String get carePayPaidTitle => 'Record a payment?';

  @override
  String get carePayPaidBody =>
      'Use this when they paid outside the app. The Join button unlocks for them straight away.';

  @override
  String get carePayMarkPaid => 'Mark as paid';

  @override
  String get carePayWaiveTitle => 'Waive the fee?';

  @override
  String get carePayWaiveBody =>
      'They won\'t be charged for this session, and can join straight away.';

  @override
  String get carePayWaive => 'Waive fee';

  @override
  String get carePayUnpaidTitle => 'Mark as unpaid?';

  @override
  String get carePayUnpaidBody => 'They\'ll need to pay before they can join.';

  @override
  String get carePayMarkUnpaid => 'Mark as unpaid';

  @override
  String get carePaymentUpdated => 'Payment updated.';

  @override
  String get careStatusAwaitingPayment =>
      'Not sent yet — the client hasn\'t paid';

  @override
  String get careStatusPending => 'Waiting to be matched';

  @override
  String get careStatusMatchedUnpaid => 'Matched — waiting for payment';

  @override
  String get careStatusBooked => 'Booked';

  @override
  String get careStatusMissed =>
      'Completed — the client didn\'t join, so the session counts as used';

  @override
  String get careStatusCompleted => 'Completed';

  @override
  String careStatusCompletedOn(String date) {
    return 'Completed $date';
  }

  @override
  String get careStatusTherapistNoShow =>
      'Cancelled — the therapist didn\'t join the call';

  @override
  String get careStatusNobodyJoined => 'Cancelled — nobody joined the call';

  @override
  String get careStatusNeverPaid => 'Cancelled — never paid';

  @override
  String get careStatusDiscarded => 'Discarded before it was paid for';

  @override
  String get careStatusCancelled => 'Cancelled';

  @override
  String get careFreeFirstSession => 'Free first session';

  @override
  String carePaidOn(String price, String date) {
    return '$price · paid on $date';
  }

  @override
  String carePaid(String price) {
    return '$price · paid';
  }

  @override
  String careWaived(String price) {
    return '$price · waived';
  }

  @override
  String careRefundedOn(String price, String date) {
    return '$price · refunded on $date, not paid';
  }

  @override
  String careNotPaidYet(String price) {
    return '$price · not paid yet';
  }

  @override
  String get careSectionClient => 'Client';

  @override
  String get careNoName => 'No name given';

  @override
  String get careCopyEmail => 'Copy email';

  @override
  String get careEmailCopied => 'Email copied.';

  @override
  String get careSectionRequest => 'Request';

  @override
  String careAsked(String when) {
    return 'Asked $when';
  }

  @override
  String get careSectionSession => 'Session';

  @override
  String careSessionWhen(String when, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
    );
    return '$when · $_temp0';
  }

  @override
  String get careMatchWithTherapist => 'Match with a therapist';

  @override
  String get careChangeTherapistOrTime => 'Change therapist or time';

  @override
  String get careSectionPayment => 'Payment';

  @override
  String get careSectionAfter => 'After the session';

  @override
  String get careNoteToClient => 'Note to the client';

  @override
  String get careNoNote => 'No note written.';

  @override
  String get careClientRating => 'Client\'s rating';

  @override
  String get careNotRatedYet => 'Not rated yet.';

  @override
  String get careTherapistRating => 'Therapist\'s rating — private';

  @override
  String get careCancelThisSession => 'Cancel this session';

  @override
  String get careCancelThisRequest => 'Cancel this request';

  @override
  String get careEditorPhotoFailed => 'Couldn\'t open your photo library.';

  @override
  String get careCouldNotSave => 'Couldn\'t save — check your connection.';

  @override
  String get careEditorTitleAdd => 'Add a therapist';

  @override
  String get careEditorTitleEdit => 'Edit therapist';

  @override
  String get careEditorChangePhoto => 'Change photo';

  @override
  String get careEditorAddPhoto => 'Add a photo';

  @override
  String get careEditorFullName => 'Full name';

  @override
  String get careEditorFullNameError => 'Enter their full name';

  @override
  String get careEditorEmail => 'Sign-in email';

  @override
  String get careEditorEmailHelp =>
      'They sign in to the app with this address.';

  @override
  String get careEditorEmailError => 'Enter a valid email';

  @override
  String get careEditorTitleField => 'Title';

  @override
  String get careEditorTitleHint => 'Counselling psychologist';

  @override
  String get careEditorLicence => 'Licence or registration';

  @override
  String get careEditorLicenceHint => 'Body and registration number';

  @override
  String get careEditorYears => 'Years of experience';

  @override
  String get careEditorYearsError => 'A number from 0 to 70';

  @override
  String get careEditorLanguages => 'Languages';

  @override
  String get careEditorLanguagesHint => 'English, Swahili';

  @override
  String get careEditorAbout => 'About them';

  @override
  String get careEditorAboutHelp => 'Clients read this on their profile.';

  @override
  String get careEditorSpecialties => 'Specialties';

  @override
  String get careEditorTakingClients => 'Taking new clients';

  @override
  String get careEditorTakingClientsHint =>
      'When off, they can\'t be matched. Their booked and past sessions stay.';

  @override
  String get careEditorAddButton => 'Add therapist';

  @override
  String get careEditorInviteNote =>
      'They\'ll get an email explaining how to sign in and find their sessions.';

  @override
  String get careEditorFeedback => 'Client feedback';

  @override
  String get careEditorFeedbackNote =>
      'Only the care team sees individual ratings. Clients see an average once there are three.';

  @override
  String careEditorStats(int upcoming, int completed) {
    return '$upcoming upcoming · $completed completed';
  }

  @override
  String careEditorRatingFrom(String rating, int count) {
    return '$rating from $count';
  }

  @override
  String careEditorSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String careEditorNotSignedIn(String email) {
    return 'Hasn\'t signed in yet. They need to sign in to the app with $email to see and join sessions.';
  }

  @override
  String get careSessionsCouldNotLoad =>
      'Couldn\'t load your sessions — check your connection.';

  @override
  String get careSessionsSaved => 'Saved.';

  @override
  String get careSessionsFinished => 'Session finished — thank you.';

  @override
  String get careSessionsTitle => 'My sessions';

  @override
  String get careSessionsEmpty =>
      'No sessions yet. When the care team books one with you, it shows up here and you\'ll get an email.';

  @override
  String get careSessionsUpcoming => 'Upcoming';

  @override
  String get careSessionsPast => 'Past';

  @override
  String get careSessionsTooEarly =>
      'The call opens 10 minutes before the start.';

  @override
  String get careSessionsOver =>
      'The call has closed. Finish the session to close it out — otherwise it closes itself in a couple of hours.';

  @override
  String get careSessionsUnpaid =>
      'The client hasn\'t paid yet — the call opens once they do.';

  @override
  String get careSessionsOpen => 'The call is open.';

  @override
  String careSessionsTheyWrote(String note) {
    return 'They wrote: “$note”';
  }

  @override
  String get careSessionsJoin => 'Join session';

  @override
  String get careSessionsFinish => 'Finish session';

  @override
  String get careSessionsClientMissed => 'The client didn\'t join the call.';

  @override
  String get careSessionsDidNotHappen => 'Didn\'t happen';

  @override
  String get careSessionsRate => 'Rate';

  @override
  String get careFinishNeedsRating =>
      'Add a star rating to send private feedback.';

  @override
  String careFinishTitleDone(String name) {
    return 'Session with $name';
  }

  @override
  String careFinishTitle(String name) {
    return 'Finish your session with $name';
  }

  @override
  String careFinishNoteLabel(String name) {
    return 'A note for $name (optional)';
  }

  @override
  String get careFinishNoteHelp =>
      'They see this in the app — a takeaway, or something to practise. Keep clinical notes out of it.';

  @override
  String get careFinishHowDidItGo => 'How did it go?';

  @override
  String get careFinishPrivateNote =>
      'Private note for the care team (optional)';

  @override
  String get careFinishPrivacy =>
      'Only the care team sees your rating, flags and private note. Flagging a safety concern emails them straight away.';

  @override
  String toolkitStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get toolkitSavedToJournal => 'Saved to your journal.';

  @override
  String get toolkitSaveFailed => 'Couldn\'t save — check your connection.';

  @override
  String toolkitCouldntOpenLink(String url) {
    return 'Couldn\'t open $url';
  }

  @override
  String get toolkitToolsTitle => 'Tools';

  @override
  String get toolkitLessonsTitle => 'Learn the ideas';

  @override
  String get toolkitResourcesIntro =>
      'Reputable, clinician-written material from outside the app. Links open in your browser.';

  @override
  String get toolkitFreeResources => 'Free resources';

  @override
  String get toolkitPremiumTitle => 'This is part of Premium';

  @override
  String toolkitPremiumMessage(String offer) {
    return 'Free includes a taste of each programme. Premium unlocks every tool and read — and $offer.';
  }

  @override
  String toolkitCountLine(int free, int locked) {
    return '$free free · $locked Premium';
  }

  @override
  String toolkitMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
    );
    return '$_temp0';
  }

  @override
  String toolkitMinutesRead(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min read',
    );
    return '$_temp0';
  }

  @override
  String get toolkitLearnTitle => 'Learn';

  @override
  String get toolkitSessionPremiumTitle => 'This session is part of Premium';

  @override
  String toolkitSessionPremiumMessage(String offer) {
    return 'Free includes a taste of each practice. Premium unlocks every session — and $offer.';
  }

  @override
  String get cbtTitle => 'CBT toolkit';

  @override
  String get cbtHeadline => 'Skills you can use today';

  @override
  String get cbtIntro =>
      'Cognitive behavioural therapy is the best-studied talking therapy for anxiety and depression, and much of it is learnable. These are the tools therapists hand out first — for the minutes between sessions, or before you\'ve had one.';

  @override
  String get cbtTherapistBannerTitle => 'Want to do this with someone?';

  @override
  String get cbtTherapistBannerDetail =>
      'A licensed therapist can take you through these properly. Book a private video session.';

  @override
  String get cbtFootnote =>
      'Self-help is not a substitute for care in a crisis. If you\'re in immediate danger, use Get help now on the Home screen.';

  @override
  String get stressTitle => 'Manage stress';

  @override
  String get stressHeadline => 'Down from the ceiling, then sort the load';

  @override
  String get stressIntro =>
      'Stress is a body state before it\'s a thought, so the fastest tools work on the body: breath and muscles first, thinking second. Then a check-in to see the trend, and two tools for the load itself — what you can change, and what refills you.';

  @override
  String get stressCbtBannerTitle => 'When the stress is in the thinking';

  @override
  String get stressCbtBannerDetail =>
      'Thought records, thinking traps and worry windows are in the CBT toolkit.';

  @override
  String get stressTherapistBannerTitle => 'Been like this for months?';

  @override
  String get stressTherapistBannerDetail =>
      'That\'s worth a real conversation. Book a private session with a licensed therapist.';

  @override
  String get stressFootnote =>
      'Chest pain, breathlessness or palpitations that don\'t settle need a doctor, not a breathing exercise. In an emergency, call your local emergency number.';

  @override
  String get groundingTitle => 'Grounding';

  @override
  String get groundingDoneTitle => 'You\'re here';

  @override
  String get groundingDoneBody =>
      'Notice your breathing. Notice the weight of your body where you\'re sitting. Whatever was pulling at you is still there, but you\'re here, and here is manageable.';

  @override
  String get groundingBreatheButton => 'Breathe for a few minutes';

  @override
  String get toolkitGoAgain => 'Go again';

  @override
  String get groundingFoundOne => 'Found one';

  @override
  String get groundingFoundLast => 'Found one — last';

  @override
  String groundingStepTitle(int count, String sense) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things you can $sense',
    );
    return '$_temp0';
  }

  @override
  String groundingToGo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'to go',
    );
    return '$_temp0';
  }

  @override
  String cbtQuoted(String text) {
    return '“$text”';
  }

  @override
  String get thinkingTrapsTitle => 'Thinking traps';

  @override
  String get thinkingTrapsSectionTitle => 'Spot the pattern';

  @override
  String get thinkingTrapsSectionBody =>
      'Anxious and low moods run on a handful of predictable distortions. Naming one takes some of its power away. Write the thought that\'s bothering you, then see which of these it\'s wearing.';

  @override
  String get thinkingTrapsThoughtLabel => 'The thought (optional)';

  @override
  String thinkingTrapsWhichOne(String thought) {
    return '$thought\n\nWhich of these does it sound like?';
  }

  @override
  String get thinkingTrapsForExample => 'For example';

  @override
  String get thinkingTrapsAskYourself => 'Ask yourself';

  @override
  String get thinkingTrapsFooter =>
      'Found one? The thought record walks you through checking the evidence and writing something fairer.';

  @override
  String get cbtFeelingAnxious => 'Anxious';

  @override
  String get cbtFeelingSad => 'Sad';

  @override
  String get cbtFeelingAngry => 'Angry';

  @override
  String get cbtFeelingAshamed => 'Ashamed';

  @override
  String get cbtFeelingGuilty => 'Guilty';

  @override
  String get cbtFeelingHopeless => 'Hopeless';

  @override
  String get cbtFeelingLonely => 'Lonely';

  @override
  String get cbtFeelingOverwhelmed => 'Overwhelmed';

  @override
  String get thoughtRecordTitle => 'Thought record';

  @override
  String get thoughtRecordNoneSpotted => 'none spotted';

  @override
  String thoughtRecordSummary(
    String situation,
    String thought,
    String feelings,
    int before,
    String traps,
    String evidenceFor,
    String evidenceAgainst,
    String balanced,
    int after,
  ) {
    return 'Situation: $situation\nAutomatic thought: $thought\nFeeling: $feelings — $before/100 before\nThinking traps: $traps\nEvidence for: $evidenceFor\nEvidence against: $evidenceAgainst\nBalanced thought: $balanced\nFeeling now: $after/100';
  }

  @override
  String thoughtRecordOutOf100(int value) {
    return '$value out of 100';
  }

  @override
  String get thoughtRecordStep1Title => 'What was the situation?';

  @override
  String get thoughtRecordStep1Hint =>
      'Just the facts, as a camera would have seen them. Where were you, who was there, what happened?';

  @override
  String get thoughtRecordStep1Field =>
      'e.g. Sent a message at 2pm, no reply by 9pm';

  @override
  String get thoughtRecordStep2Title => 'What went through your mind?';

  @override
  String get thoughtRecordStep2Hint =>
      'The first, quickest thought — the one that stung. Write it the way it sounded in your head.';

  @override
  String get thoughtRecordStep2Field => 'e.g. She\'s had enough of me';

  @override
  String get thoughtRecordStep3Title => 'How did it make you feel?';

  @override
  String get thoughtRecordStep3Hint =>
      'Pick what fits, then rate how strong it was.';

  @override
  String get thoughtRecordStep4Title => 'Any thinking traps in there?';

  @override
  String get thoughtRecordStep4Hint =>
      'Tap any that fit. Most hot thoughts have at least one.';

  @override
  String get thoughtRecordStep5Title => 'Check the evidence';

  @override
  String get thoughtRecordStep5Hint =>
      'Facts, not feelings. What would a fair judge accept?';

  @override
  String get thoughtRecordEvidenceFor => 'What supports the thought?';

  @override
  String get thoughtRecordEvidenceAgainst => 'What doesn\'t fit with it?';

  @override
  String get thoughtRecordQuestionsWorthAsking => 'Questions worth asking';

  @override
  String get thoughtRecordStep6Title => 'Write a fairer thought';

  @override
  String get thoughtRecordStep6Hint =>
      'Not the cheerful opposite — something you could defend. It often starts \"Even though…\" or \"It\'s possible that…\".';

  @override
  String get thoughtRecordBalancedField => 'A more balanced way to see it';

  @override
  String get thoughtRecordStep7Title => 'How strong is the feeling now?';

  @override
  String get thoughtRecordStep7Hint =>
      'It rarely goes to zero. A few points down is the skill working.';

  @override
  String get cbtSaveToJournal => 'Save to journal';

  @override
  String cbtBullet(String text) {
    return '• $text';
  }

  @override
  String get worryTimeParked =>
      'Parked. It\'ll be here at worry time — you don\'t have to hold it now.';

  @override
  String get worryTimeTimesUp =>
      'Time\'s up. Whatever\'s left can wait for tomorrow\'s window.';

  @override
  String get worryTimeHavePlan => 'You\'ve got a plan for this one.';

  @override
  String get worryTimeLetGo => 'Let go — nothing to do here today.';

  @override
  String get worryTimeCanYouAct =>
      'Can you do something about it in the next week?';

  @override
  String get worryTimeYesPlan => 'Yes — plan it';

  @override
  String get worryTimeNoLetGo => 'No — let it go';

  @override
  String get worryTimeTitle => 'Worry window';

  @override
  String get worryTimeSectionTitle => 'Worry later, on purpose';

  @override
  String get worryTimeSectionBody =>
      'You can\'t stop a worry arriving, but you can decide when to give it attention. Park it here as it comes. Then, once a day, open a fifteen-minute window and go through the list — and only then.';

  @override
  String get worryTimeInputLabel => 'What\'s on your mind right now?';

  @override
  String get worryTimeParkTooltip => 'Park it';

  @override
  String get worryTimeNothingParked => 'Nothing parked';

  @override
  String worryTimeParkedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parked for worry time',
    );
    return '$_temp0';
  }

  @override
  String get worryTimeBestTime =>
      'Best kept to the same time each day — not the hour before bed.';

  @override
  String get worryTimeOpenWindow => 'Open window';

  @override
  String get worryTimeGoThrough =>
      'Go through each worry once. Decide, don\'t dwell.';

  @override
  String get worryTimeYourList => 'Your list';

  @override
  String get worryTimeClearDecided => 'Clear decided';

  @override
  String get worryTimeEmpty =>
      'Your parked worries appear here. Most people find half of them have lost their sting by the time the window opens.';

  @override
  String get problemSolvingWhenToday => 'Today';

  @override
  String get problemSolvingWhenTomorrow => 'Tomorrow';

  @override
  String get problemSolvingWhenThisWeek => 'This week';

  @override
  String get problemSolvingWhenNextWeek => 'Next week';

  @override
  String problemSolvingSummary(
    String problem,
    String options,
    String chosen,
    String firstStep,
    String when,
  ) {
    return 'Problem: $problem\nOptions considered: $options\nChosen: $chosen\nFirst step: $firstStep — $when';
  }

  @override
  String get problemSolvingPlanTitle => 'Problem-solving plan';

  @override
  String get problemSolvingTitle => 'Problem solving';

  @override
  String get problemSolvingStep1Title => 'What exactly is the problem?';

  @override
  String get problemSolvingStep1Hint =>
      'One problem, in one sentence, specific enough to act on. \"Money\" is a worry; \"I\'m £300 short for rent on the 1st\" is a problem.';

  @override
  String get problemSolvingStep1Field => 'The problem, precisely';

  @override
  String get problemSolvingStep2Title => 'List every option';

  @override
  String get problemSolvingStep2Hint =>
      'Don\'t judge them yet — bad ideas loosen up good ones. Aim for at least three, including one you\'d never do.';

  @override
  String get problemSolvingOptionField => 'An option';

  @override
  String get problemSolvingStep3Title => 'Pick one to try';

  @override
  String get problemSolvingStep3Hint =>
      'Not the perfect one — the one that\'s good enough and that you\'d actually do. You can come back to the others.';

  @override
  String get problemSolvingStep4Title => 'What\'s the first step?';

  @override
  String get problemSolvingStep4Hint =>
      'Something that takes under twenty minutes and needs no one\'s permission. Then decide when.';

  @override
  String problemSolvingTrying(String option) {
    return 'Trying: $option';
  }

  @override
  String get problemSolvingFirstStepField => 'First step';

  @override
  String get activityPlannerTooMany =>
      'Three is plenty for one day. Swap one out if you\'d rather.';

  @override
  String get activityPlannerAllDone =>
      'That\'s today\'s plan done. Notice how you feel now compared with before.';

  @override
  String get activityPlannerTitle => 'One small thing';

  @override
  String get activityPlannerSectionTitle => 'Do first, feel later';

  @override
  String get activityPlannerSectionBody =>
      'When mood is low, motivation doesn\'t come before action — it comes after. Pick up to three small things for today. Small enough that you\'d do them on a bad day.';

  @override
  String activityPlannerTodayProgress(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Today · $done of $total done',
    );
    return '$_temp0';
  }

  @override
  String get activityPlannerIdeas => 'Ideas';

  @override
  String get activityPlannerAll => 'All';

  @override
  String get activityPlannerOwnField => 'Or something of your own';

  @override
  String get controlCircleZoneControl => 'Control';

  @override
  String get controlCircleZoneControlHint => 'I can change this';

  @override
  String get controlCircleZoneInfluence => 'Influence';

  @override
  String get controlCircleZoneInfluenceHint => 'I can lean on it';

  @override
  String get controlCircleZoneAccept => 'Accept';

  @override
  String get controlCircleZoneAcceptHint => 'Not mine to move';

  @override
  String get controlCircleControlAdvice =>
      'These are yours to move. Pick one — the smallest — and take the first step this week.';

  @override
  String get controlCircleControlAction => 'Work one through';

  @override
  String get controlCircleInfluenceAdvice =>
      'You can\'t decide these, but you can ask, say, or nudge. What is the one conversation each of these needs?';

  @override
  String get controlCircleAcceptAdvice =>
      'Not yours to carry, and carrying them anyway is where a lot of stress lives. Practise setting them down — it\'s a skill, not a mood.';

  @override
  String get controlCircleAcceptAction => 'Breathe it out';

  @override
  String controlCircleZoneCount(String zone, int count) {
    return '$zone · $count';
  }

  @override
  String get controlCircleTitle => 'What\'s in your hands';

  @override
  String get controlCircleSectionTitle => 'Three circles';

  @override
  String get controlCircleSectionBody =>
      'Write down everything that\'s weighing on you, then sort each one. Most stress comes from spending effort in the outer circles and neglecting the inner one.';

  @override
  String get controlCircleInputLabel => 'Something on your mind';

  @override
  String get controlCircleEffortTitle => 'Where your effort goes';

  @override
  String get controlCircleEmpty =>
      'Start with whatever came to mind first. Vague is fine — \"work\", \"money\", \"mum\" — you can sharpen it later.';

  @override
  String get toolkitBegin => 'Begin';

  @override
  String get muscleRelaxTitle => 'Tense and release';

  @override
  String get muscleRelaxIntroTitle => 'Eight groups, once each';

  @override
  String get muscleRelaxIntroBody =>
      'Sit or lie somewhere you won\'t be disturbed for eight minutes. For each group: tense hard for five seconds — not to pain — then let go completely for ten, and notice the difference. That noticing is the exercise.';

  @override
  String get muscleRelaxDoneTitle => 'Let it all stay loose';

  @override
  String get muscleRelaxDoneBody =>
      'Sit for a moment before you get up. Where was the most tension hiding? That\'s the place to check in on during the day.';

  @override
  String get muscleRelaxReleaseHint =>
      'Let go all at once. Feel the difference.';

  @override
  String get muscleRelaxTense => 'Tense';

  @override
  String get muscleRelaxRelease => 'Release';

  @override
  String get sighPhaseIn => 'Breathe in';

  @override
  String get sighPhaseInHint => 'Through the nose, most of the way.';

  @override
  String get sighPhaseSip => 'One more sip';

  @override
  String get sighPhaseSipHint => 'A short top-up, right to the top.';

  @override
  String get sighPhaseOut => 'Long breath out';

  @override
  String get sighPhaseOutHint =>
      'Slowly, through the mouth, until you\'re empty.';

  @override
  String get sighTitle => 'Physiological sigh';

  @override
  String get sighAnotherRound => 'Another round';

  @override
  String get sighStart => 'Start';

  @override
  String get sighDoneTitle => 'That\'s the round';

  @override
  String sighRoundOf(int round, int total) {
    return 'Round $round of $total';
  }

  @override
  String get sighIntroTitle => 'Two in, one long out';

  @override
  String get sighDoneBody =>
      'Notice your shoulders and your jaw. Most people feel the drop within a round or two. Use it any time — in a meeting, in a queue, before a call.';

  @override
  String get sighIntroBody =>
      'Breathe in through your nose, then take one more short sip on top. Let it all out slowly through your mouth. That\'s one. Follow the circle.';

  @override
  String get sighDone => 'Done';

  @override
  String get sighReady => 'Ready';

  @override
  String get rechargeTitle => 'Recharge list';

  @override
  String get rechargeSectionTitle => 'Know your tank';

  @override
  String get rechargeSectionBody =>
      'Stress is a budget: things that take from it and things that pay in. Most people can name the drains instantly and go quiet on the refills. Write both. Then choose one refill for today — and treat it as an appointment.';

  @override
  String rechargeToday(String pick) {
    return 'Today: $pick';
  }

  @override
  String get rechargeDrainsTitle => 'What drains me';

  @override
  String get rechargeAddDrain => 'Add a drain';

  @override
  String get rechargeRefillsTitle => 'What refills me';

  @override
  String get rechargeRefillsHint => 'Tap one to make it today\'s.';

  @override
  String get rechargeAddRefill => 'Add a refill';

  @override
  String get rechargeBorrow => 'Stuck for refills? Borrow one:';

  @override
  String get stressBandLow => 'Low';

  @override
  String get stressBandLowAdvice =>
      'You\'re carrying this week fine. Keep whatever recovery you\'ve got in place — it\'s working.';

  @override
  String get stressBandModerate => 'Moderate';

  @override
  String get stressBandModerateAdvice =>
      'Noticeable, and worth ten deliberate minutes a day: a sigh round, a walk, a proper break. Sort one thing that\'s in your hands.';

  @override
  String get stressBandHigh => 'High';

  @override
  String get stressBandHighAdvice =>
      'A lot right now. Bring the body down first — sigh, tense and release — then look at the load. If it\'s been like this for weeks, talk to someone; that\'s what the therapist sessions are for.';

  @override
  String stressCheckinQuestion(int number, String question) {
    return '$number. $question';
  }

  @override
  String get stressCheckinHistoryTitle => 'Your last check-ins';

  @override
  String stressCheckinHistoryRange(String from, String to) {
    return '$from → $to · 0 is calm, 20 is a lot';
  }

  @override
  String get stressCheckinTitle => 'Stress check-in';

  @override
  String stressCheckinScore(int score, String band) {
    return '$score out of 20 · $band';
  }

  @override
  String get stressCheckinDisclaimer =>
      'A check-in is a snapshot of one week, not a diagnosis. If the high scores keep coming, that\'s the signal to talk to someone.';

  @override
  String get stressCheckinSeeScore => 'See my score';

  @override
  String stressCheckinAnswered(int answered, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$answered of $total answered',
    );
    return '$_temp0';
  }

  @override
  String get stressCheckinSectionTitle => 'The past week';

  @override
  String get stressCheckinSectionBody =>
      'Go with your first answer. Once a week, same day, gives you a line you can actually read.';

  @override
  String get awakeTitle => 'Awake at 3am?';

  @override
  String get awakeStep1Title => 'Awake, and it\'s not passing?';

  @override
  String get awakeStep1Hint =>
      'Don\'t check the time — it only gives you sums to do. If it feels like you\'ve been lying here twenty minutes or more, that\'s long enough.';

  @override
  String get awakeStep1Note =>
      'Lying in bed awake and frustrated teaches your brain that the bed is a place to be awake and frustrated. Getting up breaks that link. It feels backwards; it\'s the most reliable trick sleep clinics have.';

  @override
  String get awakeStep2Title => 'Get up. Low light, something dull.';

  @override
  String get awakeStep2Hint =>
      'Another room if you can. No bright screens, no news, no work. Boring is the goal — you\'re waiting for sleepiness to come back, not entertaining yourself.';

  @override
  String get awakeTimerHint =>
      'Sleepy before this runs out? Go back to bed now — sleepiness wins over the timer.';

  @override
  String get awakeOptionBoxBreathing => 'Box breathing';

  @override
  String get awakeOptionBoxBreathingDetail =>
      'Four counts each way, in the dark.';

  @override
  String get awakeOptionSound => 'A quiet sound';

  @override
  String get awakeOptionSoundDetail => 'Rain or crickets, low, on a timer.';

  @override
  String get awakeOptionDeepRest => 'Deep rest';

  @override
  String get awakeOptionDeepRestDetail =>
      'A long guided lie-down for when sleep won\'t come.';

  @override
  String get awakeOptionBook => 'A dull book';

  @override
  String get awakeOptionBookDetail =>
      'Something you\'ve read before. Paper, if you have it.';

  @override
  String get awakeStep3Title =>
      'Back to bed when sleepy — not when the clock says';

  @override
  String get awakeStep3Hint =>
      'Heavy eyes, slow thoughts, a yawn. That\'s the signal. If it doesn\'t come, stay up a little longer; if you go back and it doesn\'t take, do the whole thing again.';

  @override
  String get awakeStep3Note =>
      'Tomorrow: get up at your usual time however the night went. The sleep pressure you build will make tonight easier. One rough night is survivable; a drifting wake time isn\'t.';

  @override
  String get awakeConfirmButton => 'Yes — I\'ve been awake a while';

  @override
  String get awakeStartBreakButton => 'Start a 15-minute break';

  @override
  String get awakeSleepyButton => 'I\'m sleepy — back to bed';

  @override
  String get awakeGoodnightButton => 'Goodnight';

  @override
  String get sleepDiaryTitle => 'Sleep diary';

  @override
  String get sleepDiaryVerdictEmpty => 'Log a night to get started.';

  @override
  String sleepDiaryVerdictEarly(int pct) {
    return 'Sleep efficiency $pct% so far. Five nights in, this starts to mean something — keep going.';
  }

  @override
  String sleepDiaryVerdictGood(int pct) {
    return 'Sleep efficiency $pct%: your bed is doing its job. If you\'re still tired, the lever is probably total time — try lights out 15 minutes earlier, same wake time.';
  }

  @override
  String sleepDiaryVerdictLow(int pct) {
    return 'Sleep efficiency $pct%. Under 85% means a lot of your time in bed is spent awake, which teaches the bed the wrong lesson. Tighten the window: later to bed, same wake time, until it\'s above 85%, then add 15 minutes a week.';
  }

  @override
  String sleepDiaryHoursMinutes(int hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get sleepDiaryQualityAwful => 'Awful';

  @override
  String get sleepDiaryQualityPoor => 'Poor';

  @override
  String get sleepDiaryQualityOkay => 'Okay';

  @override
  String get sleepDiaryQualityGood => 'Good';

  @override
  String get sleepDiaryQualityGreat => 'Great';

  @override
  String get sleepDiaryLightsOut => 'Lights out';

  @override
  String get sleepDiaryWoke => 'Woke for the day';

  @override
  String sleepDiaryLogged(String duration, int pct) {
    return 'Logged: $duration asleep, $pct% efficient.';
  }

  @override
  String sleepDiarySliderLabel(String label, int minutes) {
    return '$label · $minutes min';
  }

  @override
  String get sleepDiaryLastNight => 'Last night';

  @override
  String get sleepDiaryLastNightHint =>
      'Best guesses are fine — don\'t clock-watch to get this right. Rough and every day beats exact and occasional.';

  @override
  String get sleepDiaryTimeToFallAsleep => 'Time to fall asleep';

  @override
  String get sleepDiaryAwakeInNight => 'Awake during the night';

  @override
  String get sleepDiaryHowDidYouFeel => 'How did you feel on waking?';

  @override
  String get sleepDiaryYourNights => 'Your nights';

  @override
  String get sleepDiaryYourNightsHint =>
      'Sleep efficiency is the share of your time in bed you actually spend asleep. Clinics aim for 85% and above.';

  @override
  String get sleepDiaryStatEfficiency => 'Efficiency';

  @override
  String get sleepDiaryStatAsleep => 'Asleep';

  @override
  String get sleepDiaryStatNights => 'Nights';

  @override
  String sleepDiaryNightsOfSeven(int count) {
    return '$count of 7';
  }

  @override
  String sleepDiarySuggestedWindow(String bed, String wake) {
    return 'Suggested window: in bed $bed to $wake.';
  }

  @override
  String get sleepDiaryEmpty =>
      'No nights yet. Log this morning\'s and the picture starts to form within a week.';

  @override
  String sleepDiaryNightSummary(String bed, String wake, String duration) {
    return '$bed → $wake · $duration asleep';
  }

  @override
  String sleepDiaryNightDetail(
    String date,
    int latency,
    int awake,
    String quality,
  ) {
    return '$date · $latency min to drop off, $awake min awake · $quality';
  }

  @override
  String get sleepDiarySaveNight => 'Save night';

  @override
  String get sleepDiaryEditToday => 'Edit this morning\'s entry';

  @override
  String get sleepDiaryLogLastNight => 'Log last night';

  @override
  String get sleepHabitsTitle => 'Sleep habits check';

  @override
  String get sleepHabitsYes => 'Yes';

  @override
  String get sleepHabitsNo => 'No';

  @override
  String get sleepHabitsVerdictNone =>
      'Nothing here is working against you. If sleep is still hard, the diary and the 20-minute rule are the next places to look.';

  @override
  String get sleepHabitsVerdictFew =>
      'One or two habits to change — small, and they tend to pay back within a week or two.';

  @override
  String get sleepHabitsVerdictSome =>
      'A few things are stacking up against your nights. Pick the easiest one first; momentum matters more than order.';

  @override
  String get sleepHabitsVerdictMany =>
      'Quite a lot is working against you, which is actually good news: there\'s a lot of room to improve without anything drastic. Start with the wake time.';

  @override
  String get sleepHabitsAllClear => 'All clear';

  @override
  String sleepHabitsToWorkOn(int count) {
    return '$count of 10 to work on';
  }

  @override
  String get sleepHabitsAnswerAgain => 'Answer again';

  @override
  String get sleepHabitsSeeResults => 'See what to change';

  @override
  String sleepHabitsAnswered(int answered, int total) {
    return '$answered of $total answered';
  }

  @override
  String get sleepHabitsIntroTitle => 'Honest answers, please';

  @override
  String get sleepHabitsIntroHint =>
      'Most of these are ordinary — everyone has a few. Each yes comes with a specific, small change.';

  @override
  String get sleepHubTitle => 'Sleep better';

  @override
  String get sleepHubHeadline => 'Sleep is built in the daytime';

  @override
  String get sleepHubIntro =>
      'Most sleep problems aren\'t fixed in bed. They\'re fixed by a steady wake time, an evening that winds down on purpose, and not fighting the nights that go wrong. These are the tools sleep clinics use — cognitive behavioural therapy for insomnia — in a form you can start tonight.';

  @override
  String get sleepHubSoundsTitle => 'Sounds to fall asleep to';

  @override
  String get sleepHubSoundsDetail =>
      'Rainfall, crickets, pink noise and more — loops that keep going after you\'ve stopped listening.';

  @override
  String get sleepHubFootnote =>
      'Snoring with pauses in breathing, falling asleep in the day, or insomnia that\'s lasted months deserve a doctor\'s look. These tools sit alongside that, not instead of it.';

  @override
  String get tomorrowListTitle => 'Put the day down';

  @override
  String tomorrowListSummary(String top, String letGo, String good) {
    return 'Tomorrow:\n$top\n\nLetting go tonight: $letGo\nOne good thing today: $good';
  }

  @override
  String get tomorrowListSaved => 'Written down. It\'ll keep till morning.';

  @override
  String get tomorrowListSaveToJournal => 'Save to journal';

  @override
  String get tomorrowListDoneForTonight => 'Done for tonight';

  @override
  String get tomorrowListIntroTitle => 'Out of your head, onto the page';

  @override
  String get tomorrowListIntroHint =>
      'The 2am mind is a to-do list with nowhere to go. Give it somewhere. Three things for tomorrow — not ten — one thing you\'re choosing not to carry tonight, and one thing that was good today, however small.';

  @override
  String get tomorrowListTopThree => 'Tomorrow\'s three';

  @override
  String tomorrowListThing(int number) {
    return 'Thing $number';
  }

  @override
  String get tomorrowListLetGo => 'Tonight I\'m letting go of';

  @override
  String get tomorrowListLetGoHint => 'A worry that can wait until daylight';

  @override
  String get tomorrowListGood => 'One good thing today';

  @override
  String get tomorrowListGoodHint => 'Small counts';

  @override
  String get windDownTitle => 'Wind-down plan';

  @override
  String get windDownPickerTitle => 'Lights out at';

  @override
  String get windDownAllDone => 'That\'s the whole wind-down. Sleep well.';

  @override
  String get windDownIntroTitle => 'The last hour decides the night';

  @override
  String get windDownIntroHint =>
      'Bodies don\'t switch off; they dim. The same five steps in the same order, every evening, become the cue your brain waits for. Tick them off as you go.';

  @override
  String windDownLightsOutAt(String time) {
    return 'Lights out at $time';
  }

  @override
  String get windDownLightsOutHint =>
      'Same time most nights, and a wake time that never moves.';

  @override
  String get windDownReminderNote =>
      'Want a nudge when it\'s time to start? The Wind-down reminder is in Reminders.';

  @override
  String get windDownReminderButton => 'Set it';

  @override
  String windDownStepTime(String time, int minutes) {
    return '$time · $minutes min before';
  }

  @override
  String get journalEditorSaveFailed =>
      'Couldn\'t save your entry — check your connection.';

  @override
  String get journalEditorDeleteFailed =>
      'Couldn\'t delete the entry — check your connection.';

  @override
  String get journalEditorDeleteTitle => 'Delete this entry?';

  @override
  String get journalEditorDeleteBody => 'This can\'t be undone.';

  @override
  String get journalEditorDeleteTooltip => 'Delete entry';

  @override
  String get journalEditorTitleHint => 'Title (optional)';

  @override
  String get journalEditorBodyHint =>
      'Whatever\'s on your mind — this space is yours alone.';

  @override
  String get journalEditorSave => 'Save entry';

  @override
  String get journalHubTitle => 'Journal & mood';

  @override
  String get journalHubIntro =>
      'Put the day into words — start from a blank page or let a prompt do the opening line.';

  @override
  String get journalHubWriteSection => 'Write';

  @override
  String get journalHubMyJournal => 'My journal';

  @override
  String get journalHubMyJournalDetail =>
      'Every entry you\'ve written, newest first.';

  @override
  String get journalHubFreeWrite => 'Free write';

  @override
  String get journalHubFreeWriteDetail => 'A blank page, no prompt, no rules.';

  @override
  String get journalHubMoodSection => 'Mood';

  @override
  String get journalHubMoodHistory => 'Mood history';

  @override
  String get journalHubMoodHistoryDetail =>
      'Every check-in, and how the weeks actually went.';

  @override
  String get journalHubPromptPremiumTitle => 'This prompt is part of Premium';

  @override
  String journalHubPromptPremiumMessage(int count, String offer) {
    return 'Free includes a prompt to try. Premium unlocks all $count — and $offer.';
  }

  @override
  String get journalHubMoodPremiumTitle => 'Mood history is part of Premium';

  @override
  String journalHubMoodPremiumMessage(String offer) {
    return 'Checking in is always free. Premium keeps the record and shows you the pattern — and $offer.';
  }

  @override
  String get journalTitle => 'Journal';

  @override
  String get journalToday => 'Today';

  @override
  String get journalYesterday => 'Yesterday';

  @override
  String get journalUntitled => 'Untitled';

  @override
  String get journalLoadFailed => 'Couldn\'t load your journal.';

  @override
  String get journalEmpty =>
      'Your space is ready.\nWrite your first entry whenever you like.';

  @override
  String get journalIntro => 'A private place for whatever\'s on your mind.';

  @override
  String journalIntroFree(int count, int limit) {
    return 'A private place for whatever\'s on your mind · $count/$limit free entries used.';
  }

  @override
  String get practiceKindMeditation => 'Meditation';

  @override
  String get practiceKindBreathing => 'Breathing';

  @override
  String get practiceKindSound => 'Sound';

  @override
  String get feelingWorse => 'Worse';

  @override
  String get feelingSame => 'About the same';

  @override
  String get feelingBetter => 'Better';

  @override
  String feelingSummaryLine(int answered, int better) {
    String _temp0 = intl.Intl.pluralLogic(
      answered,
      locale: localeName,
      other: 'You felt better after $better of your last $answered sessions.',
    );
    return '$_temp0';
  }

  @override
  String get practiceFreeSessionsDoneTitle =>
      'You\'ve finished your free sessions';

  @override
  String practiceFreeSessionsDoneMessage(String offer) {
    return 'Premium opens all 20 meditations and every breathing exercise, with the sounds to go with them — and $offer.';
  }

  @override
  String get closeOutHowDoYouFeel => 'How do you feel now?';

  @override
  String get closeOutNoted => 'Noted. Thank you.';

  @override
  String get closeOutCompared => 'Compared with when you started.';

  @override
  String get closeOutWriteAboutIt => 'Write about it';

  @override
  String closeOutJournalSeed(String title) {
    return 'After $title, I noticed ';
  }

  @override
  String get practiceToday => 'Today';

  @override
  String get practiceYesterday => 'Yesterday';

  @override
  String get practiceDatePattern => 'd MMM';

  @override
  String get practiceDatePatternWithYear => 'd MMM y';

  @override
  String practiceSessionMeta(String kind, String date) {
    return '$kind · $date';
  }

  @override
  String practiceMinutesShort(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get practiceLoadError => 'Couldn\'t load your practice history.';

  @override
  String get practiceEmpty =>
      'Nothing here yet. Finish a meditation, a breathing session, or a few minutes of sound, and it starts filling in.';

  @override
  String get practiceLast30Days => 'Last 30 days';

  @override
  String practiceStatSessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sessions',
    );
    return '$_temp0';
  }

  @override
  String practiceStatMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'minutes',
    );
    return '$_temp0';
  }

  @override
  String practiceStatDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'day streak',
    );
    return '$_temp0';
  }

  @override
  String practiceStatThisWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'this week',
    );
    return '$_temp0';
  }

  @override
  String get practiceEverySession => 'Every session';

  @override
  String get practiceTitle => 'Your practice';

  @override
  String get practiceSubtitle =>
      'Minutes nobody else counted. They still happened.';

  @override
  String get courseDayDone => 'Done';

  @override
  String get courseDayOpensTomorrow => 'Opens tomorrow';

  @override
  String courseDayNumber(int day) {
    return 'Day $day';
  }

  @override
  String courseAllDaysDone(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'All $days days done. Come back to any of them whenever you need.',
    );
    return '$_temp0';
  }

  @override
  String courseDaysDoneProgress(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$done of $total days done · one new step each day',
    );
    return '$_temp0';
  }

  @override
  String courseCardPickedForYou(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Picked for you · $days days',
    );
    return '$_temp0';
  }

  @override
  String courseCardStepADay(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days · a step a day',
    );
    return '$_temp0';
  }

  @override
  String courseCardFinished(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Finished · all $days days',
    );
    return '$_temp0';
  }

  @override
  String courseCardReadyToday(int day, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Day $day of $total · ready today',
    );
    return '$_temp0';
  }

  @override
  String courseCardOpensTomorrow(int day) {
    return 'Day $day opens tomorrow';
  }

  @override
  String get rhythmMilestoneWeek1 => 'A first week of looking after yourself.';

  @override
  String get rhythmMilestoneWeek4 => 'A month of looking after yourself.';

  @override
  String get rhythmMilestoneWeek12 =>
      'Three months of showing up for yourself.';

  @override
  String get rhythmMilestoneWeek26 => 'Half a year of small, steady steps.';

  @override
  String get rhythmMilestoneWeek52 => 'A whole year of sunrises.';

  @override
  String get rhythmWelcomeBack => 'Welcome back';

  @override
  String get rhythmSunIsUp => 'Your sun is up this week';

  @override
  String get rhythmNewWeek => 'A new week, a new sunrise';

  @override
  String rhythmDaysThisWeek(int days, int goal) {
    String _temp0 = intl.Intl.pluralLogic(
      goal,
      locale: localeName,
      other: '$days of $goal days this week',
    );
    return '$_temp0';
  }

  @override
  String get rhythmAnyStepCounts =>
      'Any small step counts — a check-in, a breath, a few lines.';

  @override
  String rhythmShownUpWelcomeBack(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'You\'ve shown up $days days in total. Today can count too.',
      one: 'You\'ve shown up 1 day in total. Today can count too.',
    );
    return '$_temp0';
  }

  @override
  String rhythmWeeksAndTotal(int weeks, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$weeks-week rhythm · $days days in total',
      one: '$weeks-week rhythm · 1 day in total',
    );
    return '$_temp0';
  }

  @override
  String rhythmDaysInTotal(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days in total',
      one: '1 day in total',
    );
    return '$_temp0';
  }

  @override
  String rhythmCardSemantics(String headline, String detail) {
    return '$headline. $detail';
  }

  @override
  String get rhythmTitle => 'Your rhythm';

  @override
  String get rhythmWeeklyGoalHeading => 'Your weekly goal';

  @override
  String get rhythmWeeklyGoalBody =>
      'How many days a week feels right? The other days are rest days — they\'re part of the rhythm too.';

  @override
  String rhythmDaysAWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days a week',
      one: '1 day a week',
    );
    return '$_temp0';
  }

  @override
  String get rhythmLastTwelveWeeks => 'The last twelve weeks';

  @override
  String rhythmStatWeekRhythm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'week rhythm',
    );
    return '$_temp0';
  }

  @override
  String rhythmStatLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'longest',
    );
    return '$_temp0';
  }

  @override
  String rhythmStatDaysInTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days in total',
    );
    return '$_temp0';
  }

  @override
  String get rhythmWhatCounts => 'What counts';

  @override
  String get rhythmCountsMood => 'A mood check-in';

  @override
  String get rhythmCountsPractice => 'A meditation or breathing exercise';

  @override
  String get rhythmCountsSound => 'Listening to a sound';

  @override
  String get rhythmCountsJournal => 'A journal entry';

  @override
  String get rhythmNothingIsLost =>
      'One small step is enough for the day. Nothing is lost when you take a break — every day you\'ve shown up stays counted.';

  @override
  String get recoveryMilestoneDayOne => 'Day one';

  @override
  String recoveryMilestoneDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String recoveryMilestoneWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String recoveryMilestoneMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String recoveryMilestoneYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get recoveryTriggerStress => 'Stress';

  @override
  String get recoveryTriggerBoredom => 'Boredom';

  @override
  String get recoveryTriggerLoneliness => 'Loneliness';

  @override
  String get recoveryTriggerSocialPressure => 'Social pressure';

  @override
  String get recoveryTriggerTiredness => 'Tiredness';

  @override
  String get recoveryTriggerHabit => 'Habit';

  @override
  String get recoveryTriggerOther => 'Other';

  @override
  String get recoveryPartOfDayMorning => 'Morning';

  @override
  String get recoveryPartOfDayAfternoon => 'Afternoon';

  @override
  String get recoveryPartOfDayEvening => 'Evening';

  @override
  String get recoveryPartOfDayNight => 'Night';

  @override
  String get recoveryPremiumTitle => 'Recovery tracking is part of Premium';

  @override
  String recoveryPremiumMessage(String offer) {
    return 'Urge surfing is free for everyone, always. Premium adds commitment streaks, daily pledges, and the trigger tracker — and $offer.';
  }

  @override
  String get recoveryAddHabitTitle => 'What are you leaving behind?';

  @override
  String get recoveryAddHabitHint => 'e.g. Alcohol, smoking, gambling…';

  @override
  String get recoveryCountingFrom => 'Counting from';

  @override
  String get recoveryToday => 'Today';

  @override
  String get recoveryYesterday => 'Yesterday';

  @override
  String get recoveryPickADate => 'Pick a date';

  @override
  String get recoverySaveFailed => 'Couldn\'t save — check your connection.';

  @override
  String get recoveryDeleteFailed =>
      'Couldn\'t delete — check your connection.';

  @override
  String get recoveryStartCounting => 'Start counting';

  @override
  String recoveryPledgedSnack(String habit) {
    return 'Pledged: today, not $habit.';
  }

  @override
  String get recoveryResetTitle => 'Starting again?';

  @override
  String recoveryResetBody(int best) {
    String _temp0 = intl.Intl.pluralLogic(
      best,
      locale: localeName,
      other:
          'Slips happen — they don\'t erase what you learned. Your best streak ($best days) stays on record, and day one starts now.',
    );
    return '$_temp0';
  }

  @override
  String get recoveryResetConfirm => 'Reset to day one';

  @override
  String recoveryRemoveTitle(String habit) {
    return 'Remove \"$habit\"?';
  }

  @override
  String get recoveryRemoveBody => 'Its streak and pledges will be deleted.';

  @override
  String recoveryDayNumber(int day) {
    return 'Day $day';
  }

  @override
  String get recoveryResetDayOne => 'Reset day one';

  @override
  String get recoveryPastEveryMilestone =>
      'Past every milestone — extraordinary.';

  @override
  String recoveryNextMilestone(String milestone, int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Next milestone: $milestone ($daysLeft days to go)',
      one: 'Next milestone: $milestone (1 day to go)',
    );
    return '$_temp0';
  }

  @override
  String recoveryNextMilestoneWithBest(
    String milestone,
    int daysLeft,
    int best,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Next milestone: $milestone ($daysLeft days to go) · best $best',
      one: 'Next milestone: $milestone (1 day to go) · best $best',
    );
    return '$_temp0';
  }

  @override
  String get recoveryPledgedForToday => 'Pledged for today';

  @override
  String get recoveryPledgeButton => 'I\'m in for today';

  @override
  String get recoveryLogCravingTitle => 'Log a craving';

  @override
  String get recoveryLogCravingSubtitle =>
      'Noticing is progress — patterns lose power once you can see them.';

  @override
  String get recoveryLogCravingStrength => 'How strong was it?';

  @override
  String get recoveryLogCravingTrigger => 'What set it off?';

  @override
  String get recoveryLogCravingNote => 'Anything else? (optional)';

  @override
  String get recoveryCravingLogged => 'Logged. You rode it out — that counts.';

  @override
  String recoveryMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min ago',
    );
    return '$_temp0';
  }

  @override
  String recoveryHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours h ago',
    );
    return '$_temp0';
  }

  @override
  String get recoveryYesterdayLower => 'yesterday';

  @override
  String recoveryDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
    );
    return '$_temp0';
  }

  @override
  String get recoveryTitle => 'Recovery';

  @override
  String get recoverySubtitle =>
      'One day at a time — with tools for the hard minutes.';

  @override
  String get recoveryCravingNowTitle => 'Craving right now?';

  @override
  String get recoveryCravingNowBody =>
      'Urges pass. Surf this one — 8 guided minutes.';

  @override
  String get recoveryInTheMoment => 'In the moment';

  @override
  String get recoveryHaltCardTitle => 'HALT check';

  @override
  String get recoveryHaltCardDetail =>
      'Hungry, angry, lonely, tired — find out what the craving is standing in for.';

  @override
  String get recoveryTapeCardTitle => 'Play the tape forward';

  @override
  String get recoveryTapeCardDetail =>
      'Watch the rest of the film before you decide, then keep it in your journal.';

  @override
  String get recoveryMyCommitments => 'My commitments';

  @override
  String get recoveryAddButton => '+ Add';

  @override
  String get recoveryCommitmentsLocked =>
      'Count every day, pledge each morning, and celebrate milestones.';

  @override
  String get recoveryLoadError => 'Couldn\'t load your recovery data.';

  @override
  String get recoveryCommitmentsEmpty =>
      'What are you leaving behind? Add it — we\'ll count every day with you.';

  @override
  String get recoveryMilestonesCardTitle => 'Milestones';

  @override
  String get recoveryMilestonesCardDetail =>
      'Every marker, reached and ahead, for each commitment.';

  @override
  String get recoveryTriggerTracker => 'Trigger tracker';

  @override
  String get recoveryLogButton => '+ Log';

  @override
  String get recoveryTrackerLocked =>
      'Log cravings as they happen and learn what sets them off.';

  @override
  String recoveryTopTrigger(String trigger) {
    return 'Your most common trigger lately: $trigger. Naming it is half the battle.';
  }

  @override
  String get recoveryCravingsEmpty =>
      'Nothing logged yet. Next time a craving hits, ride it out and note it here.';

  @override
  String get recoveryInsightsCardTitle => 'Trigger insights';

  @override
  String get recoveryInsightsCardDetail =>
      'What sets them off, when they land, and how hard — over the last 90 days.';

  @override
  String get recoveryCrisisFooterTrailing =>
      ' Recovery is easier with backup — a licensed therapist here is never far away.';

  @override
  String get recoveryDatePattern => 'd MMM';

  @override
  String get recoveryDatePatternWithYear => 'd MMM y';

  @override
  String milestonesReachedOn(String date) {
    return 'Reached $date';
  }

  @override
  String milestonesDaysToGo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days to go',
      one: '1 day to go',
    );
    return '$_temp0';
  }

  @override
  String milestonesReached(int reached, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$reached of $total reached',
    );
    return '$_temp0';
  }

  @override
  String milestonesReachedWithBest(int reached, int total, int best) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$reached of $total reached · best $best days',
    );
    return '$_temp0';
  }

  @override
  String get milestonesLoadError => 'Couldn\'t load your commitments.';

  @override
  String get milestonesEmpty =>
      'No commitments yet. Add one on the recovery screen and every marker below starts counting from today.';

  @override
  String get milestonesTitle => 'Milestones';

  @override
  String get milestonesSubtitle =>
      'Days add up whether or not anyone claps. Here they are, counted.';

  @override
  String get triggerInsightsLoadError => 'Couldn\'t load your craving log.';

  @override
  String get triggerInsightsEmpty =>
      'Nothing logged in the last three months. Log a craving as it happens and the pattern shows up here — usually sooner than you\'d expect.';

  @override
  String triggerInsightsStatLogged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'logged',
    );
    return '$_temp0';
  }

  @override
  String get triggerInsightsStatAverage => 'average';

  @override
  String get triggerInsightsStatStrongest => 'strongest';

  @override
  String get triggerInsightsStatUsualTime => 'usual time';

  @override
  String triggerInsightsPattern(String trigger, String part) {
    String _temp0 = intl.Intl.selectLogic(part, {
      'morning':
          '$trigger in the morning is your pattern. That\'s the one worth planning for.',
      'afternoon':
          '$trigger in the afternoon is your pattern. That\'s the one worth planning for.',
      'evening':
          '$trigger in the evening is your pattern. That\'s the one worth planning for.',
      'other':
          '$trigger in the night is your pattern. That\'s the one worth planning for.',
    });
    return '$_temp0';
  }

  @override
  String get triggerInsightsWhatSetsThemOff => 'What sets them off';

  @override
  String get triggerInsightsWhenTheyLand => 'When they land';

  @override
  String get triggerInsightsFooter =>
      'Every one of these was a craving you sat with instead of acting on. That is the whole skill.';

  @override
  String get triggerInsightsTitle => 'Trigger insights';

  @override
  String get triggerInsightsSubtitle =>
      'Cravings feel random from the inside. Logged, they stop being random — and a pattern you can see is one you can plan around.';

  @override
  String get haltHungryTitle => 'Hungry';

  @override
  String get haltHungryQuestion => 'When did you last eat something proper?';

  @override
  String get haltHungryAdvice =>
      'Low blood sugar feels a lot like craving, and it argues with you the same way. Eat something first — a real meal if you can, anything if you can\'t — then see what\'s left of the urge.';

  @override
  String get haltHungryAction => 'Steady the breath while you eat';

  @override
  String get haltAngryTitle => 'Angry';

  @override
  String get haltAngryQuestion => 'Is something still sitting unsaid?';

  @override
  String get haltAngryAdvice =>
      'Anger wants somewhere to go, and the old habit is the easiest door. Give it a different one for nine minutes and see if it still wants the same thing.';

  @override
  String get haltAngryAction => 'Letting go of anger · 9 min';

  @override
  String get haltLonelyTitle => 'Lonely';

  @override
  String get haltLonelyQuestion => 'Who have you actually spoken to today?';

  @override
  String get haltLonelyAdvice =>
      'This is the one that most often gets answered with the habit. A real person beats anything else here — and if there isn\'t one right now, a session is a person.';

  @override
  String get haltLonelyAction => 'Talk to a therapist';

  @override
  String get haltTiredTitle => 'Tired';

  @override
  String get haltTiredQuestion => 'Have you slept properly this week?';

  @override
  String get haltTiredAdvice =>
      'Tired makes every urge louder and every reason quieter. Nothing you decide right now will be as good as what you decide after some rest.';

  @override
  String get haltTiredAction => 'Wind down and sleep';

  @override
  String get haltHungryLetter => 'H';

  @override
  String get haltAngryLetter => 'A';

  @override
  String get haltLonelyLetter => 'L';

  @override
  String get haltTiredLetter => 'T';

  @override
  String get haltTitle => 'HALT check';

  @override
  String get haltIntro =>
      'A craving is often something else wearing a disguise. Before you decide anything, check the four it\'s usually hiding behind — tick whichever are true.';

  @override
  String get haltNoneOfThem =>
      'None of them? Then it\'s the urge on its own — and those pass on their own too. Ride it out.';

  @override
  String get haltWhatThatMeans => 'What that means';

  @override
  String get tapeForwardHourWhen => 'In an hour';

  @override
  String get tapeForwardHourQuestion =>
      'You gave in. What does the next hour actually look like?';

  @override
  String get tapeForwardHourHint => 'Not the first five minutes — the hour.';

  @override
  String get tapeForwardMorningWhen => 'Tomorrow morning';

  @override
  String get tapeForwardMorningQuestion =>
      'You wake up. What\'s the first thing you remember?';

  @override
  String get tapeForwardMorningHint => 'How does the day start from there?';

  @override
  String get tapeForwardWeekWhen => 'A week from now';

  @override
  String get tapeForwardWeekQuestion => 'Where has this put you by next week?';

  @override
  String get tapeForwardWeekHint =>
      'And what would the other choice have bought you?';

  @override
  String get tapeForwardJournalTitle => 'Playing the tape forward';

  @override
  String get tapeForwardSaved => 'Saved to your journal.';

  @override
  String get tapeForwardTitle => 'Play the tape forward';

  @override
  String get tapeForwardIntro =>
      'A craving only ever shows you the first five minutes. Watch the rest of the film before you decide — in your own words, because yours are the ones you believe.';

  @override
  String get tapeForwardSaving => 'Saving…';

  @override
  String get tapeForwardKeep => 'Keep this in my journal';

  @override
  String get tapeForwardFooter =>
      'Next time, this is waiting for you — written by the one person the craving can\'t argue with.';

  @override
  String get rhythmWeekdayLetters => 'M T W T F S S';

  @override
  String get explorePillarMeditate => 'Meditate';

  @override
  String get explorePillarWellbeing => 'Well being';

  @override
  String get explorePillarJournal => 'Journal & mood';

  @override
  String get explorePillarRecovery => 'Recovery tools';

  @override
  String get exploreProgramCbtTitle => 'CBT for Therapy';

  @override
  String get exploreProgramCbtBlurb =>
      'Tools and reads for anxious & low thoughts';

  @override
  String get exploreProgramSleepTitle => 'Sleep better';

  @override
  String get exploreProgramSleepBlurb =>
      'A wind-down, the 20-minute rule, a sleep diary';

  @override
  String get exploreProgramStressTitle => 'Manage stress';

  @override
  String get exploreProgramStressBlurb =>
      'Bring the body down, then sort the load';

  @override
  String get exploreCollectionBreathingTitle => 'Breathing exercises';

  @override
  String get exploreCollectionBreathingSubtitle =>
      'A few minutes of paced breathing, each with its own rhythm.';

  @override
  String exploreCollectionBreathingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rhythms',
    );
    return '$_temp0';
  }

  @override
  String get exploreCollectionMeditationsTitle => 'Guided meditations';

  @override
  String get exploreCollectionMeditationsSubtitle =>
      'Timed sessions with gentle guidance on screen.';

  @override
  String exploreCollectionMeditationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
    );
    return '$_temp0';
  }

  @override
  String get exploreCollectionSoundsTitle => 'Wellbeing sounds';

  @override
  String get exploreCollectionSoundsSubtitle =>
      'Ambient sound for focus, sleep and calm. Plays on with the screen off.';

  @override
  String exploreCollectionSoundsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count loops',
    );
    return '$_temp0';
  }

  @override
  String get exploreCollectionPromptsTitle => 'Journal prompts';

  @override
  String get exploreCollectionPromptsSubtitle =>
      'A first line to get you writing, so the page is never blank.';

  @override
  String exploreCollectionPromptsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prompts',
    );
    return '$_temp0';
  }

  @override
  String get exploreCollectionReadsTitle => 'Short reads';

  @override
  String get exploreCollectionReadsSubtitle =>
      'The ideas behind the tools, a few minutes each.';

  @override
  String exploreCollectionReadsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reads',
    );
    return '$_temp0';
  }

  @override
  String get exploreCollectionRecoveryTitle => 'Recovery tools';

  @override
  String get exploreCollectionRecoverySubtitle =>
      'For cravings and the commitments you\'re keeping.';

  @override
  String exploreCollectionRecoveryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tools',
    );
    return '$_temp0';
  }

  @override
  String exploreCollectionMeta(String amount, String access) {
    return '$amount · $access';
  }

  @override
  String get exploreNeedsTitle => 'What do you need right now?';

  @override
  String get exploreSearch => 'Search';

  @override
  String get exploreFeaturedTitle => 'Our featured programs';

  @override
  String get exploreFeaturedSubtitle =>
      'Step-by-step tools and short reads, each built around one thing.';

  @override
  String get exploreBookTitle => 'Book a session';

  @override
  String get exploreBookSubtitle => 'Speak to a human therapist';

  @override
  String get exploreCoursesTitle => '7-day courses';

  @override
  String get exploreCoursesSubtitle =>
      'One step a day, in an order that builds.';

  @override
  String get exploreCollectionsTitle => 'All collections';

  @override
  String get exploreSearchRecent => 'Recent';

  @override
  String get exploreSearchClear => 'Clear';

  @override
  String get exploreSearchSuggestions => 'Try searching for';

  @override
  String get exploreSearchEmpty => 'Nothing matches that yet.';

  @override
  String get homeUiFriendFallback => 'friend';

  @override
  String homeUiUnlockItem(String item) {
    return 'Unlock “$item”';
  }

  @override
  String get homeUiSeePremium => 'See Premium';

  @override
  String get homeUiUnlockWithPremium => 'Unlock with Premium';

  @override
  String get homeUiSignedOutError =>
      'You\'ve been signed out. Please log in again.';

  @override
  String get homeUiJournalCapTitle => 'You\'ve filled your free pages';

  @override
  String homeUiJournalCapMessage(int count, String offer) {
    return 'The free plan includes $count journal entries. Premium unlocks unlimited journaling — and $offer.';
  }

  @override
  String homeUiComingSoon(String feature) {
    return '$feature is coming soon — stay close.';
  }

  @override
  String get homeUiSeeAll => 'See all';

  @override
  String get homeUiPremiumChip => 'Premium';

  @override
  String get moodAwful => 'Awful';

  @override
  String get moodLow => 'Low';

  @override
  String get moodOkay => 'Okay';

  @override
  String get moodGood => 'Good';

  @override
  String get moodGreat => 'Great';

  @override
  String get moodHistoryTitle => 'Mood history';

  @override
  String get moodHistoryIntro =>
      'Hard weeks feel permanent while you\'re in them. This is the record that says otherwise.';

  @override
  String get moodHistoryToday => 'Today';

  @override
  String get moodHistoryYesterday => 'Yesterday';

  @override
  String get moodHistoryDatePattern => 'd MMM';

  @override
  String get moodHistoryDatePatternWithYear => 'd MMM y';

  @override
  String get moodHistoryLoadError => 'Couldn\'t load your check-ins.';

  @override
  String get moodHistoryEmpty =>
      'No check-ins yet. Tap a face on the home screen and this fills in — one day at a time.';

  @override
  String get moodHistoryLast30Days => 'Last 30 days';

  @override
  String get moodHistoryStatCheckIns => 'check-ins';

  @override
  String get moodHistoryStatStreak => 'day streak';

  @override
  String get moodHistoryStatAverage => 'average';

  @override
  String get moodHistoryStatMostDays => 'most days';

  @override
  String get moodHistoryEveryCheckIn => 'Every check-in';

  @override
  String get moodInsightsUpgradeTitle => 'Insights are part of Premium';

  @override
  String moodInsightsUpgradeMessage(String offer) {
    return 'See how your practice, your week and your moods connect — and $offer.';
  }

  @override
  String get moodInsightsTitle => 'Your insights';

  @override
  String get moodInsightsIntro =>
      'From your check-ins, practice and how sessions left you, over the last 90 days.';

  @override
  String get moodInsightsEmpty =>
      'Not enough to go on yet. Check in each day and answer the question at the end of a session — insights start appearing within a week or two.';

  @override
  String moodInsightCheckedInTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You\'ve checked in $count days this month',
      one: 'You\'ve checked in 1 day this month',
    );
    return '$_temp0';
  }

  @override
  String moodInsightCheckedInStreak(int count) {
    return 'That\'s $count days in a row right now. Noticing is where change starts.';
  }

  @override
  String get moodInsightCheckedInFirst =>
      'Every check-in makes the picture clearer.';

  @override
  String get moodInsightPracticeHigherTitle =>
      'Your mood is higher on days you practise';

  @override
  String get moodInsightPracticeHigherDetail =>
      'Days with a meditation, breathing or a sound score better than days without. Worth keeping a small daily habit.';

  @override
  String get moodInsightPracticeLowerTitle =>
      'You tend to practise on harder days';

  @override
  String get moodInsightPracticeLowerDetail =>
      'Your practice days have lower moods — which may mean you reach for it when you need it. That\'s what it\'s for.';

  @override
  String get moodInsightPracticeSameTitle =>
      'Practice days and other days look alike so far';

  @override
  String get moodInsightPracticeSameDetail =>
      'Keep checking in — the pattern gets clearer with a few more weeks.';

  @override
  String moodWeekdays(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'mon': 'Mondays',
      'tue': 'Tuesdays',
      'wed': 'Wednesdays',
      'thu': 'Thursdays',
      'fri': 'Fridays',
      'sat': 'Saturdays',
      'other': 'Sundays',
    });
    return '$_temp0';
  }

  @override
  String moodWeekdaysMidSentence(String day) {
    String _temp0 = intl.Intl.selectLogic(day, {
      'mon': 'mondays',
      'tue': 'tuesdays',
      'wed': 'wednesdays',
      'thu': 'thursdays',
      'fri': 'fridays',
      'sat': 'saturdays',
      'other': 'sundays',
    });
    return '$_temp0';
  }

  @override
  String moodInsightHardestDayTitle(String weekday) {
    return '$weekday are usually your hardest days';
  }

  @override
  String moodInsightHardestDayDetail(String bestDay, String hardestDay) {
    return '$bestDay tend to go best. A little something planned for $hardestDay could help.';
  }

  @override
  String get moodInsightBetterTitle => 'The last two weeks have been better';

  @override
  String get moodInsightBetterDetail =>
      'Your check-ins are up on the fortnight before. Whatever you\'re doing, it\'s worth noticing.';

  @override
  String get moodInsightHarderTitle => 'The last two weeks have been harder';

  @override
  String get moodInsightHarderDetail =>
      'Your check-ins are down on the fortnight before. Be gentle with yourself — and talking to someone can help.';

  @override
  String get moodInsightFeelingsDetail =>
      'From how you said you felt at the end of each session.';

  @override
  String get breathingBreatheIn => 'Breathe in';

  @override
  String get breathingHold => 'Hold';

  @override
  String get breathingBreatheOut => 'Breathe out';

  @override
  String breathingMinutesChip(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get breathingBegin => 'Begin';

  @override
  String get breathingWellDone => 'Well done';

  @override
  String breathingDoneSummary(int minutes, int cycles) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0 · about $cycles breath cycles.\nNotice how you feel right now.';
  }

  @override
  String get breathingAddedToHistory => 'Added to your practice history.';

  @override
  String get breathingGoAgain => 'Go again';

  @override
  String get breathingEndSession => 'End session';

  @override
  String get meditationsUpgradeTitle => 'This session is part of Premium';

  @override
  String meditationsUpgradeMessage(String offer) {
    return 'Free includes a taste of each practice. Premium unlocks every session — and $offer.';
  }

  @override
  String meditationsItemMeta(int minutes, String detail) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
    );
    return '$_temp0 · $detail';
  }

  @override
  String get meditationsTitle => 'Meditations & breathing';

  @override
  String get meditationsIntro =>
      'A few minutes of guided calm — breathe along with the circle, or settle into a quiet session.';

  @override
  String get meditationsBreathingHeader => 'Breathing exercises';

  @override
  String get meditationsMeditationsHeader => 'Meditations';

  @override
  String get soundsUpgradeTitle => 'This sound is part of Premium';

  @override
  String soundsUpgradeMessage(String offer) {
    return 'Free includes one sound to try. Premium unlocks the whole library — and $offer.';
  }

  @override
  String get soundsPlayError => 'Couldn\'t play that sound.';

  @override
  String soundsPlayingCategory(String category) {
    return 'Playing · $category';
  }

  @override
  String get soundsTitle => 'Wellbeing sounds';

  @override
  String get soundsIntro =>
      'Loops that stay with you — pick one and let it run while you focus, drift off, or settle down.';

  @override
  String get soundsFilterAll => 'All';

  @override
  String get soundsStop => 'Stop sound';

  @override
  String get soundPlayerFallbackTitle => 'Wellbeing sound';

  @override
  String playerSleepTimerStopsIn(String time) {
    return 'Stops in $time · cancel';
  }

  @override
  String playerSleepTimerOption(int minutes) {
    return '${minutes}m';
  }

  @override
  String get meditationVoiceChip => 'Voice';

  @override
  String get meditationSessionComplete => 'Session complete';

  @override
  String meditationCompleteBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other:
          '$minutes quiet minutes, just for you.\nCarry a little of this with you.',
    );
    return '$_temp0';
  }

  @override
  String get meditationAddedToHistory => 'Added to your practice history.';

  @override
  String get meditationRemaining => 'remaining';

  @override
  String get meditationNoSound => 'No sound';

  @override
  String get needSleep => 'Can\'t sleep';

  @override
  String get needAnxious => 'Anxious';

  @override
  String get needPanic => 'Panicking';

  @override
  String get needLow => 'Feeling low';

  @override
  String get needStressed => 'Stressed';

  @override
  String get needAngry => 'Angry';

  @override
  String get needUrges => 'Urges';

  @override
  String get needFocus => 'Focus';

  @override
  String get needReflect => 'Reflect';

  @override
  String get needGood => 'Feeling good';

  @override
  String get needSleepIntro =>
      'For the evening before, and the hours you\'re lying awake.';

  @override
  String get needAnxiousIntro =>
      'Ways to bring a racing mind back to what\'s in front of you.';

  @override
  String get needPanicIntro =>
      'Quick and simple first. These work best started straight away.';

  @override
  String get needLowIntro =>
      'Small, kind things for heavy days. Start with whichever feels doable.';

  @override
  String get needStressedIntro =>
      'Bring the body down first, then sort what\'s on your plate.';

  @override
  String get needAngryIntro => 'Let it cool before you act on it.';

  @override
  String get needUrgesIntro =>
      'Ride it out: urges peak and pass, usually within minutes.';

  @override
  String get needFocusIntro => 'Clear your head and settle into one thing.';

  @override
  String get needReflectIntro =>
      'Prompts and reads for making sense of things.';

  @override
  String get needGoodIntro =>
      'Notice what\'s going right, so it stays with you.';

  @override
  String get dayPartMorning => 'For this morning';

  @override
  String get dayPartAfternoon => 'For this afternoon';

  @override
  String get dayPartEvening => 'For this evening';

  @override
  String get dayPartNight => 'For tonight';

  @override
  String get contentKindBreathing => 'Breathing';

  @override
  String get contentKindMeditation => 'Meditation';

  @override
  String get contentKindSound => 'Sound';

  @override
  String get contentKindPrompt => 'Journal prompt';

  @override
  String get contentKindTool => 'Tool';

  @override
  String get contentKindLesson => 'Read';

  @override
  String get contentKindRecovery => 'Recovery';

  @override
  String get lengthAny => 'Any length';

  @override
  String get lengthShort => 'Under 5 min';

  @override
  String get lengthMedium => '5–10 min';

  @override
  String get lengthLong => 'Over 10 min';

  @override
  String contentMeta(String what, int minutes) {
    return '$what · $minutes min';
  }

  @override
  String get contentPremiumTitle => 'This is part of Premium';

  @override
  String contentPremiumMessage(String offer) {
    return 'Free includes a taste of everything. Premium unlocks every session, tool and read — and $offer.';
  }

  @override
  String get contentNewBadge => 'New';

  @override
  String get contentSaveTooltip => 'Save';

  @override
  String get contentUnsaveTooltip => 'Remove from saved';

  @override
  String get contentPremiumLabel => 'Premium';

  @override
  String get contentNothingThatLength => 'Nothing that length yet.';

  @override
  String get meditationSoundPremiumTitle => 'This sound is part of Premium';

  @override
  String meditationSoundPremiumMessage(String offer) {
    return 'Free includes one sound to try. Premium unlocks the whole library — and $offer.';
  }

  @override
  String get homeQuickMeditate => 'Meditate';

  @override
  String get homeQuickMeditateSub => 'Breathe & settle';

  @override
  String get homeQuickJournal => 'Journal';

  @override
  String get homeQuickJournalSub => 'Write it out';

  @override
  String get homeQuickSounds => 'Sounds';

  @override
  String get homeQuickSoundsSub => 'Focus · sleep · calm';

  @override
  String get homeQuickRecovery => 'Recovery';

  @override
  String get homeQuickRecoverySub => 'One day at a time';

  @override
  String get homeThanksForCheckingIn => 'Thanks for checking in.';

  @override
  String get homeMoodSaveFailed =>
      'Couldn\'t save your mood — check your connection.';

  @override
  String get homeNudgeCheckinsTitle => 'Three check-ins in';

  @override
  String homeNudgeCheckinsMessage(String offer) {
    return 'You\'re building a habit. Premium keeps every check-in and shows you how the weeks are actually going — and $offer.';
  }

  @override
  String get homeMoodHistoryPremiumTitle => 'Mood history is part of Premium';

  @override
  String homeMoodHistoryPremiumMessage(String offer) {
    return 'Checking in is always free. Premium keeps the record and shows you the pattern — and $offer.';
  }

  @override
  String get homeGreetingMorning => 'Good morning,';

  @override
  String get homeGreetingAfternoon => 'Good afternoon,';

  @override
  String get homeGreetingEvening => 'Good evening,';

  @override
  String get homeYourPractice => 'Your practice';

  @override
  String homePracticeSummary(int minutes, int sessions) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
    );
    String _temp1 = intl.Intl.pluralLogic(
      sessions,
      locale: localeName,
      other: '$sessions sessions',
    );
    return '$_temp0 this week · $_temp1 in all';
  }

  @override
  String homeLastTime(String title) {
    return 'Last time: $title';
  }

  @override
  String get homeSuggestionLow => 'Something that might help';

  @override
  String get homeSuggestionOkay => 'Something for right now';

  @override
  String get homeSuggestionGood => 'Something to keep it going';

  @override
  String homeMoreForNeed(String need) {
    return 'More for “$need”';
  }

  @override
  String get homeYourWeek => 'Your week';

  @override
  String get homeHistory => 'History';

  @override
  String get homeHowAreYouFeeling => 'How are you feeling today?';

  @override
  String get homeTodaysPrompt => 'TODAY\'S PROMPT';

  @override
  String get homeTodaysRead => 'TODAY\'S READ';

  @override
  String get homeNeedHelpNow => 'Need help now?';

  @override
  String get homeSaved => 'Saved';

  @override
  String get homeYourInsights => 'Your insights';

  @override
  String get homeInsightsSub =>
      'How practice, your week and your moods connect.';

  @override
  String get homeBeforeSessionJournalTitle => 'Before my session';

  @override
  String get homeBeforeSessionJournalSeed =>
      'In my session, I\'d like to talk about ';

  @override
  String get homeBeforeSessionTitle => 'Before your session';

  @override
  String get homeBeforeSessionSub =>
      'Jot down what you want to talk about, so nothing slips away when the call starts.';

  @override
  String get homeFromLastSession => 'FROM YOUR LAST SESSION';

  @override
  String get homeReadItAll => 'Read it all';

  @override
  String get homePractiseUntilNext => 'Something to practise until next time';

  @override
  String homeToday(String time) {
    return 'Today, $time';
  }

  @override
  String homeTomorrow(String time) {
    return 'Tomorrow, $time';
  }

  @override
  String homeYourSession(String when) {
    return 'Your session · $when';
  }

  @override
  String get homeSessionOpen => 'It\'s open now — tap to join.';

  @override
  String get homeSessionDetails =>
      'Tap for the details, or to join when it opens.';

  @override
  String get homeFindingTherapist => 'Finding your therapist';

  @override
  String get homeFindingTherapistSub =>
      'We\'ll let you know as soon as your session is booked.';

  @override
  String get homeTalkToTherapist => 'Talk to a real therapist';

  @override
  String homeTalkToTherapistSub(String price) {
    return '$price a session, paid when you book.';
  }

  @override
  String get homeQuickAccess => 'Quick access';

  @override
  String get downloadAction => 'Download for offline';

  @override
  String get downloadDone => 'Downloaded';

  @override
  String get downloadQueued => 'Waiting to download · tap to cancel';

  @override
  String get downloadWaitingWifi => 'Waiting for Wi-Fi · tap to cancel';

  @override
  String downloadProgress(int percent) {
    return 'Downloading $percent% · tap to cancel';
  }

  @override
  String get downloadFailed => 'Download failed · tap to try again';

  @override
  String get downloadRemove => 'Remove download';

  @override
  String get downloadCourse => 'Download course';

  @override
  String get downloadCourseDone => 'Course downloaded';

  @override
  String downloadCourseProgress(int done, int total) {
    return 'Downloading · $done of $total ready';
  }

  @override
  String get downloadCourseWaiting => 'Waiting for Wi-Fi to download';

  @override
  String get downloadPreparing => 'Getting this sound ready…';

  @override
  String get downloadNeedsConnection =>
      'Couldn\'t get that sound. Connect to the internet to play it the first time.';

  @override
  String get downloadPremiumNeeded => 'This sound is part of Premium.';

  @override
  String get downloadCouldNotPlay => 'Couldn\'t play that sound.';

  @override
  String get downloadsTitle => 'Downloads & storage';

  @override
  String get downloadsIntro =>
      'Sounds and meditations you\'ve downloaded play without a connection. Delete them here to free up space.';

  @override
  String get downloadsWifiOnly => 'Download on Wi-Fi only';

  @override
  String get downloadsWifiOnlyDetail =>
      'Downloads wait for Wi-Fi, so they don\'t use your mobile data.';

  @override
  String downloadsUsing(String size) {
    return 'Using $size on this phone';
  }

  @override
  String get downloadsInProgress => 'In progress';

  @override
  String get downloadsOnPhone => 'On this phone';

  @override
  String get downloadsEmpty =>
      'Nothing downloaded yet. Tap the download button on a sound, meditation or course to keep it for when you\'re offline.';

  @override
  String get downloadsDeleteAll => 'Delete all downloads';

  @override
  String get downloadsDeleteAllTitle => 'Delete all downloads?';

  @override
  String get downloadsDeleteAllBody =>
      'They\'ll be removed from this phone. You can download them again any time.';

  @override
  String downloadsDeleteOne(String title) {
    return 'Delete $title';
  }

  @override
  String get backgroundCalmVisuals => 'Calm visuals';

  @override
  String get backgroundCalmVisualsHint =>
      'Slowly moving backgrounds behind sounds and sessions. Off holds them still.';

  @override
  String get backgroundReduceMotionNote =>
      'Your phone is set to reduce motion, so backgrounds stay still.';

  @override
  String get backgroundPickerTitle => 'Background';

  @override
  String get backgroundPickerTooltip => 'Change background';

  @override
  String get settingsSubscriptionManagement => 'Subscription management';

  @override
  String get settingsRestoringPurchases => 'Restoring purchases';

  @override
  String get settingsPremiumRestored => 'Premium restored — welcome back.';

  @override
  String get settingsNoPurchasesFound => 'No previous purchases found.';

  @override
  String get settingsLogOutTitle => 'Log out?';

  @override
  String get settingsLogOutBody =>
      'You can always come back — your progress stays safe.';

  @override
  String get settingsLogOut => 'Log out';

  @override
  String get settingsDeleting => 'Deleting your account…';

  @override
  String get settingsDeleteFailed =>
      'Couldn\'t finish deleting your account. Your request is on file and we\'ll complete it — or try again.';

  @override
  String get settingsYourAccount => 'Your account';

  @override
  String get settingsPremiumPlan => 'Premium';

  @override
  String get settingsFreePlan => 'Free plan';

  @override
  String get settingsPremiumTagline => 'Every room in the house is open.';

  @override
  String get settingsManage => 'Manage';

  @override
  String get settingsUpgrade => 'Upgrade';

  @override
  String get settingsCareTeam => 'Care team';

  @override
  String get settingsCareDashboard => 'Care team dashboard';

  @override
  String get settingsMyTherapySessions => 'My therapy sessions';

  @override
  String get settingsGoalsTitle => 'What would help most?';

  @override
  String get settingsGoalsSub => 'We\'ll put these first in your suggestions.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSystemHint =>
      'Light by day, dark when your phone is.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsReminders => 'Reminders & notifications';

  @override
  String get settingsGoals => 'What would help most';

  @override
  String get settingsRestorePurchases => 'Restore purchases';

  @override
  String get settingsSupport => 'Support';

  @override
  String get settingsCrisisResources => 'Crisis resources';

  @override
  String get settingsContactUs => 'Contact us';

  @override
  String get settingsFaq => 'FAQ';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsTerms => 'Terms of service';

  @override
  String get settingsAccountActions => 'Account actions';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteTitle => 'Delete your account?';

  @override
  String get settingsDeleteBody =>
      'This removes your profile, journal entries, mood check-ins, recovery streaks, craving logs, therapy requests and photo. It happens straight away and it can\'t be undone.';

  @override
  String get settingsKeepAccount => 'Keep my account';

  @override
  String get settingsDeleteForGood => 'Delete for good';

  @override
  String settingsPasswordResetSent(String email) {
    return 'Password reset link sent to $email';
  }

  @override
  String settingsEmailCopied(String email) {
    return 'Email address copied: $email';
  }

  @override
  String settingsTypeToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String settingsGoalsMore(String first, int more) {
    return '$first +$more';
  }

  @override
  String get crisisChangeCountry => 'Change country';

  @override
  String get crisisUsePhoneCountry => 'Use my phone\'s country';

  @override
  String get crisisUncheckedNumbers =>
      'Draft: these numbers haven\'t been checked yet. In an emergency, call the number above.';
}
