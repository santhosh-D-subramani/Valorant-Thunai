import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ta.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ta'),
  ];

  /// The conventional newborn programmer greeting
  ///
  /// In en, this message translates to:
  /// **'Hello World!'**
  String get helloWorld;

  /// Title on blocked screen
  ///
  /// In en, this message translates to:
  /// **'Feature Under Maintenance'**
  String get featureUnderMaintenance;

  /// Default message when feature is blocked/in maintenance
  ///
  /// In en, this message translates to:
  /// **'This feature is temporarily undergoing maintenance or has been disabled remotely. Please check back later.'**
  String get featureDisabledMaintenanceMessage;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'ooi riot give me my store offer man.....'**
  String get funnyLoading1;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Asking Riot nicely to hand over the store offers...'**
  String get funnyLoading2;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Bribing Riot servers with virtual cookies...'**
  String get funnyLoading3;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Knocking on Riot\'s backend doors: open up please!'**
  String get funnyLoading4;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Are we there yet? Riot client is taking a scenic route...'**
  String get funnyLoading5;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Wait, is the shopkeeper on a coffee break?'**
  String get funnyLoading6;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Searching the bottom drawer of the Valorant store...'**
  String get funnyLoading7;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Pleading with the API: give us the good skins!'**
  String get funnyLoading8;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Generating random luck... please stand by...'**
  String get funnyLoading9;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Riot says: \'No Kuronami Vandal for you today\' ... wait, let\'s try again...'**
  String get funnyLoading10;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Checking if Riot gave you the Reaver Vandal yet...'**
  String get funnyLoading11;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Polishing the weapons so they look shiny on your screen...'**
  String get funnyLoading12;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Calculating how many times you got flash-banned by your own Phoenix...'**
  String get funnyLoading13;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Decoupling Sage walls from gravity...'**
  String get funnyLoading14;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Asking Cypher for his setup... but he\'s already dead...'**
  String get funnyLoading15;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Telling Jett that \'dash-in and die\' is not a viable strategy...'**
  String get funnyLoading16;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Dusting off the store counter... a lot of Smite skins here...'**
  String get funnyLoading17;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Replacing your cheap skins with dreams of RGX...'**
  String get funnyLoading18;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Charging up the Neon slide... slide... slide...'**
  String get funnyLoading19;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Convincing Omen that teleporting into enemy spawn is a bad idea...'**
  String get funnyLoading20;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Checking if the store has the Magepunk Sparkplug...'**
  String get funnyLoading21;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Asking Brimstone how to open his iPad...'**
  String get funnyLoading22;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Counting the number of times you said \'one shot\' when they had 140 HP...'**
  String get funnyLoading23;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Trying to retrieve your rank from the bottom of Iron 1...'**
  String get funnyLoading24;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Locating the spike... wait, who dropped it in spawn?'**
  String get funnyLoading25;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Cleaning up the acid puddles left by Viper...'**
  String get funnyLoading26;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Checking if your teammate\'s microphone is actually a potato...'**
  String get funnyLoading27;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Consulting Sova\'s double-shock-dart calculator...'**
  String get funnyLoading28;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Calibrating the recoil of the Odin (just drag down, right?)...'**
  String get funnyLoading29;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Buying a Shield... wait, no, buying a Sheriff and no armor...'**
  String get funnyLoading30;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Whispering sweet nothing to the matchmaking algorithm...'**
  String get funnyLoading31;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Analyzing why you always lose the 5v1 post-plant...'**
  String get funnyLoading32;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Waiting for the Chamber pocket-guardian to reload...'**
  String get funnyLoading33;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Asking Reyna if she plans to helper-heal or just dismiss...'**
  String get funnyLoading34;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Untangling Fade\'s nightmares...'**
  String get funnyLoading35;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Recharging the Gekko wingman so he can plant again...'**
  String get funnyLoading36;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Checking if the shopkeeper accepts Valorant Points or only prayers...'**
  String get funnyLoading37;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Searching for the legendary \'good teammates\' in the API database...'**
  String get funnyLoading38;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Pretending we are analyzing complex metadata (we are just waiting)...'**
  String get funnyLoading39;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Translating Astra\'s galaxy-brain plays into plain English...'**
  String get funnyLoading40;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Trying to mute the toxic teammate before we even log in...'**
  String get funnyLoading41;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Polishing the gold borders on the Radiant rank badge (not yours, sadly)...'**
  String get funnyLoading42;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Convincing Raze that satcheling into a wall is still satcheling...'**
  String get funnyLoading43;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Counting the milliseconds Jett spent in the air before getting headshot...'**
  String get funnyLoading44;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Waiting for Cypher\'s camera to stop staring at a blank wall...'**
  String get funnyLoading45;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Sweeping the teleporter exit on Bind...'**
  String get funnyLoading46;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Tuning Harbor\'s water filter...'**
  String get funnyLoading47;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Looking for the crosshair settings that will make you a Radiant...'**
  String get funnyLoading48;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Checking if the night market has returned with 10% off a bunch of melee skins...'**
  String get funnyLoading49;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Feeding the Gekko pets some virtual pet food...'**
  String get funnyLoading50;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Asking Iso if he wants to 1v1 in the gulag...'**
  String get funnyLoading51;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Calculating the velocity of a flying Vandal...'**
  String get funnyLoading52;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Warming up the servers... please don\'t alt-tab...'**
  String get funnyLoading53;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Wiping the screen of flash bangs... so bright...'**
  String get funnyLoading54;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Trying to figure out where Yoru went...'**
  String get funnyLoading55;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Waiting for the Iso shield to wear off...'**
  String get funnyLoading56;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Telling Clove that dying on purpose is not a superpower...'**
  String get funnyLoading57;

  /// Funny loading message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get funnyLoading58;

  /// 404 page not found text
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// Session expired dialog title
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get sessionExpiredTitle;

  /// Session expired dialog content
  ///
  /// In en, this message translates to:
  /// **'Your Riot Games session has expired. Please log in again to fetch the latest shop data.'**
  String get sessionExpiredMessage;

  /// Dismiss button
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// Action to re-login
  ///
  /// In en, this message translates to:
  /// **'Login Again'**
  String get loginAgain;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Profile tab label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// Party tab label
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get tabParty;

  /// Career tab label (rank goals, contracts & missions, friends)
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get tabHub;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Snackbar when offline retry fails
  ///
  /// In en, this message translates to:
  /// **'Still offline. Please check your network connection.'**
  String get stillOfflineMessage;

  /// Offline overlay title
  ///
  /// In en, this message translates to:
  /// **'CONNECTION LOST'**
  String get connectionLostTitle;

  /// Offline overlay description
  ///
  /// In en, this message translates to:
  /// **'You are currently offline. Please restore your connection to continue using Valorant Thunai.'**
  String get connectionLostDescription;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get retryButton;

  /// Help page title
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get helpFaqTitle;

  /// FAQ category
  ///
  /// In en, this message translates to:
  /// **'LOGIN TROUBLESHOOTING'**
  String get faqLoginTroubleshootingTitle;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Make sure you are using your primary Riot account credentials. At this time, direct social media logins (like Google or Facebook) are not supported unless they are already connected to a standard Riot Games account.'**
  String get faqLoginTroubleshootingContent;

  /// FAQ category
  ///
  /// In en, this message translates to:
  /// **'SESSION EXPIRED ERROR'**
  String get faqSessionExpiredTitle;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'If you see a session expiry alert, it simply means your temporary access token has reached its limit. Riot requires a fresh login periodically for security. Just log out and sign back in to refresh your access.'**
  String get faqSessionExpiredContent;

  /// FAQ category
  ///
  /// In en, this message translates to:
  /// **'WHY AM I BEING RATE LIMITED?'**
  String get faqRateLimitedTitle;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Riot\'s servers sometimes receive too many requests at once. To keep the service stable, they might temporarily pause requests from third-party apps. If this happens, please wait about 5 minutes before trying to refresh again.'**
  String get faqRateLimitedContent;

  /// FAQ category
  ///
  /// In en, this message translates to:
  /// **'IS MY ACCOUNT SECURE?'**
  String get faqAccountSecurityTitle;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'Your privacy is our number one priority. This application does not have a central server; all your tokens and account details are stored exclusively on your own device. We never see or store your personal information.'**
  String get faqAccountSecurityContent;

  /// FAQ category
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT SAFETY & RISK'**
  String get faqAccountSafetyTitle;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'While this app only reads publicly available data through Riot\'s API, using any third-party software involves a minor degree of risk. By using this service, you accept responsibility for your account\'s status. To stay safe, avoid spamming the refresh button and use the app moderately.'**
  String get faqAccountSafetyContent;

  /// FAQ category
  ///
  /// In en, this message translates to:
  /// **'FUTURE OF THE APP'**
  String get faqFutureAppTitle;

  /// FAQ answer
  ///
  /// In en, this message translates to:
  /// **'The functionality of this app depends entirely on Riot Games providing API access. Should they choose to restrict this access in the future, some or all features may become unavailable.'**
  String get faqFutureAppContent;

  /// FAQ section header
  ///
  /// In en, this message translates to:
  /// **'DIAGNOSTIC LOGS'**
  String get diagnosticLogsSection;

  /// FAQ diagnostic description
  ///
  /// In en, this message translates to:
  /// **'If you are experiencing bugs, you can share the app logs with the developer to help identify the issue.'**
  String get diagnosticLogsDescription;

  /// Snackbar when no logs to share
  ///
  /// In en, this message translates to:
  /// **'No logs available yet.'**
  String get noLogsAvailable;

  /// Button to share diagnostic logs
  ///
  /// In en, this message translates to:
  /// **'Share Logs with Developer'**
  String get shareLogsWithDeveloper;

  /// Subject line when sharing logs
  ///
  /// In en, this message translates to:
  /// **'Valorant Thunai Diagnostic Logs'**
  String get shareLogsSubject;

  /// Footer message
  ///
  /// In en, this message translates to:
  /// **'Thank you for using Valorant Thunai!'**
  String get thankYouUsingApp;

  /// System logs screen title
  ///
  /// In en, this message translates to:
  /// **'System Logs'**
  String get systemLogsTitle;

  /// Snackbar text
  ///
  /// In en, this message translates to:
  /// **'Logs censored. Sensitive info masked.'**
  String get logsCensoredSnackbar;

  /// Snackbar text
  ///
  /// In en, this message translates to:
  /// **'Uncensored logs active.'**
  String get uncensoredLogsActiveSnackbar;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Reveal Uncensored Logs'**
  String get revealUncensoredLogsTitle;

  /// Dialog description
  ///
  /// In en, this message translates to:
  /// **'Enter the developer passcode to view raw API keys and authentication tokens.'**
  String get revealUncensoredLogsDescription;

  /// Textfield label
  ///
  /// In en, this message translates to:
  /// **'Passcode'**
  String get passcodeLabel;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Unlock button
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// Snackbar text
  ///
  /// In en, this message translates to:
  /// **'Passcode verified. Uncensored logs revealed!'**
  String get passcodeVerifiedSnackbar;

  /// Snackbar error text
  ///
  /// In en, this message translates to:
  /// **'Incorrect passcode!'**
  String get incorrectPasscodeSnackbar;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Censor Logs'**
  String get censorLogsTooltip;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Unlock Uncensored Logs'**
  String get unlockUncensoredLogsTooltip;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAllTooltip;

  /// Snackbar text
  ///
  /// In en, this message translates to:
  /// **'Uncensored logs copied to clipboard'**
  String get uncensoredLogsCopiedSnackbar;

  /// Snackbar text
  ///
  /// In en, this message translates to:
  /// **'Censored logs copied to clipboard'**
  String get censoredLogsCopiedSnackbar;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearTooltip;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// Banner warning
  ///
  /// In en, this message translates to:
  /// **'Uncensored Mode: Sensitive tokens & API keys are visible.'**
  String get uncensoredModeWarning;

  /// Empty logs text
  ///
  /// In en, this message translates to:
  /// **'No logs available'**
  String get noLogsAvailableMessage;

  /// Cache manager screen title
  ///
  /// In en, this message translates to:
  /// **'Cache Manager'**
  String get cacheManagerTitle;

  /// Clear cache dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear {title}?'**
  String clearCacheDialogTitle(String title);

  /// Clear cache dialog body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear {title}? Clearing this cache is generally not needed because these files rarely change. Reloading them will consume more network data and slow down screen load times.'**
  String clearCacheDialogContent(String title);

  /// Clear action button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearButton;

  /// Snackbar when cache is cleared
  ///
  /// In en, this message translates to:
  /// **'{title} cleared successfully'**
  String cacheClearedSuccess(String title);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'INFO'**
  String get cacheInfoSectionHeader;

  /// Cache info paragraph
  ///
  /// In en, this message translates to:
  /// **'Images, ranks, and video previews are saved on your device so they load instantly and save network data. Clearing these caches is generally not recommended unless you are experiencing display issues or running low on storage.'**
  String get cacheInfoDescription;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'MANAGED CACHES'**
  String get managedCachesSectionHeader;

  /// Cache item title
  ///
  /// In en, this message translates to:
  /// **'Rank Icons Cache'**
  String get rankIconsCacheTitle;

  /// Cache item subtitle
  ///
  /// In en, this message translates to:
  /// **'Indefinite cache of competitive tier images'**
  String get rankIconsCacheSubtitle;

  /// Cache item title
  ///
  /// In en, this message translates to:
  /// **'Bundle Images Cache'**
  String get bundleImagesCacheTitle;

  /// Cache item subtitle
  ///
  /// In en, this message translates to:
  /// **'Saves images of featured store bundles'**
  String get bundleImagesCacheSubtitle;

  /// Cache item title
  ///
  /// In en, this message translates to:
  /// **'Daily Store Images Cache'**
  String get dailyStoreImagesCacheTitle;

  /// Cache item subtitle
  ///
  /// In en, this message translates to:
  /// **'Saves skin icons of the daily rotation storefront'**
  String get dailyStoreImagesCacheSubtitle;

  /// Cache item title
  ///
  /// In en, this message translates to:
  /// **'Loadout & Preset Images Cache'**
  String get loadoutPresetImagesCacheTitle;

  /// Cache item subtitle
  ///
  /// In en, this message translates to:
  /// **'Saves weapon skins, buddies, and preset thumbnail images'**
  String get loadoutPresetImagesCacheSubtitle;

  /// Cache item title
  ///
  /// In en, this message translates to:
  /// **'Video Preview Cache'**
  String get videoPreviewCacheTitle;

  /// Cache item subtitle
  ///
  /// In en, this message translates to:
  /// **'Saves download data of weapon preview clips'**
  String get videoPreviewCacheSubtitle;

  /// Cache item title
  ///
  /// In en, this message translates to:
  /// **'Store Text Cache'**
  String get storeTextCacheTitle;

  /// Cache item subtitle
  ///
  /// In en, this message translates to:
  /// **'Stores localized config text, shop contracts, and APIs'**
  String get storeTextCacheSubtitle;

  /// Cache item title
  ///
  /// In en, this message translates to:
  /// **'Friend Names Cache'**
  String get friendNamesCacheTitle;

  /// Cache item subtitle
  ///
  /// In en, this message translates to:
  /// **'Resolved friend display names, refreshed once a day'**
  String get friendNamesCacheSubtitle;

  /// Notifications screen title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Appearance page title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSectionHeader;

  /// Option title
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appThemeOption;

  /// Theme mode name
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Theme mode name
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Theme mode name
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Toggle title
  ///
  /// In en, this message translates to:
  /// **'Pure black dark mode'**
  String get pureBlackDarkModeTitle;

  /// Toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Saves battery on OLED screens'**
  String get pureBlackDarkModeSubtitle;

  /// Toggle title
  ///
  /// In en, this message translates to:
  /// **'Use system colors'**
  String get useSystemColorsTitle;

  /// Toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Use dynamic colors from your wallpaper'**
  String get useSystemColorsSubtitle;

  /// Slider title
  ///
  /// In en, this message translates to:
  /// **'Color blend level'**
  String get colorBlendLevelTitle;

  /// Color preset name
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get colorPresetDefault;

  /// Color preset name
  ///
  /// In en, this message translates to:
  /// **'Green Apple'**
  String get colorPresetGreenApple;

  /// Color preset name
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get colorPresetLavender;

  /// Color preset name
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get colorPresetMidnight;

  /// Color preset name
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorPresetOrange;

  /// Color preset name
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorPresetTeal;

  /// Color preset name
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorPresetRed;

  /// All bundles screen title
  ///
  /// In en, this message translates to:
  /// **'All Bundles'**
  String get allBundlesTitle;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMessage(String error);

  /// Fallback when item has no name
  ///
  /// In en, this message translates to:
  /// **'No Name'**
  String get noName;

  /// Daily shop title
  ///
  /// In en, this message translates to:
  /// **'Daily Shop'**
  String get dailyShopTitle;

  /// Welcome title
  ///
  /// In en, this message translates to:
  /// **'Welcome to Valorant Thunai'**
  String get welcomeToValShop;

  /// Welcome subtitle
  ///
  /// In en, this message translates to:
  /// **'Login to view your daily offers'**
  String get loginToViewOffers;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login with Riot'**
  String get loginWithRiot;

  /// Changelog screen title
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelogTitle;

  /// Fallback changelog text
  ///
  /// In en, this message translates to:
  /// **'No changelog available.'**
  String get noChangelogAvailable;

  /// Changelog error text
  ///
  /// In en, this message translates to:
  /// **'Failed to load changelog.\n{error}'**
  String failedToLoadChangelog(String error);

  /// Video player loading state
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get loadingVideo;

  /// Video player error
  ///
  /// In en, this message translates to:
  /// **'Error playing video:\n{error}'**
  String errorPlayingVideo(String error);

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Enter Developer Passcode'**
  String get enterDeveloperPasscode;

  /// Snackbar text
  ///
  /// In en, this message translates to:
  /// **'Developer Mode Unlocked!'**
  String get developerModeUnlockedSnackbar;

  /// Unread notification count
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String unreadCount(int count);

  /// No notifications subtitle
  ///
  /// In en, this message translates to:
  /// **'No new notifications'**
  String get noNewNotifications;

  /// Appearance subtitle
  ///
  /// In en, this message translates to:
  /// **'Theme, color, icon'**
  String get themeColorIconSubtitle;

  /// Settings item
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// Changelog subtitle
  ///
  /// In en, this message translates to:
  /// **'See what\'s new in this version'**
  String get seeWhatsNewSubtitle;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'ACCOUNTS'**
  String get accountsSectionHeader;

  /// Settings section header for rank goals, contracts, and friends
  ///
  /// In en, this message translates to:
  /// **'VALORANT'**
  String get valorantSectionHeader;

  /// Login subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your store'**
  String get signInToViewStoreSubtitle;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdatedSnackbar;

  /// Snackbar error
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String updateFailedSnackbar(String error);

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOutTitle;

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of this account?'**
  String get logOutConfirmMessage;

  /// Button to add account
  ///
  /// In en, this message translates to:
  /// **'Add another account'**
  String get addAnotherAccount;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'DEVELOPER OPTIONS'**
  String get developerOptionsHeader;

  /// Toggle title
  ///
  /// In en, this message translates to:
  /// **'Bypass Remote Config'**
  String get bypassRemoteConfigTitle;

  /// Toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Ignore remote blocklists and features overrides'**
  String get bypassRemoteConfigSubtitle;

  /// Toggle title
  ///
  /// In en, this message translates to:
  /// **'Bypass Log Censoring'**
  String get bypassLogCensoringTitle;

  /// Toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Show raw tokens and API keys in diagnostic logs'**
  String get bypassLogCensoringSubtitle;

  /// Button title
  ///
  /// In en, this message translates to:
  /// **'Lock Developer Mode'**
  String get lockDeveloperModeTitle;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Developer mode locked & bypass disabled.'**
  String get developerModeLockedSnackbar;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Rate Valorant Thunai'**
  String get rateValShopTitle;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'Show some love on the Play Store'**
  String get rateValShopSubtitle;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Discover More Apps'**
  String get discoverMoreAppsTitle;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'Check out my other creations'**
  String get discoverMoreAppsSubtitle;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'App Logs'**
  String get appLogsTitle;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'View debugging logs'**
  String get viewDebuggingLogsSubtitle;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage cached images, previews, and data sizes'**
  String get manageCachedImagesSubtitle;

  /// Settings section header
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get supportSectionHeader;

  /// Settings item title
  ///
  /// In en, this message translates to:
  /// **'Show Sasuke on Jul 23'**
  String get showSasukeEasterEggTitle;

  /// Settings item subtitle
  ///
  /// In en, this message translates to:
  /// **'Enable or disable the Easter Egg'**
  String get showSasukeEasterEggSubtitle;

  /// Update checking toast
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get checkingForUpdates;

  /// Latest version message
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version!'**
  String get latestVersionMessage;

  /// Update check failed message
  ///
  /// In en, this message translates to:
  /// **'Update check failed. Please try again later.'**
  String get updateCheckFailedMessage;

  /// Update dialog title
  ///
  /// In en, this message translates to:
  /// **'New update is available'**
  String get newUpdateAvailableTitle;

  /// Update dialog body
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. Update now to get the latest features and improvements.'**
  String updateDialogContent(String version);

  /// Update dialog action
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNowButton;

  /// Skin details section header
  ///
  /// In en, this message translates to:
  /// **'Color Variants'**
  String get colorVariantsTitle;

  /// Skin details section header
  ///
  /// In en, this message translates to:
  /// **'Skin Levels'**
  String get skinLevelsTitle;

  /// Skin level number
  ///
  /// In en, this message translates to:
  /// **'Level {number}'**
  String levelNumberTitle(int number);

  /// Skin level VFX label
  ///
  /// In en, this message translates to:
  /// **'Visual Effects'**
  String get visualEffectsLevelItem;

  /// Chroma preview subtitle
  ///
  /// In en, this message translates to:
  /// **'{name} Preview'**
  String variantPreviewSubtitle(String name);

  /// Bundle details screen title
  ///
  /// In en, this message translates to:
  /// **'Bundle Details'**
  String get bundleDetailsTitle;

  /// Full bundle card title
  ///
  /// In en, this message translates to:
  /// **'Full Bundle'**
  String get fullBundleTitle;

  /// Bundle items section header
  ///
  /// In en, this message translates to:
  /// **'Bundle Items'**
  String get bundleItemsTitle;

  /// Bundle items info box
  ///
  /// In en, this message translates to:
  /// **'Access to individual bundle items is available when this bundle is currently featured in the shop.'**
  String get bundleItemsFeaturedInfo;

  /// Bundle ROI card title
  ///
  /// In en, this message translates to:
  /// **'Bundle Value'**
  String get bundleRoiTitle;

  /// Bundle ROI savings summary
  ///
  /// In en, this message translates to:
  /// **'Save {amount} VP ({percent}%) vs buying separately'**
  String bundleRoiSavings(String amount, String percent);

  /// Shown when bundle offers no discount vs individual items
  ///
  /// In en, this message translates to:
  /// **'No savings vs buying items separately'**
  String get bundleRoiNoSavings;

  /// Free item price label
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freePriceLabel;

  /// Watch video link
  ///
  /// In en, this message translates to:
  /// **'Watch Video'**
  String get watchVideoLabel;

  /// Accessory inspector header
  ///
  /// In en, this message translates to:
  /// **'PLAYER CARD INSPECT'**
  String get playerCardInspectHeader;

  /// Inspector tab
  ///
  /// In en, this message translates to:
  /// **'Lobby Card'**
  String get lobbyCardTab;

  /// Inspector tab
  ///
  /// In en, this message translates to:
  /// **'Profile DP'**
  String get profileDpTab;

  /// Inspector tab
  ///
  /// In en, this message translates to:
  /// **'Match Loading'**
  String get matchLoadingTab;

  /// Inspector badge
  ///
  /// In en, this message translates to:
  /// **'Full Portrait Lobby Card'**
  String get fullPortraitLobbyCardBadge;

  /// Inspector badge
  ///
  /// In en, this message translates to:
  /// **'Player Profile Icon'**
  String get playerProfileIconBadge;

  /// Inspector description
  ///
  /// In en, this message translates to:
  /// **'Displayed across Friend List, Social Hub & Party Header'**
  String get playerProfileIconDescription;

  /// Inspector badge
  ///
  /// In en, this message translates to:
  /// **'In-Match Loading Banner'**
  String get inMatchLoadingBannerBadge;

  /// Inspector category tag
  ///
  /// In en, this message translates to:
  /// **'SPRAY'**
  String get sprayTag;

  /// Inspector category tag
  ///
  /// In en, this message translates to:
  /// **'ANIMATED SPRAY'**
  String get animatedSprayTag;

  /// Inspector badge
  ///
  /// In en, this message translates to:
  /// **'Animated Valorant Spray'**
  String get animatedValorantSprayBadge;

  /// Inspector badge
  ///
  /// In en, this message translates to:
  /// **'Standard Valorant Spray'**
  String get standardValorantSprayBadge;

  /// Favorites screen title
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// Shop rotation history screen title
  ///
  /// In en, this message translates to:
  /// **'Shop History'**
  String get shopHistoryTitle;

  /// Shop history empty state message
  ///
  /// In en, this message translates to:
  /// **'No shop history yet — check back after a few daily resets.'**
  String get shopHistoryEmptyState;

  /// How many times a skin has appeared in the shop history
  ///
  /// In en, this message translates to:
  /// **'Seen {count}x'**
  String shopHistorySeenCount(int count);

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Clear all favorites?'**
  String get clearAllFavoritesTitle;

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your entire favorites history.'**
  String get clearAllFavoritesContent;

  /// Delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// Empty favorites text
  ///
  /// In en, this message translates to:
  /// **'No favorites yet.'**
  String get noFavoritesYet;

  /// Added date label
  ///
  /// In en, this message translates to:
  /// **'Added: {date}'**
  String addedDatePrefix(String date);

  /// Loadout screen title
  ///
  /// In en, this message translates to:
  /// **'Loadout'**
  String get loadoutTitle;

  /// Title loader state
  ///
  /// In en, this message translates to:
  /// **'Loading Title...'**
  String get loadingTitleText;

  /// No title state
  ///
  /// In en, this message translates to:
  /// **'No Title'**
  String get noTitleText;

  /// Title error state
  ///
  /// In en, this message translates to:
  /// **'Error loading title'**
  String get errorLoadingTitle;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Choose Player Card'**
  String get choosePlayerCardTitle;

  /// Option button
  ///
  /// In en, this message translates to:
  /// **'Change Title'**
  String get changeTitleOption;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Choose Title'**
  String get chooseTitleScreenTitle;

  /// Option button
  ///
  /// In en, this message translates to:
  /// **'Weapon Loadout'**
  String get weaponLoadoutOption;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Choose {slot} Spray'**
  String chooseSpraySlotTitle(String slot);

  /// Weapons screen title
  ///
  /// In en, this message translates to:
  /// **'Weapons'**
  String get weaponsTitle;

  /// Customize weapon screen title
  ///
  /// In en, this message translates to:
  /// **'Customize {weapon}'**
  String customizeWeaponTitle(String weapon);

  /// Standard skin name
  ///
  /// In en, this message translates to:
  /// **'Standard {weapon}'**
  String standardSkinPrefix(String weapon);

  /// Option row
  ///
  /// In en, this message translates to:
  /// **'Change Skin'**
  String get changeSkinOption;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Choose Skin'**
  String get chooseSkinScreenTitle;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Buddy'**
  String get buddySectionTitle;

  /// Buddy empty state
  ///
  /// In en, this message translates to:
  /// **'No Buddy'**
  String get noBuddyText;

  /// Option row
  ///
  /// In en, this message translates to:
  /// **'Change Buddy'**
  String get changeBuddyOption;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Choose Buddy'**
  String get chooseBuddyScreenTitle;

  /// Search input hint
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchPlaceholder;

  /// Tab label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalTab;

  /// Tab label with count
  ///
  /// In en, this message translates to:
  /// **'Owned ({count})'**
  String ownedCountTab(int count);

  /// Spray category
  ///
  /// In en, this message translates to:
  /// **'Spray'**
  String get sprayCategoryTab;

  /// Spray category
  ///
  /// In en, this message translates to:
  /// **'GIF Spray'**
  String get gifSprayCategoryTab;

  /// Spray category
  ///
  /// In en, this message translates to:
  /// **'Flex'**
  String get flexCategoryTab;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Weapon not found'**
  String get weaponNotFoundMessage;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Unknown item type'**
  String get unknownItemTypeMessage;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to equip skin: {error}'**
  String failedToEquipSkin(String error);

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to equip buddy: {error}'**
  String failedToEquipBuddy(String error);

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to equip title: {error}'**
  String failedToEquipTitle(String error);

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to equip spray: {error}'**
  String failedToEquipSpray(String error);

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to equip card: {error}'**
  String failedToEquipCard(String error);

  /// Friends screen title
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// Title for the home/hub card summarizing friends currently in a Valorant match
  ///
  /// In en, this message translates to:
  /// **'Friends in game'**
  String get friendsInGameDigestTitle;

  /// Subtitle for the friends-in-game digest card, count of friends currently in game
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} friend is in a match} other {{count} friends are in a match}}'**
  String friendsInGameDigestCount(int count);

  /// Overflow label on the friends-in-game digest card, e.g. '+3 more'
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String friendsInGameDigestMore(int count);

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Friend request sent!'**
  String get friendRequestSentSnackbar;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get addFriendDialogTitle;

  /// Dialog description
  ///
  /// In en, this message translates to:
  /// **'Enter the Riot ID of the player you want to add.'**
  String get addFriendDialogDescription;

  /// Text field hint
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameFieldHint;

  /// Text field hint
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get tagFieldHint;

  /// Form validation error
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredValidation;

  /// Button label to send friend request
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequestButton;

  /// Error state
  ///
  /// In en, this message translates to:
  /// **'Error loading friends: {error}'**
  String errorLoadingFriends(String error);

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Search input hint
  ///
  /// In en, this message translates to:
  /// **'Search friends'**
  String get searchFriendsHint;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get onlineStatusText;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineStatusText;

  /// Time label
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNowText;

  /// Last online text
  ///
  /// In en, this message translates to:
  /// **'Last online {count} minutes ago'**
  String lastOnlineMinutesAgo(int count);

  /// Last online text
  ///
  /// In en, this message translates to:
  /// **'Last online {count} {unit} ago'**
  String lastOnlineHoursAgo(int count, String unit);

  /// Last online text
  ///
  /// In en, this message translates to:
  /// **'Last online {hours} {hUnit}, {minutes} {mUnit} ago'**
  String lastOnlineHoursMinutesAgo(
    int hours,
    String hUnit,
    int minutes,
    String mUnit,
  );

  /// Last online text
  ///
  /// In en, this message translates to:
  /// **'Last online {count} days ago'**
  String lastOnlineDaysAgo(int count);

  /// Last online text
  ///
  /// In en, this message translates to:
  /// **'Last online {days} days, {hours} {hUnit} ago'**
  String lastOnlineDaysHoursAgo(int days, int hours, String hUnit);

  /// Last online text
  ///
  /// In en, this message translates to:
  /// **'Last online {days} day, {minutes} {mUnit} ago'**
  String lastOnlineDaysMinutesAgo(int days, int minutes, String mUnit);

  /// Party extra members
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String moreMembersCount(int count);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Online Friends — {count}'**
  String onlineFriendsHeader(int count);

  /// Friends section header for friends actively in a Valorant session
  ///
  /// In en, this message translates to:
  /// **'In Valorant — {count}'**
  String inValorantHeader(int count);

  /// Friends section header for friends online on Riot Client but not in a Valorant session
  ///
  /// In en, this message translates to:
  /// **'Riot Client — {count}'**
  String riotClientHeader(int count);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Offline — {count}'**
  String offlineFriendsHeader(int count);

  /// Appbar title
  ///
  /// In en, this message translates to:
  /// **'Valorant Live Social'**
  String get valorantLiveSocialTitle;

  /// Appbar title
  ///
  /// In en, this message translates to:
  /// **'XMPP Disconnected'**
  String get xmppDisconnectedTitle;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Reconnect XMPP'**
  String get reconnectXmppMenu;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Set Status: Online'**
  String get setStatusOnlineMenu;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Set Status: Away'**
  String get setStatusAwayMenu;

  /// Menu item
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectMenu;

  /// Status info bar
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusLabelPrefix(String status);

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectButton;

  /// Sidebar header
  ///
  /// In en, this message translates to:
  /// **'Friends ({count})'**
  String friendsCountSidebar(int count);

  /// Sidebar empty state
  ///
  /// In en, this message translates to:
  /// **'No friends found'**
  String get noFriendsFound;

  /// Chat placeholder
  ///
  /// In en, this message translates to:
  /// **'Select a friend to start chatting'**
  String get selectFriendToChat;

  /// Empty conversation placeholder
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hi!'**
  String get noMessagesYetSayHi;

  /// Chat input hint
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessageHint;

  /// Match details title
  ///
  /// In en, this message translates to:
  /// **'Match Details'**
  String get matchDetailsTitle;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No details available'**
  String get noDetailsAvailable;

  /// Match result badge
  ///
  /// In en, this message translates to:
  /// **'DRAW'**
  String get matchResultDraw;

  /// Match result badge
  ///
  /// In en, this message translates to:
  /// **'VICTORY'**
  String get matchResultVictory;

  /// Match result badge
  ///
  /// In en, this message translates to:
  /// **'DEFEAT'**
  String get matchResultDefeat;

  /// Match details section
  ///
  /// In en, this message translates to:
  /// **'Scoreboard'**
  String get scoreboardHeader;

  /// Table column header
  ///
  /// In en, this message translates to:
  /// **'K'**
  String get killsColumnHeader;

  /// Table column header
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get deathsColumnHeader;

  /// Table column header
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get assistsColumnHeader;

  /// Table column header
  ///
  /// In en, this message translates to:
  /// **'SCORE'**
  String get scoreColumnHeader;

  /// Match details section
  ///
  /// In en, this message translates to:
  /// **'Round Breakdown'**
  String get roundBreakdownHeader;

  /// Team section header
  ///
  /// In en, this message translates to:
  /// **'Allies'**
  String get teamAlliesHeader;

  /// Team section header
  ///
  /// In en, this message translates to:
  /// **'Enemies'**
  String get teamEnemiesHeader;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Search Players'**
  String get searchPlayersTitle;

  /// Search input hint
  ///
  /// In en, this message translates to:
  /// **'Search Name#Tag or PUUID...'**
  String get searchPlayerHint;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recentSearchesHeader;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAllButton;

  /// Matches empty state
  ///
  /// In en, this message translates to:
  /// **'Matches not available'**
  String get matchesNotAvailable;

  /// Empty matches message
  ///
  /// In en, this message translates to:
  /// **'No recent matches found'**
  String get noRecentMatchesFound;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'K/D'**
  String get kdRatioLabel;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'HS%'**
  String get headshotPercentLabel;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'WIN%'**
  String get winRateLabel;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Current Rank'**
  String get currentRankHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Peak Rank'**
  String get peakRankHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Recent Matches'**
  String get recentMatchesHeader;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Season Goal Archived'**
  String get seasonGoalArchivedTitle;

  /// Dialog body
  ///
  /// In en, this message translates to:
  /// **'Your goal for {season} has been archived.\n\nTarget Rank: {target}\nStarting Rank: {starting}\nFinished Rank: {finished}'**
  String seasonGoalArchivedBody(
    String season,
    String target,
    String starting,
    String finished,
  );

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// Max rank banner
  ///
  /// In en, this message translates to:
  /// **'You have reached the maximum rank!'**
  String get reachedMaxRankMessage;

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Seasonal Rank Goal'**
  String get seasonalRankGoalTitle;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'Profile data not available'**
  String get profileDataNotAvailable;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Error loading rank goals: {error}'**
  String errorLoadingRankGoals(String error);

  /// Timer state
  ///
  /// In en, this message translates to:
  /// **'Act ended'**
  String get actEndedText;

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'{count} days left'**
  String daysLeftText(int count);

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'{count} hrs left'**
  String hoursLeftText(int count);

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'{count} mins left'**
  String minsLeftText(int count);

  /// Rank status badge
  ///
  /// In en, this message translates to:
  /// **'STARTING'**
  String get startingBadge;

  /// Rank status badge
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get currentBadge;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Active Goal?'**
  String get deleteActiveGoalTitle;

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your current rank goal and starting status. You cannot recover your starting rank history if you delete it. Are you sure you want to delete this goal?'**
  String get deleteActiveGoalContent;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete History Entry?'**
  String get deleteHistoryEntryTitle;

  /// Dialog description
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete this archived goal from your history? This action cannot be undone.'**
  String get deleteHistoryEntryContent;

  /// History subtitle
  ///
  /// In en, this message translates to:
  /// **'Target: {target} • Finished: {finished}'**
  String goalHistoryTargetFinished(String target, String finished);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Contracts & Missions'**
  String get contractsMissionsTitle;

  /// Tab title
  ///
  /// In en, this message translates to:
  /// **'Missions'**
  String get missionsTab;

  /// Tab title
  ///
  /// In en, this message translates to:
  /// **'Battle Pass'**
  String get battlePassTab;

  /// Tab title
  ///
  /// In en, this message translates to:
  /// **'Event Pass'**
  String get eventPassTab;

  /// Tab title
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentsTab;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Refresh Data'**
  String get refreshDataButton;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'Progression data not available'**
  String get progressionDataNotAvailable;

  /// Error state
  ///
  /// In en, this message translates to:
  /// **'Error loading contracts: {error}'**
  String errorLoadingContracts(String error);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Daily Reset'**
  String get dailyResetHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Daily Checkpoints'**
  String get dailyCheckpointsHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Weekly Missions'**
  String get weeklyMissionsHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'{count} Future Weeklies'**
  String futureWeekliesCountHeader(int count);

  /// Fallback title
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get missionDefaultTitle;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Agent Recruitment'**
  String get agentRecruitmentHeader;

  /// Title of the per-agent cosmetic contract progress screen
  ///
  /// In en, this message translates to:
  /// **'Agent Gear'**
  String get agentGearTitle;

  /// Completed vs total tiers for an agent's gear contract
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} tiers'**
  String agentGearTiersFormat(int completed, int total);

  /// Shown when an agent's gear contract is fully completed
  ///
  /// In en, this message translates to:
  /// **'Maxed'**
  String get agentGearMaxed;

  /// Kingdom Credits remaining to fully complete an agent's gear contract
  ///
  /// In en, this message translates to:
  /// **'{amount} KC to max'**
  String agentGearKcRemaining(String amount);

  /// Label for a single reward tier in the agent gear detail list
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}'**
  String agentGearTierFormat(int tier);

  /// KC balance
  ///
  /// In en, this message translates to:
  /// **'Kingdom Credits: {amount}'**
  String kingdomCreditsBalance(int amount);

  /// Profile empty state
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedInMessage;

  /// Title for the local RR-over-time graph card on the profile screen
  ///
  /// In en, this message translates to:
  /// **'RR History'**
  String get rankHistoryTitle;

  /// ListTile title
  ///
  /// In en, this message translates to:
  /// **'Rank Goals'**
  String get rankGoalsTileTitle;

  /// ListTile subtitle
  ///
  /// In en, this message translates to:
  /// **'Set and track your climb progress'**
  String get rankGoalsTileSubtitle;

  /// ListTile subtitle
  ///
  /// In en, this message translates to:
  /// **'Track agent recruitment and missions progress'**
  String get contractsTileSubtitle;

  /// Fallback label
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownText;

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'Remaining Time: {time}'**
  String remainingTimeLabel(String time);

  /// Dropdown filter
  ///
  /// In en, this message translates to:
  /// **'All Queues'**
  String get allQueuesFilter;

  /// Queue name
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get queueCompetitive;

  /// Queue name
  ///
  /// In en, this message translates to:
  /// **'Unrated'**
  String get queueUnrated;

  /// Queue name
  ///
  /// In en, this message translates to:
  /// **'Swiftplay'**
  String get queueSwiftplay;

  /// Queue name
  ///
  /// In en, this message translates to:
  /// **'Spike Rush'**
  String get queueSpikeRush;

  /// Queue name
  ///
  /// In en, this message translates to:
  /// **'Deathmatch'**
  String get queueDeathmatch;

  /// Sort option
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// Sort option
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get sortOldest;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgainButton;

  /// Empty matches state
  ///
  /// In en, this message translates to:
  /// **'No matches found for the selected filter'**
  String get noMatchesFilterMessage;

  /// Pagination button
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMoreButton;

  /// Stats tab header
  ///
  /// In en, this message translates to:
  /// **'Top Agents'**
  String get topAgentsHeader;

  /// Stats tab header
  ///
  /// In en, this message translates to:
  /// **'Top Weapons'**
  String get topWeaponsHeader;

  /// Stats tab header
  ///
  /// In en, this message translates to:
  /// **'Top Maps'**
  String get topMapsHeader;

  /// Stats tab header
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracyHeader;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Login Successful!'**
  String get loginSuccessfulSnackbar;

  /// Snackbar error
  ///
  /// In en, this message translates to:
  /// **'Login Failed: {error}'**
  String loginFailedSnackbar(String error);

  /// Screen title
  ///
  /// In en, this message translates to:
  /// **'Riot Login'**
  String get riotLoginTitle;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Failed to refresh shop.'**
  String get noInternetShopRefreshFailed;

  /// Snackbar error
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh shop: {error}'**
  String failedToRefreshShop(String error);

  /// Shop section header
  ///
  /// In en, this message translates to:
  /// **'Featured Bundle'**
  String get featuredBundleHeader;

  /// Shop section header
  ///
  /// In en, this message translates to:
  /// **'Daily Offers'**
  String get dailyOffersHeader;

  /// Shop section header
  ///
  /// In en, this message translates to:
  /// **'Night Market'**
  String get nightMarketHeader;

  /// Shop section header
  ///
  /// In en, this message translates to:
  /// **'Accessory Store'**
  String get accessoryStoreHeader;

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'Expires in {time}'**
  String bundleExpiresIn(String time);

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'Resets in {time}'**
  String offersResetIn(String time);

  /// Discount badge
  ///
  /// In en, this message translates to:
  /// **'-{percent}%'**
  String discountPercentBadge(int percent);

  /// Option button
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsOptionTitle;

  /// Option subtitle
  ///
  /// In en, this message translates to:
  /// **'View online status and send friend requests'**
  String get friendsOptionSubtitle;

  /// Configuration title
  ///
  /// In en, this message translates to:
  /// **'Match Type'**
  String get matchTypeTitle;

  /// Configuration title
  ///
  /// In en, this message translates to:
  /// **'Preferred Servers'**
  String get preferredServersTitle;

  /// Configuration title
  ///
  /// In en, this message translates to:
  /// **'Party Code'**
  String get partyCodeTitle;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCodeTooltip;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Party code copied to clipboard!'**
  String get partyCodeCopiedSnackbar;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Disable Code'**
  String get disableCodeTooltip;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generateCodeButton;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Copied {text} to clipboard!'**
  String copiedToClipboardSnackbar(String text);

  /// Context menu item
  ///
  /// In en, this message translates to:
  /// **'Copy Riot ID'**
  String get copyRiotIdMenu;

  /// Context menu item
  ///
  /// In en, this message translates to:
  /// **'Open Profile'**
  String get openProfileMenu;

  /// Menu subtitle
  ///
  /// In en, this message translates to:
  /// **'View career match history and stats'**
  String get openProfileSubtitle;

  /// Context menu item
  ///
  /// In en, this message translates to:
  /// **'Show Loadout'**
  String get showLoadoutMenu;

  /// Menu subtitle
  ///
  /// In en, this message translates to:
  /// **'Inspect equipped weapon skins'**
  String get showLoadoutSubtitle;

  /// Context menu item
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get addFriendMenu;

  /// Menu subtitle
  ///
  /// In en, this message translates to:
  /// **'Send Riot friend request'**
  String get addFriendSubtitle;

  /// Context menu item
  ///
  /// In en, this message translates to:
  /// **'Invite to Party'**
  String get inviteToPartyMenu;

  /// Menu subtitle
  ///
  /// In en, this message translates to:
  /// **'Invite player to current lobby'**
  String get inviteToPartySubtitle;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Game Name'**
  String get gameNameFieldHint;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get taglineFieldHint;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Friend request sent to {name}#{tag}!'**
  String friendRequestSentToPlayer(String name, String tag);

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Match Type'**
  String get selectMatchTypeTitle;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Servers'**
  String get selectServersTitle;

  /// Screen header
  ///
  /// In en, this message translates to:
  /// **'Party Lobby'**
  String get partyLobbyHeader;

  /// FAB label
  ///
  /// In en, this message translates to:
  /// **'START MATCH'**
  String get startMatchmakingButton;

  /// FAB label
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelMatchmakingButton;

  /// Queue timer
  ///
  /// In en, this message translates to:
  /// **'IN QUEUE: {time}'**
  String matchmakingInQueue(String time);

  /// Phase title
  ///
  /// In en, this message translates to:
  /// **'Agent Select'**
  String get agentSelectPhaseTitle;

  /// Phase title
  ///
  /// In en, this message translates to:
  /// **'In Match'**
  String get inMatchPhaseTitle;

  /// Starting side label
  ///
  /// In en, this message translates to:
  /// **'Attackers'**
  String get attackersSideLabel;

  /// Starting side label
  ///
  /// In en, this message translates to:
  /// **'Defenders'**
  String get defendersSideLabel;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Leave Party'**
  String get leavePartyButton;

  /// Accessibility mode
  ///
  /// In en, this message translates to:
  /// **'Open Party'**
  String get openPartyAccessibility;

  /// Accessibility mode
  ///
  /// In en, this message translates to:
  /// **'Closed Party'**
  String get closedPartyAccessibility;

  /// Player status
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get playerReadyLabel;

  /// Player status
  ///
  /// In en, this message translates to:
  /// **'NOT READY'**
  String get playerNotReadyLabel;

  /// Leader tag
  ///
  /// In en, this message translates to:
  /// **'LEADER'**
  String get leaderBadge;

  /// Force update dialog title
  ///
  /// In en, this message translates to:
  /// **'Critical Update Required'**
  String get criticalUpdateRequiredTitle;

  /// Normal update dialog title
  ///
  /// In en, this message translates to:
  /// **'Update Available!'**
  String get updateAvailableTitle;

  /// Force update dialog body
  ///
  /// In en, this message translates to:
  /// **'A critical update (v{version}) is required to continue using the app. This fix addresses essential Riot API changes.'**
  String criticalUpdateRequiredBody(String version);

  /// Normal update dialog body
  ///
  /// In en, this message translates to:
  /// **'A new version (v{version}) of Valorant Thunai is ready! Update now for new features and bug fixes.'**
  String updateAvailableBody(String version);

  /// Error message when item type is unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown item type'**
  String get unknownItemType;

  /// Form validation required message
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredValidator;

  /// Party members overflow text
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String plusMorePartyMembers(int count);

  /// Time ago string
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Last online text for 1 day
  ///
  /// In en, this message translates to:
  /// **'Last online 1 day ago'**
  String get lastOnlineOneDayAgo;

  /// Archived goal dialog message
  ///
  /// In en, this message translates to:
  /// **'Your goal for {season} has been archived.\n\nTarget: {target}\nFinished: {finished} ({currentRR} RR)\n\n{resultMessage}'**
  String seasonGoalArchivedContent(
    String season,
    String target,
    String finished,
    int currentRR,
    String resultMessage,
  );

  /// Archived dialog congratulation
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You reached your goal! 🎉'**
  String get goalReachedCongratulations;

  /// Archived dialog encouragement
  ///
  /// In en, this message translates to:
  /// **'Nice try! Set a new goal for the current season.'**
  String get goalMissedEncouragement;

  /// Modal sheet title
  ///
  /// In en, this message translates to:
  /// **'Select Target Rank Goal'**
  String get selectTargetRankGoal;

  /// Title when no rank goal is active
  ///
  /// In en, this message translates to:
  /// **'No Rank Goal Set'**
  String get noRankGoalSet;

  /// Description when no goal is active
  ///
  /// In en, this message translates to:
  /// **'Your current rank is {rank} ({rr} RR). Set a seasonal target to track your progress and climb the leaderboard.'**
  String noRankGoalSetDescription(String rank, int rr);

  /// Button label to set rank goal
  ///
  /// In en, this message translates to:
  /// **'Set Target Goal'**
  String get setTargetGoal;

  /// Timer text when act is finished
  ///
  /// In en, this message translates to:
  /// **'Act ended'**
  String get actEnded;

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String daysLeft(int days);

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'{hours} hrs left'**
  String hoursLeft(int hours);

  /// Timer text
  ///
  /// In en, this message translates to:
  /// **'{mins} mins left'**
  String minsLeft(int mins);

  /// Label for current active act
  ///
  /// In en, this message translates to:
  /// **'Active Act'**
  String get activeAct;

  /// Progress card title
  ///
  /// In en, this message translates to:
  /// **'Climb Progress'**
  String get climbProgress;

  /// Date goal was set
  ///
  /// In en, this message translates to:
  /// **'Set: {date}'**
  String setPrefix(String date);

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'STARTING'**
  String get startingLabel;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get currentLabel;

  /// Rank rating suffix
  ///
  /// In en, this message translates to:
  /// **'{rr} RR'**
  String rrSuffix(int rr);

  /// Progress status
  ///
  /// In en, this message translates to:
  /// **'Goal Achieved!'**
  String get goalAchieved;

  /// Section title for the RR trend/games-to-goal estimate
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get rankGoalTrendTitle;

  /// Shown when there isn't enough local rank history to compute a trend
  ///
  /// In en, this message translates to:
  /// **'Not enough recent games to estimate yet'**
  String get rankGoalNotEnoughData;

  /// Shown when the average RR change per game is flat or negative
  ///
  /// In en, this message translates to:
  /// **'Trending away from goal'**
  String get rankGoalTrendingAway;

  /// Estimated number of games left to reach the rank goal at the current trend
  ///
  /// In en, this message translates to:
  /// **'~{games} games to goal'**
  String rankGoalEstimatedGames(int games);

  /// Average RR change per game over the trailing window used for the estimate
  ///
  /// In en, this message translates to:
  /// **'Avg {avg} RR/game over last {games} games'**
  String rankGoalAvgRRPerGame(String avg, int games);

  /// Title of the compact rank goal progress summary card
  ///
  /// In en, this message translates to:
  /// **'Goal Progress'**
  String get rankGoalSummaryCardTitle;

  /// Compact summary card subtitle naming the target rank tier
  ///
  /// In en, this message translates to:
  /// **'Target: {tierName}'**
  String rankGoalSummaryTargetLabel(String tierName);

  /// Progress status remaining RR
  ///
  /// In en, this message translates to:
  /// **'{rr} RR to go'**
  String rrToGo(int rr);

  /// Positive RR gain
  ///
  /// In en, this message translates to:
  /// **'+{rr} RR'**
  String plusRR(int rr);

  /// Timeline title
  ///
  /// In en, this message translates to:
  /// **'The Climb Timeline'**
  String get theClimbTimeline;

  /// Delete goal button label
  ///
  /// In en, this message translates to:
  /// **'Delete Goal'**
  String get deleteGoal;

  /// Section title for past goals
  ///
  /// In en, this message translates to:
  /// **'Goal History'**
  String get goalHistory;

  /// Status badge
  ///
  /// In en, this message translates to:
  /// **'ACHIEVED'**
  String get achievedStatus;

  /// Status badge
  ///
  /// In en, this message translates to:
  /// **'MISSED'**
  String get missedStatus;

  /// Fallback season text
  ///
  /// In en, this message translates to:
  /// **'Unknown Season'**
  String get unknownSeason;

  /// Fallback rank name
  ///
  /// In en, this message translates to:
  /// **'UNRANKED'**
  String get unranked;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to load match details from Riot server.'**
  String get failedToLoadMatchDetails;

  /// Fallback map name
  ///
  /// In en, this message translates to:
  /// **'Unknown Map'**
  String get unknownMap;

  /// Performance section header
  ///
  /// In en, this message translates to:
  /// **'YOUR PERFORMANCE'**
  String get yourPerformance;

  /// Fallback agent name
  ///
  /// In en, this message translates to:
  /// **'Unknown Agent'**
  String get unknownAgent;

  /// Account level label
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String accountLevelFormat(int level);

  /// KD Ratio string
  ///
  /// In en, this message translates to:
  /// **'K/D Ratio: {ratio}'**
  String kdRatioWithVal(String ratio);

  /// Combat score stat label
  ///
  /// In en, this message translates to:
  /// **'ACS'**
  String get acs;

  /// Kills stat label
  ///
  /// In en, this message translates to:
  /// **'Kills'**
  String get kills;

  /// Assists stat label
  ///
  /// In en, this message translates to:
  /// **'Assists'**
  String get assists;

  /// Team name
  ///
  /// In en, this message translates to:
  /// **'Blue Team'**
  String get blueTeam;

  /// Team name
  ///
  /// In en, this message translates to:
  /// **'Red Team'**
  String get redTeam;

  /// Rounds won count
  ///
  /// In en, this message translates to:
  /// **'{count} Rounds'**
  String roundsWonFormat(int count);

  /// KDA column header
  ///
  /// In en, this message translates to:
  /// **'K/D/A'**
  String get kdaHeader;

  /// Short player level
  ///
  /// In en, this message translates to:
  /// **'Lv {level}'**
  String playerLv(int level);

  /// Generic error fallback
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get anErrorOccurred;

  /// Empty search prompt
  ///
  /// In en, this message translates to:
  /// **'Search for a Valorant player by Name#Tag or PUUID\n(e.g., Tenz#NA1)'**
  String get searchEmptyPrompt;

  /// Region label
  ///
  /// In en, this message translates to:
  /// **'Region: {region}'**
  String regionPrefix(String region);

  /// Current rank upper label
  ///
  /// In en, this message translates to:
  /// **'CURRENT RANK'**
  String get currentRankUpper;

  /// Lifetime peak label
  ///
  /// In en, this message translates to:
  /// **'Lifetime Peak'**
  String get lifetimePeak;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to perform search.'**
  String get mustBeLoggedInToSearch;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Invalid Name#Tag format. Example: Tenz#NA1'**
  String get invalidNameTagFormat;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid Name#Tag or 36-character PUUID'**
  String get enterValidNameTagOrPuuid;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Player not found. Double check their name/tag or PUUID.'**
  String get playerNotFound;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh Data'**
  String get refreshDataTooltip;

  /// Missions empty state
  ///
  /// In en, this message translates to:
  /// **'All weeklies completed!'**
  String get allWeekliesCompleted;

  /// Time until weekly mission unlocks
  ///
  /// In en, this message translates to:
  /// **'in {count} {unit}'**
  String inWeeks(int count, String unit);

  /// Pass empty state
  ///
  /// In en, this message translates to:
  /// **'No active pass available currently.'**
  String get noActivePassAvailable;

  /// Next reward title
  ///
  /// In en, this message translates to:
  /// **'Next Reward'**
  String get nextReward;

  /// Pass level indicator
  ///
  /// In en, this message translates to:
  /// **'Level {current} / {total}'**
  String passLevelFormat(int current, int total);

  /// Estimated days remaining to finish the current battle pass tier/act, based on locally observed XP pace
  ///
  /// In en, this message translates to:
  /// **'At this pace, ~{days} {days, plural, one {day} other {days}} to finish'**
  String xpForecastDaysFormat(int days);

  /// Locally observed average XP gain per day
  ///
  /// In en, this message translates to:
  /// **'~{xp} XP/day'**
  String xpForecastRatePerDay(String xp);

  /// Shown when not enough local XP history exists yet to forecast pass completion
  ///
  /// In en, this message translates to:
  /// **'Gathering XP pace data — check back after a few sessions'**
  String get xpForecastGatheringData;

  /// Agent stat label
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlockedLabel;

  /// Agent stat label
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedLabel;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Manage Loadout'**
  String get manageLoadoutButton;

  /// Ban banner title
  ///
  /// In en, this message translates to:
  /// **'Competitive Queue Ban'**
  String get competitiveQueueBan;

  /// Ban banner title
  ///
  /// In en, this message translates to:
  /// **'Matchmaking Queue Ban'**
  String get matchmakingQueueBan;

  /// Ban banner title
  ///
  /// In en, this message translates to:
  /// **'Communication Restriction'**
  String get communicationRestriction;

  /// Ban banner title
  ///
  /// In en, this message translates to:
  /// **'Account Restriction ({type})'**
  String accountRestriction(String type);

  /// Ban banner item
  ///
  /// In en, this message translates to:
  /// **'Started: {time}'**
  String startedPrefix(String time);

  /// Ban banner item
  ///
  /// In en, this message translates to:
  /// **'Expires: {time}'**
  String expiresPrefix(String time);

  /// Ban banner item
  ///
  /// In en, this message translates to:
  /// **'Remaining Time: {time}'**
  String remainingTimePrefix(String time);

  /// Duration text
  ///
  /// In en, this message translates to:
  /// **'{hours} hours and {minutes} minutes'**
  String hoursAndMinutes(int hours, int minutes);

  /// Duration text
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String minutesOnly(int minutes);

  /// Empty list message
  ///
  /// In en, this message translates to:
  /// **'No matches found for the selected filter'**
  String get noMatchesFoundForFilter;

  /// List footer
  ///
  /// In en, this message translates to:
  /// **'No more matches to load'**
  String get noMoreMatchesToLoad;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Match History'**
  String get matchHistoryTitle;

  /// Queue mode name
  ///
  /// In en, this message translates to:
  /// **'Escalation'**
  String get queueEscalation;

  /// Queue mode name
  ///
  /// In en, this message translates to:
  /// **'Replication'**
  String get queueReplication;

  /// Queue mode name
  ///
  /// In en, this message translates to:
  /// **'Snowball Fight'**
  String get queueSnowballFight;

  /// Queue mode name
  ///
  /// In en, this message translates to:
  /// **'Team Deathmatch'**
  String get queueTeamDeathmatch;

  /// Queue mode name
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get queueRetake;

  /// Queue mode name
  ///
  /// In en, this message translates to:
  /// **'Custom / Unknown'**
  String get queueCustomUnknown;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Session expired or user not logged in'**
  String get sessionExpiredOrNotLoggedIn;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to load match history from Riot server'**
  String get failedToLoadMatchHistory;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'First Win of the Day'**
  String get firstWinOfTheDay;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Recent XP'**
  String get recentXpHeader;

  /// Subtitle
  ///
  /// In en, this message translates to:
  /// **'Last {count} matches'**
  String lastMatchesCount(int count);

  /// Empty message
  ///
  /// In en, this message translates to:
  /// **'No recent match history found.'**
  String get noRecentMatchHistoryFound;

  /// Toggle button
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// Toggle button
  ///
  /// In en, this message translates to:
  /// **'Show More'**
  String get showMore;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'View Agent Contracts'**
  String get viewAgentContracts;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Failed to load matches.'**
  String get failedToLoadMatches;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No matches found for selected mode.'**
  String get noMatchesFoundForMode;

  /// Header title
  ///
  /// In en, this message translates to:
  /// **'Performance (Last {count} matches)'**
  String performanceLastMatches(int count);

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'K/D'**
  String get statKd;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'WIN %'**
  String get statWinrate;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'ACS'**
  String get statAcs;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'HOURS'**
  String get statHours;

  /// Toggle/label for stats gathered only since the app was opened
  ///
  /// In en, this message translates to:
  /// **'This Session'**
  String get thisSession;

  /// Toggle/label for cumulative stats across all recorded matches
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// Stat label for this-session match count
  ///
  /// In en, this message translates to:
  /// **'Matches Played'**
  String get sessionMatchesPlayed;

  /// This-session win/loss record
  ///
  /// In en, this message translates to:
  /// **'{wins}W - {losses}L'**
  String sessionRecordWinLoss(int wins, int losses);

  /// Empty state for this-session stats before any match has been played
  ///
  /// In en, this message translates to:
  /// **'No matches played yet this session.'**
  String get noMatchesThisSessionYet;

  /// Stat label for clutch round win rate
  ///
  /// In en, this message translates to:
  /// **'CLUTCH %'**
  String get statClutchRate;

  /// Section title for the clutch stat card
  ///
  /// In en, this message translates to:
  /// **'Clutch Detector'**
  String get clutchDetectorTitle;

  /// Subtitle showing clutch wins out of attempts
  ///
  /// In en, this message translates to:
  /// **'{wins} of {attempts} clutch rounds won'**
  String clutchDetectorSubtitle(int wins, int attempts);

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Most Played Agents'**
  String get mostPlayedAgents;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Map Winrate %'**
  String get mapWinratePercent;

  /// Loading text
  ///
  /// In en, this message translates to:
  /// **'Authenticating with Riot...'**
  String get authenticatingWithRiot;

  /// Loading subtitle
  ///
  /// In en, this message translates to:
  /// **'Fetching your account details'**
  String get fetchingYourAccountDetails;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Please login first in Settings.'**
  String get pleaseLoginFirstInSettings;

  /// Banner text
  ///
  /// In en, this message translates to:
  /// **'FAVORITE ITEM IN STORE!'**
  String get favoriteItemInStoreBanner;

  /// Error state
  ///
  /// In en, this message translates to:
  /// **'Error loading bundles: {error}'**
  String errorLoadingBundles(String error);

  /// Header title
  ///
  /// In en, this message translates to:
  /// **'Black Market'**
  String get blackMarket;

  /// Header title
  ///
  /// In en, this message translates to:
  /// **'Weekly Accessories'**
  String get weeklyAccessories;

  /// Checkbox label
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get dontShowAgain;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// Fallback skin title
  ///
  /// In en, this message translates to:
  /// **'Skin {id}'**
  String skinFallbackName(String id);

  /// Status title
  ///
  /// In en, this message translates to:
  /// **'Agent Select • {queue}'**
  String agentSelectWithQueue(String queue);

  /// Status title
  ///
  /// In en, this message translates to:
  /// **'Agent Select'**
  String get agentSelect;

  /// Status title
  ///
  /// In en, this message translates to:
  /// **'In Match'**
  String get inMatch;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'PARTY MEMBERS ({count}/5)'**
  String partyMembersHeader(int count);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'ENEMY TEAM ({count})'**
  String enemyTeamHeader(int count);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'PERFORMANCE STATS'**
  String get performanceStatsHeader;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'COMPETITIVE RANK'**
  String get competitiveRankHeader;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No party details available. Are you logged in?'**
  String get noPartyDetailsAvailable;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No servers available'**
  String get noServersAvailable;

  /// Loadout empty state
  ///
  /// In en, this message translates to:
  /// **'Loadout unavailable or private'**
  String get loadoutUnavailableOrPrivate;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Copied \"{name}\" to clipboard!'**
  String copiedPlayerNameToClipboard(String name);

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Friend request sent to {user}!'**
  String friendRequestSentTo(String user);

  /// Modal title
  ///
  /// In en, this message translates to:
  /// **'Party Accessibility'**
  String get partyAccessibility;

  /// Modal title
  ///
  /// In en, this message translates to:
  /// **'Match Type'**
  String get matchType;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generateButton;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyButton;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabledLabel;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Featured Bundles'**
  String get featuredBundles;

  /// Price label for free item
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeLabel;

  /// Error title
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetTitle;

  /// Error subtitle
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get noInternetDescription;

  /// Party phase title
  ///
  /// In en, this message translates to:
  /// **'Current Match'**
  String get currentMatch;

  /// Party phase title
  ///
  /// In en, this message translates to:
  /// **'Matchmaking'**
  String get matchmaking;

  /// Action title
  ///
  /// In en, this message translates to:
  /// **'Copy Player Name'**
  String get copyPlayerName;

  /// Action title
  ///
  /// In en, this message translates to:
  /// **'Show Loadout'**
  String get showLoadout;

  /// Action subtitle
  ///
  /// In en, this message translates to:
  /// **'Inspect equipped weapon skins'**
  String get inspectEquippedWeaponSkins;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequest;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'START MATCH'**
  String get startMatch;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'K/D'**
  String get kdLabel;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'HS%'**
  String get hsLabel;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'KAST'**
  String get kastLabel;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'WIN%'**
  String get winPercentLabel;

  /// Input hint
  ///
  /// In en, this message translates to:
  /// **'Tag (e.g. NA1)'**
  String get tagLineHint;

  /// Input hint
  ///
  /// In en, this message translates to:
  /// **'Game Name (e.g. TenZ)'**
  String get gameNameHint;

  /// Party accessibility status
  ///
  /// In en, this message translates to:
  /// **'Open to friends'**
  String get openToFriends;

  /// Party accessibility status
  ///
  /// In en, this message translates to:
  /// **'Closed / Invite Only'**
  String get closedInviteOnly;

  /// Server selection status
  ///
  /// In en, this message translates to:
  /// **'Automatic Selection'**
  String get automaticSelection;

  /// Server selection count
  ///
  /// In en, this message translates to:
  /// **'{selected} / {total} Selected ({servers})'**
  String serversSelectedCount(int selected, int total, String servers);

  /// Party invite success
  ///
  /// In en, this message translates to:
  /// **'Invited {player} to party!'**
  String invitedPlayerToParty(String player);

  /// Party invite error
  ///
  /// In en, this message translates to:
  /// **'Failed to invite {player}'**
  String failedToInvitePlayer(String player);

  /// Server selection helper text
  ///
  /// In en, this message translates to:
  /// **'Viewing preferred pods. Only the leader can modify them.'**
  String get viewingPreferredPodsInfo;

  /// Ready status
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get readyStatus;

  /// Not ready status
  ///
  /// In en, this message translates to:
  /// **'NOT READY'**
  String get notReadyStatus;

  /// Ally tag
  ///
  /// In en, this message translates to:
  /// **'ALLY'**
  String get allyLabel;

  /// Enemy tag
  ///
  /// In en, this message translates to:
  /// **'ENEMY'**
  String get enemyLabel;

  /// Input label
  ///
  /// In en, this message translates to:
  /// **'Game Name'**
  String get gameNameLabel;

  /// Input label
  ///
  /// In en, this message translates to:
  /// **'Tagline'**
  String get taglineLabel;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// Generic error display
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String genericError(String error);

  /// Fallback unknown item
  ///
  /// In en, this message translates to:
  /// **'Unknown item'**
  String get unknownItem;

  /// Not logged in status
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get notLoggedIn;

  /// Button / Tile title to open profile
  ///
  /// In en, this message translates to:
  /// **'Open Profile'**
  String get openProfileButton;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Start label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Standard weapon skin name
  ///
  /// In en, this message translates to:
  /// **'Standard {weapon}'**
  String standardWeaponSkin(String weapon);

  /// Choose skin screen title
  ///
  /// In en, this message translates to:
  /// **'Choose Skin'**
  String get chooseSkinTitle;

  /// Gun buddy title
  ///
  /// In en, this message translates to:
  /// **'Gun Buddy'**
  String get gunBuddyTitle;

  /// Choose buddy screen title
  ///
  /// In en, this message translates to:
  /// **'Choose Buddy'**
  String get chooseBuddyTitle;

  /// Title for language setting option
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// Subtitle for language setting option
  ///
  /// In en, this message translates to:
  /// **'Select app language'**
  String get languageSubtitle;

  /// Title for language selection modal
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguageTitle;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Tamil language name
  ///
  /// In en, this message translates to:
  /// **'தமிழ்'**
  String get languageTamil;

  /// Subtitle for Tamil language option
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get languageTamilSubtitle;

  /// Subtitle for English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishSubtitle;

  /// System default language option
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystemDefault;

  /// Subtitle for system default language option
  ///
  /// In en, this message translates to:
  /// **'Follow device language'**
  String get languageSystemDefaultSubtitle;

  /// Button to open the round-by-round breakdown screen from match details
  ///
  /// In en, this message translates to:
  /// **'Round-by-Round Breakdown'**
  String get roundBreakdownButton;

  /// Title of the round-by-round breakdown screen
  ///
  /// In en, this message translates to:
  /// **'Round-by-Round'**
  String get roundBreakdownTitle;

  /// Round number label
  ///
  /// In en, this message translates to:
  /// **'Round {number}'**
  String roundNumberFormat(int number);

  /// Label showing which team won a round
  ///
  /// In en, this message translates to:
  /// **'{team} won'**
  String roundWonByFormat(String team);

  /// Round end reason: all enemies eliminated
  ///
  /// In en, this message translates to:
  /// **'Elimination'**
  String get roundReasonElimination;

  /// Round end reason: spike detonated
  ///
  /// In en, this message translates to:
  /// **'Bomb Detonated'**
  String get roundReasonDetonate;

  /// Round end reason: spike defused
  ///
  /// In en, this message translates to:
  /// **'Bomb Defused'**
  String get roundReasonDefuse;

  /// Round end reason: round timer expired
  ///
  /// In en, this message translates to:
  /// **'Time Expired'**
  String get roundReasonTime;

  /// Round end reason: match surrendered
  ///
  /// In en, this message translates to:
  /// **'Surrendered'**
  String get roundReasonSurrendered;

  /// Round end reason: could not be determined
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get roundReasonUnknown;

  /// Compact kill feed entry: killer to victim with weapon
  ///
  /// In en, this message translates to:
  /// **'{killer} → {victim} ({weapon})'**
  String killFeedFormat(String killer, String victim, String weapon);

  /// Empty state shown when a round has no kill feed data
  ///
  /// In en, this message translates to:
  /// **'No kills recorded this round'**
  String get noKillsThisRound;

  /// Empty state shown when the match has no roundResults data
  ///
  /// In en, this message translates to:
  /// **'No round-by-round data available for this match'**
  String get noRoundDataAvailable;

  /// Label showing who planted the spike in a round
  ///
  /// In en, this message translates to:
  /// **'Spike planted by {player}'**
  String plantedByFormat(String player);

  /// Label showing who defused the spike in a round
  ///
  /// In en, this message translates to:
  /// **'Spike defused by {player}'**
  String defusedByFormat(String player);

  /// Settings item title for the Night Market notification toggle
  ///
  /// In en, this message translates to:
  /// **'Night Market Alerts'**
  String get nightMarketAlertSettingTitle;

  /// Settings item subtitle for the Night Market notification toggle
  ///
  /// In en, this message translates to:
  /// **'Notify me when the Night Market opens'**
  String get nightMarketAlertSettingSubtitle;

  /// Title of the local notification fired when the Night Market appears in the storefront
  ///
  /// In en, this message translates to:
  /// **'Night Market is open!'**
  String get nightMarketNotificationTitle;

  /// Body of the local notification fired when the Night Market appears in the storefront
  ///
  /// In en, this message translates to:
  /// **'The Night Market has arrived. Check out the discounted skins before it\'s gone.'**
  String get nightMarketNotificationBody;

  /// Shown on the bundle detail screen: how many of the bundle's skins the player already owns, out of the total number of skins in the bundle
  ///
  /// In en, this message translates to:
  /// **'You already own {owned}/{total} skins in this bundle'**
  String bundleSkinCoverage(int owned, int total);

  /// Title of the screen listing skins the user has wishlisted, and tooltip for the button that opens it
  ///
  /// In en, this message translates to:
  /// **'Shop Skin Wishlist'**
  String get skinWishlistTitle;

  /// Empty-state message shown on the Shop Skin Wishlist screen when nothing is wishlisted yet
  ///
  /// In en, this message translates to:
  /// **'Tap the star on a shop skin to get notified when it\'s back.'**
  String get noWishlistedSkinsYet;

  /// Title of the local notification fired when a wishlisted skin appears in the daily shop rotation
  ///
  /// In en, this message translates to:
  /// **'Wishlisted skin in today\'s shop'**
  String get wishlistSkinInShopTitle;

  /// Body of the local notification fired when a wishlisted skin appears in the daily shop rotation
  ///
  /// In en, this message translates to:
  /// **'{skinName} is available in your shop today!'**
  String wishlistSkinInShopBody(String skinName);

  /// Match details tab: overview/summary
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get matchTabSummary;

  /// Match details tab: full team scoreboard
  ///
  /// In en, this message translates to:
  /// **'Scoreboard'**
  String get matchTabScoreboard;

  /// Match details tab: round-by-round breakdown
  ///
  /// In en, this message translates to:
  /// **'Rounds'**
  String get matchTabRounds;

  /// Match details tab: head-to-head kill/death record vs each opponent
  ///
  /// In en, this message translates to:
  /// **'Duels'**
  String get matchTabDuels;

  /// Match details tab: round-by-round performance chart
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get matchTabPerformance;

  /// Match details tab: round-by-round buy/economy breakdown
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get matchTabEconomy;

  /// Section header comparing the player's stats against the lobby average
  ///
  /// In en, this message translates to:
  /// **'Lobby Comparison'**
  String get lobbyAverageHeader;

  /// Abbreviation for Average Damage per Round
  ///
  /// In en, this message translates to:
  /// **'ADR'**
  String get adr;

  /// Abbreviation for Headshot Percentage
  ///
  /// In en, this message translates to:
  /// **'HS%'**
  String get hsPercent;

  /// Abbreviation for Kill/Assist/Survive/Trade percentage
  ///
  /// In en, this message translates to:
  /// **'KAST'**
  String get kast;

  /// Abbreviation for Kill/Death ratio
  ///
  /// In en, this message translates to:
  /// **'K/D'**
  String get kdHeader;

  /// Abbreviation for First Kills per Round
  ///
  /// In en, this message translates to:
  /// **'FK/Round'**
  String get fkPerRoundHeader;

  /// Shows the lobby average value for a stat inside an accordion
  ///
  /// In en, this message translates to:
  /// **'Lobby avg: {value}'**
  String lobbyAvgFormat(String value);

  /// Shows the player's percentile rank for a stat among the 10 players in the match
  ///
  /// In en, this message translates to:
  /// **'Better than {percent}% of this lobby'**
  String betterThanPercentFormat(int percent);

  /// Section header for the attack/defense half split
  ///
  /// In en, this message translates to:
  /// **'Attack vs Defense'**
  String get halvesHeader;

  /// Label for the attacking side of a Valorant match
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get attackHalf;

  /// Label for the defending side of a Valorant match
  ///
  /// In en, this message translates to:
  /// **'Defense'**
  String get defenseHalf;

  /// Stat label: number of spike plants
  ///
  /// In en, this message translates to:
  /// **'Plants'**
  String get plantsStat;

  /// Stat label: number of spike defuses
  ///
  /// In en, this message translates to:
  /// **'Defuses'**
  String get defusesStat;

  /// Stat label: number of rounds where the player got the first kill
  ///
  /// In en, this message translates to:
  /// **'First Bloods'**
  String get firstBloodsStat;

  /// Stat label: number of rounds where the player died first
  ///
  /// In en, this message translates to:
  /// **'First Deaths'**
  String get firstDeathsStat;

  /// Section header listing clutches and multikills
  ///
  /// In en, this message translates to:
  /// **'Match Highlights'**
  String get matchHighlightsHeader;

  /// Describes a won clutch round
  ///
  /// In en, this message translates to:
  /// **'Clutch Won • 1v{enemies} • Round {round}'**
  String clutchWonFormat(int enemies, int round);

  /// Describes a lost clutch round
  ///
  /// In en, this message translates to:
  /// **'Clutch Lost • 1v{enemies} • Round {round}'**
  String clutchLostFormat(int enemies, int round);

  /// Describes a multikill round, e.g. 3K in Round 5
  ///
  /// In en, this message translates to:
  /// **'{count}K • Round {round}'**
  String multiKillFormat(int count, int round);

  /// Shown when the player had no clutches or multikills
  ///
  /// In en, this message translates to:
  /// **'No multikills or clutches this match'**
  String get noHighlightsAvailable;

  /// Section header for the duels tab
  ///
  /// In en, this message translates to:
  /// **'Head-to-Head'**
  String get duelsHeader;

  /// Subtitle explaining the duels tab
  ///
  /// In en, this message translates to:
  /// **'Your kills and deaths against each opponent'**
  String get duelsSubtitle;

  /// Net kills minus deaths against one opponent
  ///
  /// In en, this message translates to:
  /// **'Net {value}'**
  String netFormat(String value);

  /// Shown when there is no kill data to build a duels matrix
  ///
  /// In en, this message translates to:
  /// **'No duel data available for this match'**
  String get noDuelsAvailable;

  /// Section header for the performance tab
  ///
  /// In en, this message translates to:
  /// **'Round-by-Round Performance'**
  String get performanceHeader;

  /// Section header for the economy tab
  ///
  /// In en, this message translates to:
  /// **'Round Economy'**
  String get economyHeader;

  /// Header for the per-round buy-type vs win/loss chart on the round detail screen
  ///
  /// In en, this message translates to:
  /// **'Match Economy'**
  String get economyOverviewLabel;

  /// Badge label for a pistol round
  ///
  /// In en, this message translates to:
  /// **'PISTOL'**
  String get pistolRoundLabel;

  /// Label for a player's total loadout value in a round
  ///
  /// In en, this message translates to:
  /// **'Loadout'**
  String get loadoutValueLabel;

  /// Label for credits spent in a round
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentLabel;

  /// Buy-type badge for an eco (low buy) round
  ///
  /// In en, this message translates to:
  /// **'ECO'**
  String get buyTypeEco;

  /// Buy-type badge for a semi-buy round
  ///
  /// In en, this message translates to:
  /// **'SEMI'**
  String get buyTypeSemi;

  /// Buy-type badge for a bonus/force round
  ///
  /// In en, this message translates to:
  /// **'BONUS'**
  String get buyTypeBonus;

  /// Buy-type badge for a full-buy round
  ///
  /// In en, this message translates to:
  /// **'FULL'**
  String get buyTypeFull;

  /// Label for the game server/region name in the match summary card
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverLabel;

  /// Stat label: number of deaths
  ///
  /// In en, this message translates to:
  /// **'Deaths'**
  String get deathsStat;

  /// Title of the global display/metrics format settings screen
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get displaySettingsTitle;

  /// Subtitle for the display settings entry in the settings list
  ///
  /// In en, this message translates to:
  /// **'Date, time, and number format'**
  String get displaySettingsSubtitle;

  /// Section header for choosing the date format
  ///
  /// In en, this message translates to:
  /// **'Date Format'**
  String get dateFormatSectionTitle;

  /// Section header for choosing 12h vs 24h time
  ///
  /// In en, this message translates to:
  /// **'Time Format'**
  String get timeFormatSectionTitle;

  /// Section header for choosing thousands-grouped vs plain numbers
  ///
  /// In en, this message translates to:
  /// **'Number Format'**
  String get numberFormatSectionTitle;

  /// Placeholder shown for a match participant whose name Riot redacted (privacy setting) and the name-service lookup couldn't resolve either
  ///
  /// In en, this message translates to:
  /// **'Hidden Player'**
  String get hiddenPlayerName;

  /// Header for the glossary of stat abbreviations at the bottom of the Summary tab
  ///
  /// In en, this message translates to:
  /// **'What do these mean?'**
  String get statAbbreviationsHeader;

  /// Full name of the ACS abbreviation
  ///
  /// In en, this message translates to:
  /// **'Average Combat Score'**
  String get abbrAcsFull;

  /// Full name of the ADR abbreviation
  ///
  /// In en, this message translates to:
  /// **'Average Damage per Round'**
  String get abbrAdrFull;

  /// Full name of the HS% abbreviation
  ///
  /// In en, this message translates to:
  /// **'Headshot Percentage'**
  String get abbrHsFull;

  /// Full name/explanation of the KAST abbreviation
  ///
  /// In en, this message translates to:
  /// **'Kill, Assist, Survive, or Trade — % of rounds you contributed in'**
  String get abbrKastFull;

  /// Full name of the K/D abbreviation
  ///
  /// In en, this message translates to:
  /// **'Kill / Death Ratio'**
  String get abbrKdFull;

  /// Full name of the FK/Round abbreviation
  ///
  /// In en, this message translates to:
  /// **'First Kills per Round'**
  String get abbrFkFull;

  /// Button label to open a player's profile
  ///
  /// In en, this message translates to:
  /// **'Open Profile'**
  String get openProfileAction;

  /// Label for the viewer's own team in the scoreboard
  ///
  /// In en, this message translates to:
  /// **'My Team'**
  String get myTeamLabel;

  /// Label for the opposing team in the scoreboard
  ///
  /// In en, this message translates to:
  /// **'Enemy Team'**
  String get enemyTeamLabel;

  /// Label for the scoreboard sort dropdown
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortByLabel;

  /// Label for the dropdown that changes which player's stats are highlighted across tabs
  ///
  /// In en, this message translates to:
  /// **'Focused player'**
  String get focusedPlayerLabel;

  /// Header for the pair of players with the most kills exchanged between them
  ///
  /// In en, this message translates to:
  /// **'Top Rivalry'**
  String get topRivalryHeader;

  /// Header for the pair of players with the most lopsided kill record between them
  ///
  /// In en, this message translates to:
  /// **'Biggest Mismatch'**
  String get biggestMismatchHeader;

  /// Header for the full head-to-head duel list
  ///
  /// In en, this message translates to:
  /// **'All Duels'**
  String get allDuelsHeader;

  /// Header for the mirrored kills-per-round chart in the Rounds tab
  ///
  /// In en, this message translates to:
  /// **'Kills per Round'**
  String get roundsOverviewHeader;

  /// Title of the full-screen round details page
  ///
  /// In en, this message translates to:
  /// **'Round Details'**
  String get roundDetailsTitle;

  /// Header showing which round is being viewed out of the total
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String roundOfTotalFormat(int round, int total);

  /// Describes when and who planted the spike in round details
  ///
  /// In en, this message translates to:
  /// **'{player} planted at {time}'**
  String plantedAtFormat(String player, String time);

  /// Describes when and who defused the spike in round details
  ///
  /// In en, this message translates to:
  /// **'{player} defused at {time}'**
  String defusedAtFormat(String player, String time);

  /// Describes when the spike detonated in round details
  ///
  /// In en, this message translates to:
  /// **'Spike exploded at {time}'**
  String explodedAtFormat(String time);

  /// Shown on the round details map when the spike was never planted this round
  ///
  /// In en, this message translates to:
  /// **'Spike not planted'**
  String get spikeNotPlanted;

  /// Shown below the round timeline when no event is selected, counting kills/plant/defuse/explosion
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String roundEventCountFormat(int count);

  /// Compact chip label for a multikill round, e.g. 3K
  ///
  /// In en, this message translates to:
  /// **'{count}K'**
  String multiKillChipFormat(int count);

  /// Compact chip label for a won clutch round
  ///
  /// In en, this message translates to:
  /// **'1v{enemies} W'**
  String clutchChipWonFormat(int enemies);

  /// Compact chip label for a lost clutch round
  ///
  /// In en, this message translates to:
  /// **'1v{enemies} L'**
  String clutchChipLostFormat(int enemies);

  /// Shown in the scoreboard accordion when a player had no multikill/clutch highlights
  ///
  /// In en, this message translates to:
  /// **'No multikills or clutches'**
  String get noChipsAvailable;

  /// Shown for a player with no competitive rank
  ///
  /// In en, this message translates to:
  /// **'Unrated'**
  String get unrated;

  /// Tooltip for the app bar action that opens the auto loadout rule tester
  ///
  /// In en, this message translates to:
  /// **'Test Rules'**
  String get autoLoadoutTestRulesTooltip;

  /// Title of the auto loadout rule tester dialog
  ///
  /// In en, this message translates to:
  /// **'Test Auto Loadout Rules'**
  String get autoLoadoutTestRulesTitle;

  /// Description in the auto loadout rule tester dialog
  ///
  /// In en, this message translates to:
  /// **'Pick a map and/or agent to preview which rule would auto-apply.'**
  String get autoLoadoutTestRulesDescription;

  /// Snackbar shown when there are no rules to test
  ///
  /// In en, this message translates to:
  /// **'Create at least one map or agent rule first to test it.'**
  String get autoLoadoutTestRulesEmpty;

  /// Label for the agent dropdown in the rule tester dialog
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get autoLoadoutTestRulesAgentLabel;

  /// Label for the map dropdown in the rule tester dialog
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get autoLoadoutTestRulesMapLabel;

  /// Option to select no map/agent in the rule tester dialog
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get autoLoadoutTestRulesNone;

  /// Result shown when a rule matches in the tester dialog
  ///
  /// In en, this message translates to:
  /// **'Would apply \"{presetName}\" ({targetName})'**
  String autoLoadoutTestRulesResultMatch(String presetName, String targetName);

  /// Result shown when no rule matches in the tester dialog
  ///
  /// In en, this message translates to:
  /// **'No enabled rule matches this combination.'**
  String get autoLoadoutTestRulesResultNoMatch;

  /// Close button in the rule tester dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get autoLoadoutTestRulesClose;

  /// Title for the conflict-resolution preference control on the Auto Loadouts screen
  ///
  /// In en, this message translates to:
  /// **'When Map and Agent rules disagree'**
  String get autoLoadoutConflictPreferenceTitle;

  /// Subtitle explaining the conflict-resolution preference control
  ///
  /// In en, this message translates to:
  /// **'Choose which rule wins automatically, or keep being asked each match'**
  String get autoLoadoutConflictPreferenceSubtitle;

  /// Conflict preference option: show the picker every time
  ///
  /// In en, this message translates to:
  /// **'Ask me'**
  String get autoLoadoutConflictPreferenceAsk;

  /// Conflict preference option: the Agent rule always wins
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get autoLoadoutConflictPreferenceAgent;

  /// Conflict preference option: the Map rule always wins
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get autoLoadoutConflictPreferenceMap;

  /// Collapsed summary line when the conflict preference is set to ask every time
  ///
  /// In en, this message translates to:
  /// **'Ask me each match'**
  String get autoLoadoutConflictPreferenceSummaryAsk;

  /// Collapsed summary line when the conflict preference is set to always prefer the Agent rule
  ///
  /// In en, this message translates to:
  /// **'Agent rule always wins'**
  String get autoLoadoutConflictPreferenceSummaryAgent;

  /// Collapsed summary line when the conflict preference is set to always prefer the Map rule
  ///
  /// In en, this message translates to:
  /// **'Map rule always wins'**
  String get autoLoadoutConflictPreferenceSummaryMap;

  /// Result shown in the rule tester when both an Agent and a Map rule match but disagree, and the conflict preference is set to ask
  ///
  /// In en, this message translates to:
  /// **'Two rules match — you\'d be asked to pick between \"{agentPresetName}\" ({agentTargetName}) and \"{mapPresetName}\" ({mapTargetName}).'**
  String autoLoadoutTestRulesResultConflictAsk(
    String agentPresetName,
    String agentTargetName,
    String mapPresetName,
    String mapTargetName,
  );

  /// Title of the preview shown before an imported preset code is saved
  ///
  /// In en, this message translates to:
  /// **'Confirm Import'**
  String get importPresetPreviewTitle;

  /// Subtitle explaining the imported preset preview lets the user check contents before confirming
  ///
  /// In en, this message translates to:
  /// **'Review the weapons and skins in this shared preset before adding it to your saved presets'**
  String get importPresetPreviewSubtitle;

  /// Button to discard an imported preset code without saving it
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get importPresetCancel;

  /// Button to confirm saving the previewed imported preset
  ///
  /// In en, this message translates to:
  /// **'Import Preset'**
  String get importPresetConfirm;

  /// Section header for skins seen before but absent from the shop for a while
  ///
  /// In en, this message translates to:
  /// **'Not Seen Recently'**
  String get shopHistoryNotSeenRecentlyHeader;

  /// Section subtitle explaining the not-seen-recently list
  ///
  /// In en, this message translates to:
  /// **'Skins from your history that haven\'t shown up lately'**
  String get shopHistoryNotSeenRecentlySubtitle;

  /// Badge showing how many days since a skin last appeared in the shop
  ///
  /// In en, this message translates to:
  /// **'Last seen {count}d ago'**
  String shopHistoryLastSeenDaysAgo(int count);

  /// Title for the profile tile that opens the collection value screen
  ///
  /// In en, this message translates to:
  /// **'Collection Value'**
  String get collectionValueTileTitle;

  /// Subtitle for the profile tile that opens the collection value screen
  ///
  /// In en, this message translates to:
  /// **'See your collection\'s net worth'**
  String get collectionValueTileSubtitle;

  /// App bar title for the collection value screen
  ///
  /// In en, this message translates to:
  /// **'Collection Value'**
  String get collectionValueScreenTitle;

  /// Label above the total VP value of the player's collection
  ///
  /// In en, this message translates to:
  /// **'Collection Net Worth'**
  String get collectionValueTotalLabel;

  /// Shows how many unique skins the player owns
  ///
  /// In en, this message translates to:
  /// **'{count} skins owned'**
  String collectionValueSkinsOwnedLabel(int count);

  /// Badge shown on a daily shop tile for a skin with no prior recorded appearance in the local shop rotation history
  ///
  /// In en, this message translates to:
  /// **'New!'**
  String get shopHistoryNewBadge;

  /// Section title for the per-rarity breakdown of the collection
  ///
  /// In en, this message translates to:
  /// **'Rarity Breakdown'**
  String get collectionValueBreakdownTitle;

  /// Title shown when the player owns no tracked skins
  ///
  /// In en, this message translates to:
  /// **'No Skins Found'**
  String get collectionValueEmptyTitle;

  /// Message shown when the player owns no tracked skins
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find any owned skins to value yet. Try again after your inventory has synced.'**
  String get collectionValueEmptyMessage;

  /// Error message shown when computing collection value fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t compute your collection value: {error}'**
  String collectionValueErrorMessage(String error);

  /// Retry button label for the collection value screen
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get collectionValueRetry;

  /// Fallback name for the Select content tier
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get collectionValueTierSelect;

  /// Fallback name for the Deluxe content tier
  ///
  /// In en, this message translates to:
  /// **'Deluxe'**
  String get collectionValueTierDeluxe;

  /// Fallback name for the Premium content tier
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get collectionValueTierPremium;

  /// Fallback name for the Ultra content tier
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get collectionValueTierUltra;

  /// Fallback name for the Exclusive content tier
  ///
  /// In en, this message translates to:
  /// **'Exclusive'**
  String get collectionValueTierExclusive;

  /// Shows owned count multiplied by unit price for a rarity row
  ///
  /// In en, this message translates to:
  /// **'{count} × {value} VP'**
  String collectionValueCountAndValue(int count, int value);

  /// Disclaimer explaining how collection value is estimated
  ///
  /// In en, this message translates to:
  /// **'Estimated using each skin\'s standard rarity price. Actual resale is not possible in VALORANT.'**
  String get collectionValueDisclaimer;

  /// Title for the Hub tile that opens the competitive leaderboard screen
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTileTitle;

  /// Subtitle for the Hub tile that opens the competitive leaderboard screen
  ///
  /// In en, this message translates to:
  /// **'See the top-ranked players this act'**
  String get leaderboardTileSubtitle;

  /// App bar title for the leaderboard screen
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// Shows the total number of ranked players on the leaderboard
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String leaderboardTotalPlayers(int count);

  /// Shows a leaderboard player's win count
  ///
  /// In en, this message translates to:
  /// **'{count} wins'**
  String leaderboardWinsFormat(int count);

  /// Shows a leaderboard player's Rank Rating
  ///
  /// In en, this message translates to:
  /// **'{rr} RR'**
  String leaderboardRrFormat(int rr);

  /// Shown when there's no active competitive act or its leaderboard hasn't been published yet
  ///
  /// In en, this message translates to:
  /// **'No leaderboard is available for the current act yet.'**
  String get leaderboardNoActiveAct;

  /// Shown when the leaderboard fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the leaderboard. Check your connection and try again.'**
  String get leaderboardLoadFailed;

  /// Tooltip for the button that resets leaderboard filters to the account's own region and the current act
  ///
  /// In en, this message translates to:
  /// **'Reset to my region & season'**
  String get leaderboardResetFilters;

  /// Placeholder for the leaderboard player name search field
  ///
  /// In en, this message translates to:
  /// **'Search a player…'**
  String get leaderboardSearchHint;

  /// Label for the leaderboard region/shard filter dropdown
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get leaderboardRegionLabel;

  /// Label for the leaderboard season/act filter dropdown
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get leaderboardSeasonLabel;

  /// Hint shown in the season dropdown before a specific act is chosen, meaning the currently active act
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get leaderboardCurrentSeason;

  /// Title for the profile tile that opens the Career Stats screen
  ///
  /// In en, this message translates to:
  /// **'Career Stats'**
  String get careerStatsTileTitle;

  /// Subtitle for the profile tile that opens the Career Stats screen
  ///
  /// In en, this message translates to:
  /// **'Overall stats, act-wise summary, and competitive record'**
  String get careerStatsTileSubtitle;

  /// App bar title for the Career Stats screen
  ///
  /// In en, this message translates to:
  /// **'Career Stats'**
  String get careerStatsTitle;

  /// Tab label for the Overall Player Statistics view
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get careerStatsTabOverall;

  /// Tab label for the act-wise Career Summary view
  ///
  /// In en, this message translates to:
  /// **'Career Summary'**
  String get careerStatsTabSummary;

  /// Tab label for the all-time competitive totals view
  ///
  /// In en, this message translates to:
  /// **'All-Time Competitive'**
  String get careerStatsTabCompetitive;

  /// Title shown when no matches were found to build Career Stats from
  ///
  /// In en, this message translates to:
  /// **'No Match History Yet'**
  String get careerStatsEmptyTitle;

  /// Message shown when no matches were found to build Career Stats from
  ///
  /// In en, this message translates to:
  /// **'Play a few matches and check back — Career Stats builds itself from your recent match history.'**
  String get careerStatsEmptyMessage;

  /// Shows how many recent matches Career Stats was computed from
  ///
  /// In en, this message translates to:
  /// **'Based on your last {count} matches'**
  String careerStatsSampleSize(int count);

  /// Label for headshot percentage stat
  ///
  /// In en, this message translates to:
  /// **'HS%'**
  String get careerStatsHeadshotPercent;

  /// Formatted total playtime, e.g. 12h 34m
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String careerStatsPlaytimeFormat(int hours, int minutes);

  /// Section title for current/peak rank on the Overall Stats view
  ///
  /// In en, this message translates to:
  /// **'Rank Rating'**
  String get careerStatsRankSectionTitle;

  /// Label for the player's current competitive rank
  ///
  /// In en, this message translates to:
  /// **'Current Rank'**
  String get careerStatsCurrentRank;

  /// Label for the player's peak competitive rank
  ///
  /// In en, this message translates to:
  /// **'Peak Rank'**
  String get careerStatsPeakRank;

  /// Section title for the win/loss/draw record on the Overall Stats view
  ///
  /// In en, this message translates to:
  /// **'Overall Record'**
  String get careerStatsRecordTitle;

  /// Win-loss-draw record summary
  ///
  /// In en, this message translates to:
  /// **'{wins}W - {losses}L - {draws}D'**
  String careerStatsRecordFormat(int wins, int losses, int draws);

  /// Empty state for the Career Summary and All-Time Competitive tabs when no ranked matches were found
  ///
  /// In en, this message translates to:
  /// **'No competitive matches found in your recent history yet.'**
  String get careerStatsNoCompetitiveActs;

  /// Label for a wins-out-of-games stat
  ///
  /// In en, this message translates to:
  /// **'Wins/Games'**
  String get careerStatsWinsGames;

  /// Wins out of total games played, e.g. 12/20
  ///
  /// In en, this message translates to:
  /// **'{wins}/{games}'**
  String careerStatsWinsGamesFormat(int wins, int games);

  /// Title for the combined all-time competitive stats card
  ///
  /// In en, this message translates to:
  /// **'All-Time Competitive Record'**
  String get careerStatsAllTimeCompetitiveTitle;

  /// Title of the account XP/level card on the profile screen
  ///
  /// In en, this message translates to:
  /// **'Account Level'**
  String get accountXpCardTitle;

  /// Current XP over XP needed for next level
  ///
  /// In en, this message translates to:
  /// **'{xp} / {xpNeeded} XP'**
  String accountXpProgressLabel(int xp, int xpNeeded);

  /// XP remaining until the next level
  ///
  /// In en, this message translates to:
  /// **'{xp} XP to next level'**
  String accountXpRemainingLabel(int xp);

  /// Header for the recent XP-grant history list
  ///
  /// In en, this message translates to:
  /// **'Recent XP Earned'**
  String get accountXpRecentTitle;

  /// Shown when there is no recent XP-grant history to display
  ///
  /// In en, this message translates to:
  /// **'No recent XP activity'**
  String get accountXpEmptyHistory;

  /// Friendly label for a match-completion XP grant
  ///
  /// In en, this message translates to:
  /// **'Match Completion'**
  String get accountXpSourceMatchCompletion;

  /// Friendly label for a first-win-of-the-day XP bonus grant
  ///
  /// In en, this message translates to:
  /// **'First Win of the Day'**
  String get accountXpSourceFirstWin;

  /// Fallback relative time label when a grant has no known timestamp
  ///
  /// In en, this message translates to:
  /// **'Recently'**
  String get accountXpTimeUnknown;

  /// Title of the full battlepass tier browser screen
  ///
  /// In en, this message translates to:
  /// **'Battlepass'**
  String get battlepassScreenTitle;

  /// Button label to open the full battlepass tier browser
  ///
  /// In en, this message translates to:
  /// **'View All Tiers'**
  String get battlepassViewAllTiers;

  /// Label for a battlepass tier's number
  ///
  /// In en, this message translates to:
  /// **'Tier {number}'**
  String battlepassTierNumber(int number);

  /// Label for the free reward track of a battlepass tier
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get battlepassFreeTrack;

  /// Label for the premium reward track of a battlepass tier
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get battlepassPremiumTrack;

  /// State label for an unlocked battlepass tier
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get battlepassUnlocked;

  /// State label for a locked battlepass tier
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get battlepassLocked;

  /// State label for a premium reward not available because the account doesn't own the premium pass
  ///
  /// In en, this message translates to:
  /// **'Premium Not Owned'**
  String get battlepassPremiumLocked;

  /// Shown when the battlepass provider has no data to display
  ///
  /// In en, this message translates to:
  /// **'No battlepass data available currently.'**
  String get battlepassNoDataAvailable;

  /// Label for a battlepass chapter section header
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String battlepassChapterLabel(int number);

  /// Label for the epilogue chapter section header
  ///
  /// In en, this message translates to:
  /// **'Epilogue'**
  String get battlepassEpilogueLabel;

  /// Screen title for the bookmarked players list
  ///
  /// In en, this message translates to:
  /// **'Bookmarked Players'**
  String get bookmarkedPlayersTitle;

  /// Section header on the search screen
  ///
  /// In en, this message translates to:
  /// **'Bookmarked Players'**
  String get bookmarkedPlayersHeader;

  /// Empty state message for bookmarked players
  ///
  /// In en, this message translates to:
  /// **'No bookmarked players yet.\nSearch a player and tap the star to bookmark them here.'**
  String get bookmarkedPlayersEmptyPrompt;

  /// Button label to view the full list
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAllButton;

  /// Tooltip for the add-bookmark star button
  ///
  /// In en, this message translates to:
  /// **'Bookmark this player'**
  String get addBookmarkTooltip;

  /// Tooltip for the remove-bookmark star button
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmarkTooltip;

  /// Shown on a friend's row when their gamertag has changed
  ///
  /// In en, this message translates to:
  /// **'formerly {name}'**
  String formerlyKnownAs(String name);

  /// Title of the Game Info encyclopedia hub screen
  ///
  /// In en, this message translates to:
  /// **'Game Info'**
  String get gameInfoHubTitle;

  /// Title for the Maps section of Game Info
  ///
  /// In en, this message translates to:
  /// **'Maps'**
  String get gameInfoMapsTitle;

  /// Subtitle for the Maps hub tile
  ///
  /// In en, this message translates to:
  /// **'Splash art, callouts and minimaps'**
  String get gameInfoMapsSubtitle;

  /// Title for the Agents section of Game Info
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get gameInfoAgentsTitle;

  /// Subtitle for the Agents hub tile
  ///
  /// In en, this message translates to:
  /// **'Roles, abilities and portraits'**
  String get gameInfoAgentsSubtitle;

  /// Title for the Weapons section of Game Info
  ///
  /// In en, this message translates to:
  /// **'Weapons'**
  String get gameInfoWeaponsTitle;

  /// Subtitle for the Weapons hub tile
  ///
  /// In en, this message translates to:
  /// **'Prices, skins and full stat sheets'**
  String get gameInfoWeaponsSubtitle;

  /// Generic error shown when Game Info static data fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load data. Please try again.'**
  String get gameInfoLoadError;

  /// Number of callouts on a map
  ///
  /// In en, this message translates to:
  /// **'{count} callouts'**
  String gameInfoCalloutCount(int count);

  /// Header above the list of map callouts
  ///
  /// In en, this message translates to:
  /// **'Callouts'**
  String get gameInfoCalloutsHeader;

  /// Header above an agent's list of abilities
  ///
  /// In en, this message translates to:
  /// **'Abilities'**
  String get gameInfoAbilitiesHeader;

  /// Weapon list subtitle showing shop price and skin count
  ///
  /// In en, this message translates to:
  /// **'{cost} VP • {skinCount} skins'**
  String gameInfoWeaponPriceSkins(int cost, int skinCount);

  /// Weapon list subtitle showing only the skin count (no shop price)
  ///
  /// In en, this message translates to:
  /// **'{skinCount} skins'**
  String gameInfoWeaponSkinsOnly(int skinCount);

  /// Header above a weapon's full stat sheet
  ///
  /// In en, this message translates to:
  /// **'Stat sheet'**
  String get gameInfoStatSheetHeader;

  /// Shown when a weapon has no weaponStats data
  ///
  /// In en, this message translates to:
  /// **'No stats available for this weapon.'**
  String get gameInfoNoStatsAvailable;

  /// Weapon VP shop price chip
  ///
  /// In en, this message translates to:
  /// **'{cost} VP'**
  String gameInfoVpPrice(int cost);

  /// Weapon skin count chip
  ///
  /// In en, this message translates to:
  /// **'{skinCount} skins'**
  String gameInfoSkinCount(int skinCount);

  /// Weapon stat label: fire rate
  ///
  /// In en, this message translates to:
  /// **'Fire rate'**
  String get gameInfoStatFireRate;

  /// Weapon stat label: magazine size
  ///
  /// In en, this message translates to:
  /// **'Magazine size'**
  String get gameInfoStatMagazineSize;

  /// Weapon stat label: equip time
  ///
  /// In en, this message translates to:
  /// **'Equip time'**
  String get gameInfoStatEquipTime;

  /// Weapon stat label: reload time
  ///
  /// In en, this message translates to:
  /// **'Reload time'**
  String get gameInfoStatReloadTime;

  /// Weapon stat label: first bullet accuracy
  ///
  /// In en, this message translates to:
  /// **'First shot spread'**
  String get gameInfoStatFirstShotAccuracy;

  /// Weapon stat label: run speed multiplier
  ///
  /// In en, this message translates to:
  /// **'Run speed'**
  String get gameInfoStatRunSpeed;

  /// Weapon stat label: aim-down-sights walk speed multiplier
  ///
  /// In en, this message translates to:
  /// **'ADS walk speed'**
  String get gameInfoStatWalkSpeed;

  /// Weapon stat label: wall penetration rating
  ///
  /// In en, this message translates to:
  /// **'Wall penetration'**
  String get gameInfoStatWallPenetration;

  /// Header above the weapon damage-by-range table
  ///
  /// In en, this message translates to:
  /// **'Damage ranges'**
  String get gameInfoDamageRangesHeader;

  /// Damage range table column: distance range
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get gameInfoStatRange;

  /// Damage range table column: head damage
  ///
  /// In en, this message translates to:
  /// **'Head'**
  String get gameInfoStatHeadDamage;

  /// Damage range table column: body damage
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get gameInfoStatBodyDamage;

  /// Damage range table column: leg damage
  ///
  /// In en, this message translates to:
  /// **'Leg'**
  String get gameInfoStatLegDamage;
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
      <String>['en', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
