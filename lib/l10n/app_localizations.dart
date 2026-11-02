import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Shown in place of a part of a screen that failed to draw.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong here.'**
  String get somethingWentWrongTitle;

  /// Under somethingWentWrongTitle: reassurance that no data was lost.
  ///
  /// In en, this message translates to:
  /// **'Go back and try again — nothing you saved is affected.'**
  String get somethingWentWrongBody;

  /// Appearance choice in Settings: follow the phone's light/dark setting.
  ///
  /// In en, this message translates to:
  /// **'Match my phone'**
  String get appearanceSystem;

  /// Appearance choice in Settings: always light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// Appearance choice in Settings: always dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// Settings row and picker title for choosing the app's language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Language choice in Settings: follow the phone's language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// Subtitle under languageSystemDefault in the language picker.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone\'s language.'**
  String get languageSystemDefaultHint;

  /// Button: retry an action that failed (usually loading or saving).
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Button: close a dialog or sheet without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Button: finish a step or close a screen when finished.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Button: go on to the next step.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// Button: remove an item (e.g. from a list).
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// Button: decline an offer or prompt for now, politely.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// Button: go back to the previous step.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Button: stop an exercise, timer or sound.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// Button: save changes.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Button or tooltip: close a screen, sheet or dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Button: change a choice already made.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get commonChange;

  /// Button: delete something permanently.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// First onboarding screen heading, greeting the person by first name.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String onboardingWelcomeTitle(String name);

  /// Used in place of a first name in onboardingWelcomeTitle when we don't know the person's name ("Welcome, friend").
  ///
  /// In en, this message translates to:
  /// **'friend'**
  String get onboardingWelcomeFriend;

  /// First onboarding screen, under the app name "yournotalone": the story behind the name. The app name itself stays in English; the quoted phrase is its meaning. Warm, reassuring.
  ///
  /// In en, this message translates to:
  /// **'It\'s Greek for \"you\'re not alone\" — the promise this app is built on. Like the four pillars in our logo, support stands strongest side by side. Whatever you\'re carrying, from today you don\'t carry it by yourself.'**
  String get onboardingWelcomeStory;

  /// Onboarding "what's inside" screen: title of one feature card. Short.
  ///
  /// In en, this message translates to:
  /// **'Mood tracking & journaling'**
  String get onboardingFeatureMoodTitle;

  /// Onboarding "what's inside" screen: one-sentence benefit under the feature card "Mood tracking & journaling".
  ///
  /// In en, this message translates to:
  /// **'Check in with yourself daily and put feelings into words, in a space that\'s completely private.'**
  String get onboardingFeatureMoodBenefit;

  /// Onboarding "what's inside" screen: title of one feature card. Short.
  ///
  /// In en, this message translates to:
  /// **'Guided meditations & breathing'**
  String get onboardingFeatureMeditationTitle;

  /// Onboarding "what's inside" screen: one-sentence benefit under the feature card "Guided meditations & breathing".
  ///
  /// In en, this message translates to:
  /// **'Short guided sessions that steady your breath and quiet a racing mind.'**
  String get onboardingFeatureMeditationBenefit;

  /// Onboarding "what's inside" screen: title of one feature card. Short.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing sounds'**
  String get onboardingFeatureSoundsTitle;

  /// Onboarding "what's inside" screen: one-sentence benefit under the feature card "Wellbeing sounds".
  ///
  /// In en, this message translates to:
  /// **'Soundscapes for focus, sleep, and calming down — whenever you need to reset.'**
  String get onboardingFeatureSoundsBenefit;

  /// Onboarding "what's inside" screen: title of one feature card. Short.
  ///
  /// In en, this message translates to:
  /// **'Progress insights & reminders'**
  String get onboardingFeatureInsightsTitle;

  /// Onboarding "what's inside" screen: one-sentence benefit under the feature card "Progress insights & reminders".
  ///
  /// In en, this message translates to:
  /// **'See your patterns over time and get gentle nudges that keep you going.'**
  String get onboardingFeatureInsightsBenefit;

  /// Onboarding "what's inside" screen: title of one feature card. Short.
  ///
  /// In en, this message translates to:
  /// **'Addiction recovery tools'**
  String get onboardingFeatureRecoveryTitle;

  /// Onboarding "what's inside" screen: one-sentence benefit under the feature card "Addiction recovery tools".
  ///
  /// In en, this message translates to:
  /// **'Practical resources for fighting addiction — one day at a time.'**
  String get onboardingFeatureRecoveryBenefit;

  /// Onboarding "what's inside" screen: title of one feature card. Short.
  ///
  /// In en, this message translates to:
  /// **'Real human therapy'**
  String get onboardingFeatureTherapyTitle;

  /// Onboarding "what's inside" screen: one-sentence benefit under the feature card "Real human therapy".
  ///
  /// In en, this message translates to:
  /// **'Talk with a licensed therapist in private one-on-one sessions, right from the app.'**
  String get onboardingFeatureTherapyBenefit;

  /// Heading of the second onboarding screen, which lists what the app offers. Warm, supportive.
  ///
  /// In en, this message translates to:
  /// **'Here to hold you up'**
  String get onboardingFeaturesTitle;

  /// Intro under onboardingFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'A quick look at what\'s inside — and how each piece helps you feel better, day by day.'**
  String get onboardingFeaturesIntro;

  /// Onboarding wellbeing check-in: one answer to "How are you feeling these days?", written in the first person. Short.
  ///
  /// In en, this message translates to:
  /// **'Doing okay'**
  String get onboardingCheckinSteady;

  /// Onboarding check-in: first-person explanation under the answer "Doing okay". Sensitive mental-health wording; keep it gentle.
  ///
  /// In en, this message translates to:
  /// **'I\'m here to keep my balance and build good habits.'**
  String get onboardingCheckinSteadyDetail;

  /// Onboarding wellbeing check-in: one answer to "How are you feeling these days?", written in the first person. Short.
  ///
  /// In en, this message translates to:
  /// **'Stressed or low lately'**
  String get onboardingCheckinStressed;

  /// Onboarding check-in: first-person explanation under the answer "Stressed or low lately". Sensitive mental-health wording; keep it gentle.
  ///
  /// In en, this message translates to:
  /// **'Work, life, or my mood has been weighing on me.'**
  String get onboardingCheckinStressedDetail;

  /// Onboarding wellbeing check-in: one answer to "How are you feeling these days?", written in the first person. Short.
  ///
  /// In en, this message translates to:
  /// **'Struggling'**
  String get onboardingCheckinStruggling;

  /// Onboarding check-in: first-person explanation under the answer "Struggling". Sensitive mental-health wording; keep it gentle.
  ///
  /// In en, this message translates to:
  /// **'It\'s been heavy for a while and I could use support.'**
  String get onboardingCheckinStrugglingDetail;

  /// Onboarding wellbeing check-in: one answer to "How are you feeling these days?", written in the first person. Short.
  ///
  /// In en, this message translates to:
  /// **'In a dark place'**
  String get onboardingCheckinDarkPlace;

  /// Onboarding check-in: first-person explanation under the answer "In a dark place". Sensitive mental-health wording; keep it gentle.
  ///
  /// In en, this message translates to:
  /// **'I\'m going through something serious right now.'**
  String get onboardingCheckinDarkPlaceDetail;

  /// Heading of the onboarding wellbeing check-in.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling these days?'**
  String get onboardingCheckinTitle;

  /// Intro under onboardingCheckinTitle.
  ///
  /// In en, this message translates to:
  /// **'This helps us point you to the right kind of support first. It stays private, and you can change it anytime.'**
  String get onboardingCheckinIntro;

  /// Onboarding check-in: heading above chips of goals (sleep, anxiety, stress…) the person can pick.
  ///
  /// In en, this message translates to:
  /// **'What would help most?'**
  String get onboardingGoalsTitle;

  /// Hint under onboardingGoalsTitle: any number of goals can be picked and matching suggestions are shown first.
  ///
  /// In en, this message translates to:
  /// **'Pick any. We\'ll put these first for you.'**
  String get onboardingGoalsHint;

  /// Notification permission screen: first kind of notification we send. Short title.
  ///
  /// In en, this message translates to:
  /// **'Your therapy sessions'**
  String get onboardingNotificationsSessionsTitle;

  /// Notification permission screen: explains therapy-session notifications.
  ///
  /// In en, this message translates to:
  /// **'When you\'re matched, if the time moves, and ten minutes before the call — so a paid session is never missed.'**
  String get onboardingNotificationsSessionsDetail;

  /// Notification permission screen: second kind of notification. Short title.
  ///
  /// In en, this message translates to:
  /// **'Reminders you choose'**
  String get onboardingNotificationsRemindersTitle;

  /// Notification permission screen: explains optional reminders. "Evening pages" = evening journaling.
  ///
  /// In en, this message translates to:
  /// **'A morning check-in, evening pages, a wind-down. Each one is a switch in Settings; none is on until you say.'**
  String get onboardingNotificationsRemindersDetail;

  /// Notification permission screen: third point — we send no other notifications. Short title.
  ///
  /// In en, this message translates to:
  /// **'Nothing else'**
  String get onboardingNotificationsNothingElseTitle;

  /// Notification permission screen: promise that no marketing notifications are sent.
  ///
  /// In en, this message translates to:
  /// **'No marketing, no streak guilt, no \"we miss you\". If it isn\'t about your care, it isn\'t sent.'**
  String get onboardingNotificationsNothingElseDetail;

  /// Button on the notification permission screen; triggers the system permission prompt.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get onboardingNotificationsTurnOn;

  /// Button on the notification permission screen: skip for now.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get onboardingNotificationsMaybeLater;

  /// Heading of the notification permission screen (last onboarding step).
  ///
  /// In en, this message translates to:
  /// **'Don\'t miss what matters'**
  String get onboardingNotificationsTitle;

  /// Intro on the notification permission screen, before the system prompt.
  ///
  /// In en, this message translates to:
  /// **'Your phone will ask once. Here\'s exactly what a yes means.'**
  String get onboardingNotificationsIntro;

  /// Appended (note the leading space) to the crisis-help footer sentence on the onboarding therapy offer screen. Keep the leading space unless your language joins sentences without spaces.
  ///
  /// In en, this message translates to:
  /// **' This app can\'t replace emergency care.'**
  String get onboardingTherapyCrisisTrailing;

  /// Button on the onboarding therapy offer: yes, interested in therapy sessions.
  ///
  /// In en, this message translates to:
  /// **'I\'d like that'**
  String get onboardingTherapyYes;

  /// Button on the onboarding therapy offer: not interested for now. Gentle.
  ///
  /// In en, this message translates to:
  /// **'Not right now'**
  String get onboardingTherapyNo;

  /// Heading of the onboarding therapy offer, shown to people who said they are struggling. Warm and supportive.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to do this alone'**
  String get onboardingTherapyTitle;

  /// Onboarding therapy offer intro. "yournotalone" is the app name — keep it as is.
  ///
  /// In en, this message translates to:
  /// **'Some seasons are too heavy to carry with an app alone — and that\'s exactly why we work with real people. yournotalone offers private one-on-one sessions with licensed therapists, right from here.'**
  String get onboardingTherapyIntro;

  /// Onboarding therapy offer card title. {price} is a formatted price such as "$20".
  ///
  /// In en, this message translates to:
  /// **'A real therapist, {price} a session'**
  String onboardingTherapyPrice(String price);

  /// Onboarding therapy offer card body. "Talk to a therapist" is the name of a button on the Home screen — translate it the same way as that button.
  ///
  /// In en, this message translates to:
  /// **'One session at a time, no subscription. You pay when you book, from Talk to a therapist on your Home screen, and our care team matches you within a day.'**
  String get onboardingTherapyHowItWorks;

  /// Clause about the free trial, inserted at the end of other sentences such as "Unlock every session — and {introOffer}." Starts lower-case, no final full stop. Never names a trial length.
  ///
  /// In en, this message translates to:
  /// **'you can try it free first'**
  String get billingIntroOffer;

  /// Stand-alone sentence about the free trial, shown on the paywall when store prices are unavailable. Never names a trial length.
  ///
  /// In en, this message translates to:
  /// **'Every plan starts with a free trial.'**
  String get billingIntroOfferSentence;

  /// Snackbar when the app store refuses purchases on this device (e.g. parental controls).
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t allowed on this device.'**
  String get billingErrorNotAllowed;

  /// Snackbar when a subscription payment is pending. "premium" = the Premium subscription.
  ///
  /// In en, this message translates to:
  /// **'Your payment is pending — premium unlocks once it clears.'**
  String get billingErrorPending;

  /// Snackbar when a purchase fails for network reasons.
  ///
  /// In en, this message translates to:
  /// **'Network trouble — check your connection and try again.'**
  String get billingErrorNetwork;

  /// Snackbar when the app-store account already owns the subscription under a different app account.
  ///
  /// In en, this message translates to:
  /// **'This store account already has a subscription. Sign in with the account you bought it with, or contact support.'**
  String get billingErrorAlreadyOwned;

  /// Snackbar for any other purchase failure.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through. Please try again.'**
  String get billingErrorGeneric;

  /// Android notification channel name (shown in the phone's notification settings) for subscription reminders.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get billingTrialChannelName;

  /// Android notification channel description for subscription reminders.
  ///
  /// In en, this message translates to:
  /// **'A heads-up before a free trial ends'**
  String get billingTrialChannelDescription;

  /// Apple's store, as used inside billingTrialReminderBody ("cancel any time in the App Store"). Brand name; adapt article/grammar only.
  ///
  /// In en, this message translates to:
  /// **'the App Store'**
  String get billingStoreAppStore;

  /// Google's store, as used inside billingTrialReminderBody. Brand name.
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get billingStoreGooglePlay;

  /// Notification title, two days before a free trial turns into a paid subscription.
  ///
  /// In en, this message translates to:
  /// **'Your Premium trial ends soon'**
  String get billingTrialReminderTitle;

  /// Notification body before a free trial ends. {date} is a formatted date like "Wed 1 Oct"; {store} is billingStoreAppStore or billingStoreGooglePlay.
  ///
  /// In en, this message translates to:
  /// **'From {date} it continues at the plan price. Keep it, or cancel any time in {store}.'**
  String billingTrialReminderBody(String date, String store);

  /// Paywall headline for people who said at onboarding they are struggling or in a dark place. Gentle, not salesy.
  ///
  /// In en, this message translates to:
  /// **'Support for the hard weeks'**
  String get paywallHardWeeksHeadline;

  /// Paywall text under paywallHardWeeksHeadline. Gentle, not salesy.
  ///
  /// In en, this message translates to:
  /// **'Somewhere to put the day down, every day: guided meditations for the nights that won\'t settle, a journal that keeps up, and a record of how the weeks actually go — so the next hard one is easier to see coming.'**
  String get paywallHardWeeksDetail;

  /// Paywall headline for people who said at onboarding they are stressed or low. "it" = the stress they carry.
  ///
  /// In en, this message translates to:
  /// **'Somewhere to put it down'**
  String get paywallStressedHeadline;

  /// Paywall text under paywallStressedHeadline.
  ///
  /// In en, this message translates to:
  /// **'Ten minutes that are yours: breathing for the middle of a bad afternoon, sounds to fall asleep to, and a journal that keeps up — with a record of how the weeks actually go.'**
  String get paywallStressedDetail;

  /// Paywall headline for people who said at onboarding they are doing okay (and the default).
  ///
  /// In en, this message translates to:
  /// **'Keep the good days coming'**
  String get paywallSteadyHeadline;

  /// Paywall text under paywallSteadyHeadline.
  ///
  /// In en, this message translates to:
  /// **'The habits that keep you steady, all in one place: every meditation and sound, an unlimited journal, and a record of how the weeks actually go.'**
  String get paywallSteadyDetail;

  /// Length of a free trial, used in the paywall button "Try free for {trial}" (paywallTryFreeFor).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String billingTrialDays(int count);

  /// Length of a free trial, used in the paywall button "Try free for {trial}" (paywallTryFreeFor).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String billingTrialWeeks(int count);

  /// Length of a free trial, used in the paywall button "Try free for {trial}" (paywallTryFreeFor).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String billingTrialMonths(int count);

  /// Length of a free trial, used in the paywall button "Try free for {trial}" (paywallTryFreeFor).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String billingTrialYears(int count);

  /// Suffix after a store price: "Ksh 400/week". Keep it short.
  ///
  /// In en, this message translates to:
  /// **'/week'**
  String get billingSuffixWeek;

  /// Suffix after a store price: "Ksh 1,500/month". Keep it short.
  ///
  /// In en, this message translates to:
  /// **'/month'**
  String get billingSuffixMonth;

  /// Suffix after a store price: "Ksh 9,000/year". Keep it short.
  ///
  /// In en, this message translates to:
  /// **'/year'**
  String get billingSuffixYear;

  /// Paywall free-trial timeline: first step label.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get paywallTimelineToday;

  /// Paywall free-trial timeline: what happens today when the trial starts.
  ///
  /// In en, this message translates to:
  /// **'Full access to everything in Premium.'**
  String get paywallTimelineTodayDetail;

  /// Paywall free-trial timeline: step label for a day of the trial, e.g. "Day 5".
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String paywallTimelineDay(int day);

  /// Paywall free-trial timeline: two days before the end, a reminder notification is sent.
  ///
  /// In en, this message translates to:
  /// **'We remind you that the trial is about to end.'**
  String get paywallTimelineReminderDetail;

  /// Paywall free-trial timeline: last day, the paid plan begins. {price} is a store price with period, e.g. "Ksh 1,500/month".
  ///
  /// In en, this message translates to:
  /// **'{price} starts. Cancel any time before and pay nothing.'**
  String paywallTimelineChargeDetail(String price);

  /// Paywall Free-vs-Premium table: feature row.
  ///
  /// In en, this message translates to:
  /// **'Guided meditations & breathing'**
  String get paywallRowMeditations;

  /// Paywall Free-vs-Premium table: feature row.
  ///
  /// In en, this message translates to:
  /// **'Journaling'**
  String get paywallRowJournaling;

  /// Paywall Free-vs-Premium table: feature row.
  ///
  /// In en, this message translates to:
  /// **'Mood history & progress'**
  String get paywallRowMoodHistory;

  /// Paywall Free-vs-Premium table: feature row.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing sounds — focus, sleep, calm'**
  String get paywallRowSounds;

  /// Paywall Free-vs-Premium table: feature row.
  ///
  /// In en, this message translates to:
  /// **'Journal prompts'**
  String get paywallRowPrompts;

  /// Paywall Free-vs-Premium table: feature row (addiction recovery).
  ///
  /// In en, this message translates to:
  /// **'Recovery tracking & insights'**
  String get paywallRowRecovery;

  /// Paywall Free-vs-Premium table: feature row.
  ///
  /// In en, this message translates to:
  /// **'Daily mood check-ins'**
  String get paywallRowCheckins;

  /// Paywall Free-vs-Premium table: feature row.
  ///
  /// In en, this message translates to:
  /// **'Daily reminders'**
  String get paywallRowReminders;

  /// Paywall Free-vs-Premium table: feature row. "Urge surfing" is a recovery technique: riding out a craving.
  ///
  /// In en, this message translates to:
  /// **'Urge surfing, any time'**
  String get paywallRowUrgeSurfing;

  /// Paywall table cell in the Premium column (narrow, ~76px).
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get paywallCellUnlimited;

  /// Paywall table cell in the Free column (narrow, ~64px): how many items are free, e.g. "2 free".
  ///
  /// In en, this message translates to:
  /// **'{count} free'**
  String paywallCellFree(int count);

  /// Paywall table cell in the Premium column (narrow, ~76px): all items, e.g. "All 20".
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String paywallCellAll(int count);

  /// Paywall table cell in the Free column (narrow, ~64px): journal entries allowed for free.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String paywallCellEntries(int count);

  /// Snackbar on the paywall when the person already subscribes.
  ///
  /// In en, this message translates to:
  /// **'You already have Premium — everything is unlocked.'**
  String get paywallAlreadyPremium;

  /// Snackbar when the store has no plans to sell (e.g. offline or unsupported device).
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t available on this device yet — you can upgrade later from Settings.'**
  String get paywallPurchasesUnavailable;

  /// Snackbar when a purchase succeeded but Premium did not unlock. "Restore purchases" names a button (paywallRestore) — use the same wording.
  ///
  /// In en, this message translates to:
  /// **'Purchase completed, but premium didn\'t activate. Try \"Restore purchases\", or contact support.'**
  String get paywallNotActivated;

  /// Snackbar after "Restore purchases" finds nothing to restore.
  ///
  /// In en, this message translates to:
  /// **'No previous purchases found.'**
  String get paywallNoPurchases;

  /// Paywall plan card title (narrow card, one of three side by side).
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get paywallPlanWeekly;

  /// Paywall plan card title (narrow card, one of three side by side).
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallPlanMonthly;

  /// Paywall plan card title (narrow card, one of three side by side).
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get paywallPlanYearly;

  /// Small note under the weekly plan price on the paywall (one line, narrow).
  ///
  /// In en, this message translates to:
  /// **'per week'**
  String get paywallPerWeek;

  /// Small note under the monthly plan price on the paywall (one line, narrow).
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get paywallPerMonth;

  /// Small note under a yearly plan price on the paywall (one line, narrow).
  ///
  /// In en, this message translates to:
  /// **'per year'**
  String get paywallPerYear;

  /// Paywall trust badge (small chip).
  ///
  /// In en, this message translates to:
  /// **'Licensed therapists'**
  String get paywallTrustTherapists;

  /// Paywall trust badge (small chip).
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get paywallTrustPrivate;

  /// Paywall trust badge (small chip): the subscription can be cancelled at any time.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get paywallTrustCancel;

  /// Badge on the yearly plan card: percent saved versus paying monthly. All capitals in English; tiny badge, keep short.
  ///
  /// In en, this message translates to:
  /// **'SAVE {percent}%'**
  String paywallSave(int percent);

  /// Paywall table column heading: the free plan (narrow, ~64px).
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get paywallColumnFree;

  /// Paywall table column heading: the Premium plan (narrow, ~76px). Product name; may stay "Premium".
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get paywallColumnPremium;

  /// Paywall button folding the feature table back to three rows.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get paywallShowLess;

  /// Paywall button unfolding the full feature table.
  ///
  /// In en, this message translates to:
  /// **'See everything'**
  String get paywallSeeEverything;

  /// Link at the bottom of the paywall to the terms of use (required by the app stores).
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get paywallTerms;

  /// Link at the bottom of the paywall to the privacy policy (required by the app stores).
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get paywallPrivacy;

  /// Main paywall button when the plan has a free trial. {trial} is a length such as "7 days" or "1 month" (billingTrialDays etc.).
  ///
  /// In en, this message translates to:
  /// **'Try free for {trial}'**
  String paywallTryFreeFor(String trial);

  /// Main paywall button when the plan has no trial. {price} is the store price, e.g. "Ksh 1,500".
  ///
  /// In en, this message translates to:
  /// **'Start Premium — {price}'**
  String paywallStartPremiumPrice(String price);

  /// Main paywall button when no plan is loaded.
  ///
  /// In en, this message translates to:
  /// **'Start Premium'**
  String get paywallStartPremium;

  /// Small line under the paywall button when the plan has a free trial: after the trial, this price. {price} is like "Ksh 1,500/month". Starts lower-case.
  ///
  /// In en, this message translates to:
  /// **'then {price} · cancel anytime'**
  String paywallThenPriceCancelAnytime(String price);

  /// Small line under the paywall button when the plan has no trial. {price} is like "Ksh 1,500/month".
  ///
  /// In en, this message translates to:
  /// **'{price} · cancel anytime'**
  String paywallPriceCancelAnytime(String price);

  /// Small line under the paywall button when no plan is loaded.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get paywallCancelAnytime;

  /// Paywall button at the end of onboarding: carry on with the free plan.
  ///
  /// In en, this message translates to:
  /// **'Continue with Free'**
  String get paywallContinueFree;

  /// Paywall button (reached from Settings/upgrade prompts): close without buying.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get paywallMaybeLater;

  /// Paywall button: restore a subscription bought earlier on this store account.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// Footnote on the paywall: therapy sessions are not part of Premium.
  ///
  /// In en, this message translates to:
  /// **'Therapy sessions are available to everyone and booked separately.'**
  String get paywallTherapyNote;

  /// Word set into a divider line between the email form and the "Continue with Apple/Google" buttons on the log-in and sign-up screens.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// Snackbar when signing in, signing up or resetting a password fails for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// Form error under an empty email field.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEmailRequired;

  /// Form error under an email field that is not an email address.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get authEmailInvalid;

  /// Form error under an empty password field.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordRequired;

  /// Form error when a new password is too short.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters'**
  String authPasswordTooShort(int count);

  /// Sign-in button. Follow Apple's official wording for your language if one exists.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueWithApple;

  /// Sign-in button. Follow Google's official wording for your language if one exists.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// Snackbar: Google sign-in cannot run on this phone.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t available on this device.'**
  String get authGoogleUnavailable;

  /// Snackbar: Google sign-in failed without giving us credentials.
  ///
  /// In en, this message translates to:
  /// **'Google didn\'t return a sign-in token. Please try again.'**
  String get authGoogleNoToken;

  /// Snackbar: Google sign-in was interrupted. A technical detail in brackets may follow.
  ///
  /// In en, this message translates to:
  /// **'Google couldn\'t finish signing you in. Please try again, or use your email instead.'**
  String get authGoogleInterrupted;

  /// Snackbar: Google sign-in configuration error. A technical detail in brackets may follow.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t set up correctly for this app.'**
  String get authGoogleMisconfigured;

  /// Snackbar: Google returned a different account than expected.
  ///
  /// In en, this message translates to:
  /// **'That\'s a different Google account than the one expected.'**
  String get authGoogleWrongAccount;

  /// Snackbar: Google sign-in failed for an unknown reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in with Google. Please try again.'**
  String get authGoogleFailed;

  /// Snackbar. "Sign in with Apple" is Apple's product name — use Apple's official localised name.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple isn\'t available on this device.'**
  String get authAppleUnavailable;

  /// Snackbar: Apple sign-in failed without giving us credentials.
  ///
  /// In en, this message translates to:
  /// **'Apple didn\'t return a sign-in token. Please try again.'**
  String get authAppleNoToken;

  /// Snackbar: Apple sign-in failed, usually because the phone is not signed in to an Apple Account. "Settings" is the iPhone Settings app. A technical detail in brackets may follow.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in with Apple. Check that this device is signed in to an Apple Account in Settings, then try again.'**
  String get authAppleNoAccount;

  /// Snackbar: Apple sign-in failed. A technical detail in brackets may follow.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in with Apple. Please try again, or use your email instead.'**
  String get authAppleFailed;

  /// Log-in screen footer, before the "Create an account" button.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get authNewHere;

  /// Log-in screen footer button that opens sign-up.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authCreateAnAccount;

  /// Log-in screen heading.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authLoginTitle;

  /// Log-in screen subtitle. "You are not alone" echoes the app name (yournotalone).
  ///
  /// In en, this message translates to:
  /// **'You are not alone. Log in to pick up right where you left off.'**
  String get authLoginSubtitle;

  /// Label of an email text field.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// Label of a password text field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// Log-in screen link to reset the password.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// Button that logs in (log-in screen, and sign-up screen footer).
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogIn;

  /// Heading after sign-up, while waiting for the person to tap the confirmation link.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get authConfirmEmailTitle;

  /// Text under authConfirmEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to verify it\'s really you. Tap the link, then come back and log in.'**
  String get authConfirmEmailSubtitle;

  /// Button returning to the log-in screen.
  ///
  /// In en, this message translates to:
  /// **'Back to log in'**
  String get authBackToLogIn;

  /// Sign-up screen footer, before the "Log in" button.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccount;

  /// Sign-up screen heading.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authSignupTitle;

  /// Sign-up screen subtitle.
  ///
  /// In en, this message translates to:
  /// **'A calmer mind starts here. It only takes a minute.'**
  String get authSignupSubtitle;

  /// Sign-up text field label for the person's name.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// Form error under an empty name field.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get authNameRequired;

  /// Label of the second password field, to type the password again.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// Form error when the two passwords differ.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get authPasswordsDontMatch;

  /// Sign-up submit button.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// Legal notice at the bottom of sign-up. {terms} is replaced by the link authTermsOfService and {privacy} by the link authPrivacyPolicy; put them where your grammar needs them.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to our {terms} and {privacy}.'**
  String authSignupAgreement(String terms, String privacy);

  /// Link inside authSignupAgreement to the terms of service.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authTermsOfService;

  /// Link inside authSignupAgreement to the privacy policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// Snackbar after setting a new password.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get authPasswordUpdated;

  /// Heading of the screen opened from a password-reset email.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get authNewPasswordTitle;

  /// Text under authNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re verified — set the password you\'ll use to log in from now on.'**
  String get authNewPasswordSubtitle;

  /// Password field label on the new-password screen.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// Submit button on the new-password screen.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get authSavePassword;

  /// Heading after requesting a password-reset email.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get authCheckInboxTitle;

  /// Text under authCheckInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that address, the reset link is already on its way.'**
  String get authCheckInboxSubtitle;

  /// Button to go back and enter a different email for the password reset.
  ///
  /// In en, this message translates to:
  /// **'Try another email'**
  String get authTryAnotherEmail;

  /// Heading of the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetTitle;

  /// Text under authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you signed up with and we\'ll send you a link to set a new password.'**
  String get authResetSubtitle;

  /// Submit button on the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendResetLink;

  /// Bottom navigation tab label. One short word.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellTabHome;

  /// Bottom navigation tab label: browse all exercises and content. One short word.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get shellTabExplore;

  /// Bottom navigation tab label. One short word.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellTabSettings;

  /// Snackbar on Edit profile when the camera cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available right now.'**
  String get profileCameraUnavailable;

  /// Snackbar on Edit profile when the photo library cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your photo library.'**
  String get profileLibraryUnavailable;

  /// Edit profile photo sheet option: pick a profile photo from the phone's photos.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get profileChooseFromLibrary;

  /// Edit profile photo sheet option: take a new profile photo with the camera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get profileTakePhoto;

  /// Edit profile photo sheet option: remove the profile photo.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profileRemovePhoto;

  /// Snackbar after saving the profile.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profileUpdated;

  /// Snackbar when uploading the profile photo fails. {error} is a technical message from the server (usually English).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your photo: {error}'**
  String profilePhotoSaveFailed(String error);

  /// App bar title of the Edit profile screen.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditTitle;

  /// Edit profile button under the avatar when a photo is set.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get profileChangePhoto;

  /// Edit profile button under the avatar when no photo is set.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get profileAddPhoto;

  /// Edit profile text field label.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileYourName;

  /// Note under the (read-only) email on Edit profile.
  ///
  /// In en, this message translates to:
  /// **'Your email can\'t be changed here.'**
  String get profileEmailFixed;

  /// Edit profile save button.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSaveChanges;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
