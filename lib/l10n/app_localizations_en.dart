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
}
