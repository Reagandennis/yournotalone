import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_zh.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ];

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

  /// Screen title. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night). Short.
  ///
  /// In en, this message translates to:
  /// **'Awake at 3am?'**
  String get awakeTitle;

  /// Step 1 heading. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Awake, and it\'s not passing?'**
  String get awakeStep1Title;

  /// Step 1 hint under the heading. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night). Gentle, sleepy tone.
  ///
  /// In en, this message translates to:
  /// **'Don\'t check the time — it only gives you sums to do. If it feels like you\'ve been lying here twenty minutes or more, that\'s long enough.'**
  String get awakeStep1Hint;

  /// Step 1 explanatory note. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Lying in bed awake and frustrated teaches your brain that the bed is a place to be awake and frustrated. Getting up breaks that link. It feels backwards; it\'s the most reliable trick sleep clinics have.'**
  String get awakeStep1Note;

  /// Step 2 heading. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Get up. Low light, something dull.'**
  String get awakeStep2Title;

  /// Step 2 hint. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Another room if you can. No bright screens, no news, no work. Boring is the goal — you\'re waiting for sleepiness to come back, not entertaining yourself.'**
  String get awakeStep2Hint;

  /// Next to the break countdown timer. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Sleepy before this runs out? Go back to bed now — sleepiness wins over the timer.'**
  String get awakeTimerHint;

  /// Option card title: a breathing exercise (4 counts in, hold, out, hold). Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Box breathing'**
  String get awakeOptionBoxBreathing;

  /// Option card detail for box breathing. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Four counts each way, in the dark.'**
  String get awakeOptionBoxBreathingDetail;

  /// Option card title: play a calming sound. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'A quiet sound'**
  String get awakeOptionSound;

  /// Option card detail for the sound option. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Rain or crickets, low, on a timer.'**
  String get awakeOptionSoundDetail;

  /// Option card title: a long guided meditation called "Deep rest". Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Deep rest'**
  String get awakeOptionDeepRest;

  /// Option card detail for Deep rest. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'A long guided lie-down for when sleep won\'t come.'**
  String get awakeOptionDeepRestDetail;

  /// Option card title: read something boring. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'A dull book'**
  String get awakeOptionBook;

  /// Option card detail for the book option. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Something you\'ve read before. Paper, if you have it.'**
  String get awakeOptionBookDetail;

  /// Step 3 heading. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Back to bed when sleepy — not when the clock says'**
  String get awakeStep3Title;

  /// Step 3 hint. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Heavy eyes, slow thoughts, a yawn. That\'s the signal. If it doesn\'t come, stay up a little longer; if you go back and it doesn\'t take, do the whole thing again.'**
  String get awakeStep3Hint;

  /// Step 3 note about the next morning. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Tomorrow: get up at your usual time however the night went. The sleep pressure you build will make tonight easier. One rough night is survivable; a drifting wake time isn\'t.'**
  String get awakeStep3Note;

  /// Button on step 1: confirms they have been awake long enough to get up. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Yes — I\'ve been awake a while'**
  String get awakeConfirmButton;

  /// Button on step 2: starts a 15-minute out-of-bed timer. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Start a 15-minute break'**
  String get awakeStartBreakButton;

  /// Button while the break timer runs: ends it early. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'I\'m sleepy — back to bed'**
  String get awakeSleepyButton;

  /// Final button: closes the screen. Awake at 3am? (sleep toolkit: the 20-minute rule, used in the middle of the night).
  ///
  /// In en, this message translates to:
  /// **'Goodnight'**
  String get awakeGoodnightButton;

  /// Screen title. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Sleep diary'**
  String get sleepDiaryTitle;

  /// Summary text when no nights are logged. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Log a night to get started.'**
  String get sleepDiaryVerdictEmpty;

  /// Summary after 1–4 nights. pct = average sleep efficiency percentage. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Sleep efficiency {pct}% so far. Five nights in, this starts to mean something — keep going.'**
  String sleepDiaryVerdictEarly(int pct);

  /// Summary when efficiency is 85% or more. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Sleep efficiency {pct}%: your bed is doing its job. If you\'re still tired, the lever is probably total time — try lights out 15 minutes earlier, same wake time.'**
  String sleepDiaryVerdictGood(int pct);

  /// Summary when efficiency is under 85% (sleep restriction advice). Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Sleep efficiency {pct}%. Under 85% means a lot of your time in bed is spent awake, which teaches the bed the wrong lesson. Tighten the window: later to bed, same wake time, until it\'s above 85%, then add 15 minutes a week.'**
  String sleepDiaryVerdictLow(int pct);

  /// A duration of sleep, e.g. "7h 05m". minutes is already zero-padded. Use the local short units. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String sleepDiaryHoursMinutes(int hours, String minutes);

  /// How they felt on waking, 1 of 5 (worst). Short chip label; also shown lower-cased in the night list. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Awful'**
  String get sleepDiaryQualityAwful;

  /// How they felt on waking, 2 of 5. Short chip label. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get sleepDiaryQualityPoor;

  /// How they felt on waking, 3 of 5. Short chip label. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get sleepDiaryQualityOkay;

  /// How they felt on waking, 4 of 5. Short chip label. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get sleepDiaryQualityGood;

  /// How they felt on waking, 5 of 5 (best). Short chip label. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get sleepDiaryQualityGreat;

  /// Row label and time-picker title: the time they turned the lights off to sleep. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Lights out'**
  String get sleepDiaryLightsOut;

  /// Row label and time-picker title: the time they finally woke up for the day. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Woke for the day'**
  String get sleepDiaryWoke;

  /// Snackbar after saving a night. duration is like "7h 05m". Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Logged: {duration} asleep, {pct}% efficient.'**
  String sleepDiaryLogged(String duration, int pct);

  /// Slider label with its current value in minutes, e.g. "Time to fall asleep · 15 min". Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'{label} · {minutes} min'**
  String sleepDiarySliderLabel(String label, int minutes);

  /// Section title of the logging form. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Last night'**
  String get sleepDiaryLastNight;

  /// Hint under "Last night". Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Best guesses are fine — don\'t clock-watch to get this right. Rough and every day beats exact and occasional.'**
  String get sleepDiaryLastNightHint;

  /// Slider label: minutes it took to fall asleep. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Time to fall asleep'**
  String get sleepDiaryTimeToFallAsleep;

  /// Slider label: minutes awake in the night. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Awake during the night'**
  String get sleepDiaryAwakeInNight;

  /// Question above the 5 quality chips. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'How did you feel on waking?'**
  String get sleepDiaryHowDidYouFeel;

  /// Section title of the overview. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Your nights'**
  String get sleepDiaryYourNights;

  /// Explains sleep efficiency. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Sleep efficiency is the share of your time in bed you actually spend asleep. Clinics aim for 85% and above.'**
  String get sleepDiaryYourNightsHint;

  /// Small stat label: average sleep efficiency. Sleep diary (sleep toolkit: log last night, see sleep efficiency). Short.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get sleepDiaryStatEfficiency;

  /// Small stat label: average time asleep. Sleep diary (sleep toolkit: log last night, see sleep efficiency). Short.
  ///
  /// In en, this message translates to:
  /// **'Asleep'**
  String get sleepDiaryStatAsleep;

  /// Small stat label: nights logged this week. Sleep diary (sleep toolkit: log last night, see sleep efficiency). Short.
  ///
  /// In en, this message translates to:
  /// **'Nights'**
  String get sleepDiaryStatNights;

  /// Stat value: how many of the last 7 nights are logged. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'{count} of 7'**
  String sleepDiaryNightsOfSeven(int count);

  /// The suggested sleep window (24-hour times). Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Suggested window: in bed {bed} to {wake}.'**
  String sleepDiarySuggestedWindow(String bed, String wake);

  /// Empty state. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'No nights yet. Log this morning\'s and the picture starts to form within a week.'**
  String get sleepDiaryEmpty;

  /// One night in the list: bed time → wake time · time asleep. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'{bed} → {wake} · {duration} asleep'**
  String sleepDiaryNightSummary(String bed, String wake, String duration);

  /// Second line of a night in the list. date is yyyy-mm-dd; quality is a lower-cased quality word (e.g. "good"). Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'{date} · {latency} min to drop off, {awake} min awake · {quality}'**
  String sleepDiaryNightDetail(
    String date,
    int latency,
    int awake,
    String quality,
  );

  /// Button: save the logged night. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Save night'**
  String get sleepDiarySaveNight;

  /// Button when today is already logged. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Edit this morning\'s entry'**
  String get sleepDiaryEditToday;

  /// Button: start logging last night. Sleep diary (sleep toolkit: log last night, see sleep efficiency).
  ///
  /// In en, this message translates to:
  /// **'Log last night'**
  String get sleepDiaryLogLastNight;

  /// Screen title. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'Sleep habits check'**
  String get sleepHabitsTitle;

  /// Answer chip for a habit question. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get sleepHabitsYes;

  /// Answer chip for a habit question. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get sleepHabitsNo;

  /// Result summary when no habits need work. "The diary" and "the 20-minute rule" are other sleep tools in the app. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'Nothing here is working against you. If sleep is still hard, the diary and the 20-minute rule are the next places to look.'**
  String get sleepHabitsVerdictNone;

  /// Result summary for 1–2 habits to work on. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'One or two habits to change — small, and they tend to pay back within a week or two.'**
  String get sleepHabitsVerdictFew;

  /// Result summary for 3–4 habits to work on. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'A few things are stacking up against your nights. Pick the easiest one first; momentum matters more than order.'**
  String get sleepHabitsVerdictSome;

  /// Result summary for 5+ habits to work on. Encouraging, not judging. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'Quite a lot is working against you, which is actually good news: there\'s a lot of room to improve without anything drastic. Start with the wake time.'**
  String get sleepHabitsVerdictMany;

  /// Results title when no habits need work. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get sleepHabitsAllClear;

  /// Results title: how many of the ten habits need work. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'{count} of 10 to work on'**
  String sleepHabitsToWorkOn(int count);

  /// Button: redo the questions. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'Answer again'**
  String get sleepHabitsAnswerAgain;

  /// Button when all questions are answered. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'See what to change'**
  String get sleepHabitsSeeResults;

  /// Disabled button text showing progress. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} answered'**
  String sleepHabitsAnswered(int answered, int total);

  /// Section title above the questions. Friendly. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'Honest answers, please'**
  String get sleepHabitsIntroTitle;

  /// Hint above the questions. Sleep habits check (sleep toolkit: ten yes/no questions about habits that hurt sleep).
  ///
  /// In en, this message translates to:
  /// **'Most of these are ordinary — everyone has a few. Each yes comes with a specific, small change.'**
  String get sleepHabitsIntroHint;

  /// Screen title of the sleep toolkit. Sleep toolkit hub screen ("Sleep better").
  ///
  /// In en, this message translates to:
  /// **'Sleep better'**
  String get sleepHubTitle;

  /// Headline at the top of the hub. Sleep toolkit hub screen ("Sleep better").
  ///
  /// In en, this message translates to:
  /// **'Sleep is built in the daytime'**
  String get sleepHubHeadline;

  /// Intro paragraph. Sleep toolkit hub screen ("Sleep better").
  ///
  /// In en, this message translates to:
  /// **'Most sleep problems aren\'t fixed in bed. They\'re fixed by a steady wake time, an evening that winds down on purpose, and not fighting the nights that go wrong. These are the tools sleep clinics use — cognitive behavioural therapy for insomnia — in a form you can start tonight.'**
  String get sleepHubIntro;

  /// Banner title linking to the sounds screen. Sleep toolkit hub screen ("Sleep better").
  ///
  /// In en, this message translates to:
  /// **'Sounds to fall asleep to'**
  String get sleepHubSoundsTitle;

  /// Banner detail for sounds. Sleep toolkit hub screen ("Sleep better").
  ///
  /// In en, this message translates to:
  /// **'Rainfall, crickets, pink noise and more — loops that keep going after you\'ve stopped listening.'**
  String get sleepHubSoundsDetail;

  /// Medical-safety footnote at the bottom of the hub. Keep the meaning precise. Sleep toolkit hub screen ("Sleep better").
  ///
  /// In en, this message translates to:
  /// **'Snoring with pauses in breathing, falling asleep in the day, or insomnia that\'s lasted months deserve a doctor\'s look. These tools sit alongside that, not instead of it.'**
  String get sleepHubFootnote;

  /// Screen title; also the title of the journal entry it can save. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Put the day down'**
  String get tomorrowListTitle;

  /// Text of the journal entry saved from this screen. top is a numbered list (one per line) or "—"; letGo and good are what the person wrote, or "—". Keep the line breaks. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Tomorrow:\n{top}\n\nLetting go tonight: {letGo}\nOne good thing today: {good}'**
  String tomorrowListSummary(String top, String letGo, String good);

  /// Snackbar after saving without the journal. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Written down. It\'ll keep till morning.'**
  String get tomorrowListSaved;

  /// Button: save this page to the journal too. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Save to journal'**
  String get tomorrowListSaveToJournal;

  /// Main button: save and close. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Done for tonight'**
  String get tomorrowListDoneForTonight;

  /// Section title. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Out of your head, onto the page'**
  String get tomorrowListIntroTitle;

  /// Intro text. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'The 2am mind is a to-do list with nowhere to go. Give it somewhere. Three things for tomorrow — not ten — one thing you\'re choosing not to carry tonight, and one thing that was good today, however small.'**
  String get tomorrowListIntroHint;

  /// Label above three text fields for tomorrow's tasks. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s three'**
  String get tomorrowListTopThree;

  /// Text field label, numbered 1–3. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Thing {number}'**
  String tomorrowListThing(int number);

  /// Label above a text field: a worry to set aside tonight. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Tonight I\'m letting go of'**
  String get tomorrowListLetGo;

  /// Field label inside the let-go text field. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'A worry that can wait until daylight'**
  String get tomorrowListLetGoHint;

  /// Label above a text field. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'One good thing today'**
  String get tomorrowListGood;

  /// Field label inside the good-thing text field: even small things count. Put the day down (sleep toolkit: write tomorrow's three things, one worry to let go, one good thing).
  ///
  /// In en, this message translates to:
  /// **'Small counts'**
  String get tomorrowListGoodHint;

  /// Screen title. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'Wind-down plan'**
  String get windDownTitle;

  /// Title of the time picker for bedtime. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'Lights out at'**
  String get windDownPickerTitle;

  /// Snackbar when every step is ticked. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'That\'s the whole wind-down. Sleep well.'**
  String get windDownAllDone;

  /// Section title. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'The last hour decides the night'**
  String get windDownIntroTitle;

  /// Intro text. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'Bodies don\'t switch off; they dim. The same five steps in the same order, every evening, become the cue your brain waits for. Tick them off as you go.'**
  String get windDownIntroHint;

  /// Bedtime shown in a card, e.g. "Lights out at 22:30". Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'Lights out at {time}'**
  String windDownLightsOutAt(String time);

  /// Under the bedtime. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'Same time most nights, and a wake time that never moves.'**
  String get windDownLightsOutHint;

  /// Note pointing to the Reminders screen. "Reminders" is the name of that screen. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'Want a nudge when it\'s time to start? The Wind-down reminder is in Reminders.'**
  String get windDownReminderNote;

  /// Short button: open Reminders to set the wind-down reminder. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'Set it'**
  String get windDownReminderButton;

  /// Above each step: its clock time and how many minutes before bedtime. Wind-down plan (sleep toolkit: an hour of steps counted back from bedtime).
  ///
  /// In en, this message translates to:
  /// **'{time} · {minutes} min before'**
  String windDownStepTime(String time, int minutes);

  /// Snackbar when saving fails. Journal entry editor.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your entry — check your connection.'**
  String get journalEditorSaveFailed;

  /// Snackbar when deleting fails. Journal entry editor.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the entry — check your connection.'**
  String get journalEditorDeleteFailed;

  /// Confirm dialog title. Journal entry editor.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get journalEditorDeleteTitle;

  /// Confirm dialog body. Journal entry editor.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone.'**
  String get journalEditorDeleteBody;

  /// Tooltip/accessibility label of the delete icon. Journal entry editor.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get journalEditorDeleteTooltip;

  /// Placeholder in the title field. Journal entry editor.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get journalEditorTitleHint;

  /// Placeholder in the main writing area. Private, warm. Journal entry editor.
  ///
  /// In en, this message translates to:
  /// **'Whatever\'s on your mind — this space is yours alone.'**
  String get journalEditorBodyHint;

  /// Main button. Journal entry editor.
  ///
  /// In en, this message translates to:
  /// **'Save entry'**
  String get journalEditorSave;

  /// Screen title. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Journal & mood'**
  String get journalHubTitle;

  /// Intro under the title. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Put the day into words — start from a blank page or let a prompt do the opening line.'**
  String get journalHubIntro;

  /// Section heading above the writing options. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get journalHubWriteSection;

  /// Card title: opens the list of entries. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'My journal'**
  String get journalHubMyJournal;

  /// Card detail for My journal. One line. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Every entry you\'ve written, newest first.'**
  String get journalHubMyJournalDetail;

  /// Card title: start a blank entry. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Free write'**
  String get journalHubFreeWrite;

  /// Card detail for Free write. One line. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'A blank page, no prompt, no rules.'**
  String get journalHubFreeWriteDetail;

  /// Section heading above mood history. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get journalHubMoodSection;

  /// Card title: opens past mood check-ins. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Mood history'**
  String get journalHubMoodHistory;

  /// Card detail for Mood history. One line. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Every check-in, and how the weeks actually went.'**
  String get journalHubMoodHistoryDetail;

  /// Upgrade sheet title when a free user taps a locked writing prompt. "Premium" is the paid plan name. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'This prompt is part of Premium'**
  String get journalHubPromptPremiumTitle;

  /// Upgrade sheet message. count = number of prompts; offer is a separately translated phrase such as "you can try it free first". Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Free includes a prompt to try. Premium unlocks all {count} — and {offer}.'**
  String journalHubPromptPremiumMessage(int count, String offer);

  /// Upgrade sheet title when a free user taps Mood history. Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Mood history is part of Premium'**
  String get journalHubMoodPremiumTitle;

  /// Upgrade sheet message. offer is a separately translated phrase such as "you can try it free first". Journal & mood hub screen.
  ///
  /// In en, this message translates to:
  /// **'Checking in is always free. Premium keeps the record and shows you the pattern — and {offer}.'**
  String journalHubMoodPremiumMessage(String offer);

  /// Screen title. Journal entry list screen.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get journalTitle;

  /// Date label on an entry written today. Journal entry list screen.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get journalToday;

  /// Date label on an entry written yesterday. Journal entry list screen.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get journalYesterday;

  /// Shown for an entry with no title. Journal entry list screen.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get journalUntitled;

  /// Error state when the entries fail to load. Journal entry list screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your journal.'**
  String get journalLoadFailed;

  /// Empty state; keep the line break. Journal entry list screen.
  ///
  /// In en, this message translates to:
  /// **'Your space is ready.\nWrite your first entry whenever you like.'**
  String get journalEmpty;

  /// Intro under the title (Premium users). Journal entry list screen.
  ///
  /// In en, this message translates to:
  /// **'A private place for whatever\'s on your mind.'**
  String get journalIntro;

  /// Intro under the title for free users, with how many of the free entries are used, e.g. "3/5". Journal entry list screen.
  ///
  /// In en, this message translates to:
  /// **'A private place for whatever\'s on your mind · {count}/{limit} free entries used.'**
  String journalIntroFree(int count, int limit);

  /// Kind of practice session, shown in the practice history list (e.g. 'Meditation · Today').
  ///
  /// In en, this message translates to:
  /// **'Meditation'**
  String get practiceKindMeditation;

  /// Kind of practice session: a breathing exercise. Shown in the practice history list.
  ///
  /// In en, this message translates to:
  /// **'Breathing'**
  String get practiceKindBreathing;

  /// Kind of practice session: listening to a calming sound. Shown in the practice history list.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get practiceKindSound;

  /// Answer after a session to 'How do you feel now?' compared with before. Short; fits a small button.
  ///
  /// In en, this message translates to:
  /// **'Worse'**
  String get feelingWorse;

  /// Answer after a session to 'How do you feel now?': no change. Short; fits a small button.
  ///
  /// In en, this message translates to:
  /// **'About the same'**
  String get feelingSame;

  /// Answer after a session to 'How do you feel now?': feels better. Short; fits a small button.
  ///
  /// In en, this message translates to:
  /// **'Better'**
  String get feelingBetter;

  /// Encouraging summary on the practice and mood-insights screens. answered is always 3 or more.
  ///
  /// In en, this message translates to:
  /// **'{answered, plural, other{You felt better after {better} of your last {answered} sessions.}}'**
  String feelingSummaryLine(int answered, int better);

  /// Title of the upgrade sheet shown after someone completes their second free session.
  ///
  /// In en, this message translates to:
  /// **'You\'ve finished your free sessions'**
  String get practiceFreeSessionsDoneTitle;

  /// Body of the upgrade sheet after the free sessions. offer is the intro offer phrase, already translated, e.g. 'a 7-day free trial'.
  ///
  /// In en, this message translates to:
  /// **'Premium opens all 20 meditations and every breathing exercise, with the sounds to go with them — and {offer}.'**
  String practiceFreeSessionsDoneMessage(String offer);

  /// Question at the end of a meditation/breathing/sound session.
  ///
  /// In en, this message translates to:
  /// **'How do you feel now?'**
  String get closeOutHowDoYouFeel;

  /// Replaces closeOutHowDoYouFeel once the person has answered. Warm and brief.
  ///
  /// In en, this message translates to:
  /// **'Noted. Thank you.'**
  String get closeOutNoted;

  /// Hint under 'How do you feel now?': compare with the start of the session.
  ///
  /// In en, this message translates to:
  /// **'Compared with when you started.'**
  String get closeOutCompared;

  /// Button at the end of a session: opens a new journal entry.
  ///
  /// In en, this message translates to:
  /// **'Write about it'**
  String get closeOutWriteAboutIt;

  /// Opening words placed in a new journal entry after a session; the person keeps writing from here. Keep the trailing space. title is the session's name in lower case.
  ///
  /// In en, this message translates to:
  /// **'After {title}, I noticed '**
  String closeOutJournalSeed(String title);

  /// Date label in the practice history list for a session done today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get practiceToday;

  /// Date label in the practice history list for a session done yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get practiceYesterday;

  /// ICU/intl DateFormat pattern for a session date this year (English shows '5 Jan'). Translate as a date pattern for your language, e.g. 'd. MMM' or 'M月d日'. Do not translate the letters as words.
  ///
  /// In en, this message translates to:
  /// **'d MMM'**
  String get practiceDatePattern;

  /// ICU/intl DateFormat pattern for a session date in an earlier year (English shows '5 Jan 2025'). A date pattern, not words.
  ///
  /// In en, this message translates to:
  /// **'d MMM y'**
  String get practiceDatePatternWithYear;

  /// Line under a session in the practice history: the kind of practice and when.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {date}'**
  String practiceSessionMeta(String kind, String date);

  /// How long a session lasted, abbreviated minutes, right-aligned in the history list.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} min}}'**
  String practiceMinutesShort(int minutes);

  /// Error on the practice screen when the session history fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your practice history.'**
  String get practiceLoadError;

  /// Empty state of the practice history screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Finish a meditation, a breathing session, or a few minutes of sound, and it starts filling in.'**
  String get practiceEmpty;

  /// Section heading above a bar strip of daily practice minutes.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get practiceLast30Days;

  /// Small label under a big number on the practice screen: number of sessions in the last 30 days. Only the word; the number is shown above it.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{sessions}}'**
  String practiceStatSessions(int count);

  /// Small label under a big number: total minutes practised. Only the word.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{minutes}}'**
  String practiceStatMinutes(int count);

  /// Small label under a big number: how many days in a row someone has practised. Only the words.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{day streak}}'**
  String practiceStatDayStreak(int count);

  /// Small label under a big number: minutes practised this week. Only the words.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{this week}}'**
  String practiceStatThisWeek(int count);

  /// Section heading above the full list of past sessions.
  ///
  /// In en, this message translates to:
  /// **'Every session'**
  String get practiceEverySession;

  /// Title of the practice history screen.
  ///
  /// In en, this message translates to:
  /// **'Your practice'**
  String get practiceTitle;

  /// Gentle subtitle on the practice history screen: the time spent counts even if no one saw it.
  ///
  /// In en, this message translates to:
  /// **'Minutes nobody else counted. They still happened.'**
  String get practiceSubtitle;

  /// Status on a day of a multi-day course: this day is completed. Short label beside the day.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get courseDayDone;

  /// Status on the next day of a course: it unlocks tomorrow (one new day per day). Short label.
  ///
  /// In en, this message translates to:
  /// **'Opens tomorrow'**
  String get courseDayOpensTomorrow;

  /// Status on a course day that isn't open yet: just its number.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String courseDayNumber(int day);

  /// Under the progress bar on a finished course.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, other{All {days} days done. Come back to any of them whenever you need.}}'**
  String courseAllDaysDone(int days);

  /// Under the progress bar on a course in progress.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, other{{done} of {total} days done · one new step each day}}'**
  String courseDaysDoneProgress(int done, int total);

  /// Line on a course card suggested to the person, before they start it.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, other{Picked for you · {days} days}}'**
  String courseCardPickedForYou(int days);

  /// Line on a course card in a list, before it's started.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, other{{days} days · a step a day}}'**
  String courseCardStepADay(int days);

  /// Line on a course card once every day is done.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, other{Finished · all {days} days}}'**
  String courseCardFinished(int days);

  /// Line on a course card: the next day is open now.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, other{Day {day} of {total} · ready today}}'**
  String courseCardReadyToday(int day, int total);

  /// Line on a course card: the next day unlocks tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Day {day} opens tomorrow'**
  String courseCardOpensTomorrow(int day);

  /// Milestone headline on the weekly 'rhythm' (sunrise) card when the weekly goal is met for the first week. Warm, celebratory, never pressuring.
  ///
  /// In en, this message translates to:
  /// **'A first week of looking after yourself.'**
  String get rhythmMilestoneWeek1;

  /// Rhythm milestone headline: 4 weeks in a row of meeting the weekly goal.
  ///
  /// In en, this message translates to:
  /// **'A month of looking after yourself.'**
  String get rhythmMilestoneWeek4;

  /// Rhythm milestone headline: 12 weeks in a row.
  ///
  /// In en, this message translates to:
  /// **'Three months of showing up for yourself.'**
  String get rhythmMilestoneWeek12;

  /// Rhythm milestone headline: 26 weeks in a row.
  ///
  /// In en, this message translates to:
  /// **'Half a year of small, steady steps.'**
  String get rhythmMilestoneWeek26;

  /// Rhythm milestone headline: 52 weeks in a row. The card shows a sunrise picture that rises as the week fills.
  ///
  /// In en, this message translates to:
  /// **'A whole year of sunrises.'**
  String get rhythmMilestoneWeek52;

  /// Rhythm card headline when someone returns after 3+ days away. Never about loss.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get rhythmWelcomeBack;

  /// Rhythm card headline when the weekly goal is met (the sunrise picture is fully risen).
  ///
  /// In en, this message translates to:
  /// **'Your sun is up this week'**
  String get rhythmSunIsUp;

  /// Rhythm card headline at the start of a week with nothing done yet.
  ///
  /// In en, this message translates to:
  /// **'A new week, a new sunrise'**
  String get rhythmNewWeek;

  /// Rhythm card headline: progress towards the weekly goal of days.
  ///
  /// In en, this message translates to:
  /// **'{goal, plural, other{{days} of {goal} days this week}}'**
  String rhythmDaysThisWeek(int days, int goal);

  /// Line under the rhythm headline before anything has been done: any small action (mood check-in, breathing exercise, journal entry) counts.
  ///
  /// In en, this message translates to:
  /// **'Any small step counts — a check-in, a breath, a few lines.'**
  String get rhythmAnyStepCounts;

  /// Line under 'Welcome back' on the rhythm card: total days shown up, and an invitation to count today.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{You\'ve shown up 1 day in total. Today can count too.} other{You\'ve shown up {days} days in total. Today can count too.}}'**
  String rhythmShownUpWelcomeBack(int days);

  /// Line under the rhythm headline: how many weeks in a row the goal was met, and total days shown up.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{{weeks}-week rhythm · 1 day in total} other{{weeks}-week rhythm · {days} days in total}}'**
  String rhythmWeeksAndTotal(int weeks, int days);

  /// Line under the rhythm headline: total days someone has shown up.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day in total} other{{days} days in total}}'**
  String rhythmDaysInTotal(int days);

  /// Screen-reader label for the rhythm card: the headline and the line under it.
  ///
  /// In en, this message translates to:
  /// **'{headline}. {detail}'**
  String rhythmCardSemantics(String headline, String detail);

  /// Title of the rhythm screen (weekly goal of days looking after yourself, shown as a sunrise).
  ///
  /// In en, this message translates to:
  /// **'Your rhythm'**
  String get rhythmTitle;

  /// Heading above the choice of how many days a week to aim for.
  ///
  /// In en, this message translates to:
  /// **'Your weekly goal'**
  String get rhythmWeeklyGoalHeading;

  /// Explains the weekly goal; missed days are rest days, not failures.
  ///
  /// In en, this message translates to:
  /// **'How many days a week feels right? The other days are rest days — they\'re part of the rhythm too.'**
  String get rhythmWeeklyGoalBody;

  /// Under the 1–7 goal chips: the chosen weekly goal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day a week} other{{count} days a week}}'**
  String rhythmDaysAWeek(int count);

  /// Heading above twelve small suns, one per past week.
  ///
  /// In en, this message translates to:
  /// **'The last twelve weeks'**
  String get rhythmLastTwelveWeeks;

  /// Small label under a big number: weeks in a row the goal was met. Only the words; the number is shown above.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{week rhythm}}'**
  String rhythmStatWeekRhythm(int count);

  /// Small label under a big number: the longest run of weeks. Only the word.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{longest}}'**
  String rhythmStatLongest(int count);

  /// Small label under a big number: total days shown up. Only the words.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{days in total}}'**
  String rhythmStatDaysInTotal(int count);

  /// Heading above the list of actions that count as showing up for the day.
  ///
  /// In en, this message translates to:
  /// **'What counts'**
  String get rhythmWhatCounts;

  /// Item in 'What counts' on the rhythm screen.
  ///
  /// In en, this message translates to:
  /// **'A mood check-in'**
  String get rhythmCountsMood;

  /// Item in 'What counts' on the rhythm screen.
  ///
  /// In en, this message translates to:
  /// **'A meditation or breathing exercise'**
  String get rhythmCountsPractice;

  /// Item in 'What counts' on the rhythm screen (calming sounds).
  ///
  /// In en, this message translates to:
  /// **'Listening to a sound'**
  String get rhythmCountsSound;

  /// Item in 'What counts' on the rhythm screen.
  ///
  /// In en, this message translates to:
  /// **'A journal entry'**
  String get rhythmCountsJournal;

  /// Reassurance at the bottom of the rhythm screen.
  ///
  /// In en, this message translates to:
  /// **'One small step is enough for the day. Nothing is lost when you take a break — every day you\'ve shown up stays counted.'**
  String get rhythmNothingIsLost;

  /// Name of the first milestone on a recovery streak (the day someone starts). Shown in milestone lists.
  ///
  /// In en, this message translates to:
  /// **'Day one'**
  String get recoveryMilestoneDayOne;

  /// Name of a recovery-streak milestone measured in days (e.g. '3 days', '90 days').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String recoveryMilestoneDays(int count);

  /// Name of a recovery-streak milestone in weeks (e.g. '1 week', '2 weeks').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String recoveryMilestoneWeeks(int count);

  /// Name of a recovery-streak milestone in months (e.g. '1 month', '6 months').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String recoveryMilestoneMonths(int count);

  /// Name of a recovery-streak milestone in years ('1 year').
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String recoveryMilestoneYears(int count);

  /// What set off a craving: stress. Choice chip in the craving log, also in charts.
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get recoveryTriggerStress;

  /// What set off a craving: boredom. Choice chip in the craving log.
  ///
  /// In en, this message translates to:
  /// **'Boredom'**
  String get recoveryTriggerBoredom;

  /// What set off a craving: loneliness. Choice chip in the craving log.
  ///
  /// In en, this message translates to:
  /// **'Loneliness'**
  String get recoveryTriggerLoneliness;

  /// What set off a craving: pressure from people around you. Choice chip in the craving log.
  ///
  /// In en, this message translates to:
  /// **'Social pressure'**
  String get recoveryTriggerSocialPressure;

  /// What set off a craving: tiredness. Choice chip in the craving log.
  ///
  /// In en, this message translates to:
  /// **'Tiredness'**
  String get recoveryTriggerTiredness;

  /// What set off a craving: plain habit/routine. Choice chip in the craving log.
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get recoveryTriggerHabit;

  /// What set off a craving: something else. Choice chip in the craving log.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get recoveryTriggerOther;

  /// Part of the day a craving was logged (6:00–12:00). Label in the trigger insights chart; can be a single word.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get recoveryPartOfDayMorning;

  /// Part of the day a craving was logged (12:00–18:00).
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get recoveryPartOfDayAfternoon;

  /// Part of the day a craving was logged (18:00–24:00).
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get recoveryPartOfDayEvening;

  /// Part of the day a craving was logged (0:00–6:00).
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get recoveryPartOfDayNight;

  /// Title of the upgrade sheet when a free user taps a premium recovery tool.
  ///
  /// In en, this message translates to:
  /// **'Recovery tracking is part of Premium'**
  String get recoveryPremiumTitle;

  /// Body of the recovery upgrade sheet. offer is the intro offer phrase, already translated, e.g. 'a 7-day free trial'.
  ///
  /// In en, this message translates to:
  /// **'Urge surfing is free for everyone, always. Premium adds commitment streaks, daily pledges, and the trigger tracker — and {offer}.'**
  String recoveryPremiumMessage(String offer);

  /// Title of the sheet for adding a recovery commitment (a habit or substance someone is stopping). Gentle, non-judgemental.
  ///
  /// In en, this message translates to:
  /// **'What are you leaving behind?'**
  String get recoveryAddHabitTitle;

  /// Label/hint of the text field for what someone is quitting.
  ///
  /// In en, this message translates to:
  /// **'e.g. Alcohol, smoking, gambling…'**
  String get recoveryAddHabitHint;

  /// Label above the choice of the streak's start date (Today, Yesterday, Pick a date).
  ///
  /// In en, this message translates to:
  /// **'Counting from'**
  String get recoveryCountingFrom;

  /// Start-date choice chip when adding a recovery commitment.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get recoveryToday;

  /// Start-date choice chip when adding a recovery commitment.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get recoveryYesterday;

  /// Chip that opens a date picker for the streak's start date.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get recoveryPickADate;

  /// Snackbar when saving recovery data (or a journal entry from a recovery tool) fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save — check your connection.'**
  String get recoverySaveFailed;

  /// Snackbar when deleting a recovery commitment fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete — check your connection.'**
  String get recoveryDeleteFailed;

  /// Button that saves a new recovery commitment and starts its day count.
  ///
  /// In en, this message translates to:
  /// **'Start counting'**
  String get recoveryStartCounting;

  /// Snackbar after the daily pledge. habit is what the person is leaving behind, as they typed it (lower-cased), e.g. 'Pledged: today, not alcohol.'
  ///
  /// In en, this message translates to:
  /// **'Pledged: today, not {habit}.'**
  String recoveryPledgedSnack(String habit);

  /// Title of the dialog for resetting a streak after a slip. Kind, no blame.
  ///
  /// In en, this message translates to:
  /// **'Starting again?'**
  String get recoveryResetTitle;

  /// Body of the reset-streak dialog: compassionate; the best streak is kept.
  ///
  /// In en, this message translates to:
  /// **'{best, plural, other{Slips happen — they don\'t erase what you learned. Your best streak ({best} days) stays on record, and day one starts now.}}'**
  String recoveryResetBody(int best);

  /// Confirm button in the reset-streak dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset to day one'**
  String get recoveryResetConfirm;

  /// Title of the dialog for deleting a recovery commitment. habit is its name as the person typed it.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{habit}\"?'**
  String recoveryRemoveTitle(String habit);

  /// Body of the delete-commitment dialog.
  ///
  /// In en, this message translates to:
  /// **'Its streak and pledges will be deleted.'**
  String get recoveryRemoveBody;

  /// Big counter on a recovery commitment: which day of the streak it is.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String recoveryDayNumber(int day);

  /// Menu item on a recovery commitment: start the count again after a slip.
  ///
  /// In en, this message translates to:
  /// **'Reset day one'**
  String get recoveryResetDayOne;

  /// Under a commitment's progress bar once every milestone (up to 1 year) is behind them.
  ///
  /// In en, this message translates to:
  /// **'Past every milestone — extraordinary.'**
  String get recoveryPastEveryMilestone;

  /// Under a commitment's progress bar. milestone is a milestone name such as '2 weeks'.
  ///
  /// In en, this message translates to:
  /// **'{daysLeft, plural, =1{Next milestone: {milestone} (1 day to go)} other{Next milestone: {milestone} ({daysLeft} days to go)}}'**
  String recoveryNextMilestone(String milestone, int daysLeft);

  /// Like recoveryNextMilestone, plus the best streak so far in days (just the number).
  ///
  /// In en, this message translates to:
  /// **'{daysLeft, plural, =1{Next milestone: {milestone} (1 day to go) · best {best}} other{Next milestone: {milestone} ({daysLeft} days to go) · best {best}}}'**
  String recoveryNextMilestoneWithBest(
    String milestone,
    int daysLeft,
    int best,
  );

  /// Shown on a commitment once today's pledge is made.
  ///
  /// In en, this message translates to:
  /// **'Pledged for today'**
  String get recoveryPledgedForToday;

  /// Button to make today's pledge (commit to not doing the habit today). First person, encouraging.
  ///
  /// In en, this message translates to:
  /// **'I\'m in for today'**
  String get recoveryPledgeButton;

  /// Title of the sheet for logging a craving.
  ///
  /// In en, this message translates to:
  /// **'Log a craving'**
  String get recoveryLogCravingTitle;

  /// Subtitle of the log-a-craving sheet.
  ///
  /// In en, this message translates to:
  /// **'Noticing is progress — patterns lose power once you can see them.'**
  String get recoveryLogCravingSubtitle;

  /// Label above a 1–5 craving strength scale.
  ///
  /// In en, this message translates to:
  /// **'How strong was it?'**
  String get recoveryLogCravingStrength;

  /// Label above the craving trigger chips.
  ///
  /// In en, this message translates to:
  /// **'What set it off?'**
  String get recoveryLogCravingTrigger;

  /// Label of the optional note field when logging a craving.
  ///
  /// In en, this message translates to:
  /// **'Anything else? (optional)'**
  String get recoveryLogCravingNote;

  /// Snackbar after logging a craving: affirming that resisting it counts.
  ///
  /// In en, this message translates to:
  /// **'Logged. You rode it out — that counts.'**
  String get recoveryCravingLogged;

  /// When a craving was logged, minutes ago (abbreviated).
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} min ago}}'**
  String recoveryMinutesAgo(int minutes);

  /// When a craving was logged, hours ago (abbreviated).
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, other{{hours} h ago}}'**
  String recoveryHoursAgo(int hours);

  /// When a craving was logged: yesterday. Lower case in English because it sits at the end of a row.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get recoveryYesterdayLower;

  /// When a craving was logged, days ago (always 2 or more).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, other{{days} days ago}}'**
  String recoveryDaysAgo(int days);

  /// Title of the recovery hub (tools for quitting a habit or substance).
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get recoveryTitle;

  /// Subtitle on the recovery hub.
  ///
  /// In en, this message translates to:
  /// **'One day at a time — with tools for the hard minutes.'**
  String get recoverySubtitle;

  /// Title of the SOS card that opens the guided urge-surfing session.
  ///
  /// In en, this message translates to:
  /// **'Craving right now?'**
  String get recoveryCravingNowTitle;

  /// Body of the SOS card. 'Surf' refers to 'urge surfing', riding out an urge like a wave.
  ///
  /// In en, this message translates to:
  /// **'Urges pass. Surf this one — 8 guided minutes.'**
  String get recoveryCravingNowBody;

  /// Section heading above tools for an urge that's happening now.
  ///
  /// In en, this message translates to:
  /// **'In the moment'**
  String get recoveryInTheMoment;

  /// Card title for the HALT tool (Hungry, Angry, Lonely, Tired). HALT is a well-known recovery acronym; keep it or use the established local equivalent.
  ///
  /// In en, this message translates to:
  /// **'HALT check'**
  String get recoveryHaltCardTitle;

  /// Card description for the HALT tool.
  ///
  /// In en, this message translates to:
  /// **'Hungry, angry, lonely, tired — find out what the craving is standing in for.'**
  String get recoveryHaltCardDetail;

  /// Card title for the 'play the tape forward' tool: imagine what happens after giving in. Use the established phrase in your language if there is one.
  ///
  /// In en, this message translates to:
  /// **'Play the tape forward'**
  String get recoveryTapeCardTitle;

  /// Card description for the play-the-tape-forward tool.
  ///
  /// In en, this message translates to:
  /// **'Watch the rest of the film before you decide, then keep it in your journal.'**
  String get recoveryTapeCardDetail;

  /// Section heading above the person's recovery commitments (habits they're quitting, each with a day count).
  ///
  /// In en, this message translates to:
  /// **'My commitments'**
  String get recoveryMyCommitments;

  /// Small text button that adds a recovery commitment.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get recoveryAddButton;

  /// Locked (Premium) card in place of the commitments list.
  ///
  /// In en, this message translates to:
  /// **'Count every day, pledge each morning, and celebrate milestones.'**
  String get recoveryCommitmentsLocked;

  /// Error when the recovery hub fails to load.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your recovery data.'**
  String get recoveryLoadError;

  /// Empty state of the commitments list.
  ///
  /// In en, this message translates to:
  /// **'What are you leaving behind? Add it — we\'ll count every day with you.'**
  String get recoveryCommitmentsEmpty;

  /// Card title opening the milestones screen.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get recoveryMilestonesCardTitle;

  /// Card description for the milestones screen.
  ///
  /// In en, this message translates to:
  /// **'Every marker, reached and ahead, for each commitment.'**
  String get recoveryMilestonesCardDetail;

  /// Section heading above the craving log.
  ///
  /// In en, this message translates to:
  /// **'Trigger tracker'**
  String get recoveryTriggerTracker;

  /// Small text button that opens the log-a-craving sheet.
  ///
  /// In en, this message translates to:
  /// **'+ Log'**
  String get recoveryLogButton;

  /// Locked (Premium) card in place of the craving log.
  ///
  /// In en, this message translates to:
  /// **'Log cravings as they happen and learn what sets them off.'**
  String get recoveryTrackerLocked;

  /// Insight above the craving log. trigger is a trigger name in lower case, e.g. 'boredom'.
  ///
  /// In en, this message translates to:
  /// **'Your most common trigger lately: {trigger}. Naming it is half the battle.'**
  String recoveryTopTrigger(String trigger);

  /// Empty state of the craving log.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet. Next time a craving hits, ride it out and note it here.'**
  String get recoveryCravingsEmpty;

  /// Card title opening the trigger insights screen.
  ///
  /// In en, this message translates to:
  /// **'Trigger insights'**
  String get recoveryInsightsCardTitle;

  /// Card description for trigger insights ('them' = cravings).
  ///
  /// In en, this message translates to:
  /// **'What sets them off, when they land, and how hard — over the last 90 days.'**
  String get recoveryInsightsCardDetail;

  /// Appended to the crisis footer at the bottom of the recovery hub. Keep the leading space.
  ///
  /// In en, this message translates to:
  /// **' Recovery is easier with backup — a licensed therapist here is never far away.'**
  String get recoveryCrisisFooterTrailing;

  /// ICU/intl DateFormat pattern for the date a milestone was reached, this year (English '5 Jan'). A date pattern, not words — e.g. 'd. MMM' or 'M月d日'.
  ///
  /// In en, this message translates to:
  /// **'d MMM'**
  String get recoveryDatePattern;

  /// ICU/intl DateFormat pattern for a milestone date in an earlier year (English '5 Jan 2025'). A date pattern, not words.
  ///
  /// In en, this message translates to:
  /// **'d MMM y'**
  String get recoveryDatePatternWithYear;

  /// Under a reached milestone: the date it was reached.
  ///
  /// In en, this message translates to:
  /// **'Reached {date}'**
  String milestonesReachedOn(String date);

  /// Under a milestone not reached yet.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day to go} other{{days} days to go}}'**
  String milestonesDaysToGo(int days);

  /// Under a commitment's name on the milestones screen.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, other{{reached} of {total} reached}}'**
  String milestonesReached(int reached, int total);

  /// Like milestonesReached, plus the best streak in days when it's longer than the current one.
  ///
  /// In en, this message translates to:
  /// **'{total, plural, other{{reached} of {total} reached · best {best} days}}'**
  String milestonesReachedWithBest(int reached, int total, int best);

  /// Error on the milestones screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your commitments.'**
  String get milestonesLoadError;

  /// Empty state of the milestones screen.
  ///
  /// In en, this message translates to:
  /// **'No commitments yet. Add one on the recovery screen and every marker below starts counting from today.'**
  String get milestonesEmpty;

  /// Title of the milestones screen.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestonesTitle;

  /// Subtitle of the milestones screen.
  ///
  /// In en, this message translates to:
  /// **'Days add up whether or not anyone claps. Here they are, counted.'**
  String get milestonesSubtitle;

  /// Error on the trigger insights screen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your craving log.'**
  String get triggerInsightsLoadError;

  /// Empty state of the trigger insights screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged in the last three months. Log a craving as it happens and the pattern shows up here — usually sooner than you\'d expect.'**
  String get triggerInsightsEmpty;

  /// Small label under a big number: cravings logged in 90 days. Only the word.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{logged}}'**
  String triggerInsightsStatLogged(int count);

  /// Small label under a number: average craving strength (1–5).
  ///
  /// In en, this message translates to:
  /// **'average'**
  String get triggerInsightsStatAverage;

  /// Small label under a number: the strongest craving (1–5).
  ///
  /// In en, this message translates to:
  /// **'strongest'**
  String get triggerInsightsStatStrongest;

  /// Small label under a part of the day (e.g. 'Evening'): when cravings usually land.
  ///
  /// In en, this message translates to:
  /// **'usual time'**
  String get triggerInsightsStatUsualTime;

  /// Insight on the trigger insights screen: the most common trigger and part of the day. trigger is a trigger name such as 'Boredom'. part is a fixed key (morning/afternoon/evening/night) — translate only the text inside the braces.
  ///
  /// In en, this message translates to:
  /// **'{part, select, morning{{trigger} in the morning is your pattern. That\'s the one worth planning for.} afternoon{{trigger} in the afternoon is your pattern. That\'s the one worth planning for.} evening{{trigger} in the evening is your pattern. That\'s the one worth planning for.} other{{trigger} in the night is your pattern. That\'s the one worth planning for.}}'**
  String triggerInsightsPattern(String trigger, String part);

  /// Section heading above a bar chart of craving triggers.
  ///
  /// In en, this message translates to:
  /// **'What sets them off'**
  String get triggerInsightsWhatSetsThemOff;

  /// Section heading above a bar chart of the part of day cravings happen.
  ///
  /// In en, this message translates to:
  /// **'When they land'**
  String get triggerInsightsWhenTheyLand;

  /// Encouraging line at the bottom of trigger insights.
  ///
  /// In en, this message translates to:
  /// **'Every one of these was a craving you sat with instead of acting on. That is the whole skill.'**
  String get triggerInsightsFooter;

  /// Title of the trigger insights screen.
  ///
  /// In en, this message translates to:
  /// **'Trigger insights'**
  String get triggerInsightsTitle;

  /// Subtitle of the trigger insights screen.
  ///
  /// In en, this message translates to:
  /// **'Cravings feel random from the inside. Logged, they stop being random — and a pattern you can see is one you can plan around.'**
  String get triggerInsightsSubtitle;

  /// HALT check: the H, hunger. Title of an option.
  ///
  /// In en, this message translates to:
  /// **'Hungry'**
  String get haltHungryTitle;

  /// HALT check: question under 'Hungry'.
  ///
  /// In en, this message translates to:
  /// **'When did you last eat something proper?'**
  String get haltHungryQuestion;

  /// HALT check: advice shown when 'Hungry' is ticked.
  ///
  /// In en, this message translates to:
  /// **'Low blood sugar feels a lot like craving, and it argues with you the same way. Eat something first — a real meal if you can, anything if you can\'t — then see what\'s left of the urge.'**
  String get haltHungryAdvice;

  /// HALT check: button under the hunger advice; opens a short meditation.
  ///
  /// In en, this message translates to:
  /// **'Steady the breath while you eat'**
  String get haltHungryAction;

  /// HALT check: the A, anger. Title of an option.
  ///
  /// In en, this message translates to:
  /// **'Angry'**
  String get haltAngryTitle;

  /// HALT check: question under 'Angry'.
  ///
  /// In en, this message translates to:
  /// **'Is something still sitting unsaid?'**
  String get haltAngryQuestion;

  /// HALT check: advice shown when 'Angry' is ticked.
  ///
  /// In en, this message translates to:
  /// **'Anger wants somewhere to go, and the old habit is the easiest door. Give it a different one for nine minutes and see if it still wants the same thing.'**
  String get haltAngryAdvice;

  /// HALT check: button opening the 9-minute meditation 'Letting go of anger'.
  ///
  /// In en, this message translates to:
  /// **'Letting go of anger · 9 min'**
  String get haltAngryAction;

  /// HALT check: the L, loneliness. Title of an option.
  ///
  /// In en, this message translates to:
  /// **'Lonely'**
  String get haltLonelyTitle;

  /// HALT check: question under 'Lonely'.
  ///
  /// In en, this message translates to:
  /// **'Who have you actually spoken to today?'**
  String get haltLonelyQuestion;

  /// HALT check: advice shown when 'Lonely' is ticked. 'A session' = a session with a therapist in the app.
  ///
  /// In en, this message translates to:
  /// **'This is the one that most often gets answered with the habit. A real person beats anything else here — and if there isn\'t one right now, a session is a person.'**
  String get haltLonelyAdvice;

  /// HALT check: button opening the therapy screen.
  ///
  /// In en, this message translates to:
  /// **'Talk to a therapist'**
  String get haltLonelyAction;

  /// HALT check: the T, tiredness. Title of an option.
  ///
  /// In en, this message translates to:
  /// **'Tired'**
  String get haltTiredTitle;

  /// HALT check: question under 'Tired'.
  ///
  /// In en, this message translates to:
  /// **'Have you slept properly this week?'**
  String get haltTiredQuestion;

  /// HALT check: advice shown when 'Tired' is ticked.
  ///
  /// In en, this message translates to:
  /// **'Tired makes every urge louder and every reason quieter. Nothing you decide right now will be as good as what you decide after some rest.'**
  String get haltTiredAdvice;

  /// HALT check: button opening a sleep sound.
  ///
  /// In en, this message translates to:
  /// **'Wind down and sleep'**
  String get haltTiredAction;

  /// Letter on the disc next to 'Hungry' — the H of the HALT acronym. Keep 'H' unless your language uses its own acronym; one character.
  ///
  /// In en, this message translates to:
  /// **'H'**
  String get haltHungryLetter;

  /// Letter on the disc next to 'Angry' — the A of HALT. One character.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get haltAngryLetter;

  /// Letter on the disc next to 'Lonely' — the L of HALT. One character.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get haltLonelyLetter;

  /// Letter on the disc next to 'Tired' — the T of HALT. One character.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get haltTiredLetter;

  /// Title of the HALT check screen (Hungry, Angry, Lonely, Tired).
  ///
  /// In en, this message translates to:
  /// **'HALT check'**
  String get haltTitle;

  /// Intro on the HALT check screen.
  ///
  /// In en, this message translates to:
  /// **'A craving is often something else wearing a disguise. Before you decide anything, check the four it\'s usually hiding behind — tick whichever are true.'**
  String get haltIntro;

  /// HALT check: shown when nothing is ticked.
  ///
  /// In en, this message translates to:
  /// **'None of them? Then it\'s the urge on its own — and those pass on their own too. Ride it out.'**
  String get haltNoneOfThem;

  /// HALT check: heading above the advice for the ticked needs.
  ///
  /// In en, this message translates to:
  /// **'What that means'**
  String get haltWhatThatMeans;

  /// Play the tape forward, step 1 heading: imagine an hour after giving in. Also written into the saved journal entry.
  ///
  /// In en, this message translates to:
  /// **'In an hour'**
  String get tapeForwardHourWhen;

  /// Play the tape forward, step 1 question.
  ///
  /// In en, this message translates to:
  /// **'You gave in. What does the next hour actually look like?'**
  String get tapeForwardHourQuestion;

  /// Play the tape forward, step 1 hint in the text field.
  ///
  /// In en, this message translates to:
  /// **'Not the first five minutes — the hour.'**
  String get tapeForwardHourHint;

  /// Play the tape forward, step 2 heading. Also written into the saved journal entry.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow morning'**
  String get tapeForwardMorningWhen;

  /// Play the tape forward, step 2 question.
  ///
  /// In en, this message translates to:
  /// **'You wake up. What\'s the first thing you remember?'**
  String get tapeForwardMorningQuestion;

  /// Play the tape forward, step 2 hint in the text field.
  ///
  /// In en, this message translates to:
  /// **'How does the day start from there?'**
  String get tapeForwardMorningHint;

  /// Play the tape forward, step 3 heading. Also written into the saved journal entry.
  ///
  /// In en, this message translates to:
  /// **'A week from now'**
  String get tapeForwardWeekWhen;

  /// Play the tape forward, step 3 question.
  ///
  /// In en, this message translates to:
  /// **'Where has this put you by next week?'**
  String get tapeForwardWeekQuestion;

  /// Play the tape forward, step 3 hint in the text field.
  ///
  /// In en, this message translates to:
  /// **'And what would the other choice have bought you?'**
  String get tapeForwardWeekHint;

  /// Title of the journal entry saved from the play-the-tape-forward tool.
  ///
  /// In en, this message translates to:
  /// **'Playing the tape forward'**
  String get tapeForwardJournalTitle;

  /// Snackbar after saving the play-the-tape-forward answers to the journal.
  ///
  /// In en, this message translates to:
  /// **'Saved to your journal.'**
  String get tapeForwardSaved;

  /// Title of the play-the-tape-forward screen.
  ///
  /// In en, this message translates to:
  /// **'Play the tape forward'**
  String get tapeForwardTitle;

  /// Intro on the play-the-tape-forward screen.
  ///
  /// In en, this message translates to:
  /// **'A craving only ever shows you the first five minutes. Watch the rest of the film before you decide — in your own words, because yours are the ones you believe.'**
  String get tapeForwardIntro;

  /// Button label while the answers are being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get tapeForwardSaving;

  /// Button that saves the answers as a journal entry.
  ///
  /// In en, this message translates to:
  /// **'Keep this in my journal'**
  String get tapeForwardKeep;

  /// Line under the save button: the entry will be there for the next craving.
  ///
  /// In en, this message translates to:
  /// **'Next time, this is waiting for you — written by the one person the craving can\'t argue with.'**
  String get tapeForwardFooter;

  /// One-letter (or one-character) names of the weekdays, Monday first, separated by single spaces — exactly 7 items. Shown under seven small suns on the rhythm card.
  ///
  /// In en, this message translates to:
  /// **'M T W T F S S'**
  String get rhythmWeekdayLetters;

  /// Explore tab: tile opening meditations and breathing. Short; fits a half-width tile, max 2 lines.
  ///
  /// In en, this message translates to:
  /// **'Meditate'**
  String get explorePillarMeditate;

  /// Explore tab: tile opening the wellbeing sounds (ambient audio loops). Short; fits a half-width tile, max 2 lines.
  ///
  /// In en, this message translates to:
  /// **'Well being'**
  String get explorePillarWellbeing;

  /// Explore tab: tile opening the journal and mood tracking hub. Short; fits a half-width tile, max 2 lines.
  ///
  /// In en, this message translates to:
  /// **'Journal & mood'**
  String get explorePillarJournal;

  /// Explore tab: tile opening the addiction-recovery tools (cravings, sober days). Short; fits a half-width tile, max 2 lines.
  ///
  /// In en, this message translates to:
  /// **'Recovery tools'**
  String get explorePillarRecovery;

  /// Explore tab: title of the featured cognitive behavioural therapy (CBT) programme card. One line.
  ///
  /// In en, this message translates to:
  /// **'CBT for Therapy'**
  String get exploreProgramCbtTitle;

  /// Explore tab: one-line description under the CBT programme title.
  ///
  /// In en, this message translates to:
  /// **'Tools and reads for anxious & low thoughts'**
  String get exploreProgramCbtBlurb;

  /// Explore tab: title of the featured sleep programme card. One line.
  ///
  /// In en, this message translates to:
  /// **'Sleep better'**
  String get exploreProgramSleepTitle;

  /// Explore tab: description of the sleep programme. 'The 20-minute rule' is a sleep tip: get up if you can't sleep after about 20 minutes.
  ///
  /// In en, this message translates to:
  /// **'A wind-down, the 20-minute rule, a sleep diary'**
  String get exploreProgramSleepBlurb;

  /// Explore tab: title of the featured stress programme card. One line.
  ///
  /// In en, this message translates to:
  /// **'Manage stress'**
  String get exploreProgramStressTitle;

  /// Explore tab: description of the stress programme: first calm the body, then deal with what's causing the stress.
  ///
  /// In en, this message translates to:
  /// **'Bring the body down, then sort the load'**
  String get exploreProgramStressBlurb;

  /// Explore tab: collection card and list title for all breathing exercises.
  ///
  /// In en, this message translates to:
  /// **'Breathing exercises'**
  String get exploreCollectionBreathingTitle;

  /// Intro at the top of the breathing exercises list.
  ///
  /// In en, this message translates to:
  /// **'A few minutes of paced breathing, each with its own rhythm.'**
  String get exploreCollectionBreathingSubtitle;

  /// Explore tab: number of breathing exercises in the collection, e.g. '8 rhythms'. Followed by ' · ' and a free/Premium count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} rhythms}}'**
  String exploreCollectionBreathingCount(int count);

  /// Explore tab: collection card and list title for all guided meditations.
  ///
  /// In en, this message translates to:
  /// **'Guided meditations'**
  String get exploreCollectionMeditationsTitle;

  /// Intro at the top of the guided meditations list.
  ///
  /// In en, this message translates to:
  /// **'Timed sessions with gentle guidance on screen.'**
  String get exploreCollectionMeditationsSubtitle;

  /// Explore tab: number of guided meditations, e.g. '9 sessions'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} sessions}}'**
  String exploreCollectionMeditationsCount(int count);

  /// Explore tab: collection card and list title for all ambient sound loops.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing sounds'**
  String get exploreCollectionSoundsTitle;

  /// Intro at the top of the wellbeing sounds list.
  ///
  /// In en, this message translates to:
  /// **'Ambient sound for focus, sleep and calm. Plays on with the screen off.'**
  String get exploreCollectionSoundsSubtitle;

  /// Explore tab: number of sound loops, e.g. '12 loops'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} loops}}'**
  String exploreCollectionSoundsCount(int count);

  /// Explore tab: collection card and list title for all journal writing prompts.
  ///
  /// In en, this message translates to:
  /// **'Journal prompts'**
  String get exploreCollectionPromptsTitle;

  /// Intro at the top of the journal prompts list.
  ///
  /// In en, this message translates to:
  /// **'A first line to get you writing, so the page is never blank.'**
  String get exploreCollectionPromptsSubtitle;

  /// Explore tab: number of journal prompts, e.g. '20 prompts'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} prompts}}'**
  String exploreCollectionPromptsCount(int count);

  /// Explore tab: collection card and list title for all short articles/lessons.
  ///
  /// In en, this message translates to:
  /// **'Short reads'**
  String get exploreCollectionReadsTitle;

  /// Intro at the top of the short reads list.
  ///
  /// In en, this message translates to:
  /// **'The ideas behind the tools, a few minutes each.'**
  String get exploreCollectionReadsSubtitle;

  /// Explore tab: number of short reads, e.g. '9 reads'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} reads}}'**
  String exploreCollectionReadsCount(int count);

  /// Explore tab: collection card and list title for all addiction-recovery tools.
  ///
  /// In en, this message translates to:
  /// **'Recovery tools'**
  String get exploreCollectionRecoveryTitle;

  /// Intro at the top of the recovery tools list: for people recovering from addiction.
  ///
  /// In en, this message translates to:
  /// **'For cravings and the commitments you\'re keeping.'**
  String get exploreCollectionRecoverySubtitle;

  /// Explore tab: number of recovery tools, e.g. '5 tools'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} tools}}'**
  String exploreCollectionRecoveryCount(int count);

  /// Explore tab: line under a collection title. amount is e.g. '8 rhythms'; access is how many are free or Premium, e.g. '3 free · 5 Premium'. Usually keep as is.
  ///
  /// In en, this message translates to:
  /// **'{amount} · {access}'**
  String exploreCollectionMeta(String amount, String access);

  /// Explore tab: heading above chips like 'Sleep', 'Anxious', each opening matching content. Warm, informal.
  ///
  /// In en, this message translates to:
  /// **'What do you need right now?'**
  String get exploreNeedsTitle;

  /// Explore tab: search bar label and the search field's placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get exploreSearch;

  /// Explore tab: heading over the featured programme cards (CBT, sleep, stress).
  ///
  /// In en, this message translates to:
  /// **'Our featured programs'**
  String get exploreFeaturedTitle;

  /// Explore tab: line under exploreFeaturedTitle; each programme focuses on one topic.
  ///
  /// In en, this message translates to:
  /// **'Step-by-step tools and short reads, each built around one thing.'**
  String get exploreFeaturedSubtitle;

  /// Explore tab: floating card title for booking a session with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Book a session'**
  String get exploreBookTitle;

  /// Explore tab: under exploreBookTitle; stresses it's a real person, not an app or bot.
  ///
  /// In en, this message translates to:
  /// **'Speak to a human therapist'**
  String get exploreBookSubtitle;

  /// Explore tab: heading over the week-long courses (one step per day).
  ///
  /// In en, this message translates to:
  /// **'7-day courses'**
  String get exploreCoursesTitle;

  /// Explore tab: line under exploreCoursesTitle; each day builds on the one before.
  ///
  /// In en, this message translates to:
  /// **'One step a day, in an order that builds.'**
  String get exploreCoursesSubtitle;

  /// Explore tab: heading over the collection cards (breathing, meditations, sounds, ...).
  ///
  /// In en, this message translates to:
  /// **'All collections'**
  String get exploreCollectionsTitle;

  /// Explore search: heading over the person's recent searches.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get exploreSearchRecent;

  /// Explore search: button clearing the recent searches list.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get exploreSearchClear;

  /// Explore search: heading over suggestion chips (needs like 'Sleep', 'Anxious') before anything is typed.
  ///
  /// In en, this message translates to:
  /// **'Try searching for'**
  String get exploreSearchSuggestions;

  /// Explore search: shown when no content matches the search text.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that yet.'**
  String get exploreSearchEmpty;

  /// Used in place of the person's first name when we don't know it, e.g. in a greeting 'Good morning, friend'. Lowercase, warm.
  ///
  /// In en, this message translates to:
  /// **'friend'**
  String get homeUiFriendFallback;

  /// Upgrade sheet title when a free user taps a Premium item; item is its title (a meditation, sound, prompt...).
  ///
  /// In en, this message translates to:
  /// **'Unlock “{item}”'**
  String homeUiUnlockItem(String item);

  /// Upgrade sheet button opening the Premium plans screen. 'Premium' is the paid plan's name.
  ///
  /// In en, this message translates to:
  /// **'See Premium'**
  String get homeUiSeePremium;

  /// Upgrade sheet button when unlocking a specific item; opens the Premium plans screen.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Premium'**
  String get homeUiUnlockWithPremium;

  /// Error shown when an action failed because the person's session ended.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been signed out. Please log in again.'**
  String get homeUiSignedOutError;

  /// Upgrade sheet title when a free user has used up their free journal entries.
  ///
  /// In en, this message translates to:
  /// **'You\'ve filled your free pages'**
  String get homeUiJournalCapTitle;

  /// Upgrade sheet message under homeUiJournalCapTitle. offer is a lowercase clause about the free trial, e.g. 'you can try it free first' (it ends the sentence).
  ///
  /// In en, this message translates to:
  /// **'The free plan includes {count} journal entries. Premium unlocks unlimited journaling — and {offer}.'**
  String homeUiJournalCapMessage(int count, String offer);

  /// Snackbar for a feature that isn't built yet; feature is its name, e.g. a Settings row label.
  ///
  /// In en, this message translates to:
  /// **'{feature} is coming soon — stay close.'**
  String homeUiComingSoon(String feature);

  /// Small button at the end of a section heading, opening the full list.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeUiSeeAll;

  /// Tiny chip with a lock on content that needs the paid Premium plan. Very short.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get homeUiPremiumChip;

  /// Mood scale, worst of five: how the day/they feel. Shown under a face and in mood history. One word.
  ///
  /// In en, this message translates to:
  /// **'Awful'**
  String get moodAwful;

  /// Mood scale, second of five (feeling down). One word.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get moodLow;

  /// Mood scale, middle of five (neutral). One word.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get moodOkay;

  /// Mood scale, fourth of five. One word.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get moodGood;

  /// Mood scale, best of five. One word.
  ///
  /// In en, this message translates to:
  /// **'Great'**
  String get moodGreat;

  /// Mood history screen title.
  ///
  /// In en, this message translates to:
  /// **'Mood history'**
  String get moodHistoryTitle;

  /// Mood history screen intro: gentle encouragement that bad times pass.
  ///
  /// In en, this message translates to:
  /// **'Hard weeks feel permanent while you\'re in them. This is the record that says otherwise.'**
  String get moodHistoryIntro;

  /// Mood history: date label for today, and under the right end of the 30-day chart.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get moodHistoryToday;

  /// Mood history: date label for yesterday's check-in.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get moodHistoryYesterday;

  /// Date format pattern (ICU/intl DateFormat: d = day, MMM = short month name, M = month number) for a check-in this year, e.g. '5 Jan'. Use your language's usual order, e.g. 'M月d日' for Chinese. Do not translate the letters.
  ///
  /// In en, this message translates to:
  /// **'d MMM'**
  String get moodHistoryDatePattern;

  /// Date format pattern like moodHistoryDatePattern but with the year (y), for check-ins from an earlier year, e.g. '5 Jan 2025'. Chinese e.g. 'y年M月d日'. Do not translate the letters.
  ///
  /// In en, this message translates to:
  /// **'d MMM y'**
  String get moodHistoryDatePatternWithYear;

  /// Mood history: error when the mood check-ins couldn't be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your check-ins.'**
  String get moodHistoryLoadError;

  /// Mood history: empty state before any daily mood check-in.
  ///
  /// In en, this message translates to:
  /// **'No check-ins yet. Tap a face on the home screen and this fills in — one day at a time.'**
  String get moodHistoryEmpty;

  /// Mood history: section heading over a 30-day bar chart.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get moodHistoryLast30Days;

  /// Mood history stats: small label under a number, the count of mood check-ins. Lowercase, very short.
  ///
  /// In en, this message translates to:
  /// **'check-ins'**
  String get moodHistoryStatCheckIns;

  /// Mood history stats: small label under a number, how many days in a row they've checked in. Very short.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get moodHistoryStatStreak;

  /// Mood history stats: small label under the average mood score (1–5). Very short.
  ///
  /// In en, this message translates to:
  /// **'average'**
  String get moodHistoryStatAverage;

  /// Mood history stats: small label under the most common mood (e.g. 'Good'), meaning 'how you felt on most days'. Very short.
  ///
  /// In en, this message translates to:
  /// **'most days'**
  String get moodHistoryStatMostDays;

  /// Mood history: section heading over the list of all mood check-ins.
  ///
  /// In en, this message translates to:
  /// **'Every check-in'**
  String get moodHistoryEveryCheckIn;

  /// Upgrade sheet title when a free user opens mood insights.
  ///
  /// In en, this message translates to:
  /// **'Insights are part of Premium'**
  String get moodInsightsUpgradeTitle;

  /// Upgrade sheet message for mood insights. offer is a lowercase clause about the free trial, e.g. 'you can try it free first' (it ends the sentence).
  ///
  /// In en, this message translates to:
  /// **'See how your practice, your week and your moods connect — and {offer}.'**
  String moodInsightsUpgradeMessage(String offer);

  /// Mood insights screen title: patterns found in the person's moods and practice.
  ///
  /// In en, this message translates to:
  /// **'Your insights'**
  String get moodInsightsTitle;

  /// Mood insights intro: what the insights are based on ('how sessions left you' = how they said they felt after each session).
  ///
  /// In en, this message translates to:
  /// **'From your check-ins, practice and how sessions left you, over the last 90 days.'**
  String get moodInsightsIntro;

  /// Mood insights: empty state when there's too little data.
  ///
  /// In en, this message translates to:
  /// **'Not enough to go on yet. Check in each day and answer the question at the end of a session — insights start appearing within a week or two.'**
  String get moodInsightsEmpty;

  /// Mood insight title: how many days this month they've logged their mood.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You\'ve checked in 1 day this month} other{You\'ve checked in {count} days this month}}'**
  String moodInsightCheckedInTitle(int count);

  /// Mood insight detail: their current run of daily check-ins (always 2 or more).
  ///
  /// In en, this message translates to:
  /// **'That\'s {count} days in a row right now. Noticing is where change starts.'**
  String moodInsightCheckedInStreak(int count);

  /// Mood insight detail when there's no streak yet: encouragement to keep checking in.
  ///
  /// In en, this message translates to:
  /// **'Every check-in makes the picture clearer.'**
  String get moodInsightCheckedInFirst;

  /// Mood insight title: moods are better on days with a meditation/breathing/sound session.
  ///
  /// In en, this message translates to:
  /// **'Your mood is higher on days you practise'**
  String get moodInsightPracticeHigherTitle;

  /// Detail under moodInsightPracticeHigherTitle.
  ///
  /// In en, this message translates to:
  /// **'Days with a meditation, breathing or a sound score better than days without. Worth keeping a small daily habit.'**
  String get moodInsightPracticeHigherDetail;

  /// Mood insight title: moods are lower on practice days, framed kindly.
  ///
  /// In en, this message translates to:
  /// **'You tend to practise on harder days'**
  String get moodInsightPracticeLowerTitle;

  /// Detail under moodInsightPracticeLowerTitle; reassuring, not a judgement.
  ///
  /// In en, this message translates to:
  /// **'Your practice days have lower moods — which may mean you reach for it when you need it. That\'s what it\'s for.'**
  String get moodInsightPracticeLowerDetail;

  /// Mood insight title: no clear difference in mood between days with and without practice.
  ///
  /// In en, this message translates to:
  /// **'Practice days and other days look alike so far'**
  String get moodInsightPracticeSameTitle;

  /// Detail under moodInsightPracticeSameTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep checking in — the pattern gets clearer with a few more weeks.'**
  String get moodInsightPracticeSameDetail;

  /// A day of the week in general (plural: 'Mondays' = every Monday), starting a sentence in moodInsightHardestDayTitle and moodInsightHardestDayDetail. Translate only the words inside the braces.
  ///
  /// In en, this message translates to:
  /// **'{day, select, mon{Mondays} tue{Tuesdays} wed{Wednesdays} thu{Thursdays} fri{Fridays} sat{Saturdays} other{Sundays}}'**
  String moodWeekdays(String day);

  /// Same as moodWeekdays but used mid-sentence ('planned for mondays'). Use your language's normal capitalisation for weekdays in the middle of a sentence. Translate only the words inside the braces.
  ///
  /// In en, this message translates to:
  /// **'{day, select, mon{mondays} tue{tuesdays} wed{wednesdays} thu{thursdays} fri{fridays} sat{saturdays} other{sundays}}'**
  String moodWeekdaysMidSentence(String day);

  /// Mood insight title; weekday is from moodWeekdays, e.g. 'Mondays'.
  ///
  /// In en, this message translates to:
  /// **'{weekday} are usually your hardest days'**
  String moodInsightHardestDayTitle(String weekday);

  /// Detail under moodInsightHardestDayTitle. bestDay from moodWeekdays (e.g. 'Fridays'), hardestDay from moodWeekdaysMidSentence (e.g. 'mondays'). 'A little something planned' = something small to look forward to.
  ///
  /// In en, this message translates to:
  /// **'{bestDay} tend to go best. A little something planned for {hardestDay} could help.'**
  String moodInsightHardestDayDetail(String bestDay, String hardestDay);

  /// Mood insight title: mood in the last 14 days is up on the 14 before.
  ///
  /// In en, this message translates to:
  /// **'The last two weeks have been better'**
  String get moodInsightBetterTitle;

  /// Detail under moodInsightBetterTitle.
  ///
  /// In en, this message translates to:
  /// **'Your check-ins are up on the fortnight before. Whatever you\'re doing, it\'s worth noticing.'**
  String get moodInsightBetterDetail;

  /// Mood insight title: mood in the last 14 days is down on the 14 before.
  ///
  /// In en, this message translates to:
  /// **'The last two weeks have been harder'**
  String get moodInsightHarderTitle;

  /// Detail under moodInsightHarderTitle. Caring tone; gently suggests talking to someone (e.g. a therapist or friend).
  ///
  /// In en, this message translates to:
  /// **'Your check-ins are down on the fortnight before. Be gentle with yourself — and talking to someone can help.'**
  String get moodInsightHarderDetail;

  /// Mood insight detail under a summary of how they felt after sessions (answers to 'How do you feel now?').
  ///
  /// In en, this message translates to:
  /// **'From how you said you felt at the end of each session.'**
  String get moodInsightFeelingsDetail;

  /// Breathing exercise: instruction inside the growing circle. Short, imperative, informal.
  ///
  /// In en, this message translates to:
  /// **'Breathe in'**
  String get breathingBreatheIn;

  /// Breathing exercise: instruction to hold the breath. Short.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get breathingHold;

  /// Breathing exercise: instruction inside the shrinking circle. Short.
  ///
  /// In en, this message translates to:
  /// **'Breathe out'**
  String get breathingBreatheOut;

  /// Breathing exercise: chip choosing the length, e.g. '3 min'. Abbreviated, very short.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} min}}'**
  String breathingMinutesChip(int minutes);

  /// Breathing exercise: button starting the exercise.
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get breathingBegin;

  /// Breathing exercise: heading when the exercise finishes. Warm.
  ///
  /// In en, this message translates to:
  /// **'Well done'**
  String get breathingWellDone;

  /// Breathing exercise finished: how long it lasted and roughly how many breaths (in and out = one cycle), then an invitation to notice how they feel. Keep the line break (\n).
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}} · about {cycles} breath cycles.\nNotice how you feel right now.'**
  String breathingDoneSummary(int minutes, int cycles);

  /// Breathing exercise finished: confirms the session was logged.
  ///
  /// In en, this message translates to:
  /// **'Added to your practice history.'**
  String get breathingAddedToHistory;

  /// Breathing exercise finished: button to do it once more.
  ///
  /// In en, this message translates to:
  /// **'Go again'**
  String get breathingGoAgain;

  /// Breathing exercise: tooltip/accessibility label on the stop button.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get breathingEndSession;

  /// Upgrade sheet subtitle when a free user taps a Premium meditation or breathing exercise.
  ///
  /// In en, this message translates to:
  /// **'This session is part of Premium'**
  String get meditationsUpgradeTitle;

  /// Upgrade sheet message for meditations. offer is a lowercase clause about the free trial, e.g. 'you can try it free first' (it ends the sentence).
  ///
  /// In en, this message translates to:
  /// **'Free includes a taste of each practice. Premium unlocks every session — and {offer}.'**
  String meditationsUpgradeMessage(String offer);

  /// Meditations list: line under a meditation's title: its length, then a short description from the content (already in the right language).
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} min}} · {detail}'**
  String meditationsItemMeta(int minutes, String detail);

  /// Meditations hub screen title.
  ///
  /// In en, this message translates to:
  /// **'Meditations & breathing'**
  String get meditationsTitle;

  /// Meditations hub intro. 'The circle' is the animated breathing circle.
  ///
  /// In en, this message translates to:
  /// **'A few minutes of guided calm — breathe along with the circle, or settle into a quiet session.'**
  String get meditationsIntro;

  /// Meditations hub: section heading over the breathing exercises.
  ///
  /// In en, this message translates to:
  /// **'Breathing exercises'**
  String get meditationsBreathingHeader;

  /// Meditations hub: section heading over the guided meditations.
  ///
  /// In en, this message translates to:
  /// **'Meditations'**
  String get meditationsMeditationsHeader;

  /// Upgrade sheet subtitle when a free user taps a Premium sound.
  ///
  /// In en, this message translates to:
  /// **'This sound is part of Premium'**
  String get soundsUpgradeTitle;

  /// Upgrade sheet message for sounds. offer is a lowercase clause about the free trial, e.g. 'you can try it free first' (it ends the sentence).
  ///
  /// In en, this message translates to:
  /// **'Free includes one sound to try. Premium unlocks the whole library — and {offer}.'**
  String soundsUpgradeMessage(String offer);

  /// Snackbar when a sound fails to play.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play that sound.'**
  String get soundsPlayError;

  /// Sounds list: line under the sound that's playing now; category is its group, e.g. 'Nature'.
  ///
  /// In en, this message translates to:
  /// **'Playing · {category}'**
  String soundsPlayingCategory(String category);

  /// Sounds screen title: ambient audio loops.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing sounds'**
  String get soundsTitle;

  /// Sounds screen intro.
  ///
  /// In en, this message translates to:
  /// **'Loops that stay with you — pick one and let it run while you focus, drift off, or settle down.'**
  String get soundsIntro;

  /// Sounds screen: filter chip showing every category. Very short.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get soundsFilterAll;

  /// Sounds screen: button stopping the sound that's playing.
  ///
  /// In en, this message translates to:
  /// **'Stop sound'**
  String get soundsStop;

  /// Title on the lock screen / media notification for a sound with no name.
  ///
  /// In en, this message translates to:
  /// **'Wellbeing sound'**
  String get soundPlayerFallbackTitle;

  /// Sound player button while a sleep timer runs: time left as mm:ss; tapping it cancels the timer. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Stops in {time} · cancel'**
  String playerSleepTimerStopsIn(String time);

  /// Small chip on the sound player to set a sleep timer of this many minutes (15, 30, 60). Abbreviated minutes; very short.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String playerSleepTimerOption(int minutes);

  /// Chip during a guided meditation that turns the narrator's voice on or off. One short word.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get meditationVoiceChip;

  /// Heading when a meditation session ends.
  ///
  /// In en, this message translates to:
  /// **'Session complete'**
  String get meditationSessionComplete;

  /// Under 'Session complete' after a meditation: gentle, warm. Two lines (keep the line break).
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} quiet minutes, just for you.\nCarry a little of this with you.}}'**
  String meditationCompleteBody(int minutes);

  /// Small note after a meditation: the session was recorded in the practice history.
  ///
  /// In en, this message translates to:
  /// **'Added to your practice history.'**
  String get meditationAddedToHistory;

  /// Under the countdown clock during a meditation (time remaining). Lower-case, one word if possible.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get meditationRemaining;

  /// Chip during a meditation: play no background sound.
  ///
  /// In en, this message translates to:
  /// **'No sound'**
  String get meditationNoSound;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): sleeplessness. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Can\'t sleep'**
  String get needSleep;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): anxiety. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Anxious'**
  String get needAnxious;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): a panic attack happening now. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Panicking'**
  String get needPanic;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): low mood. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Feeling low'**
  String get needLow;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): stress. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Stressed'**
  String get needStressed;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): anger. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Angry'**
  String get needAngry;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): cravings/urges (addiction recovery). Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Urges'**
  String get needUrges;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): wanting to concentrate. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get needFocus;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): wanting to reflect, make sense of things. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Reflect'**
  String get needReflect;

  /// A 'need' chip on Explore, Home and in Settings ('What would help most'): feeling good, wanting to keep it. Short, fits on a chip; also used as a list title.
  ///
  /// In en, this message translates to:
  /// **'Feeling good'**
  String get needGood;

  /// Intro under the title of the list for the needSleep chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'For the evening before, and the hours you\'re lying awake.'**
  String get needSleepIntro;

  /// Intro under the title of the list for the needAnxious chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Ways to bring a racing mind back to what\'s in front of you.'**
  String get needAnxiousIntro;

  /// Intro under the title of the list for the needPanic chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Quick and simple first. These work best started straight away.'**
  String get needPanicIntro;

  /// Intro under the title of the list for the needLow chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Small, kind things for heavy days. Start with whichever feels doable.'**
  String get needLowIntro;

  /// Intro under the title of the list for the needStressed chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Bring the body down first, then sort what\'s on your plate.'**
  String get needStressedIntro;

  /// Intro under the title of the list for the needAngry chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Let it cool before you act on it.'**
  String get needAngryIntro;

  /// Intro under the title of the list for the needUrges chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Ride it out: urges peak and pass, usually within minutes.'**
  String get needUrgesIntro;

  /// Intro under the title of the list for the needFocus chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Clear your head and settle into one thing.'**
  String get needFocusIntro;

  /// Intro under the title of the list for the needReflect chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Prompts and reads for making sense of things.'**
  String get needReflectIntro;

  /// Intro under the title of the list for the needGood chip. Gentle, one sentence.
  ///
  /// In en, this message translates to:
  /// **'Notice what\'s going right, so it stays with you.'**
  String get needGoodIntro;

  /// Section heading on Home above suggestions that fit the time of day.
  ///
  /// In en, this message translates to:
  /// **'For this morning'**
  String get dayPartMorning;

  /// Section heading on Home above suggestions that fit the time of day.
  ///
  /// In en, this message translates to:
  /// **'For this afternoon'**
  String get dayPartAfternoon;

  /// Section heading on Home above suggestions that fit the time of day.
  ///
  /// In en, this message translates to:
  /// **'For this evening'**
  String get dayPartEvening;

  /// Section heading on Home above suggestions that fit the time of day.
  ///
  /// In en, this message translates to:
  /// **'For tonight'**
  String get dayPartNight;

  /// Kind of item, shown small on content cards: a breathing exercise. One or two words.
  ///
  /// In en, this message translates to:
  /// **'Breathing'**
  String get contentKindBreathing;

  /// Kind of item, shown small on content cards: a guided meditation. One or two words.
  ///
  /// In en, this message translates to:
  /// **'Meditation'**
  String get contentKindMeditation;

  /// Kind of item, shown small on content cards: a calming sound. One or two words.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get contentKindSound;

  /// Kind of item, shown small on content cards: a writing prompt. One or two words.
  ///
  /// In en, this message translates to:
  /// **'Journal prompt'**
  String get contentKindPrompt;

  /// Kind of item, shown small on content cards: an interactive exercise. One or two words.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get contentKindTool;

  /// Kind of item, shown small on content cards: a short article to read (noun). One or two words.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get contentKindLesson;

  /// Kind of item, shown small on content cards: an addiction-recovery tool. One or two words.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get contentKindRecovery;

  /// Filter chip on a content list: how long items take. Short.
  ///
  /// In en, this message translates to:
  /// **'Any length'**
  String get lengthAny;

  /// Filter chip on a content list: how long items take. Short.
  ///
  /// In en, this message translates to:
  /// **'Under 5 min'**
  String get lengthShort;

  /// Filter chip on a content list: how long items take. Short.
  ///
  /// In en, this message translates to:
  /// **'5–10 min'**
  String get lengthMedium;

  /// Filter chip on a content list: how long items take. Short.
  ///
  /// In en, this message translates to:
  /// **'Over 10 min'**
  String get lengthLong;

  /// Small line on a content card: the programme or kind, then minutes, e.g. 'CBT · 5 min'.
  ///
  /// In en, this message translates to:
  /// **'{what} · {minutes} min'**
  String contentMeta(String what, int minutes);

  /// Title of the sheet shown when someone taps a Premium item on the free plan. 'Premium' is the plan name.
  ///
  /// In en, this message translates to:
  /// **'This is part of Premium'**
  String get contentPremiumTitle;

  /// Body of the Premium sheet. {offer} is a phrase about the trial, e.g. 'you can try it free for 7 days'.
  ///
  /// In en, this message translates to:
  /// **'Free includes a taste of everything. Premium unlocks every session, tool and read — and {offer}.'**
  String contentPremiumMessage(String offer);

  /// Small badge on content added in the last few weeks. Very short.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get contentNewBadge;

  /// Tooltip/accessibility label of the heart button that saves an item to Home.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get contentSaveTooltip;

  /// Tooltip/accessibility label of the heart button when the item is already saved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get contentUnsaveTooltip;

  /// Accessibility label of the lock icon on a Premium card. Plan name; usually not translated.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get contentPremiumLabel;

  /// Empty state on a content list when the chosen length filter matches nothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing that length yet.'**
  String get contentNothingThatLength;

  /// Sheet title when a free user picks a Premium background sound during a meditation.
  ///
  /// In en, this message translates to:
  /// **'This sound is part of Premium'**
  String get meditationSoundPremiumTitle;

  /// Sheet body. {offer} is a phrase about the trial.
  ///
  /// In en, this message translates to:
  /// **'Free includes one sound to try. Premium unlocks the whole library — and {offer}.'**
  String meditationSoundPremiumMessage(String offer);

  /// Home 'Quick access' tile title: opens meditations and breathing. One short word.
  ///
  /// In en, this message translates to:
  /// **'Meditate'**
  String get homeQuickMeditate;

  /// Home 'Quick access' tile subtitle under 'Meditate'. Very short.
  ///
  /// In en, this message translates to:
  /// **'Breathe & settle'**
  String get homeQuickMeditateSub;

  /// Home 'Quick access' tile title: opens the journal. One short word.
  ///
  /// In en, this message translates to:
  /// **'Journal'**
  String get homeQuickJournal;

  /// Home 'Quick access' tile subtitle under 'Journal'. Very short.
  ///
  /// In en, this message translates to:
  /// **'Write it out'**
  String get homeQuickJournalSub;

  /// Home 'Quick access' tile title: opens calming sounds. One short word.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get homeQuickSounds;

  /// Home 'Quick access' tile subtitle under 'Sounds': three uses of the sounds. Very short.
  ///
  /// In en, this message translates to:
  /// **'Focus · sleep · calm'**
  String get homeQuickSoundsSub;

  /// Home 'Quick access' tile title: opens addiction-recovery tools. One short word.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get homeQuickRecovery;

  /// Home 'Quick access' tile subtitle under 'Recovery': the recovery saying. Very short.
  ///
  /// In en, this message translates to:
  /// **'One day at a time'**
  String get homeQuickRecoverySub;

  /// Snackbar after the first mood check-in of the day.
  ///
  /// In en, this message translates to:
  /// **'Thanks for checking in.'**
  String get homeThanksForCheckingIn;

  /// Error snackbar when saving a mood check-in fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your mood — check your connection.'**
  String get homeMoodSaveFailed;

  /// Title of the gentle Premium offer shown after someone's third mood check-in.
  ///
  /// In en, this message translates to:
  /// **'Three check-ins in'**
  String get homeNudgeCheckinsTitle;

  /// Body of the offer after the third check-in. {offer} is a phrase about the trial.
  ///
  /// In en, this message translates to:
  /// **'You\'re building a habit. Premium keeps every check-in and shows you how the weeks are actually going — and {offer}.'**
  String homeNudgeCheckinsMessage(String offer);

  /// Sheet title when a free user taps their mood week on Home.
  ///
  /// In en, this message translates to:
  /// **'Mood history is part of Premium'**
  String get homeMoodHistoryPremiumTitle;

  /// Sheet body. {offer} is a phrase about the trial.
  ///
  /// In en, this message translates to:
  /// **'Checking in is always free. Premium keeps the record and shows you the pattern — and {offer}.'**
  String homeMoodHistoryPremiumMessage(String offer);

  /// Greeting at the top of Home before noon; the person's first name follows on the next line.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get homeGreetingMorning;

  /// Greeting at the top of Home from noon to 6pm; the first name follows on the next line.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon,'**
  String get homeGreetingAfternoon;

  /// Greeting at the top of Home after 6pm; the first name follows on the next line.
  ///
  /// In en, this message translates to:
  /// **'Good evening,'**
  String get homeGreetingEvening;

  /// Title of the Home card summarising meditation/breathing practice.
  ///
  /// In en, this message translates to:
  /// **'Your practice'**
  String get homeYourPractice;

  /// Under 'Your practice': minutes practised this week, and total sessions ever.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, other{{minutes} minutes}} this week · {sessions, plural, other{{sessions} sessions}} in all'**
  String homePracticeSummary(int minutes, int sessions);

  /// On the practice card: the last thing practised. {title} is a content title.
  ///
  /// In en, this message translates to:
  /// **'Last time: {title}'**
  String homeLastTime(String title);

  /// Heading above one suggestion after picking a low mood (awful/bad).
  ///
  /// In en, this message translates to:
  /// **'Something that might help'**
  String get homeSuggestionLow;

  /// Heading above one suggestion after picking 'okay'.
  ///
  /// In en, this message translates to:
  /// **'Something for right now'**
  String get homeSuggestionOkay;

  /// Heading above one suggestion after picking a good mood.
  ///
  /// In en, this message translates to:
  /// **'Something to keep it going'**
  String get homeSuggestionGood;

  /// Link under the mood suggestion to the full list for that need. {need} is a need chip label, lower-cased in English (e.g. “feeling low”).
  ///
  /// In en, this message translates to:
  /// **'More for “{need}”'**
  String homeMoreForNeed(String need);

  /// Label above the last seven days of mood faces on Home.
  ///
  /// In en, this message translates to:
  /// **'Your week'**
  String get homeYourWeek;

  /// Link to the mood history, beside 'Your week'.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get homeHistory;

  /// The mood check-in question on Home.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling today?'**
  String get homeHowAreYouFeeling;

  /// Small upper-case label on the card with today's journal prompt.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S PROMPT'**
  String get homeTodaysPrompt;

  /// Small upper-case label on the card with today's short read.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S READ'**
  String get homeTodaysRead;

  /// Button on Home that opens the crisis resources. Needs a fluent, careful review.
  ///
  /// In en, this message translates to:
  /// **'Need help now?'**
  String get homeNeedHelpNow;

  /// Section heading on Home for items the person has saved (hearted).
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get homeSaved;

  /// Title of the Home card that opens mood/practice insights.
  ///
  /// In en, this message translates to:
  /// **'Your insights'**
  String get homeYourInsights;

  /// Subtitle on the insights card.
  ///
  /// In en, this message translates to:
  /// **'How practice, your week and your moods connect.'**
  String get homeInsightsSub;

  /// Title of a new journal entry started from Home before a therapy session. Written in first person; it's saved in the journal.
  ///
  /// In en, this message translates to:
  /// **'Before my session'**
  String get homeBeforeSessionJournalTitle;

  /// Opening words of that journal entry; the person continues the sentence. Keep the trailing space.
  ///
  /// In en, this message translates to:
  /// **'In my session, I\'d like to talk about '**
  String get homeBeforeSessionJournalSeed;

  /// Card title on Home when a therapy session is booked.
  ///
  /// In en, this message translates to:
  /// **'Before your session'**
  String get homeBeforeSessionTitle;

  /// Card subtitle: invites writing notes before the session.
  ///
  /// In en, this message translates to:
  /// **'Jot down what you want to talk about, so nothing slips away when the call starts.'**
  String get homeBeforeSessionSub;

  /// Small upper-case label above the therapist's summary of the last session.
  ///
  /// In en, this message translates to:
  /// **'FROM YOUR LAST SESSION'**
  String get homeFromLastSession;

  /// Button: open the full session summary.
  ///
  /// In en, this message translates to:
  /// **'Read it all'**
  String get homeReadItAll;

  /// Heading above one suggestion related to the last therapy session.
  ///
  /// In en, this message translates to:
  /// **'Something to practise until next time'**
  String get homePractiseUntilNext;

  /// When a session is today. {time} is a formatted time like 17:00.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String homeToday(String time);

  /// When a session is tomorrow. {time} is a formatted time.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, {time}'**
  String homeTomorrow(String time);

  /// Therapy banner title on Home for a booked session. {when} is e.g. 'Today, 17:00'.
  ///
  /// In en, this message translates to:
  /// **'Your session · {when}'**
  String homeYourSession(String when);

  /// Therapy banner subtitle when the session room is open.
  ///
  /// In en, this message translates to:
  /// **'It\'s open now — tap to join.'**
  String get homeSessionOpen;

  /// Therapy banner subtitle before the session opens.
  ///
  /// In en, this message translates to:
  /// **'Tap for the details, or to join when it opens.'**
  String get homeSessionDetails;

  /// Therapy banner title while a request is being matched with a therapist.
  ///
  /// In en, this message translates to:
  /// **'Finding your therapist'**
  String get homeFindingTherapist;

  /// Therapy banner subtitle while matching.
  ///
  /// In en, this message translates to:
  /// **'We\'ll let you know as soon as your session is booked.'**
  String get homeFindingTherapistSub;

  /// Therapy banner title inviting someone to book a session.
  ///
  /// In en, this message translates to:
  /// **'Talk to a real therapist'**
  String get homeTalkToTherapist;

  /// Therapy banner subtitle. {price} is the session price, e.g. $20.
  ///
  /// In en, this message translates to:
  /// **'{price} a session, paid when you book.'**
  String homeTalkToTherapistSub(String price);

  /// Section heading on Home above four shortcut tiles.
  ///
  /// In en, this message translates to:
  /// **'Quick access'**
  String get homeQuickAccess;

  /// Download button on a sound, meditation or the Downloads screen: download it to play without internet.
  ///
  /// In en, this message translates to:
  /// **'Download for offline'**
  String get downloadAction;

  /// Download button on a sound, meditation or the Downloads screen: it is on the phone.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloadDone;

  /// Download button on a sound, meditation or the Downloads screen: queued; tapping cancels. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Waiting to download · tap to cancel'**
  String get downloadQueued;

  /// Download button on a sound, meditation or the Downloads screen: waiting for Wi-Fi (Wi-Fi-only setting is on); tapping cancels.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi · tap to cancel'**
  String get downloadWaitingWifi;

  /// Download button on a sound, meditation or the Downloads screen: download in progress. {percent} is 0–100.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}% · tap to cancel'**
  String downloadProgress(int percent);

  /// Download button on a sound, meditation or the Downloads screen: the download failed; tapping retries.
  ///
  /// In en, this message translates to:
  /// **'Download failed · tap to try again'**
  String get downloadFailed;

  /// Title of the dialog/action that deletes a downloaded item from the phone.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get downloadRemove;

  /// Button on a course: download all its audio.
  ///
  /// In en, this message translates to:
  /// **'Download course'**
  String get downloadCourse;

  /// Course download button when everything is on the phone.
  ///
  /// In en, this message translates to:
  /// **'Course downloaded'**
  String get downloadCourseDone;

  /// Course download button during download.
  ///
  /// In en, this message translates to:
  /// **'Downloading · {done} of {total} ready'**
  String downloadCourseProgress(int done, int total);

  /// Course download button while waiting for Wi-Fi.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Wi-Fi to download'**
  String get downloadCourseWaiting;

  /// Shown on the sound player while a sound streams/downloads before it first plays.
  ///
  /// In en, this message translates to:
  /// **'Getting this sound ready…'**
  String get downloadPreparing;

  /// Snackbar when a sound isn't on the phone and there's no connection.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get that sound. Connect to the internet to play it the first time.'**
  String get downloadNeedsConnection;

  /// Snackbar when a free user tries to play a Premium sound.
  ///
  /// In en, this message translates to:
  /// **'This sound is part of Premium.'**
  String get downloadPremiumNeeded;

  /// Snackbar when a sound fails to play for another reason.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play that sound.'**
  String get downloadCouldNotPlay;

  /// Settings row and screen title for managing downloaded audio.
  ///
  /// In en, this message translates to:
  /// **'Downloads & storage'**
  String get downloadsTitle;

  /// Intro on the Downloads & storage screen.
  ///
  /// In en, this message translates to:
  /// **'Sounds and meditations you\'ve downloaded play without a connection. Delete them here to free up space.'**
  String get downloadsIntro;

  /// Switch on the Downloads screen.
  ///
  /// In en, this message translates to:
  /// **'Download on Wi-Fi only'**
  String get downloadsWifiOnly;

  /// Explanation under the Wi-Fi-only switch.
  ///
  /// In en, this message translates to:
  /// **'Downloads wait for Wi-Fi, so they don\'t use your mobile data.'**
  String get downloadsWifiOnlyDetail;

  /// How much storage downloads use. {size} is formatted, e.g. '24.3 MB'.
  ///
  /// In en, this message translates to:
  /// **'Using {size} on this phone'**
  String downloadsUsing(String size);

  /// Section label on the Downloads screen: downloads under way.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get downloadsInProgress;

  /// Section label on the Downloads screen: finished downloads.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get downloadsOnPhone;

  /// Empty state on the Downloads screen.
  ///
  /// In en, this message translates to:
  /// **'Nothing downloaded yet. Tap the download button on a sound, meditation or course to keep it for when you\'re offline.'**
  String get downloadsEmpty;

  /// Button on the Downloads screen.
  ///
  /// In en, this message translates to:
  /// **'Delete all downloads'**
  String get downloadsDeleteAll;

  /// Confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete all downloads?'**
  String get downloadsDeleteAllTitle;

  /// Confirmation dialog body.
  ///
  /// In en, this message translates to:
  /// **'They\'ll be removed from this phone. You can download them again any time.'**
  String get downloadsDeleteAllBody;

  /// Tooltip on the delete button of one downloaded item. {title} is its title.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}'**
  String downloadsDeleteOne(String title);

  /// Settings switch and picker option: slowly moving backgrounds behind sounds and sessions.
  ///
  /// In en, this message translates to:
  /// **'Calm visuals'**
  String get backgroundCalmVisuals;

  /// Explanation under the Calm visuals switch.
  ///
  /// In en, this message translates to:
  /// **'Slowly moving backgrounds behind sounds and sessions. Off holds them still.'**
  String get backgroundCalmVisualsHint;

  /// Shown instead of the hint when the phone's reduce-motion setting is on.
  ///
  /// In en, this message translates to:
  /// **'Your phone is set to reduce motion, so backgrounds stay still.'**
  String get backgroundReduceMotionNote;

  /// Title of the sheet for choosing the animated background of a sound or session.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get backgroundPickerTitle;

  /// Tooltip of the button that opens the background picker.
  ///
  /// In en, this message translates to:
  /// **'Change background'**
  String get backgroundPickerTooltip;

  /// Name of a feature shown in a 'coming soon' message from Settings when the store isn't set up.
  ///
  /// In en, this message translates to:
  /// **'Subscription management'**
  String get settingsSubscriptionManagement;

  /// Name of a feature shown in a 'coming soon' message from Settings when the store isn't set up.
  ///
  /// In en, this message translates to:
  /// **'Restoring purchases'**
  String get settingsRestoringPurchases;

  /// Snackbar after restoring purchases found a Premium subscription.
  ///
  /// In en, this message translates to:
  /// **'Premium restored — welcome back.'**
  String get settingsPremiumRestored;

  /// Snackbar after restoring purchases found nothing.
  ///
  /// In en, this message translates to:
  /// **'No previous purchases found.'**
  String get settingsNoPurchasesFound;

  /// Log-out confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsLogOutTitle;

  /// Log-out confirmation dialog body: reassuring.
  ///
  /// In en, this message translates to:
  /// **'You can always come back — your progress stays safe.'**
  String get settingsLogOutBody;

  /// Settings row and dialog button: sign out of the account.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOut;

  /// Progress dialog while the account is being deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account…'**
  String get settingsDeleting;

  /// Snackbar when account deletion fails partway.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t finish deleting your account. Your request is on file and we\'ll complete it — or try again.'**
  String get settingsDeleteFailed;

  /// Shown on the profile card in Settings when the person has no name set.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get settingsYourAccount;

  /// Plan name on the Settings plan card for subscribers. Usually not translated.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get settingsPremiumPlan;

  /// Plan name on the Settings plan card for free users.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get settingsFreePlan;

  /// Under 'Premium' on the plan card: everything is unlocked (a gentle metaphor).
  ///
  /// In en, this message translates to:
  /// **'Every room in the house is open.'**
  String get settingsPremiumTagline;

  /// Button on the plan card: manage the subscription.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get settingsManage;

  /// Button on the plan card: open the paywall.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get settingsUpgrade;

  /// Section label in Settings, only for care-team staff and therapists. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Care team'**
  String get settingsCareTeam;

  /// Settings row for care-team staff.
  ///
  /// In en, this message translates to:
  /// **'Care team dashboard'**
  String get settingsCareDashboard;

  /// Settings row for therapists: their sessions with clients.
  ///
  /// In en, this message translates to:
  /// **'My therapy sessions'**
  String get settingsMyTherapySessions;

  /// Title of the sheet for choosing what the person wants help with (the 'need' chips).
  ///
  /// In en, this message translates to:
  /// **'What would help most?'**
  String get settingsGoalsTitle;

  /// Under the goals sheet title.
  ///
  /// In en, this message translates to:
  /// **'We\'ll put these first in your suggestions.'**
  String get settingsGoalsSub;

  /// Settings row and sheet title: light/dark theme.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Subtitle under 'Match my phone' in the appearance sheet.
  ///
  /// In en, this message translates to:
  /// **'Light by day, dark when your phone is.'**
  String get settingsAppearanceSystemHint;

  /// Title of the Settings tab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section label in Settings. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Settings row.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfile;

  /// Settings row: sends a password reset email.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// Settings row.
  ///
  /// In en, this message translates to:
  /// **'Reminders & notifications'**
  String get settingsReminders;

  /// Settings row: choose what the person wants help with; the current picks are shown on the right.
  ///
  /// In en, this message translates to:
  /// **'What would help most'**
  String get settingsGoals;

  /// Settings row: restore a subscription bought on another phone.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get settingsRestorePurchases;

  /// Section label in Settings. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupport;

  /// Settings row: opens helplines. Needs a careful, fluent review.
  ///
  /// In en, this message translates to:
  /// **'Crisis resources'**
  String get settingsCrisisResources;

  /// Settings row: email support.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get settingsContactUs;

  /// Settings row: frequently asked questions.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get settingsFaq;

  /// Section label in Settings. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// Settings row.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// Settings row.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get settingsTerms;

  /// Section label in Settings above Log out and Delete account. Shown in capitals.
  ///
  /// In en, this message translates to:
  /// **'Account actions'**
  String get settingsAccountActions;

  /// Settings row: permanently delete the account.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Delete-account confirmation dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get settingsDeleteTitle;

  /// Delete-account dialog body: plain and complete about what is deleted.
  ///
  /// In en, this message translates to:
  /// **'This removes your profile, journal entries, mood check-ins, recovery streaks, craving logs, therapy requests and photo. It happens straight away and it can\'t be undone.'**
  String get settingsDeleteBody;

  /// Dialog button: cancel deleting the account.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get settingsKeepAccount;

  /// Dialog button: confirm permanent deletion.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get settingsDeleteForGood;

  /// Snackbar after requesting a password reset.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to {email}'**
  String settingsPasswordResetSent(String email);

  /// Snackbar when no mail app is available and the support address was copied.
  ///
  /// In en, this message translates to:
  /// **'Email address copied: {email}'**
  String settingsEmailCopied(String email);

  /// Label of the text field in the delete-account dialog. {word} is DELETE, which must be typed exactly as shown — don't translate it.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String settingsTypeToConfirm(String word);

  /// Value on the 'What would help most' row when more than two are picked: two names, then how many more.
  ///
  /// In en, this message translates to:
  /// **'{first} +{more}'**
  String settingsGoalsMore(String first, int more);

  /// Small line under a suggestion on Home, picked because the person just checked in feeling awful or low. Keep it short (about 25 characters).
  ///
  /// In en, this message translates to:
  /// **'For right now'**
  String get homeReasonLead;

  /// Small line under the crisis-support suggestion on Home. Keep it short (about 30 characters).
  ///
  /// In en, this message translates to:
  /// **'Here whenever you need it'**
  String get homeReasonSupport;

  /// Small line under a suggestion on Home: the next day of the course the person is doing. {course} is the course's title, for example '7 days to better sleep'.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {course}'**
  String homeReasonCourseDay(int day, String course);

  /// Small line under a suggestion on Home: the person said they felt better after {title}, a meditation, exercise or sound with similar aims. Shown on two lines at most.
  ///
  /// In en, this message translates to:
  /// **'Because you felt better after {title}'**
  String homeReasonFeltBetter(String title);

  /// Small line under a suggestion on Home: it fits one of the goals the person chose in onboarding. {need} picks the goal; translate each sentence whole. Shown on two lines at most.
  ///
  /// In en, this message translates to:
  /// **'{need, select, sleep{Because you\'re working on sleep} anxious{Because you\'re working on anxiety} panic{Because you\'re working on panic} low{Because you\'re working on low moods} stressed{Because you\'re working on stress} angry{Because you\'re working on anger} urges{Because you\'re working on urges} focus{Because you\'re working on focus} reflect{Because you\'re working on reflection} good{Because you want to keep the good days going} other{Because of what you\'re working on}}'**
  String homeReasonGoal(String need);

  /// Small line under a suggestion on Home: the item is new in the app.
  ///
  /// In en, this message translates to:
  /// **'Just added'**
  String get homeReasonFresh;

  /// Small line under a suggestion on Home: many people used it in the last 30 days.
  ///
  /// In en, this message translates to:
  /// **'Popular this month'**
  String get homeReasonPopular;

  /// Small line under a suggestion on Home: the person saved (hearted) this item.
  ///
  /// In en, this message translates to:
  /// **'One you saved'**
  String get homeReasonSaved;

  /// Small line under a suggestion on Home when there's no particular reason for it.
  ///
  /// In en, this message translates to:
  /// **'Something to try'**
  String get homeReasonFallback;

  /// Title of a dialog shown once, 30 days after someone's Premium subscription ended, asking whether to delete the Premium audio still saved on the phone.
  ///
  /// In en, this message translates to:
  /// **'Remove Premium downloads?'**
  String get downloadsLapsedTitle;

  /// Body of the 'Remove Premium downloads?' dialog. {size} is a file size, for example '48.2 MB'. Gentle: nothing is deleted unless they choose to.
  ///
  /// In en, this message translates to:
  /// **'Your Premium ended over a month ago, and its downloads still take up {size} on this phone. Remove them to free up space? If you come back to Premium, you can download them again.'**
  String downloadsLapsedBody(String size);

  /// Button in the 'Remove Premium downloads?' dialog: keep the files. It asks again in 30 days.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get downloadsLapsedKeep;

  /// Button in the 'Remove Premium downloads?' dialog: delete the Premium downloads.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get downloadsLapsedRemove;

  /// Button on the crisis screen, next to the country name, that opens the list of countries whose helplines can be shown. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'Change country'**
  String get crisisChangeCountry;

  /// First option in the country list on the crisis screen: show helplines for the country the phone is set to, instead of one picked by hand.
  ///
  /// In en, this message translates to:
  /// **'Use my phone\'s country'**
  String get crisisUsePhoneCountry;

  /// Warning on the crisis screen, only in test builds, above helplines nobody has checked yet. Crisis wording: needs careful review by a fluent speaker.
  ///
  /// In en, this message translates to:
  /// **'Draft: these numbers haven\'t been checked yet. In an emergency, call the number above.'**
  String get crisisUncheckedNumbers;
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
      <String>['de', 'en', 'es', 'fr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
