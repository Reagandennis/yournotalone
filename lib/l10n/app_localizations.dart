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

  /// Snackbar on the crisis screen when a phone number, text or website could not be opened. {target} is the number or web address.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {target}'**
  String crisisCouldNotOpen(String target);

  /// Title of the sheet on the crisis screen for picking the country whose helplines are shown. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'Where are you?'**
  String get crisisWhereAreYou;

  /// Big button on the crisis screen that calls the local emergency number. {number} is e.g. 999 or 112. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'Call {number}'**
  String crisisCallEmergency(String number);

  /// Under the emergency call button on the crisis screen. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'If you are in immediate danger, this comes first.'**
  String get crisisEmergencyHint;

  /// Button on a helpline card: call this phone number.
  ///
  /// In en, this message translates to:
  /// **'Call {phone}'**
  String crisisCallLine(String phone);

  /// Button on a helpline card: send a text message with {keyword} to the short number {number} (e.g. "Text SHOUT to 85258"). Keep {keyword} as is; it is what the service expects.
  ///
  /// In en, this message translates to:
  /// **'Text {keyword} to {number}'**
  String crisisTextLine(String keyword, String number);

  /// Button on a helpline card: open the service's website. {host} is the web address, e.g. samaritans.org.
  ///
  /// In en, this message translates to:
  /// **'Open {host}'**
  String crisisOpenSite(String host);

  /// Title of the crisis resources screen, which lists emergency and helpline numbers. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'Help right now'**
  String get crisisTitle;

  /// Intro on the crisis screen: reassurance that anyone can call these lines. Warm, plain, never clinical. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'You do not have to explain yourself well, or be in enough trouble to deserve it. Any of these will pick up.'**
  String get crisisIntro;

  /// Heading on the crisis screen above international helplines, for people outside the chosen country.
  ///
  /// In en, this message translates to:
  /// **'Somewhere else'**
  String get crisisSomewhereElse;

  /// Small print at the bottom of the crisis screen, before a button to book a therapy session. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'This app can\'t replace emergency care. When the moment has passed, a licensed therapist here can help you work through what led to it.'**
  String get crisisNotEmergencyCare;

  /// Button at the bottom of the crisis screen and the heavy-day sheet: book a session with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Book a session'**
  String get crisisBookSession;

  /// Underlined link at the bottom of several screens, opening the crisis screen. Followed by crisisFooterRest in the same line. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'In crisis or immediate danger? Get help now'**
  String get crisisFooterLink;

  /// Follows crisisFooterLink in the same sentence (note the leading space and dash): the crisis screen has real phone numbers you can call with one tap. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **' — real numbers, one tap.'**
  String get crisisFooterRest;

  /// Snackbar when a phone call could not be started from the heavy-day sheet.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t call {number}'**
  String heavyDayCouldNotCall(String number);

  /// Title of the sheet shown after someone checks in with the lowest mood ("Awful"). Gentle and validating. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'That sounds like a heavy day.'**
  String get heavyDayTitle;

  /// Body of the heavy-day sheet, offering a therapy session. Keep the price "$20" as is. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have to carry it on your own. A licensed therapist here will listen — \$20 a session, booked in a minute.'**
  String get heavyDayBody;

  /// Heading above emergency and helpline call buttons on the heavy-day sheet. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'If you need someone right now'**
  String get heavyDayRightNow;

  /// Name on the call button for the local emergency number (e.g. "Emergency · 112").
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get heavyDayEmergency;

  /// Link at the bottom of the heavy-day sheet opening the full crisis resources screen.
  ///
  /// In en, this message translates to:
  /// **'More ways to get help'**
  String get heavyDayMoreHelp;

  /// At the top of the Privacy Policy and Terms screens. {date} is the date the document was last changed (shown as written in the document).
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String legalLastUpdated(String date);

  /// FAQ section heading (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Using the app'**
  String get faqSectionUsingApp;

  /// FAQ question (a heading people tap to open the answer). Keep the app name "yournotalone" as is.
  ///
  /// In en, this message translates to:
  /// **'What is yournotalone?'**
  String get faqWhatIsQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. The first sentence explains the app name "yournotalone" (= "you're not alone").
  ///
  /// In en, this message translates to:
  /// **'You\'re not alone — that\'s the name and the idea. It\'s a wellbeing companion for the moments between the hard ones. Check in with your mood, keep a private journal, follow guided meditations and breathing exercises, unwind with calming sounds, track your recovery, and reach a licensed therapist when you need one.'**
  String get faqWhatIsA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'Is the app a substitute for therapy or medical care?'**
  String get faqSubstituteQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'No. The app supports your wellbeing, but it doesn\'t diagnose or treat anything, and it\'s not emergency care. If you\'re in crisis or immediate danger, call your local emergency number right away.'**
  String get faqSubstituteA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'How do daily reminders work?'**
  String get faqRemindersQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. "Settings → Reminders & notifications" names a menu path: match the translated Settings row label.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings → Reminders & notifications to switch on gentle nudges — a morning check-in, a daily pledge, evening pages, and a wind-down. You choose the times, and reminders are scheduled on your phone; they never leave your device.'**
  String get faqRemindersA;

  /// FAQ section heading (shown in capitals). "Premium" is the paid plan.
  ///
  /// In en, this message translates to:
  /// **'Premium & billing'**
  String get faqSectionBilling;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'What do I get with Premium?'**
  String get faqPremiumQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Every room in the house: the full meditation library, all calming sounds and breathing exercises, unlimited journaling, and the complete recovery toolkit. Plans usually start with a free trial — the price is always shown before you subscribe.'**
  String get faqPremiumA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'How do I cancel my subscription?'**
  String get faqCancelSubQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. {store} is "apple" on iPhone/Mac and "google" on Android; keep each branch a whole sentence and keep the store names (App Store, Google Play, Apple Account) as the stores call them in your language.
  ///
  /// In en, this message translates to:
  /// **'{store, select, apple{Subscriptions are billed by Apple, so you cancel in your App Store subscription settings — deleting the app doesn\'t cancel it. You keep Premium until the end of the period you\'ve paid for.} other{Subscriptions are billed by Google, so you cancel in your Google Play subscription settings — deleting the app doesn\'t cancel it. You keep Premium until the end of the period you\'ve paid for.}}'**
  String faqCancelSubA(String store);

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'I\'m a subscriber, but the app says I\'m on the Free plan.'**
  String get faqWrongPlanQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. {store} is "apple" on iPhone/Mac and "google" on Android; keep each branch a whole sentence and keep the store names (App Store, Google Play, Apple Account) as the stores call them in your language.
  ///
  /// In en, this message translates to:
  /// **'{store, select, apple{Make sure you\'re signed in to the same Apple Account you subscribed with, then tap Settings → Restore purchases. If it still doesn\'t unlock, email us and we\'ll sort it out.} other{Make sure you\'re signed in to the same Google account you subscribed with, then tap Settings → Restore purchases. If it still doesn\'t unlock, email us and we\'ll sort it out.}}'**
  String faqWrongPlanA(String store);

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'Can I get a refund?'**
  String get faqRefundQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. {store} is "apple" on iPhone/Mac and "google" on Android; keep each branch a whole sentence and keep the store names (App Store, Google Play, Apple Account) as the stores call them in your language.
  ///
  /// In en, this message translates to:
  /// **'{store, select, apple{Refunds for subscriptions are handled by Apple under its policies — request one from your App Store purchase history. If you get stuck, write to us and we\'ll point you the right way.} other{Refunds for subscriptions are handled by Google under its policies — request one from your Google Play order history. If you get stuck, write to us and we\'ll point you the right way.}}'**
  String faqRefundA(String store);

  /// FAQ section heading (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Therapy sessions'**
  String get faqSectionTherapy;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'How do I book a therapy session?'**
  String get faqBookQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. "Talk to a therapist" is the name of a screen in the app.
  ///
  /// In en, this message translates to:
  /// **'Open Talk to a therapist, tell us what you\'d like to talk about and when suits you, and send the request. Our care team matches you with a licensed therapist and a time — usually within a day — and you\'ll see who and when in the app and by email.'**
  String get faqBookA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'How much does a session cost, and when do I pay?'**
  String get faqCostQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. Keep the price "$20" as is.
  ///
  /// In en, this message translates to:
  /// **'Each session is \$20, paid securely in the app when you book — that\'s what sends your request to our care team, and you get a receipt by email straight away. No subscription; you book one session at a time.'**
  String get faqCostA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'What if I need to cancel or move my session?'**
  String get faqMoveQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. Cancellation policy: keep the terms (24 hours, full refund) exact.
  ///
  /// In en, this message translates to:
  /// **'You can cancel in the app up to 24 hours before your session and you\'ll be refunded in full. To move it, reply to your booking email at least 24 hours before and we\'ll rebook you. A session cancelled later than that, or one you don\'t join, isn\'t refunded — your therapist has set that time aside for you. If we or your therapist have to cancel, you\'re refunded in full.'**
  String get faqMoveA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'How do sessions work?'**
  String get faqHowSessionsQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'They\'re private video calls, right in the app. The Join button appears 10 minutes before the start, and you\'ll need your camera and microphone. Calls aren\'t recorded.'**
  String get faqHowSessionsA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'Will I be reminded?'**
  String get faqRemindedQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Yes. You\'ll get an email and a phone notification when you\'re matched, if anything changes, and 10 minutes before your session. Phone notifications can arrive a little later than the emails.'**
  String get faqRemindedA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'Can I cancel a session?'**
  String get faqCancelSessionQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Yes. You can cancel a request, or a matched session you haven\'t paid for, from the same screen. To cancel a paid session, contact us before it starts and we\'ll refund you.'**
  String get faqCancelSessionA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'Who are the therapists?'**
  String get faqWhoQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Licensed mental-health professionals. Our care team matches you based on what you share in your request, so you don\'t have to scroll through directories while you\'re struggling. Once you\'re matched, you can see their profile — credentials, experience and what they specialise in.'**
  String get faqWhoA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'Can I rate my session?'**
  String get faqRateQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person. "Past sessions" is a heading on the therapy screen.
  ///
  /// In en, this message translates to:
  /// **'Yes — after a session, tap it under Past sessions. Your therapist never sees your rating on its own, only an average across several people.'**
  String get faqRateA;

  /// FAQ section heading (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Privacy & your data'**
  String get faqSectionPrivacy;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'Who can read my journal?'**
  String get faqJournalQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Only you. Your entries are protected by row-level security, which means only your signed-in account can retrieve them — our team doesn\'t read them.'**
  String get faqJournalA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'Do you sell my data or show ads?'**
  String get faqSellDataQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Never. No ads, no analytics trackers, no data brokers. We collect only what the app needs to work — the Privacy Policy in Settings spells out every detail.'**
  String get faqSellDataA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'How do I delete my account and data?'**
  String get faqDeleteQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Settings → Delete account removes your profile, journal, moods, recovery data, and therapy sessions permanently. You can also email us from your registered address and we\'ll do it for you. Deletion can\'t be undone.'**
  String get faqDeleteA;

  /// FAQ section heading (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get faqSectionAccount;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'How do I change my name or profile photo?'**
  String get faqProfileQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Settings → Edit profile. Tap the photo to take a new one, choose from your library, or remove it.'**
  String get faqProfileA;

  /// FAQ question (a heading people tap to open the answer).
  ///
  /// In en, this message translates to:
  /// **'How do I change my password?'**
  String get faqPasswordQ;

  /// FAQ answer, shown when the question is opened. Help text: warm, plain, second person.
  ///
  /// In en, this message translates to:
  /// **'Settings → Change password sends a secure reset link to your email. Follow the link, choose a new password, and log back in.'**
  String get faqPasswordA;

  /// Snackbar after tapping the contact card on the FAQ screen, which copies the support email address.
  ///
  /// In en, this message translates to:
  /// **'Email address copied.'**
  String get faqEmailCopied;

  /// Title of the contact card at the end of the FAQ.
  ///
  /// In en, this message translates to:
  /// **'Still need help?'**
  String get faqStillNeedHelp;

  /// Under faqStillNeedHelp: the support email address; tapping the card copies it.
  ///
  /// In en, this message translates to:
  /// **'Write to us at {email} — tap to copy.'**
  String faqWriteToUs(String email);

  /// App bar title of the frequently asked questions screen. Use the usual short form in your language.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqTitle;

  /// Intro at the top of the FAQ screen.
  ///
  /// In en, this message translates to:
  /// **'Quick answers to the questions we hear most. Tap a question to open it.'**
  String get faqIntro;

  /// Care team: stands in for a client's name when neither their name nor email is known.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get careClientFallback;

  /// Therapist view: stands in for a client whose first name isn't known.
  ///
  /// In en, this message translates to:
  /// **'Your client'**
  String get careYourClientFallback;

  /// Flag a therapist can raise about a session: the client did not join. Therapist-facing screen.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t show up'**
  String get careFlagNoShow;

  /// Flag a therapist can raise about a session: the client joined late. Therapist-facing screen.
  ///
  /// In en, this message translates to:
  /// **'Joined late'**
  String get careFlagLate;

  /// Flag a therapist can raise about a session: the client needs follow-up care. Therapist-facing screen.
  ///
  /// In en, this message translates to:
  /// **'Needs a follow-up'**
  String get careFlagFollowUp;

  /// Flag a therapist can raise about a session: worried about the client's safety. Therapist-facing screen.
  ///
  /// In en, this message translates to:
  /// **'Safety concern'**
  String get careFlagSafety;

  /// Error shown to staff or therapists when their login session has ended.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been signed out. Please log in again.'**
  String get careSignedOut;

  /// Small badge: this therapy session is free (no payment). Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get carePaymentFree;

  /// Small badge: the client's payment was refunded. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get carePaymentRefunded;

  /// Small badge: the client hasn't paid yet. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get carePaymentUnpaid;

  /// Small badge: the client has paid. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get carePaymentPaid;

  /// Small badge: the session fee was waived by the care team. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Waived'**
  String get carePaymentWaived;

  /// Error when a care-team list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load — check your connection.'**
  String get careCouldNotLoad;

  /// App bar title of the care team's dashboard. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Care team'**
  String get careDashboardTitle;

  /// Tab on the care-team dashboard: therapy requests from clients. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get careTabRequests;

  /// Tab on the care-team dashboard: the therapists. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Therapists'**
  String get careTabTherapists;

  /// Empty state: no requests are waiting for a therapist. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Nobody is waiting to be matched.'**
  String get careEmptyToMatch;

  /// Empty state: no upcoming sessions. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'No sessions booked.'**
  String get careEmptyUpcoming;

  /// Empty state of the Past filter. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Finished and cancelled sessions show up here.'**
  String get careEmptyPast;

  /// Filter pill: requests waiting for a therapist, with how many. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'To match · {count}'**
  String careFilterToMatch(int count);

  /// Filter pill: booked sessions to come, with how many. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Upcoming · {count}'**
  String careFilterUpcoming(int count);

  /// Filter pill: finished or cancelled sessions, with how many. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Past · {count}'**
  String careFilterPast(int count);

  /// Button on the care-team dashboard. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Add a therapist'**
  String get careAddTherapist;

  /// Empty state of the Therapists tab. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'No therapists yet. Add one to start matching requests.'**
  String get careNoTherapists;

  /// On a request waiting to be matched: asked less than an hour ago. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Asked just now'**
  String get careAskedJustNow;

  /// On a request waiting to be matched: how many hours it has waited (short, "h" = hours). Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Waiting {hours}h'**
  String careWaitingHours(int hours);

  /// On a request waiting to be matched: how many days it has waited (always 2 or more). Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, other{Waiting {days} days}}'**
  String careWaitingDays(int days);

  /// Stands in for the therapist's name when it isn't known. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Therapist'**
  String get careTherapistFallback;

  /// On a booked request: therapist name and session date/time. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'{therapist} · {when}'**
  String careBookedLine(String therapist, String when);

  /// On a booked request whose time has passed but that nobody marked as finished. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'{therapist} · {when} · Not finished'**
  String careBookedLineNotFinished(String therapist, String when);

  /// On a past request: how it ended (e.g. Completed, Cancelled) and the date. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'{outcome} · {date}'**
  String carePastLine(String outcome, String date);

  /// Therapist stats: number of upcoming sessions. Joined with " · ". Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'{count} upcoming'**
  String careStatUpcoming(int count);

  /// Therapist stats: number of completed sessions. Joined with " · ". Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String careStatCompleted(int count);

  /// Small badge on a therapist who is switched off and not offered for matching. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get careInactive;

  /// Warning on a therapist who hasn't signed in to the app yet, with their email. Care-team (staff) screen.
  ///
  /// In en, this message translates to:
  /// **'Not signed in yet — {email}'**
  String careNotSignedInYet(String email);

  /// Error when the list of therapists fails to load. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load therapists — check your connection.'**
  String get careMatchCouldNotLoadTherapists;

  /// Snackbar when the chosen session time is in the past. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'That time has already passed.'**
  String get careMatchTimePassed;

  /// Snackbar when booking the session failed. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t book — check your connection.'**
  String get careMatchCouldNotBook;

  /// App bar title when matching a new request with a therapist. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Match request'**
  String get careMatchTitleNew;

  /// App bar title when changing an existing booking. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Change booking'**
  String get careMatchTitleChange;

  /// Shown instead of preferred times when the client said any time suits them. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Flexible'**
  String get careMatchFlexible;

  /// Section header above the list of therapists to choose from. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Therapist'**
  String get careMatchTherapistHeader;

  /// Empty state when no therapist can be chosen. "Therapists" is the tab name (careTabTherapists). Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'No active therapists yet. Add one from the Therapists tab first.'**
  String get careMatchNoTherapists;

  /// Section header above the date and time pickers. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get careMatchWhenHeader;

  /// Button to choose the session date. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get careMatchPickDate;

  /// Button to choose the session time. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get careMatchPickTime;

  /// Hint under the date and time pickers. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'In this phone\'s time zone. The client and therapist see it in theirs.'**
  String get careMatchTimeZoneNote;

  /// Section header above session length choices. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get careMatchLengthHeader;

  /// Session length choice, e.g. "50 min". Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} min}}'**
  String careMatchMinutes(int minutes);

  /// Button: book the session with the chosen therapist and time. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Book session'**
  String get careMatchBook;

  /// Button: save changes to an existing booking. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get careMatchSaveChanges;

  /// Note under the booking button, for a free first session. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'The client and therapist are emailed the details. This is the client\'s free first session.'**
  String get careMatchFootFree;

  /// Note under the booking button, for a paid session. {price} is the formatted price, e.g. "$20". Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'The client and therapist are emailed the details. The client pays {price} in the app before they can join.'**
  String careMatchFootPays(String price);

  /// Note under the booking button when no payment is needed. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'The client and therapist are emailed the details.'**
  String get careMatchFoot;

  /// On a therapist option: they specialise in what the client asked about. Joined with " · ". Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Specialises in this'**
  String get careMatchSpecialises;

  /// Warning on a therapist who hasn't signed in to the app yet. Care-team (staff) screen for matching a client with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Not signed in yet — they can\'t join until they do'**
  String get careMatchNotSignedIn;

  /// Snackbar when an action failed. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work — check your connection.'**
  String get careDetailFailed;

  /// Snackbar after a request is matched and booked. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Booked — the client and therapist have been emailed.'**
  String get careDetailBooked;

  /// Confirmation dialog title. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancel this session?'**
  String get careCancelSessionTitle;

  /// Confirmation dialog title. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request?'**
  String get careCancelRequestTitle;

  /// Confirmation dialog body when cancelling a booked session. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'The client and therapist are emailed that it\'s cancelled.'**
  String get careCancelSessionBody;

  /// Confirmation dialog body when cancelling a booked session the client paid for. Keep "Paystack" and "Play Console" as is. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'The client and therapist are emailed that it\'s cancelled. They\'ve paid, so refund them in the Paystack dashboard (Play Console for older in-app payments).'**
  String get careCancelSessionPaidBody;

  /// Confirmation dialog body when cancelling a request not yet booked. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'The client can request again whenever they like.'**
  String get careCancelRequestBody;

  /// Destructive dialog button. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancel session'**
  String get careCancelSessionAction;

  /// Destructive dialog button. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get careCancelRequestAction;

  /// Snackbar after cancelling. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancelled.'**
  String get careCancelled;

  /// Dialog title before marking a session as paid. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Record a payment?'**
  String get carePayPaidTitle;

  /// Dialog body before marking a session as paid. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Use this when they paid outside the app. The Join button unlocks for them straight away.'**
  String get carePayPaidBody;

  /// Button and dialog action: record that the client paid. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get carePayMarkPaid;

  /// Dialog title before waiving the session fee. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Waive the fee?'**
  String get carePayWaiveTitle;

  /// Dialog body before waiving the session fee. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be charged for this session, and can join straight away.'**
  String get carePayWaiveBody;

  /// Button and dialog action: waive the session fee. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Waive fee'**
  String get carePayWaive;

  /// Dialog title before marking a session unpaid again. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Mark as unpaid?'**
  String get carePayUnpaidTitle;

  /// Dialog body before marking a session unpaid. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'They\'ll need to pay before they can join.'**
  String get carePayUnpaidBody;

  /// Button and dialog action: mark a session unpaid. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Mark as unpaid'**
  String get carePayMarkUnpaid;

  /// Snackbar after a payment status change. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Payment updated.'**
  String get carePaymentUpdated;

  /// Request status: the client started a request but hasn't paid, so it hasn't reached the care team. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Not sent yet — the client hasn\'t paid'**
  String get careStatusAwaitingPayment;

  /// Request status. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be matched'**
  String get careStatusPending;

  /// Request status. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Matched — waiting for payment'**
  String get careStatusMatchedUnpaid;

  /// Request status. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get careStatusBooked;

  /// Request status: the client missed the session. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Completed — the client didn\'t join, so the session counts as used'**
  String get careStatusMissed;

  /// Request status. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get careStatusCompleted;

  /// Request status with the date it was completed. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Completed {date}'**
  String careStatusCompletedOn(String date);

  /// Request status. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — the therapist didn\'t join the call'**
  String get careStatusTherapistNoShow;

  /// Request status. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — nobody joined the call'**
  String get careStatusNobodyJoined;

  /// Request status. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancelled — never paid'**
  String get careStatusNeverPaid;

  /// Request status: the client abandoned the request before paying. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Discarded before it was paid for'**
  String get careStatusDiscarded;

  /// Request status. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get careStatusCancelled;

  /// Payment line: the client's first session is free. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Free first session'**
  String get careFreeFirstSession;

  /// Payment line: price, paid on a date. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'{price} · paid on {date}'**
  String carePaidOn(String price, String date);

  /// Payment line: price, paid (date unknown). Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'{price} · paid'**
  String carePaid(String price);

  /// Payment line: price, fee waived. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'{price} · waived'**
  String careWaived(String price);

  /// Payment line: price, refunded on a date. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'{price} · refunded on {date}, not paid'**
  String careRefundedOn(String price, String date);

  /// Payment line: price, not paid yet. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'{price} · not paid yet'**
  String careNotPaidYet(String price);

  /// Section heading (shown in capitals). Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get careSectionClient;

  /// Shown when the client gave no name. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'No name given'**
  String get careNoName;

  /// Tooltip on the button that copies the client's email. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Copy email'**
  String get careCopyEmail;

  /// Snackbar after copying the client's email. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Email copied.'**
  String get careEmailCopied;

  /// Section heading (shown in capitals): what the client asked for. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get careSectionRequest;

  /// When the client sent the request. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Asked {when}'**
  String careAsked(String when);

  /// Section heading (shown in capitals). Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get careSectionSession;

  /// Session date/time and length in minutes. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'{when} · {minutes, plural, other{{minutes} min}}'**
  String careSessionWhen(String when, int minutes);

  /// Button. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Match with a therapist'**
  String get careMatchWithTherapist;

  /// Button. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Change therapist or time'**
  String get careChangeTherapistOrTime;

  /// Section heading (shown in capitals). Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get careSectionPayment;

  /// Section heading (shown in capitals): notes and ratings after the session. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'After the session'**
  String get careSectionAfter;

  /// Heading: the note the therapist wrote to the client after the session. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Note to the client'**
  String get careNoteToClient;

  /// Shown when the therapist wrote no note. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'No note written.'**
  String get careNoNote;

  /// Heading: how the client rated the session. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Client\'s rating'**
  String get careClientRating;

  /// Shown when there is no rating yet. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Not rated yet.'**
  String get careNotRatedYet;

  /// Heading: the therapist's private rating of the session (the client never sees it). Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Therapist\'s rating — private'**
  String get careTherapistRating;

  /// Destructive text button. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancel this session'**
  String get careCancelThisSession;

  /// Destructive text button. Care-team (staff) screen showing one therapy request.
  ///
  /// In en, this message translates to:
  /// **'Cancel this request'**
  String get careCancelThisRequest;

  /// Snackbar when the photo library could not be opened. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open your photo library.'**
  String get careEditorPhotoFailed;

  /// Snackbar/error when saving failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — check your connection.'**
  String get careCouldNotSave;

  /// App bar title. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Add a therapist'**
  String get careEditorTitleAdd;

  /// App bar title. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Edit therapist'**
  String get careEditorTitleEdit;

  /// Button under the therapist's photo. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get careEditorChangePhoto;

  /// Button under the photo placeholder. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get careEditorAddPhoto;

  /// Form field label. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get careEditorFullName;

  /// Validation error under the name field. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Enter their full name'**
  String get careEditorFullNameError;

  /// Form field label: the email the therapist signs in with. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Sign-in email'**
  String get careEditorEmail;

  /// Helper text under the sign-in email field. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'They sign in to the app with this address.'**
  String get careEditorEmailHelp;

  /// Validation error under the email field. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get careEditorEmailError;

  /// Form field label: the therapist's professional title. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get careEditorTitleField;

  /// Example placeholder in the professional title field. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Counselling psychologist'**
  String get careEditorTitleHint;

  /// Form field label: professional licence or registration. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Licence or registration'**
  String get careEditorLicence;

  /// Placeholder in the licence field: the licensing body and the number. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Body and registration number'**
  String get careEditorLicenceHint;

  /// Form field label. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get careEditorYears;

  /// Validation error under the years-of-experience field. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'A number from 0 to 70'**
  String get careEditorYearsError;

  /// Form field label: languages the therapist works in. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get careEditorLanguages;

  /// Example placeholder in the languages field (a comma-separated list of languages). Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'English, Swahili'**
  String get careEditorLanguagesHint;

  /// Form field label: the therapist's bio. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'About them'**
  String get careEditorAbout;

  /// Helper text under the bio field. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Clients read this on their profile.'**
  String get careEditorAboutHelp;

  /// Section header above specialty choices. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get careEditorSpecialties;

  /// Switch: whether the therapist can be matched. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Taking new clients'**
  String get careEditorTakingClients;

  /// Under the Taking new clients switch. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'When off, they can\'t be matched. Their booked and past sessions stay.'**
  String get careEditorTakingClientsHint;

  /// Save button when adding a new therapist. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Add therapist'**
  String get careEditorAddButton;

  /// Note under the add button. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'They\'ll get an email explaining how to sign in and find their sessions.'**
  String get careEditorInviteNote;

  /// Section header above clients' ratings of this therapist. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Client feedback'**
  String get careEditorFeedback;

  /// Note under the Client feedback header. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Only the care team sees individual ratings. Clients see an average once there are three.'**
  String get careEditorFeedbackNote;

  /// Therapist stats: upcoming and completed session counts. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'{upcoming} upcoming · {completed} completed'**
  String careEditorStats(int upcoming, int completed);

  /// Average rating and how many ratings it is from, e.g. "4.5 from 3". Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'{rating} from {count}'**
  String careEditorRatingFrom(String rating, int count);

  /// The therapist has signed in to the app with this email. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String careEditorSignedInAs(String email);

  /// Warning: the therapist hasn't signed in yet. Care-team (staff) form for adding or editing a therapist.
  ///
  /// In en, this message translates to:
  /// **'Hasn\'t signed in yet. They need to sign in to the app with {email} to see and join sessions.'**
  String careEditorNotSignedIn(String email);

  /// Error when the therapist's sessions fail to load. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your sessions — check your connection.'**
  String get careSessionsCouldNotLoad;

  /// Snackbar after editing a finished session. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get careSessionsSaved;

  /// Snackbar after finishing a session. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Session finished — thank you.'**
  String get careSessionsFinished;

  /// App bar title. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'My sessions'**
  String get careSessionsTitle;

  /// Empty state. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet. When the care team books one with you, it shows up here and you\'ll get an email.'**
  String get careSessionsEmpty;

  /// Section header: sessions to come. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get careSessionsUpcoming;

  /// Section header: earlier sessions. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get careSessionsPast;

  /// Hint under the disabled Join button. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'The call opens 10 minutes before the start.'**
  String get careSessionsTooEarly;

  /// Hint under the Join button after the session's time is over. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'The call has closed. Finish the session to close it out — otherwise it closes itself in a couple of hours.'**
  String get careSessionsOver;

  /// Hint under the disabled Join button. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'The client hasn\'t paid yet — the call opens once they do.'**
  String get careSessionsUnpaid;

  /// Hint under the Join button when the call can be joined. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'The call is open.'**
  String get careSessionsOpen;

  /// The client's note from their request, quoted. Use your language's quotation marks. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'They wrote: “{note}”'**
  String careSessionsTheyWrote(String note);

  /// Button: join the video call. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Join session'**
  String get careSessionsJoin;

  /// Button: mark the session as finished (opens a sheet). Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Finish session'**
  String get careSessionsFinish;

  /// On a past session the client missed. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'The client didn\'t join the call.'**
  String get careSessionsClientMissed;

  /// Label on a past session that was closed because nobody joined. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t happen'**
  String get careSessionsDidNotHappen;

  /// Small badge on a past session the therapist hasn't rated yet. Therapist-facing screen listing their own sessions.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get careSessionsRate;

  /// Error when flags or a private note are given without a star rating. Therapist-facing sheet for finishing a session (note to client, private rating).
  ///
  /// In en, this message translates to:
  /// **'Add a star rating to send private feedback.'**
  String get careFinishNeedsRating;

  /// Sheet title when editing a finished session. {name} is the client's first name. Therapist-facing sheet for finishing a session (note to client, private rating).
  ///
  /// In en, this message translates to:
  /// **'Session with {name}'**
  String careFinishTitleDone(String name);

  /// Sheet title. {name} is the client's first name. Therapist-facing sheet for finishing a session (note to client, private rating).
  ///
  /// In en, this message translates to:
  /// **'Finish your session with {name}'**
  String careFinishTitle(String name);

  /// Field label: a note the client will see. {name} is the client's first name. Therapist-facing sheet for finishing a session (note to client, private rating).
  ///
  /// In en, this message translates to:
  /// **'A note for {name} (optional)'**
  String careFinishNoteLabel(String name);

  /// Helper text under the note field. Therapist-facing sheet for finishing a session (note to client, private rating).
  ///
  /// In en, this message translates to:
  /// **'They see this in the app — a takeaway, or something to practise. Keep clinical notes out of it.'**
  String get careFinishNoteHelp;

  /// Heading above the star rating. Therapist-facing sheet for finishing a session (note to client, private rating).
  ///
  /// In en, this message translates to:
  /// **'How did it go?'**
  String get careFinishHowDidItGo;

  /// Field label: a note only the care team sees. Therapist-facing sheet for finishing a session (note to client, private rating).
  ///
  /// In en, this message translates to:
  /// **'Private note for the care team (optional)'**
  String get careFinishPrivateNote;

  /// Note under the private fields. Therapist-facing sheet for finishing a session (note to client, private rating).
  ///
  /// In en, this message translates to:
  /// **'Only the care team sees your rating, flags and private note. Flagging a safety concern emails them straight away.'**
  String get careFinishPrivacy;

  /// Progress label at the top of a guided exercise (CBT, sleep, stress toolkits), e.g. "Step 2 of 6".
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String toolkitStepOf(int step, int total);

  /// Snackbar after an exercise was saved as a journal entry.
  ///
  /// In en, this message translates to:
  /// **'Saved to your journal.'**
  String get toolkitSavedToJournal;

  /// Snackbar when saving an exercise to the journal failed, probably because the phone is offline.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — check your connection.'**
  String get toolkitSaveFailed;

  /// Snackbar when an outside web link could not be opened in the browser.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open {url}'**
  String toolkitCouldntOpenLink(String url);

  /// Section heading on a toolkit's front page (CBT, sleep, stress): the interactive exercises.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get toolkitToolsTitle;

  /// Section heading on a toolkit's front page: short reading lessons.
  ///
  /// In en, this message translates to:
  /// **'Learn the ideas'**
  String get toolkitLessonsTitle;

  /// Subtitle under "Free resources" on a toolkit's front page.
  ///
  /// In en, this message translates to:
  /// **'Reputable, clinician-written material from outside the app. Links open in your browser.'**
  String get toolkitResourcesIntro;

  /// Section heading on a toolkit's front page: links to free material on other websites.
  ///
  /// In en, this message translates to:
  /// **'Free resources'**
  String get toolkitFreeResources;

  /// Title of the upgrade sheet shown when tapping a locked toolkit tool or lesson.
  ///
  /// In en, this message translates to:
  /// **'This is part of Premium'**
  String get toolkitPremiumTitle;

  /// Message of the upgrade sheet for a locked toolkit item. {offer} is the free-trial phrase, e.g. "you can try it free first".
  ///
  /// In en, this message translates to:
  /// **'Free includes a taste of each programme. Premium unlocks every tool and read — and {offer}.'**
  String toolkitPremiumMessage(String offer);

  /// Counts under a section heading: how many items are free and how many need Premium, e.g. "1 free · 6 Premium". "Premium" is the plan name.
  ///
  /// In en, this message translates to:
  /// **'{free} free · {locked} Premium'**
  String toolkitCountLine(int free, int locked);

  /// How long a tool takes, on a toolkit card, e.g. "4 min".
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} min}}'**
  String toolkitMinutes(int minutes);

  /// How long a short reading lesson takes, e.g. "3 min read".
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} min read}}'**
  String toolkitMinutesRead(int minutes);

  /// App bar title of the screen showing one short reading lesson.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get toolkitLearnTitle;

  /// Title of the upgrade sheet when a toolkit links to a locked meditation or breathing session.
  ///
  /// In en, this message translates to:
  /// **'This session is part of Premium'**
  String get toolkitSessionPremiumTitle;

  /// Message of the upgrade sheet for a locked meditation/breathing session. {offer} is the free-trial phrase, e.g. "you can try it free first".
  ///
  /// In en, this message translates to:
  /// **'Free includes a taste of each practice. Premium unlocks every session — and {offer}.'**
  String toolkitSessionPremiumMessage(String offer);

  /// App bar title of the CBT (cognitive behavioural therapy) toolkit's front page.
  ///
  /// In en, this message translates to:
  /// **'CBT toolkit'**
  String get cbtTitle;

  /// Headline at the top of the CBT toolkit's front page.
  ///
  /// In en, this message translates to:
  /// **'Skills you can use today'**
  String get cbtHeadline;

  /// Intro paragraph on the CBT toolkit's front page. Warm, plain, non-clinical.
  ///
  /// In en, this message translates to:
  /// **'Cognitive behavioural therapy is the best-studied talking therapy for anxiety and depression, and much of it is learnable. These are the tools therapists hand out first — for the minutes between sessions, or before you\'ve had one.'**
  String get cbtIntro;

  /// Banner at the bottom of the CBT toolkit inviting the person to book a therapist.
  ///
  /// In en, this message translates to:
  /// **'Want to do this with someone?'**
  String get cbtTherapistBannerTitle;

  /// Detail line of the banner inviting the person to book a therapist session.
  ///
  /// In en, this message translates to:
  /// **'A licensed therapist can take you through these properly. Book a private video session.'**
  String get cbtTherapistBannerDetail;

  /// Safety footnote at the end of the CBT toolkit. "Get help now" is the name of the crisis button on the Home screen — keep it consistent with that button's translation.
  ///
  /// In en, this message translates to:
  /// **'Self-help is not a substitute for care in a crisis. If you\'re in immediate danger, use Get help now on the Home screen.'**
  String get cbtFootnote;

  /// App bar title of the stress toolkit's front page.
  ///
  /// In en, this message translates to:
  /// **'Manage stress'**
  String get stressTitle;

  /// Headline on the stress toolkit's front page: first calm the body down, then deal with what's causing the stress. Idiomatic, can be rephrased.
  ///
  /// In en, this message translates to:
  /// **'Down from the ceiling, then sort the load'**
  String get stressHeadline;

  /// Intro paragraph on the stress toolkit's front page.
  ///
  /// In en, this message translates to:
  /// **'Stress is a body state before it\'s a thought, so the fastest tools work on the body: breath and muscles first, thinking second. Then a check-in to see the trend, and two tools for the load itself — what you can change, and what refills you.'**
  String get stressIntro;

  /// Banner on the stress toolkit pointing to the CBT toolkit.
  ///
  /// In en, this message translates to:
  /// **'When the stress is in the thinking'**
  String get stressCbtBannerTitle;

  /// Detail line of the banner pointing from the stress toolkit to the CBT toolkit. Names of three CBT tools.
  ///
  /// In en, this message translates to:
  /// **'Thought records, thinking traps and worry windows are in the CBT toolkit.'**
  String get stressCbtBannerDetail;

  /// Banner on the stress toolkit for long-lasting stress, inviting the person to book a therapist.
  ///
  /// In en, this message translates to:
  /// **'Been like this for months?'**
  String get stressTherapistBannerTitle;

  /// Detail line of the banner inviting the person to book a therapist session.
  ///
  /// In en, this message translates to:
  /// **'That\'s worth a real conversation. Book a private session with a licensed therapist.'**
  String get stressTherapistBannerDetail;

  /// Safety footnote at the end of the stress toolkit.
  ///
  /// In en, this message translates to:
  /// **'Chest pain, breathlessness or palpitations that don\'t settle need a doctor, not a breathing exercise. In an emergency, call your local emergency number.'**
  String get stressFootnote;

  /// App bar title of the 5-4-3-2-1 grounding exercise (name five things you see, four you feel, …).
  ///
  /// In en, this message translates to:
  /// **'Grounding'**
  String get groundingTitle;

  /// Heading when the grounding exercise is finished: you are present, in this moment.
  ///
  /// In en, this message translates to:
  /// **'You\'re here'**
  String get groundingDoneTitle;

  /// Calming text when the grounding exercise is finished.
  ///
  /// In en, this message translates to:
  /// **'Notice your breathing. Notice the weight of your body where you\'re sitting. Whatever was pulling at you is still there, but you\'re here, and here is manageable.'**
  String get groundingDoneBody;

  /// Button after the grounding exercise: opens the breathing exercises.
  ///
  /// In en, this message translates to:
  /// **'Breathe for a few minutes'**
  String get groundingBreatheButton;

  /// Button after an exercise: start it again from the beginning.
  ///
  /// In en, this message translates to:
  /// **'Go again'**
  String get toolkitGoAgain;

  /// Big button in the grounding exercise: tap each time you notice one thing (e.g. one thing you can see).
  ///
  /// In en, this message translates to:
  /// **'Found one'**
  String get groundingFoundOne;

  /// Same button as groundingFoundOne, when only one thing is left to find in this step.
  ///
  /// In en, this message translates to:
  /// **'Found one — last'**
  String get groundingFoundLast;

  /// Step title in the grounding exercise, e.g. "5 things you can see". {sense} is a verb from the exercise content (see, feel, hear, smell, taste), currently in English.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} things you can {sense}}}'**
  String groundingStepTitle(int count, String sense);

  /// Small text under the big number in the grounding exercise: how many things are still to find in this step (the number is shown above it, e.g. "3" / "to go").
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{to go}}'**
  String groundingToGo(int count);

  /// Wraps a quoted thought in the CBT tools in this language's quotation marks (e.g. „…“ in German, « … » in French).
  ///
  /// In en, this message translates to:
  /// **'“{text}”'**
  String cbtQuoted(String text);

  /// App bar title of the screen listing common unhelpful thinking patterns (cognitive distortions).
  ///
  /// In en, this message translates to:
  /// **'Thinking traps'**
  String get thinkingTrapsTitle;

  /// Section heading at the top of the thinking traps screen.
  ///
  /// In en, this message translates to:
  /// **'Spot the pattern'**
  String get thinkingTrapsSectionTitle;

  /// Intro under "Spot the pattern" on the thinking traps screen. "Distortions" = unhelpful thinking patterns.
  ///
  /// In en, this message translates to:
  /// **'Anxious and low moods run on a handful of predictable distortions. Naming one takes some of its power away. Write the thought that\'s bothering you, then see which of these it\'s wearing.'**
  String get thinkingTrapsSectionBody;

  /// Label of the text field where the person may type the thought that's bothering them.
  ///
  /// In en, this message translates to:
  /// **'The thought (optional)'**
  String get thinkingTrapsThoughtLabel;

  /// Note under the thought the person typed, asking which thinking trap it matches. {thought} is already in quotation marks. Keep the blank line.
  ///
  /// In en, this message translates to:
  /// **'{thought}\n\nWhich of these does it sound like?'**
  String thinkingTrapsWhichOne(String thought);

  /// Small label (shown in capitals) above an example of a thinking trap.
  ///
  /// In en, this message translates to:
  /// **'For example'**
  String get thinkingTrapsForExample;

  /// Small label (shown in capitals) above the question that helps loosen a thinking trap.
  ///
  /// In en, this message translates to:
  /// **'Ask yourself'**
  String get thinkingTrapsAskYourself;

  /// Note at the end of the thinking traps list, pointing to the thought record tool.
  ///
  /// In en, this message translates to:
  /// **'Found one? The thought record walks you through checking the evidence and writing something fairer.'**
  String get thinkingTrapsFooter;

  /// Feeling the person can pick in the thought record (a chip).
  ///
  /// In en, this message translates to:
  /// **'Anxious'**
  String get cbtFeelingAnxious;

  /// Feeling the person can pick in the thought record (a chip).
  ///
  /// In en, this message translates to:
  /// **'Sad'**
  String get cbtFeelingSad;

  /// Feeling the person can pick in the thought record (a chip).
  ///
  /// In en, this message translates to:
  /// **'Angry'**
  String get cbtFeelingAngry;

  /// Feeling the person can pick in the thought record (a chip).
  ///
  /// In en, this message translates to:
  /// **'Ashamed'**
  String get cbtFeelingAshamed;

  /// Feeling the person can pick in the thought record (a chip).
  ///
  /// In en, this message translates to:
  /// **'Guilty'**
  String get cbtFeelingGuilty;

  /// Feeling the person can pick in the thought record (a chip).
  ///
  /// In en, this message translates to:
  /// **'Hopeless'**
  String get cbtFeelingHopeless;

  /// Feeling the person can pick in the thought record (a chip).
  ///
  /// In en, this message translates to:
  /// **'Lonely'**
  String get cbtFeelingLonely;

  /// Feeling the person can pick in the thought record (a chip).
  ///
  /// In en, this message translates to:
  /// **'Overwhelmed'**
  String get cbtFeelingOverwhelmed;

  /// App bar title of the thought record exercise (a CBT worksheet), and the title of the journal entry it saves.
  ///
  /// In en, this message translates to:
  /// **'Thought record'**
  String get thoughtRecordTitle;

  /// In the thought record summary, after "Thinking traps:" when none were picked. Lower case, continues the line.
  ///
  /// In en, this message translates to:
  /// **'none spotted'**
  String get thoughtRecordNoneSpotted;

  /// Summary of a finished thought record, shown on the last step and saved to the journal. One labelled line each; keep the line breaks. {before}/{after} are 0–100 intensity ratings; empty answers show as "—".
  ///
  /// In en, this message translates to:
  /// **'Situation: {situation}\nAutomatic thought: {thought}\nFeeling: {feelings} — {before}/100 before\nThinking traps: {traps}\nEvidence for: {evidenceFor}\nEvidence against: {evidenceAgainst}\nBalanced thought: {balanced}\nFeeling now: {after}/100'**
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
  );

  /// Under a slider rating how strong a feeling is, from 0 to 100.
  ///
  /// In en, this message translates to:
  /// **'{value} out of 100'**
  String thoughtRecordOutOf100(int value);

  /// Step 1 question of the thought record.
  ///
  /// In en, this message translates to:
  /// **'What was the situation?'**
  String get thoughtRecordStep1Title;

  /// Hint under step 1 of the thought record.
  ///
  /// In en, this message translates to:
  /// **'Just the facts, as a camera would have seen them. Where were you, who was there, what happened?'**
  String get thoughtRecordStep1Hint;

  /// Example in the text field for step 1 of the thought record (the situation).
  ///
  /// In en, this message translates to:
  /// **'e.g. Sent a message at 2pm, no reply by 9pm'**
  String get thoughtRecordStep1Field;

  /// Step 2 question of the thought record: the automatic thought.
  ///
  /// In en, this message translates to:
  /// **'What went through your mind?'**
  String get thoughtRecordStep2Title;

  /// Hint under step 2 of the thought record.
  ///
  /// In en, this message translates to:
  /// **'The first, quickest thought — the one that stung. Write it the way it sounded in your head.'**
  String get thoughtRecordStep2Hint;

  /// Example in the text field for step 2 of the thought record (the thought).
  ///
  /// In en, this message translates to:
  /// **'e.g. She\'s had enough of me'**
  String get thoughtRecordStep2Field;

  /// Step 3 question of the thought record.
  ///
  /// In en, this message translates to:
  /// **'How did it make you feel?'**
  String get thoughtRecordStep3Title;

  /// Hint under step 3 of the thought record: pick feelings, then rate them on a slider.
  ///
  /// In en, this message translates to:
  /// **'Pick what fits, then rate how strong it was.'**
  String get thoughtRecordStep3Hint;

  /// Step 4 question of the thought record: which unhelpful thinking patterns fit.
  ///
  /// In en, this message translates to:
  /// **'Any thinking traps in there?'**
  String get thoughtRecordStep4Title;

  /// Hint under step 4 of the thought record. "Hot thoughts" = the most upsetting thoughts (CBT term).
  ///
  /// In en, this message translates to:
  /// **'Tap any that fit. Most hot thoughts have at least one.'**
  String get thoughtRecordStep4Hint;

  /// Step 5 heading of the thought record.
  ///
  /// In en, this message translates to:
  /// **'Check the evidence'**
  String get thoughtRecordStep5Title;

  /// Hint under step 5 of the thought record.
  ///
  /// In en, this message translates to:
  /// **'Facts, not feelings. What would a fair judge accept?'**
  String get thoughtRecordStep5Hint;

  /// Text field label in step 5 of the thought record: evidence for the thought.
  ///
  /// In en, this message translates to:
  /// **'What supports the thought?'**
  String get thoughtRecordEvidenceFor;

  /// Text field label in step 5 of the thought record: evidence against the thought.
  ///
  /// In en, this message translates to:
  /// **'What doesn\'t fit with it?'**
  String get thoughtRecordEvidenceAgainst;

  /// Heading of a note in step 5 listing questions for the thinking traps the person picked.
  ///
  /// In en, this message translates to:
  /// **'Questions worth asking'**
  String get thoughtRecordQuestionsWorthAsking;

  /// Step 6 heading of the thought record: write a more balanced thought.
  ///
  /// In en, this message translates to:
  /// **'Write a fairer thought'**
  String get thoughtRecordStep6Title;

  /// Hint under step 6 of the thought record. The quoted openings are examples of how a balanced thought may start.
  ///
  /// In en, this message translates to:
  /// **'Not the cheerful opposite — something you could defend. It often starts \"Even though…\" or \"It\'s possible that…\".'**
  String get thoughtRecordStep6Hint;

  /// Text field label in step 6 of the thought record.
  ///
  /// In en, this message translates to:
  /// **'A more balanced way to see it'**
  String get thoughtRecordBalancedField;

  /// Step 7 question of the thought record: rate the feeling again.
  ///
  /// In en, this message translates to:
  /// **'How strong is the feeling now?'**
  String get thoughtRecordStep7Title;

  /// Hint under step 7 of the thought record.
  ///
  /// In en, this message translates to:
  /// **'It rarely goes to zero. A few points down is the skill working.'**
  String get thoughtRecordStep7Hint;

  /// Button at the end of a CBT exercise: save it as a journal entry.
  ///
  /// In en, this message translates to:
  /// **'Save to journal'**
  String get cbtSaveToJournal;

  /// A bulleted line in a list (CBT tools).
  ///
  /// In en, this message translates to:
  /// **'• {text}'**
  String cbtBullet(String text);

  /// Snackbar after the person "parks" a worry to look at later, during their daily worry time.
  ///
  /// In en, this message translates to:
  /// **'Parked. It\'ll be here at worry time — you don\'t have to hold it now.'**
  String get worryTimeParked;

  /// Snackbar when the daily worry window (a 15-minute timer) runs out.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up. Whatever\'s left can wait for tomorrow\'s window.'**
  String get worryTimeTimesUp;

  /// Shown under a worry the person decided to make a plan for.
  ///
  /// In en, this message translates to:
  /// **'You\'ve got a plan for this one.'**
  String get worryTimeHavePlan;

  /// Shown under a worry the person decided to let go of.
  ///
  /// In en, this message translates to:
  /// **'Let go — nothing to do here today.'**
  String get worryTimeLetGo;

  /// Question under each worry during the worry window.
  ///
  /// In en, this message translates to:
  /// **'Can you do something about it in the next week?'**
  String get worryTimeCanYouAct;

  /// Answer button: yes, I can do something about this worry, so I'll plan it.
  ///
  /// In en, this message translates to:
  /// **'Yes — plan it'**
  String get worryTimeYesPlan;

  /// Answer button: no, I can't act on this worry, so I'll let it go.
  ///
  /// In en, this message translates to:
  /// **'No — let it go'**
  String get worryTimeNoLetGo;

  /// App bar title of the worry time tool (CBT technique: postpone worrying to a set daily window).
  ///
  /// In en, this message translates to:
  /// **'Worry window'**
  String get worryTimeTitle;

  /// Section heading at the top of the worry window screen.
  ///
  /// In en, this message translates to:
  /// **'Worry later, on purpose'**
  String get worryTimeSectionTitle;

  /// Explanation of the worry window technique.
  ///
  /// In en, this message translates to:
  /// **'You can\'t stop a worry arriving, but you can decide when to give it attention. Park it here as it comes. Then, once a day, open a fifteen-minute window and go through the list — and only then.'**
  String get worryTimeSectionBody;

  /// Text field label for typing a worry to park.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind right now?'**
  String get worryTimeInputLabel;

  /// Tooltip of the button that parks (saves for later) the typed worry.
  ///
  /// In en, this message translates to:
  /// **'Park it'**
  String get worryTimeParkTooltip;

  /// Shown when no worries are waiting for the worry window.
  ///
  /// In en, this message translates to:
  /// **'Nothing parked'**
  String get worryTimeNothingParked;

  /// How many worries are waiting for the worry window, e.g. "3 parked for worry time".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} parked for worry time}}'**
  String worryTimeParkedCount(int count);

  /// Tip under the parked-worries count about when to hold the worry window.
  ///
  /// In en, this message translates to:
  /// **'Best kept to the same time each day — not the hour before bed.'**
  String get worryTimeBestTime;

  /// Button that starts the 15-minute worry window timer. Short.
  ///
  /// In en, this message translates to:
  /// **'Open window'**
  String get worryTimeOpenWindow;

  /// Instruction next to the timer while the worry window is open.
  ///
  /// In en, this message translates to:
  /// **'Go through each worry once. Decide, don\'t dwell.'**
  String get worryTimeGoThrough;

  /// Section heading above the list of parked worries.
  ///
  /// In en, this message translates to:
  /// **'Your list'**
  String get worryTimeYourList;

  /// Small button that removes the worries already decided on (planned or let go).
  ///
  /// In en, this message translates to:
  /// **'Clear decided'**
  String get worryTimeClearDecided;

  /// Empty state of the worry list.
  ///
  /// In en, this message translates to:
  /// **'Your parked worries appear here. Most people find half of them have lost their sting by the time the window opens.'**
  String get worryTimeEmpty;

  /// Chip in the problem-solving tool: when to take the first step.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get problemSolvingWhenToday;

  /// Chip in the problem-solving tool: when to take the first step.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get problemSolvingWhenTomorrow;

  /// Chip in the problem-solving tool: when to take the first step.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get problemSolvingWhenThisWeek;

  /// Chip in the problem-solving tool: when to take the first step.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get problemSolvingWhenNextWeek;

  /// Summary of a problem-solving plan, saved to the journal. Keep the line breaks. {options} is a list separated by semicolons; {when} is e.g. "Tomorrow".
  ///
  /// In en, this message translates to:
  /// **'Problem: {problem}\nOptions considered: {options}\nChosen: {chosen}\nFirst step: {firstStep} — {when}'**
  String problemSolvingSummary(
    String problem,
    String options,
    String chosen,
    String firstStep,
    String when,
  );

  /// Title of the journal entry saved from the problem-solving tool.
  ///
  /// In en, this message translates to:
  /// **'Problem-solving plan'**
  String get problemSolvingPlanTitle;

  /// App bar title of the structured problem-solving tool (CBT).
  ///
  /// In en, this message translates to:
  /// **'Problem solving'**
  String get problemSolvingTitle;

  /// Step 1 question of the problem-solving tool.
  ///
  /// In en, this message translates to:
  /// **'What exactly is the problem?'**
  String get problemSolvingStep1Title;

  /// Hint under step 1 of problem solving. Adapt the money example (currency, rent) so it feels natural in the language.
  ///
  /// In en, this message translates to:
  /// **'One problem, in one sentence, specific enough to act on. \"Money\" is a worry; \"I\'m £300 short for rent on the 1st\" is a problem.'**
  String get problemSolvingStep1Hint;

  /// Text field label in step 1 of problem solving.
  ///
  /// In en, this message translates to:
  /// **'The problem, precisely'**
  String get problemSolvingStep1Field;

  /// Step 2 heading of problem solving: brainstorm possible solutions.
  ///
  /// In en, this message translates to:
  /// **'List every option'**
  String get problemSolvingStep2Title;

  /// Hint under step 2 of problem solving.
  ///
  /// In en, this message translates to:
  /// **'Don\'t judge them yet — bad ideas loosen up good ones. Aim for at least three, including one you\'d never do.'**
  String get problemSolvingStep2Hint;

  /// Text field label for adding one possible solution.
  ///
  /// In en, this message translates to:
  /// **'An option'**
  String get problemSolvingOptionField;

  /// Step 3 heading of problem solving.
  ///
  /// In en, this message translates to:
  /// **'Pick one to try'**
  String get problemSolvingStep3Title;

  /// Hint under step 3 of problem solving.
  ///
  /// In en, this message translates to:
  /// **'Not the perfect one — the one that\'s good enough and that you\'d actually do. You can come back to the others.'**
  String get problemSolvingStep3Hint;

  /// Step 4 question of problem solving.
  ///
  /// In en, this message translates to:
  /// **'What\'s the first step?'**
  String get problemSolvingStep4Title;

  /// Hint under step 4 of problem solving.
  ///
  /// In en, this message translates to:
  /// **'Something that takes under twenty minutes and needs no one\'s permission. Then decide when.'**
  String get problemSolvingStep4Hint;

  /// Note in step 4 of problem solving showing the option the person chose.
  ///
  /// In en, this message translates to:
  /// **'Trying: {option}'**
  String problemSolvingTrying(String option);

  /// Text field label in step 4 of problem solving.
  ///
  /// In en, this message translates to:
  /// **'First step'**
  String get problemSolvingFirstStepField;

  /// Snackbar when the person tries to pick a fourth activity for today in the activity planner.
  ///
  /// In en, this message translates to:
  /// **'Three is plenty for one day. Swap one out if you\'d rather.'**
  String get activityPlannerTooMany;

  /// Snackbar when every activity picked for today is ticked off.
  ///
  /// In en, this message translates to:
  /// **'That\'s today\'s plan done. Notice how you feel now compared with before.'**
  String get activityPlannerAllDone;

  /// App bar title of the activity planner (behavioural activation: plan small, doable activities when mood is low).
  ///
  /// In en, this message translates to:
  /// **'One small thing'**
  String get activityPlannerTitle;

  /// Section heading at the top of the activity planner.
  ///
  /// In en, this message translates to:
  /// **'Do first, feel later'**
  String get activityPlannerSectionTitle;

  /// Explanation at the top of the activity planner.
  ///
  /// In en, this message translates to:
  /// **'When mood is low, motivation doesn\'t come before action — it comes after. Pick up to three small things for today. Small enough that you\'d do them on a bad day.'**
  String get activityPlannerSectionBody;

  /// Heading of today's picked activities with progress, e.g. "Today · 1 of 3 done".
  ///
  /// In en, this message translates to:
  /// **'{total, plural, other{Today · {done} of {total} done}}'**
  String activityPlannerTodayProgress(int done, int total);

  /// Section heading above the list of suggested activities.
  ///
  /// In en, this message translates to:
  /// **'Ideas'**
  String get activityPlannerIdeas;

  /// Filter chip showing activity ideas of every category.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activityPlannerAll;

  /// Text field label for adding a custom activity.
  ///
  /// In en, this message translates to:
  /// **'Or something of your own'**
  String get activityPlannerOwnField;

  /// Chip in the "What's in your hands" tool: this stressor is something I can change. One word.
  ///
  /// In en, this message translates to:
  /// **'Control'**
  String get controlCircleZoneControl;

  /// Explains the "Control" circle: things I can change.
  ///
  /// In en, this message translates to:
  /// **'I can change this'**
  String get controlCircleZoneControlHint;

  /// Chip in the "What's in your hands" tool: this stressor is something I can only influence. One word.
  ///
  /// In en, this message translates to:
  /// **'Influence'**
  String get controlCircleZoneInfluence;

  /// Explains the "Influence" circle: things I can push on or influence, but not decide.
  ///
  /// In en, this message translates to:
  /// **'I can lean on it'**
  String get controlCircleZoneInfluenceHint;

  /// Chip in the "What's in your hands" tool: this stressor is something to accept. One word.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get controlCircleZoneAccept;

  /// Explains the "Accept" circle: things outside my control.
  ///
  /// In en, this message translates to:
  /// **'Not mine to move'**
  String get controlCircleZoneAcceptHint;

  /// Advice under the stressors sorted into the "Control" circle.
  ///
  /// In en, this message translates to:
  /// **'These are yours to move. Pick one — the smallest — and take the first step this week.'**
  String get controlCircleControlAdvice;

  /// Button under the "Control" circle summary: opens the problem-solving tool for one of these stressors.
  ///
  /// In en, this message translates to:
  /// **'Work one through'**
  String get controlCircleControlAction;

  /// Advice under the stressors sorted into the "Influence" circle.
  ///
  /// In en, this message translates to:
  /// **'You can\'t decide these, but you can ask, say, or nudge. What is the one conversation each of these needs?'**
  String get controlCircleInfluenceAdvice;

  /// Advice under the stressors sorted into the "Accept" circle.
  ///
  /// In en, this message translates to:
  /// **'Not yours to carry, and carrying them anyway is where a lot of stress lives. Practise setting them down — it\'s a skill, not a mood.'**
  String get controlCircleAcceptAdvice;

  /// Button under the "Accept" circle summary: opens a slow-exhale breathing exercise.
  ///
  /// In en, this message translates to:
  /// **'Breathe it out'**
  String get controlCircleAcceptAction;

  /// Heading of a circle's summary: the circle's name and how many stressors are in it, e.g. "Control · 2".
  ///
  /// In en, this message translates to:
  /// **'{zone} · {count}'**
  String controlCircleZoneCount(String zone, int count);

  /// App bar title of the control-circle tool (sort stressors into what you can control, influence, or must accept).
  ///
  /// In en, this message translates to:
  /// **'What\'s in your hands'**
  String get controlCircleTitle;

  /// Section heading at the top of the control-circle tool.
  ///
  /// In en, this message translates to:
  /// **'Three circles'**
  String get controlCircleSectionTitle;

  /// Explanation at the top of the control-circle tool. Inner circle = control; outer = influence and accept.
  ///
  /// In en, this message translates to:
  /// **'Write down everything that\'s weighing on you, then sort each one. Most stress comes from spending effort in the outer circles and neglecting the inner one.'**
  String get controlCircleSectionBody;

  /// Text field label for adding a stressor.
  ///
  /// In en, this message translates to:
  /// **'Something on your mind'**
  String get controlCircleInputLabel;

  /// Section heading above the summary of stressors per circle.
  ///
  /// In en, this message translates to:
  /// **'Where your effort goes'**
  String get controlCircleEffortTitle;

  /// Empty state of the control-circle tool. The quoted words are examples of vague stressors; adapt them to the language.
  ///
  /// In en, this message translates to:
  /// **'Start with whatever came to mind first. Vague is fine — \"work\", \"money\", \"mum\" — you can sharpen it later.'**
  String get controlCircleEmpty;

  /// Button that starts a timed exercise (e.g. muscle relaxation).
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get toolkitBegin;

  /// App bar title of the progressive muscle relaxation exercise.
  ///
  /// In en, this message translates to:
  /// **'Tense and release'**
  String get muscleRelaxTitle;

  /// Section heading before starting progressive muscle relaxation: eight muscle groups, each tensed once.
  ///
  /// In en, this message translates to:
  /// **'Eight groups, once each'**
  String get muscleRelaxIntroTitle;

  /// Instructions before starting progressive muscle relaxation.
  ///
  /// In en, this message translates to:
  /// **'Sit or lie somewhere you won\'t be disturbed for eight minutes. For each group: tense hard for five seconds — not to pain — then let go completely for ten, and notice the difference. That noticing is the exercise.'**
  String get muscleRelaxIntroBody;

  /// Section heading after finishing progressive muscle relaxation.
  ///
  /// In en, this message translates to:
  /// **'Let it all stay loose'**
  String get muscleRelaxDoneTitle;

  /// Text after finishing progressive muscle relaxation.
  ///
  /// In en, this message translates to:
  /// **'Sit for a moment before you get up. Where was the most tension hiding? That\'s the place to check in on during the day.'**
  String get muscleRelaxDoneBody;

  /// Instruction during the release phase of a muscle group.
  ///
  /// In en, this message translates to:
  /// **'Let go all at once. Feel the difference.'**
  String get muscleRelaxReleaseHint;

  /// Big label in the circle while the person tenses a muscle group (imperative). Short.
  ///
  /// In en, this message translates to:
  /// **'Tense'**
  String get muscleRelaxTense;

  /// Big label in the circle while the person relaxes a muscle group (imperative). Short.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get muscleRelaxRelease;

  /// Label in the circle during the physiological sigh: first inhale. Short.
  ///
  /// In en, this message translates to:
  /// **'Breathe in'**
  String get sighPhaseIn;

  /// Instruction during the first inhale of the physiological sigh.
  ///
  /// In en, this message translates to:
  /// **'Through the nose, most of the way.'**
  String get sighPhaseInHint;

  /// Label in the circle during the physiological sigh: a second, short inhale on top of the first ("sip" of air). Short.
  ///
  /// In en, this message translates to:
  /// **'One more sip'**
  String get sighPhaseSip;

  /// Instruction during the second short inhale of the physiological sigh.
  ///
  /// In en, this message translates to:
  /// **'A short top-up, right to the top.'**
  String get sighPhaseSipHint;

  /// Label in the circle during the physiological sigh: the long exhale. Short.
  ///
  /// In en, this message translates to:
  /// **'Long breath out'**
  String get sighPhaseOut;

  /// Instruction during the long exhale of the physiological sigh.
  ///
  /// In en, this message translates to:
  /// **'Slowly, through the mouth, until you\'re empty.'**
  String get sighPhaseOutHint;

  /// App bar title of the physiological sigh breathing exercise (two inhales, one long exhale).
  ///
  /// In en, this message translates to:
  /// **'Physiological sigh'**
  String get sighTitle;

  /// Button after finishing the physiological sigh: do it again.
  ///
  /// In en, this message translates to:
  /// **'Another round'**
  String get sighAnotherRound;

  /// Button that starts the physiological sigh exercise.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get sighStart;

  /// Section heading when the physiological sigh exercise is finished.
  ///
  /// In en, this message translates to:
  /// **'That\'s the round'**
  String get sighDoneTitle;

  /// Section heading while the physiological sigh runs, e.g. "Round 2 of 5".
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String sighRoundOf(int round, int total);

  /// Section heading before the physiological sigh starts: two inhales, one long exhale.
  ///
  /// In en, this message translates to:
  /// **'Two in, one long out'**
  String get sighIntroTitle;

  /// Text after the physiological sigh is finished.
  ///
  /// In en, this message translates to:
  /// **'Notice your shoulders and your jaw. Most people feel the drop within a round or two. Use it any time — in a meeting, in a queue, before a call.'**
  String get sighDoneBody;

  /// Instructions before the physiological sigh starts.
  ///
  /// In en, this message translates to:
  /// **'Breathe in through your nose, then take one more short sip on top. Let it all out slowly through your mouth. That\'s one. Follow the circle.'**
  String get sighIntroBody;

  /// Label in the circle when the physiological sigh is finished. Short.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get sighDone;

  /// Label in the circle before the physiological sigh starts. Short.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get sighReady;

  /// App bar title of the recharge tool: list what drains and what refills your energy.
  ///
  /// In en, this message translates to:
  /// **'Recharge list'**
  String get rechargeTitle;

  /// Section heading at the top of the recharge list (your energy is like a fuel tank).
  ///
  /// In en, this message translates to:
  /// **'Know your tank'**
  String get rechargeSectionTitle;

  /// Explanation at the top of the recharge list.
  ///
  /// In en, this message translates to:
  /// **'Stress is a budget: things that take from it and things that pay in. Most people can name the drains instantly and go quiet on the refills. Write both. Then choose one refill for today — and treat it as an appointment.'**
  String get rechargeSectionBody;

  /// Highlighted note showing the refill (energising activity) chosen for today.
  ///
  /// In en, this message translates to:
  /// **'Today: {pick}'**
  String rechargeToday(String pick);

  /// Section heading: things that use up my energy.
  ///
  /// In en, this message translates to:
  /// **'What drains me'**
  String get rechargeDrainsTitle;

  /// Text field label for adding something that drains energy.
  ///
  /// In en, this message translates to:
  /// **'Add a drain'**
  String get rechargeAddDrain;

  /// Section heading: things that restore my energy.
  ///
  /// In en, this message translates to:
  /// **'What refills me'**
  String get rechargeRefillsTitle;

  /// Subtitle under "What refills me": tap a refill to choose it for today.
  ///
  /// In en, this message translates to:
  /// **'Tap one to make it today\'s.'**
  String get rechargeRefillsHint;

  /// Text field label for adding something that restores energy.
  ///
  /// In en, this message translates to:
  /// **'Add a refill'**
  String get rechargeAddRefill;

  /// Heading above suggested refills the person can add with one tap.
  ///
  /// In en, this message translates to:
  /// **'Stuck for refills? Borrow one:'**
  String get rechargeBorrow;

  /// Result band of the weekly stress check-in: low stress.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get stressBandLow;

  /// Advice shown with a low stress check-in score.
  ///
  /// In en, this message translates to:
  /// **'You\'re carrying this week fine. Keep whatever recovery you\'ve got in place — it\'s working.'**
  String get stressBandLowAdvice;

  /// Result band of the weekly stress check-in: moderate stress.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get stressBandModerate;

  /// Advice shown with a moderate stress check-in score. "A sigh round" = one round of the physiological sigh breathing exercise.
  ///
  /// In en, this message translates to:
  /// **'Noticeable, and worth ten deliberate minutes a day: a sigh round, a walk, a proper break. Sort one thing that\'s in your hands.'**
  String get stressBandModerateAdvice;

  /// Result band of the weekly stress check-in: high stress.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get stressBandHigh;

  /// Advice shown with a high stress check-in score. "Sigh" and "tense and release" are names of two exercises in the app.
  ///
  /// In en, this message translates to:
  /// **'A lot right now. Bring the body down first — sigh, tense and release — then look at the load. If it\'s been like this for weeks, talk to someone; that\'s what the therapist sessions are for.'**
  String get stressBandHighAdvice;

  /// A numbered question in the stress check-in, e.g. "1. How often have you felt…".
  ///
  /// In en, this message translates to:
  /// **'{number}. {question}'**
  String stressCheckinQuestion(int number, String question);

  /// Heading above a small bar chart of recent stress check-in scores.
  ///
  /// In en, this message translates to:
  /// **'Your last check-ins'**
  String get stressCheckinHistoryTitle;

  /// Caption under the stress check-in chart: date range, then how to read the 0–20 score.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to} · 0 is calm, 20 is a lot'**
  String stressCheckinHistoryRange(String from, String to);

  /// App bar title of the weekly stress check-in questionnaire.
  ///
  /// In en, this message translates to:
  /// **'Stress check-in'**
  String get stressCheckinTitle;

  /// Big result line of the stress check-in, e.g. "10 out of 20 · Moderate".
  ///
  /// In en, this message translates to:
  /// **'{score} out of 20 · {band}'**
  String stressCheckinScore(int score, String band);

  /// Small print under the stress check-in result.
  ///
  /// In en, this message translates to:
  /// **'A check-in is a snapshot of one week, not a diagnosis. If the high scores keep coming, that\'s the signal to talk to someone.'**
  String get stressCheckinDisclaimer;

  /// Button that finishes the stress check-in and shows the score.
  ///
  /// In en, this message translates to:
  /// **'See my score'**
  String get stressCheckinSeeScore;

  /// Disabled button while the stress check-in isn't complete, e.g. "3 of 5 answered".
  ///
  /// In en, this message translates to:
  /// **'{total, plural, other{{answered} of {total} answered}}'**
  String stressCheckinAnswered(int answered, int total);

  /// Section heading at the top of the stress check-in: the questions are about the past week.
  ///
  /// In en, this message translates to:
  /// **'The past week'**
  String get stressCheckinSectionTitle;

  /// Instruction at the top of the stress check-in.
  ///
  /// In en, this message translates to:
  /// **'Go with your first answer. Once a week, same day, gives you a line you can actually read.'**
  String get stressCheckinSectionBody;
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
