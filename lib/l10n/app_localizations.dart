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

  /// The ways a therapy session can be paid on the Paystack page. M-Pesa and Airtel Money are brand names: keep them; translate only "or". Used inside longer sentences ("Pay securely by {methods} through Paystack").
  ///
  /// In en, this message translates to:
  /// **'M-Pesa or Airtel Money'**
  String get therapyPaymentMethods;

  /// The therapy session cancellation/refund policy in one or two sentences, shown wherever someone is about to pay. Must stay accurate: 24 hours, full refund.
  ///
  /// In en, this message translates to:
  /// **'Cancel in the app up to 24 hours before your session for a full refund. A session cancelled later than that, or not joined, isn\'t refunded.'**
  String get therapyCancellationPolicy;

  /// Therapy topic choice (a chip) when requesting a session; also shown on the session card.
  ///
  /// In en, this message translates to:
  /// **'Anxiety & stress'**
  String get therapyTopicAnxietyStress;

  /// Therapy topic choice (a chip): feeling down/depressed, said gently.
  ///
  /// In en, this message translates to:
  /// **'Low mood'**
  String get therapyTopicLowMood;

  /// Therapy topic choice (a chip).
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get therapyTopicRelationships;

  /// Therapy topic choice (a chip): bereavement.
  ///
  /// In en, this message translates to:
  /// **'Grief & loss'**
  String get therapyTopicGriefLoss;

  /// Therapy topic choice (a chip).
  ///
  /// In en, this message translates to:
  /// **'Addiction & recovery'**
  String get therapyTopicAddictionRecovery;

  /// Therapy topic choice (a chip): the person doesn't know what to focus on yet.
  ///
  /// In en, this message translates to:
  /// **'Not sure yet'**
  String get therapyTopicNotSure;

  /// Shown when someone tries to join a therapy video call before it opens.
  ///
  /// In en, this message translates to:
  /// **'The session isn\'t open yet.'**
  String get sessionErrorTooEarly;

  /// Shown when someone tries to join a therapy call too early. {time} is a clock time like 9:05.
  ///
  /// In en, this message translates to:
  /// **'You can join from {time} — 10 minutes before the start.'**
  String sessionErrorTooEarlyAt(String time);

  /// Shown when joining a therapy call after its time window closed.
  ///
  /// In en, this message translates to:
  /// **'This session\'s time has passed.'**
  String get sessionErrorOver;

  /// Shown when joining an unpaid therapy session.
  ///
  /// In en, this message translates to:
  /// **'This session needs to be paid for before you can join.'**
  String get sessionErrorPaymentRequired;

  /// Shown when joining a therapy session that has no confirmed time yet.
  ///
  /// In en, this message translates to:
  /// **'This session isn\'t confirmed yet.'**
  String get sessionErrorNotConfirmed;

  /// Error: the therapy session no longer exists.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that session.'**
  String get sessionErrorNotFound;

  /// Error after "Check payment": no payment found yet for the session.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find your payment yet. If you were charged, try again in a minute.'**
  String get sessionErrorNoPaymentFound;

  /// Error: a session request has expired and cannot be paid.
  ///
  /// In en, this message translates to:
  /// **'This request can\'t be paid for any more — start a new one.'**
  String get sessionErrorNotPayable;

  /// Error: the Paystack payment page failed to open.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the payment page — please try again in a moment.'**
  String get sessionErrorCheckoutFailed;

  /// Error: paying needs an email address on the account (for the receipt).
  ///
  /// In en, this message translates to:
  /// **'Add an email address to your account to pay for a session.'**
  String get sessionErrorEmailRequired;

  /// Error: payments are not set up on the server yet.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t switched on yet. Please contact us.'**
  String get sessionErrorNotConfigured;

  /// Error: the person's login expired.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been signed out. Please log in again.'**
  String get sessionErrorSignedOut;

  /// Generic error for therapy session actions (joining, paying).
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — check your connection and try again.'**
  String get sessionErrorGeneric;

  /// Status label for a past therapy session the client did not join. Short, shown at the end of a list row.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get sessionOutcomeMissed;

  /// Status label for a past therapy session that took place. Short.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sessionOutcomeCompleted;

  /// Status label for a past therapy session that did not take place (nobody joined, or the therapist did not). Short.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t happen'**
  String get sessionOutcomeDidNotHappen;

  /// Status label for a session request cancelled because it was never paid. Short.
  ///
  /// In en, this message translates to:
  /// **'Not paid'**
  String get sessionOutcomeNotPaid;

  /// Status label for a session request that was never sent to the care team. Short.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get sessionOutcomeNotSent;

  /// Status label for a cancelled therapy session. Short.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get sessionOutcomeCancelled;

  /// Availability choice (chip) when requesting a therapy session.
  ///
  /// In en, this message translates to:
  /// **'Weekday mornings'**
  String get therapySlotWeekdayMornings;

  /// Availability choice (chip) when requesting a therapy session.
  ///
  /// In en, this message translates to:
  /// **'Weekday afternoons'**
  String get therapySlotWeekdayAfternoons;

  /// Availability choice (chip) when requesting a therapy session.
  ///
  /// In en, this message translates to:
  /// **'Weekday evenings'**
  String get therapySlotWeekdayEvenings;

  /// Availability choice (chip) when requesting a therapy session.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get therapySlotWeekends;

  /// Snackbar after sending a therapy request on an account whose session fee is waived.
  ///
  /// In en, this message translates to:
  /// **'Your request is with our care team — there\'s no charge for your sessions.'**
  String get therapyRequestNoCharge;

  /// Snackbar: the note to the therapist is too long.
  ///
  /// In en, this message translates to:
  /// **'That note is too long — please keep it under 1000 characters.'**
  String get therapyNoteTooLong;

  /// Snackbar: sending a therapy request failed (likely offline).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your request — check your connection.'**
  String get therapyRequestSendFailed;

  /// Dialog title: discard an unpaid therapy request.
  ///
  /// In en, this message translates to:
  /// **'Discard this request?'**
  String get therapyDiscardTitle;

  /// Dialog body under therapyDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been paid, so there\'s nothing to refund. You can start again whenever you like.'**
  String get therapyDiscardBody;

  /// Button: discard an unpaid therapy request (red, destructive).
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get therapyDiscardAction;

  /// Dialog title: cancel a booked therapy session.
  ///
  /// In en, this message translates to:
  /// **'Cancel this session?'**
  String get therapyCancelSessionTitle;

  /// Dialog body: cancelling a booked session more than 24 hours ahead. {price} is the amount paid, e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'We\'ll let your therapist know and refund your {price} in full, since it\'s more than 24 hours away. You can book again whenever you\'re ready.'**
  String therapyCancelSessionBody(String price);

  /// Button: cancel a booked therapy session (red, destructive).
  ///
  /// In en, this message translates to:
  /// **'Cancel session'**
  String get therapyCancelSessionAction;

  /// Dialog title: cancel a paid therapy request not yet matched with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request?'**
  String get therapyCancelRequestTitle;

  /// Dialog body: cancelling an unmatched paid request. {price} e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'We haven\'t matched you yet, so your {price} is refunded in full. You can book again whenever you\'re ready.'**
  String therapyCancelRequestBody(String price);

  /// Button: cancel a therapy request (red, destructive).
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get therapyCancelRequestAction;

  /// Dialog button: do not cancel, keep the request/session.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get therapyKeepIt;

  /// Snackbar: cancelling failed (likely offline).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel — check your connection.'**
  String get therapyCancelFailed;

  /// Snackbar after paying for a new therapy request.
  ///
  /// In en, this message translates to:
  /// **'Payment received — your request is with our care team and your receipt is on its way by email.'**
  String get therapyPaymentReceivedRequest;

  /// Snackbar after paying for an already matched session.
  ///
  /// In en, this message translates to:
  /// **'Payment received — your receipt is on its way by email.'**
  String get therapyPaymentReceived;

  /// Snackbar: payment not yet confirmed. "Check payment" must match the button label therapyCheckPayment.
  ///
  /// In en, this message translates to:
  /// **'Your payment is going through. If it isn\'t confirmed in a minute, tap \"Check payment\".'**
  String get therapyPaymentPending;

  /// Snackbar: the payment page could not open on this phone.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the payment page on this device — please try again later.'**
  String get therapyPaymentUnavailable;

  /// Snackbar: payment failed.
  ///
  /// In en, this message translates to:
  /// **'The payment didn\'t go through. Please try again.'**
  String get therapyPaymentFailed;

  /// Snackbar after "Check payment" finds the payment for a new request.
  ///
  /// In en, this message translates to:
  /// **'Payment found — your request is with our care team.'**
  String get therapyPaymentFoundRequest;

  /// Snackbar after "Check payment" finds the payment for a matched session.
  ///
  /// In en, this message translates to:
  /// **'Payment found — you\'re all set.'**
  String get therapyPaymentFound;

  /// Snackbar: checking the payment failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check — try again in a moment.'**
  String get therapyCheckFailed;

  /// Stand-in for the therapist's name when it isn't known (e.g. in the call screen).
  ///
  /// In en, this message translates to:
  /// **'Your therapist'**
  String get therapyYourTherapist;

  /// Title of the sheet asking the client to rate a therapy session.
  ///
  /// In en, this message translates to:
  /// **'How was your session?'**
  String get therapyRateTitle;

  /// Subtitle of the rating sheet.
  ///
  /// In en, this message translates to:
  /// **'Your rating helps us match people well.'**
  String get therapyRateSubtitle;

  /// Subtitle of the rating sheet; {name} is the therapist's first name. Reassures the rating is anonymous to them.
  ///
  /// In en, this message translates to:
  /// **'Your rating helps us match people well. {name} never sees it on its own — only an average.'**
  String therapyRateSubtitleNamed(String name);

  /// Label of the optional comment field on the rating sheet.
  ///
  /// In en, this message translates to:
  /// **'Anything you\'d like to tell us? (optional)'**
  String get therapyRateComment;

  /// Error: sending a rating failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your rating — check your connection.'**
  String get therapyRateFailed;

  /// Snackbar after a rating is sent.
  ///
  /// In en, this message translates to:
  /// **'Thank you — that helps.'**
  String get therapyRateThanks;

  /// Heading over the note a therapist wrote after a session (name unknown).
  ///
  /// In en, this message translates to:
  /// **'Notes from your therapist'**
  String get therapyNotesFromTherapist;

  /// Heading over the note a therapist wrote after a session; {name} is the therapist's first name.
  ///
  /// In en, this message translates to:
  /// **'Notes from {name}'**
  String therapyNotesFrom(String name);

  /// Shown when the therapist left no note for a session.
  ///
  /// In en, this message translates to:
  /// **'No notes for this session.'**
  String get therapyNoNotes;

  /// Button: open the rating sheet for a past session.
  ///
  /// In en, this message translates to:
  /// **'Rate this session'**
  String get therapyRateSession;

  /// Label before the stars a client gave a past session.
  ///
  /// In en, this message translates to:
  /// **'You rated it'**
  String get therapyYouRatedIt;

  /// Button: change a rating already given.
  ///
  /// In en, this message translates to:
  /// **'Change your rating'**
  String get therapyChangeRating;

  /// A numbered step heading in "how it works", e.g. "1. We match you". Change only if your language writes numbered steps differently.
  ///
  /// In en, this message translates to:
  /// **'{number}. {title}'**
  String therapyStepNumbered(int number, String title);

  /// How-it-works step 1 title.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you need, and pay'**
  String get therapyStepPayTitle;

  /// How-it-works step 1 detail. {price} is the session price, e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'A topic, the times that suit you, and {price} — paid securely in the app. Nothing is sent until it\'s paid.'**
  String therapyStepPayDetail(String price);

  /// How-it-works step 2 title.
  ///
  /// In en, this message translates to:
  /// **'We match you'**
  String get therapyStepMatchTitle;

  /// How-it-works step 2 detail.
  ///
  /// In en, this message translates to:
  /// **'A licensed therapist and a time, usually within a day.'**
  String get therapyStepMatchDetail;

  /// How-it-works step 3 title.
  ///
  /// In en, this message translates to:
  /// **'You talk'**
  String get therapyStepTalkTitle;

  /// How-it-works step 3 detail.
  ///
  /// In en, this message translates to:
  /// **'A private video call, right here in the app.'**
  String get therapyStepTalkDetail;

  /// Reassurance point title on the therapy screen.
  ///
  /// In en, this message translates to:
  /// **'Licensed therapists'**
  String get therapyPointLicensedTitle;

  /// Reassurance point detail.
  ///
  /// In en, this message translates to:
  /// **'Qualified practitioners, not volunteers or chatbots.'**
  String get therapyPointLicensedDetail;

  /// Reassurance point title: confidentiality.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get therapyPointPrivateTitle;

  /// Reassurance point detail about confidentiality.
  ///
  /// In en, this message translates to:
  /// **'What you say in a session stays between you and them. Calls aren\'t recorded.'**
  String get therapyPointPrivateDetail;

  /// Reassurance point title: pay per session, no subscription.
  ///
  /// In en, this message translates to:
  /// **'One session at a time'**
  String get therapyPointOneAtATimeTitle;

  /// Reassurance point detail: refund policy.
  ///
  /// In en, this message translates to:
  /// **'No subscription. Cancel up to 24 hours before for a full refund — after that, or if you don\'t join, the session isn\'t refunded.'**
  String get therapyPointOneAtATimeDetail;

  /// Banner title on the booking form. {price} e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'Sessions are {price}, paid when you book'**
  String therapyOfferTitle(String price);

  /// Banner detail on the booking form. {methods} is therapyPaymentMethods (e.g. "M-Pesa or Airtel Money"); {charge} is the amount in Kenyan shillings, e.g. "Ksh 2,600". Paystack is a brand.
  ///
  /// In en, this message translates to:
  /// **'Pay securely by {methods} through Paystack (charged as {charge}) and your request goes straight to our care team. You get a receipt by email. No subscription.'**
  String therapyOfferDetail(String methods, String charge);

  /// Section heading over the topic chips on the booking form.
  ///
  /// In en, this message translates to:
  /// **'What would you like to focus on?'**
  String get therapyFocusQuestion;

  /// Section heading over the availability chips on the booking form.
  ///
  /// In en, this message translates to:
  /// **'When could you meet?'**
  String get therapyWhenQuestion;

  /// Label of the optional note field on the booking form.
  ///
  /// In en, this message translates to:
  /// **'Anything your therapist should know? (optional)'**
  String get therapyNoteLabel;

  /// Main button on the booking form. {price} e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'Pay {price} and request a session'**
  String therapyPayAndRequest(String price);

  /// Small print under the booking button. {policy} is therapyCancellationPolicy.
  ///
  /// In en, this message translates to:
  /// **'We\'ll match you with a licensed therapist and a time, usually within a day, and email you when your session is booked. {policy}'**
  String therapyBookingFootnote(String policy);

  /// Price line on the session card for a free first session.
  ///
  /// In en, this message translates to:
  /// **'First session — free'**
  String get therapyPriceFirstFree;

  /// Price line on the session card. {price} e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'{price} — paid, receipt emailed'**
  String therapyPricePaid(String price);

  /// Price line on the session card when the fee is waived.
  ///
  /// In en, this message translates to:
  /// **'No charge for this session'**
  String get therapyPriceWaived;

  /// Price line on the session card for an unpaid draft request.
  ///
  /// In en, this message translates to:
  /// **'{price} — pay to send your request'**
  String therapyPriceToSend(String price);

  /// Price line on the session card when payment is due.
  ///
  /// In en, this message translates to:
  /// **'{price} — payment needed'**
  String therapyPriceNeeded(String price);

  /// Session card title: request saved but not paid yet.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get therapyAlmostThereTitle;

  /// Session card detail under therapyAlmostThereTitle.
  ///
  /// In en, this message translates to:
  /// **'Your request is saved but hasn\'t reached our care team yet. It\'s sent the moment your session is paid for.'**
  String get therapyAlmostThereDetail;

  /// Session card title: paid request waiting for a therapist match.
  ///
  /// In en, this message translates to:
  /// **'Request received'**
  String get therapyReceivedTitle;

  /// Session card detail under therapyReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re finding the right licensed therapist for you — usually within a day. We\'ll email you when your session is booked.'**
  String get therapyReceivedDetail;

  /// Session card title: matched with a therapist but not paid yet.
  ///
  /// In en, this message translates to:
  /// **'You\'re matched'**
  String get therapyMatchedTitle;

  /// Session card detail under therapyMatchedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay for your session to confirm your place.'**
  String get therapyMatchedDetail;

  /// Session card title: booked and paid.
  ///
  /// In en, this message translates to:
  /// **'Session confirmed'**
  String get therapyConfirmedTitle;

  /// Session card detail under therapyConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything\'s set. Join right here when it\'s time.'**
  String get therapyConfirmedDetail;

  /// Banner on a booked session when notifications are turned off.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off, so you won\'t get the ten-minute reminder for this session.'**
  String get therapyNotificationsOffReminder;

  /// Banner on a waiting request when notifications are turned off.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off, so you won\'t hear when you\'re matched.'**
  String get therapyNotificationsOffMatch;

  /// Session time and length on the session card, e.g. "Mon 14 Sep, 9:05 · 50 min". {when} is a formatted date and time.
  ///
  /// In en, this message translates to:
  /// **'{when} · {minutes} min'**
  String therapyWhenAndLength(String when, int minutes);

  /// Small print on a booked session inside the 24-hour no-refund window.
  ///
  /// In en, this message translates to:
  /// **'Your session is less than 24 hours away, so it can no longer be cancelled here. If you can\'t make it, reply to your booking email — a missed or late-cancelled session isn\'t refunded.'**
  String get therapyLateCancelNote;

  /// Payment box title while a payment is being confirmed.
  ///
  /// In en, this message translates to:
  /// **'Your payment is being verified'**
  String get therapyPaymentVerifying;

  /// Payment box title for an unpaid draft request. {price} e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'{price} to send your request'**
  String therapyPayToSend(String price);

  /// Payment box title for a matched session awaiting payment.
  ///
  /// In en, this message translates to:
  /// **'{price} to confirm your session'**
  String therapyPayToConfirm(String price);

  /// Payment box detail while verifying. Paystack is a brand.
  ///
  /// In en, this message translates to:
  /// **'Paystack has your payment. Don\'t pay again — your request goes through as soon as it\'s found.'**
  String get therapyPaymentVerifyingDetail;

  /// Payment box detail for a draft request. {methods} e.g. "M-Pesa or Airtel Money"; {charge} e.g. "Ksh 2,600"; {policy} is therapyCancellationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Pay securely by {methods} through Paystack (charged as {charge}) and your request goes straight to our care team, with a receipt by email. {policy}'**
  String therapyPayDetailRequest(String methods, String charge, String policy);

  /// Payment box detail for a matched session. "Join" refers to the Join session button.
  ///
  /// In en, this message translates to:
  /// **'Pay securely by {methods} through Paystack (charged as {charge}). The Join button unlocks as soon as it\'s paid.'**
  String therapyPayDetailSession(String methods, String charge);

  /// Button: ask the server whether the payment arrived.
  ///
  /// In en, this message translates to:
  /// **'Check payment'**
  String get therapyCheckPayment;

  /// Button: pay for the session. {price} e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'Pay {price}'**
  String therapyPayPrice(String price);

  /// Text button under the Pay button.
  ///
  /// In en, this message translates to:
  /// **'Already paid? Check again'**
  String get therapyAlreadyPaid;

  /// Hint under the Join session button before the call opens.
  ///
  /// In en, this message translates to:
  /// **'The call opens 10 minutes before the start.'**
  String get therapyJoinOpensSoon;

  /// Hint under Join session after an unpaid session time passed.
  ///
  /// In en, this message translates to:
  /// **'This session\'s time has passed without payment. It\'ll be cancelled shortly, and you can book again after that.'**
  String get therapyJoinOverUnpaid;

  /// Hint under Join session after the session time passed. "Past sessions" is the section title therapyPastSessions.
  ///
  /// In en, this message translates to:
  /// **'This session\'s time has passed. It closes out on its own within a couple of hours: if it went ahead, any note from your therapist appears under Past sessions; if it didn\'t happen, you\'ll be able to book again.'**
  String get therapyJoinOver;

  /// Hint under Join session when unpaid.
  ///
  /// In en, this message translates to:
  /// **'The call opens once your session is paid for.'**
  String get therapyJoinNeedsPayment;

  /// Hint under Join session when the call is open.
  ///
  /// In en, this message translates to:
  /// **'Find a quiet, private spot — you\'ll need your camera and microphone.'**
  String get therapyJoinReady;

  /// Button: join the therapy video call.
  ///
  /// In en, this message translates to:
  /// **'Join session'**
  String get therapyJoinSession;

  /// Past session row subtitle: therapist's full name and date.
  ///
  /// In en, this message translates to:
  /// **'{name} · {date}'**
  String therapyPastWithTherapist(String name, String date);

  /// Small chip on a past session that has not been rated yet.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get therapyRate;

  /// App bar title of the therapy screen.
  ///
  /// In en, this message translates to:
  /// **'Talk to a therapist'**
  String get therapyTitle;

  /// Shown when the therapy screen fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load — check your connection.'**
  String get therapyLoadFailed;

  /// Headline on the therapy screen. Warm, supportive.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to do this alone'**
  String get therapyHeadline;

  /// Intro paragraph on the therapy screen.
  ///
  /// In en, this message translates to:
  /// **'Private one-on-one sessions with licensed therapists, right from here. Tell us a little about what you need and we\'ll match you with the right person.'**
  String get therapyIntro;

  /// Section heading over the list of past therapy sessions.
  ///
  /// In en, this message translates to:
  /// **'Past sessions'**
  String get therapyPastSessions;

  /// Appended to the crisis footer on the therapy screen. Note the leading space.
  ///
  /// In en, this message translates to:
  /// **' This app can\'t replace emergency care.'**
  String get therapyCrisisTrailing;

  /// Payment waiting dialog: no connection.
  ///
  /// In en, this message translates to:
  /// **'We can\'t reach our server right now — we\'ll keep checking.'**
  String get therapyCheckoutOffline;

  /// Payment waiting dialog: payment not found yet.
  ///
  /// In en, this message translates to:
  /// **'We haven\'t seen your payment yet. If you\'ve just paid, give it a few seconds.'**
  String get therapyCheckoutNotFound;

  /// Payment waiting dialog hint. {methods} e.g. "M-Pesa or Airtel Money".
  ///
  /// In en, this message translates to:
  /// **'Finish paying on the Paystack page — by {methods}. This closes by itself once your payment is in.'**
  String therapyCheckoutHint(String methods);

  /// Title of the dialog shown while the Paystack page is open.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your payment'**
  String get therapyCheckoutTitle;

  /// Button in the payment waiting dialog: check now.
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid'**
  String get therapyIvePaid;

  /// Screen-reader label for a star rating, e.g. "4.5 out of 5 stars". {rating} is a number already formatted.
  ///
  /// In en, this message translates to:
  /// **'{rating} out of 5 stars'**
  String sessionStarsSemantic(String rating);

  /// Tooltip on each star when rating a session (1–5).
  ///
  /// In en, this message translates to:
  /// **'{stars} out of 5'**
  String sessionStarTooltip(int stars);

  /// Compact average rating and number of ratings on a therapist card, e.g. "4.5 · 12". Usually left as is.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count}'**
  String sessionRatingAndCount(String rating, int count);

  /// Therapist profile: average rating and how many ratings, e.g. "4.5 from 12 ratings".
  ///
  /// In en, this message translates to:
  /// **'{rating} from {count, plural, other{{count} ratings}}'**
  String sessionRatingFrom(String rating, int count);

  /// Therapist profile line: years of professional experience.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =1{1 year of experience} other{{years} years of experience}}'**
  String sessionYearsExperience(int years);

  /// Button on the session rating sheet.
  ///
  /// In en, this message translates to:
  /// **'Send rating'**
  String get sessionSendRating;

  /// Snackbar in a therapy video call when the microphone could not be turned on.
  ///
  /// In en, this message translates to:
  /// **'Your microphone isn\'t available. You can allow it in your phone\'s settings for this app.'**
  String get callMicUnavailable;

  /// Snackbar in a therapy video call when the camera could not be turned on.
  ///
  /// In en, this message translates to:
  /// **'Your camera isn\'t available. You can allow it in your phone\'s settings for this app.'**
  String get callCameraUnavailable;

  /// Snackbar in a therapy video call when neither microphone nor camera could be turned on. (The English is ungrammatical by accident; translate as "aren't available … allow them".)
  ///
  /// In en, this message translates to:
  /// **'Your microphone and camera isn\'t available. You can allow it in your phone\'s settings for this app.'**
  String get callMicAndCameraUnavailable;

  /// Error on the call screen: login expired.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been signed out. Please log in again.'**
  String get callSignedOut;

  /// Error on the call screen: could not connect to the video call.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect to the session — check your connection and try again.'**
  String get callConnectFailed;

  /// Shown while the therapy video call connects.
  ///
  /// In en, this message translates to:
  /// **'Connecting to your session…'**
  String get callConnecting;

  /// Title when joining the video call failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t join'**
  String get callJoinFailedTitle;

  /// Title after the video call ended.
  ///
  /// In en, this message translates to:
  /// **'The call has ended'**
  String get callEndedTitle;

  /// Detail under callEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'If you were cut off, you can rejoin while the session is still on.'**
  String get callEndedDetail;

  /// Button: join the video call again.
  ///
  /// In en, this message translates to:
  /// **'Rejoin'**
  String get callRejoin;

  /// Call status while the other person (therapist or client) has not joined yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to join…'**
  String callWaitingFor(String name);

  /// Call status: both people are in the call.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get callConnected;

  /// Call status: when the session ends; {time} is a clock time like 9:50.
  ///
  /// In en, this message translates to:
  /// **'Session ends at {time}'**
  String callEndsAt(String time);

  /// Call control button label: turn microphone off. Short.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get callMute;

  /// Call control button label: turn microphone on. Short.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get callUnmute;

  /// Call control button label. Short.
  ///
  /// In en, this message translates to:
  /// **'Turn camera off'**
  String get callCameraOff;

  /// Call control button label. Short.
  ///
  /// In en, this message translates to:
  /// **'Turn camera on'**
  String get callCameraOn;

  /// Call control: switch between front and back camera. Short.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get callSwitchCamera;

  /// Call control: leave the call (red). Short.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get callLeave;

  /// Shown in place of the other person's video when their camera is off.
  ///
  /// In en, this message translates to:
  /// **'Camera is off'**
  String get callCameraIsOff;

  /// Shown in place of the other person's video before they join.
  ///
  /// In en, this message translates to:
  /// **'Not here yet'**
  String get callNotHereYet;

  /// Ongoing Android notification title during a therapy call.
  ///
  /// In en, this message translates to:
  /// **'In a session with {name}'**
  String callInSessionWith(String name);

  /// Ongoing Android notification text during a therapy call.
  ///
  /// In en, this message translates to:
  /// **'Tap to come back to the call.'**
  String get callTapToReturn;

  /// Android notification channel name (shown in system notification settings) for the ongoing-call notification.
  ///
  /// In en, this message translates to:
  /// **'Therapy session in progress'**
  String get callChannelName;

  /// Android notification channel description for the ongoing-call notification.
  ///
  /// In en, this message translates to:
  /// **'Shown while you\'re in a session, so the call keeps running when you switch apps.'**
  String get callChannelDescription;

  /// Why the app asks for notification permission, for a client with a therapy session. Shown in the permission prompt.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tell you the moment you\'re matched with a therapist, if your session moves, and ten minutes before it starts — so you don\'t miss a session you\'ve paid for.'**
  String get notificationReasonSession;

  /// Why the app asks for notification permission, for a therapist.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be told when a session is booked with you, if it changes, and ten minutes before it starts.'**
  String get notificationReasonTherapist;

  /// Why the app asks for notification permission, on the reminders screen.
  ///
  /// In en, this message translates to:
  /// **'Reminders are notifications: without permission the phone can\'t show them.'**
  String get notificationReasonReminders;

  /// What notifications the app sends, shown during onboarding. Reassuring: nothing else.
  ///
  /// In en, this message translates to:
  /// **'Session bookings, a nudge before each session starts, and the daily reminders you choose. Nothing else.'**
  String get notificationReasonOnboarding;

  /// Dialog title when notification permission was refused.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get notificationOffTitle;

  /// Dialog body when notifications are off. {reason} is one of the notificationReason* sentences. Keep the blank line.
  ///
  /// In en, this message translates to:
  /// **'{reason}\n\nThey\'re switched off for this app at the moment. You can turn them on in your phone\'s settings — it takes a few seconds.'**
  String notificationOffBody(String reason);

  /// Dialog button: open the phone's settings for this app.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get notificationOpenSettings;

  /// Short button on a banner shown when notifications are off.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get notificationTurnOn;

  /// Android notification channel name (in system settings) for therapy session notifications.
  ///
  /// In en, this message translates to:
  /// **'Therapy sessions'**
  String get notificationSessionsChannel;

  /// Android notification channel description for therapy session notifications.
  ///
  /// In en, this message translates to:
  /// **'Bookings, changes and reminders for your sessions'**
  String get notificationSessionsChannelDescription;

  /// Used in session notifications in place of the therapist's name when it's unknown, lower-case, e.g. "You're matched with your therapist".
  ///
  /// In en, this message translates to:
  /// **'your therapist'**
  String get notificationYourTherapist;

  /// Used in session notifications (to a therapist) in place of the client's name when it's unknown, lower-case.
  ///
  /// In en, this message translates to:
  /// **'your client'**
  String get notificationYourClient;

  /// Used in session notifications in place of the date when it is unknown, e.g. "Your session with Amina on the booked time has been cancelled."
  ///
  /// In en, this message translates to:
  /// **'the booked time'**
  String get notificationBookedTime;

  /// Notification title to a client: a therapist was assigned. {who} is the therapist's name. Shown on the lock screen, so it never names the topic.
  ///
  /// In en, this message translates to:
  /// **'You\'re matched with {who}'**
  String notificationMatchedTitle(String who);

  /// Notification body to a client: session time and length, and payment still due. {price} e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'{when} · {minutes} min. Pay {price} in the app to confirm your place.'**
  String notificationMatchedBodyUnpaid(String when, int minutes, String price);

  /// Notification body to a client: session time and length; already paid.
  ///
  /// In en, this message translates to:
  /// **'{when} · {minutes} min. You\'re all set.'**
  String notificationMatchedBodyPaid(String when, int minutes);

  /// Notification title to a therapist: a session was booked with them. {who} is the client's name.
  ///
  /// In en, this message translates to:
  /// **'New session with {who}'**
  String notificationNewSessionTitle(String who);

  /// Notification body to a therapist: session time and length.
  ///
  /// In en, this message translates to:
  /// **'{when} · {minutes} min.'**
  String notificationNewSessionBody(String when, int minutes);

  /// Notification body to a therapist: session time and length; client has not paid yet.
  ///
  /// In en, this message translates to:
  /// **'{when} · {minutes} min. Waiting for the client to pay.'**
  String notificationNewSessionBodyUnpaid(String when, int minutes);

  /// Notification title to a client: the session time changed.
  ///
  /// In en, this message translates to:
  /// **'Your session has changed'**
  String get notificationChangedTitle;

  /// Notification body to a client: the new session time.
  ///
  /// In en, this message translates to:
  /// **'Now {when} with {who} · {minutes} min.'**
  String notificationChangedBody(String when, String who, int minutes);

  /// Notification title to a therapist: a session changed.
  ///
  /// In en, this message translates to:
  /// **'Session updated'**
  String get notificationUpdatedTitle;

  /// Notification body to a therapist: the new session time.
  ///
  /// In en, this message translates to:
  /// **'With {who}, now {when} · {minutes} min.'**
  String notificationUpdatedBody(String who, String when, int minutes);

  /// Notification title: a therapy session was cancelled.
  ///
  /// In en, this message translates to:
  /// **'Session cancelled'**
  String get notificationCancelledTitle;

  /// Notification body: a therapy session was cancelled.
  ///
  /// In en, this message translates to:
  /// **'Your session with {who} on {when} has been cancelled.'**
  String notificationCancelledBody(String who, String when);

  /// Notification title to a client who did not join their session. Gentle, not blaming.
  ///
  /// In en, this message translates to:
  /// **'You missed your session'**
  String get notificationMissedTitle;

  /// Notification body to a client who missed a session. {who} is the therapist (a name, or "your therapist").
  ///
  /// In en, this message translates to:
  /// **'{who} was in the call on {when} but you didn\'t join, so this session isn\'t refunded. You can book again in the app.'**
  String notificationMissedBody(String who, String when);

  /// Reminder notification title to a client before a session starts.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =0{Your session is starting now} =1{Your session starts in 1 minute} other{Your session starts in {minutes} minutes}}'**
  String notificationReminderClientTitle(int minutes);

  /// Reminder notification body to a client whose session is unpaid. hasTime is "yes" when {time} (e.g. 9:05) is known; translate both branches, keep the keywords yes/other.
  ///
  /// In en, this message translates to:
  /// **'{hasTime, select, yes{With {who} at {time} — pay in the app to join.} other{With {who} — pay in the app to join.}}'**
  String notificationReminderClientBodyUnpaid(
    String hasTime,
    String who,
    String time,
  );

  /// Reminder notification body to a client. hasTime is "yes" when {time} (e.g. 9:05) is known; translate both branches, keep the keywords yes/other.
  ///
  /// In en, this message translates to:
  /// **'{hasTime, select, yes{With {who} at {time}. Open the app to join.} other{With {who}. Open the app to join.}}'**
  String notificationReminderClientBody(
    String hasTime,
    String who,
    String time,
  );

  /// Reminder notification title to a therapist before a session. {who} is the client.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =0{Session with {who} is starting now} =1{Session with {who} starts in 1 minute} other{Session with {who} starts in {minutes} minutes}}'**
  String notificationReminderTherapistTitle(int minutes, String who);

  /// Reminder notification body to a therapist; client unpaid. hasTime is "yes" when {time} is known; keep the keywords yes/other.
  ///
  /// In en, this message translates to:
  /// **'{hasTime, select, yes{Starts at {time}. The client hasn\'t paid yet.} other{Starts. The client hasn\'t paid yet.}}'**
  String notificationReminderTherapistBodyUnpaid(String hasTime, String time);

  /// Reminder notification body to a therapist. "My sessions" is the therapist's sessions screen title. hasTime is "yes" when {time} is known; keep the keywords yes/other.
  ///
  /// In en, this message translates to:
  /// **'{hasTime, select, yes{Starts at {time}. Open My sessions to join.} other{Starts. Open My sessions to join.}}'**
  String notificationReminderTherapistBody(String hasTime, String time);

  /// Fallback notification title for session news of an unknown kind.
  ///
  /// In en, this message translates to:
  /// **'Therapy session update'**
  String get notificationGenericTitle;

  /// Fallback notification body.
  ///
  /// In en, this message translates to:
  /// **'Open the app for details.'**
  String get notificationGenericBody;

  /// Name of a daily reminder on the Reminders screen.
  ///
  /// In en, this message translates to:
  /// **'Morning check-in'**
  String get remindersCheckinLabel;

  /// Description of the morning check-in reminder.
  ///
  /// In en, this message translates to:
  /// **'A ten-second pulse on how you\'re doing. Opens the check-in.'**
  String get remindersCheckinDescription;

  /// Daily reminder notification title (morning mood check-in).
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get remindersCheckinTitle;

  /// Daily reminder notification body (morning mood check-in).
  ///
  /// In en, this message translates to:
  /// **'Take ten seconds to check in with yourself.'**
  String get remindersCheckinBody;

  /// Name of a daily reminder: the recovery pledge (a daily commitment to stay sober/clean).
  ///
  /// In en, this message translates to:
  /// **'Daily pledge'**
  String get remindersPledgeLabel;

  /// Description of the daily pledge reminder.
  ///
  /// In en, this message translates to:
  /// **'Start the day by claiming it.'**
  String get remindersPledgeDescription;

  /// Daily reminder notification title (recovery pledge).
  ///
  /// In en, this message translates to:
  /// **'A new day, on your terms'**
  String get remindersPledgeTitle;

  /// Daily reminder notification body (recovery pledge). "One day at a time" is the recovery motto.
  ///
  /// In en, this message translates to:
  /// **'Make today\'s pledge — one day at a time.'**
  String get remindersPledgeBody;

  /// Name of a daily reminder: evening journaling.
  ///
  /// In en, this message translates to:
  /// **'Evening pages'**
  String get remindersJournalLabel;

  /// Description of the evening journal reminder.
  ///
  /// In en, this message translates to:
  /// **'A quiet minute for your journal. Opens your prompts.'**
  String get remindersJournalDescription;

  /// Daily reminder notification title (evening journal).
  ///
  /// In en, this message translates to:
  /// **'A quiet minute for your journal'**
  String get remindersJournalTitle;

  /// Daily reminder notification body (evening journal).
  ///
  /// In en, this message translates to:
  /// **'Put today into words — even a few lines count.'**
  String get remindersJournalBody;

  /// Name of a daily reminder: winding down before sleep.
  ///
  /// In en, this message translates to:
  /// **'Wind-down'**
  String get remindersWindDownLabel;

  /// Description of the wind-down reminder.
  ///
  /// In en, this message translates to:
  /// **'A nudge to slow down. Opens your wind-down plan.'**
  String get remindersWindDownDescription;

  /// Daily reminder notification title (wind-down before bed).
  ///
  /// In en, this message translates to:
  /// **'Time to slow down'**
  String get remindersWindDownTitle;

  /// Daily reminder notification body (wind-down before bed).
  ///
  /// In en, this message translates to:
  /// **'Your wind-down plan is ready — tap to start.'**
  String get remindersWindDownBody;

  /// Android notification channel name (in system settings) for daily reminders.
  ///
  /// In en, this message translates to:
  /// **'Daily reminders'**
  String get remindersChannelName;

  /// Android notification channel description for daily reminders.
  ///
  /// In en, this message translates to:
  /// **'Gentle daily nudges you asked for'**
  String get remindersChannelDescription;

  /// Snackbar: scheduling a reminder failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set the reminder — fully restart the app and try again.'**
  String get remindersSetFailed;

  /// Title of the Reminders screen.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// Intro under the Reminders title.
  ///
  /// In en, this message translates to:
  /// **'Gentle daily nudges, only if you want them — tap a time to change it.'**
  String get remindersIntro;

  /// Small print at the bottom of the Reminders screen.
  ///
  /// In en, this message translates to:
  /// **'Reminders are scheduled on this device and arrive even when the app is closed. Times may shift a few minutes to save battery.'**
  String get remindersFootnote;
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
