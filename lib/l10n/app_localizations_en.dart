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
}
