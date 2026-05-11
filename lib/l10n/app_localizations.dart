import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'RFBrowser'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @browser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get browser;

  /// No description provided for @editor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editor;

  /// No description provided for @graph.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get graph;

  /// No description provided for @canvas.
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get canvas;

  /// No description provided for @aiChat.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get aiChat;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @plugins.
  ///
  /// In en, this message translates to:
  /// **'Plugins'**
  String get plugins;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get newNote;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New Tab'**
  String get newTab;

  /// No description provided for @closeTab.
  ///
  /// In en, this message translates to:
  /// **'Close Tab'**
  String get closeTab;

  /// No description provided for @closeAllTabs.
  ///
  /// In en, this message translates to:
  /// **'Close All Tabs'**
  String get closeAllTabs;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @backlinks.
  ///
  /// In en, this message translates to:
  /// **'Backlinks'**
  String get backlinks;

  /// No description provided for @outline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get outline;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @untagged.
  ///
  /// In en, this message translates to:
  /// **'Untagged'**
  String get untagged;

  /// No description provided for @dailyNotes.
  ///
  /// In en, this message translates to:
  /// **'Daily Notes'**
  String get dailyNotes;

  /// No description provided for @clippings.
  ///
  /// In en, this message translates to:
  /// **'Clippings'**
  String get clippings;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @skills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// No description provided for @agent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @gitSync.
  ///
  /// In en, this message translates to:
  /// **'Git Sync'**
  String get gitSync;

  /// No description provided for @webdavSync.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get webdavSync;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @toggleDarkLight.
  ///
  /// In en, this message translates to:
  /// **'Toggle dark/light theme'**
  String get toggleDarkLight;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accentColor;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get themeColor;

  /// No description provided for @backgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get backgroundColor;

  /// No description provided for @surfaceColor.
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get surfaceColor;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @themeTintOpacity.
  ///
  /// In en, this message translates to:
  /// **'Theme Tint Intensity'**
  String get themeTintOpacity;

  /// No description provided for @surfaceOpacity.
  ///
  /// In en, this message translates to:
  /// **'Surface Opacity'**
  String get surfaceOpacity;

  /// No description provided for @backgroundOpacity.
  ///
  /// In en, this message translates to:
  /// **'Background Opacity'**
  String get backgroundOpacity;

  /// No description provided for @components.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get components;

  /// No description provided for @buttonShape.
  ///
  /// In en, this message translates to:
  /// **'Button Shape'**
  String get buttonShape;

  /// No description provided for @rounded.
  ///
  /// In en, this message translates to:
  /// **'Rounded'**
  String get rounded;

  /// No description provided for @sharp.
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get sharp;

  /// No description provided for @pill.
  ///
  /// In en, this message translates to:
  /// **'Pill'**
  String get pill;

  /// No description provided for @cornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner Radius'**
  String get cornerRadius;

  /// No description provided for @density.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get density;

  /// No description provided for @compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compact;

  /// No description provided for @comfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortable;

  /// No description provided for @spacious.
  ///
  /// In en, this message translates to:
  /// **'Spacious'**
  String get spacious;

  /// No description provided for @iconSize.
  ///
  /// In en, this message translates to:
  /// **'Icon Size'**
  String get iconSize;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @filled.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get filled;

  /// No description provided for @outlined.
  ///
  /// In en, this message translates to:
  /// **'Outlined'**
  String get outlined;

  /// No description provided for @aiModels.
  ///
  /// In en, this message translates to:
  /// **'AI Models'**
  String get aiModels;

  /// No description provided for @openaiApiKey.
  ///
  /// In en, this message translates to:
  /// **'OpenAI API Key'**
  String get openaiApiKey;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @activeModel.
  ///
  /// In en, this message translates to:
  /// **'Active Model'**
  String get activeModel;

  /// No description provided for @localModelOllama.
  ///
  /// In en, this message translates to:
  /// **'Local Model (Ollama)'**
  String get localModelOllama;

  /// No description provided for @configureLocalModel.
  ///
  /// In en, this message translates to:
  /// **'Configure local model endpoint'**
  String get configureLocalModel;

  /// No description provided for @ollamaEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Ollama Endpoint'**
  String get ollamaEndpoint;

  /// No description provided for @ollamaHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure Ollama is running locally before using local models.'**
  String get ollamaHint;

  /// No description provided for @editorSection.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editorSection;

  /// No description provided for @syncSection.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncSection;

  /// No description provided for @configureGitRemote.
  ///
  /// In en, this message translates to:
  /// **'Configure Git remote for vault sync'**
  String get configureGitRemote;

  /// No description provided for @configureWebdav.
  ///
  /// In en, this message translates to:
  /// **'Configure WebDAV server for vault sync'**
  String get configureWebdav;

  /// No description provided for @remoteUrl.
  ///
  /// In en, this message translates to:
  /// **'Remote URL'**
  String get remoteUrl;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @versionInfo.
  ///
  /// In en, this message translates to:
  /// **'v0.2.0 - AI-Powered Knowledge Browser'**
  String get versionInfo;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @selectModel.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get selectModel;

  /// No description provided for @componentDensity.
  ///
  /// In en, this message translates to:
  /// **'Component Density'**
  String get componentDensity;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @customAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Accent Color'**
  String get customAccentColor;

  /// No description provided for @noVaultConnected.
  ///
  /// In en, this message translates to:
  /// **'No Vault Connected'**
  String get noVaultConnected;

  /// No description provided for @openVaultToStart.
  ///
  /// In en, this message translates to:
  /// **'Open a vault to start writing notes'**
  String get openVaultToStart;

  /// No description provided for @noNoteSelected.
  ///
  /// In en, this message translates to:
  /// **'No note selected'**
  String get noNoteSelected;

  /// No description provided for @createOrSelectNote.
  ///
  /// In en, this message translates to:
  /// **'Create a new note or select one from the sidebar'**
  String get createOrSelectNote;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @startWriting.
  ///
  /// In en, this message translates to:
  /// **'Start writing...'**
  String get startWriting;

  /// No description provided for @splitRight.
  ///
  /// In en, this message translates to:
  /// **'Split Right'**
  String get splitRight;

  /// No description provided for @splitLeft.
  ///
  /// In en, this message translates to:
  /// **'Split Left'**
  String get splitLeft;

  /// No description provided for @splitUp.
  ///
  /// In en, this message translates to:
  /// **'Split Up'**
  String get splitUp;

  /// No description provided for @splitDown.
  ///
  /// In en, this message translates to:
  /// **'Split Down'**
  String get splitDown;

  /// No description provided for @changeView.
  ///
  /// In en, this message translates to:
  /// **'Change View'**
  String get changeView;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @changeViewTitle.
  ///
  /// In en, this message translates to:
  /// **'Open View'**
  String get changeViewTitle;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @tabs.
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get tabs;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @noVault.
  ///
  /// In en, this message translates to:
  /// **'No Vault'**
  String get noVault;

  /// No description provided for @notesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String notesCount(int count);

  /// No description provided for @tabsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tabs'**
  String tabsCount(int count);

  /// No description provided for @clearChat.
  ///
  /// In en, this message translates to:
  /// **'Clear Chat'**
  String get clearChat;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @askAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask anything... (Ctrl+K)'**
  String get askAnything;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @vault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vault;

  /// No description provided for @openVault.
  ///
  /// In en, this message translates to:
  /// **'Open Vault'**
  String get openVault;

  /// No description provided for @createVault.
  ///
  /// In en, this message translates to:
  /// **'Create Vault'**
  String get createVault;

  /// No description provided for @selectVault.
  ///
  /// In en, this message translates to:
  /// **'Select Vault Location'**
  String get selectVault;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to RFBrowser'**
  String get welcome;

  /// No description provided for @welcomeDesc.
  ///
  /// In en, this message translates to:
  /// **'Open an existing vault or create a new one to get started.'**
  String get welcomeDesc;

  /// No description provided for @recentVaults.
  ///
  /// In en, this message translates to:
  /// **'Recent Vaults'**
  String get recentVaults;

  /// No description provided for @tabGroups.
  ///
  /// In en, this message translates to:
  /// **'Tab Groups'**
  String get tabGroups;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroup;

  /// No description provided for @ungrouped.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get ungrouped;

  /// No description provided for @clipPage.
  ///
  /// In en, this message translates to:
  /// **'Clip Page'**
  String get clipPage;

  /// No description provided for @clipSelection.
  ///
  /// In en, this message translates to:
  /// **'Clip Selection'**
  String get clipSelection;

  /// No description provided for @clipBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get clipBookmark;

  /// No description provided for @commandBar.
  ///
  /// In en, this message translates to:
  /// **'Command Bar'**
  String get commandBar;

  /// No description provided for @runCommand.
  ///
  /// In en, this message translates to:
  /// **'Run Command'**
  String get runCommand;

  /// No description provided for @noBacklinks.
  ///
  /// In en, this message translates to:
  /// **'No backlinks yet'**
  String get noBacklinks;

  /// No description provided for @noOutline.
  ///
  /// In en, this message translates to:
  /// **'No outline available'**
  String get noOutline;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get noteSaved;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// No description provided for @vaultOpened.
  ///
  /// In en, this message translates to:
  /// **'Vault opened'**
  String get vaultOpened;

  /// No description provided for @syncComplete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get syncComplete;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @agentRunning.
  ///
  /// In en, this message translates to:
  /// **'Agent running...'**
  String get agentRunning;

  /// No description provided for @agentCompleted.
  ///
  /// In en, this message translates to:
  /// **'Agent task completed'**
  String get agentCompleted;

  /// No description provided for @agentFailed.
  ///
  /// In en, this message translates to:
  /// **'Agent task failed'**
  String get agentFailed;

  /// No description provided for @newNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get newNoteTitle;

  /// No description provided for @noteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note title'**
  String get noteTitle;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @comingInPhase4.
  ///
  /// In en, this message translates to:
  /// **'Coming in Phase 4'**
  String get comingInPhase4;

  /// No description provided for @gitSyncConfig.
  ///
  /// In en, this message translates to:
  /// **'Git Sync Configuration'**
  String get gitSyncConfig;

  /// No description provided for @webdavConfig.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Configuration'**
  String get webdavConfig;

  /// No description provided for @providers.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get providers;

  /// No description provided for @addProvider.
  ///
  /// In en, this message translates to:
  /// **'Add Provider'**
  String get addProvider;

  /// No description provided for @providerName.
  ///
  /// In en, this message translates to:
  /// **'Provider Name'**
  String get providerName;

  /// No description provided for @providerNameHint.
  ///
  /// In en, this message translates to:
  /// **'My OpenAI, Work Azure, etc.'**
  String get providerNameHint;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @baseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @leaveEmptyToKeep.
  ///
  /// In en, this message translates to:
  /// **'leave empty to keep current'**
  String get leaveEmptyToKeep;

  /// No description provided for @editProvider.
  ///
  /// In en, this message translates to:
  /// **'Edit Provider'**
  String get editProvider;

  /// No description provided for @deleteProvider.
  ///
  /// In en, this message translates to:
  /// **'Delete Provider'**
  String get deleteProvider;

  /// No description provided for @deleteProviderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete provider and all its models?'**
  String get deleteProviderConfirm;

  /// No description provided for @addCustomModel.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Model'**
  String get addCustomModel;

  /// No description provided for @modelId.
  ///
  /// In en, this message translates to:
  /// **'Model ID'**
  String get modelId;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'My Custom Model'**
  String get displayNameHint;

  /// No description provided for @refreshModels.
  ///
  /// In en, this message translates to:
  /// **'Refresh Models'**
  String get refreshModels;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noProvidersHint.
  ///
  /// In en, this message translates to:
  /// **'No providers configured. Add one to get started.'**
  String get noProvidersHint;

  /// No description provided for @noModelsFound.
  ///
  /// In en, this message translates to:
  /// **'No models found'**
  String get noModelsFound;

  /// No description provided for @modelsRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get modelsRefreshed;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Knowledge Browser'**
  String get appSubtitle;

  /// No description provided for @removeVault.
  ///
  /// In en, this message translates to:
  /// **'Remove Vault'**
  String get removeVault;

  /// No description provided for @removeVaultConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from recent vaults?'**
  String removeVaultConfirm(String name);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @alwaysShowWelcomePage.
  ///
  /// In en, this message translates to:
  /// **'Always Show Welcome Page'**
  String get alwaysShowWelcomePage;

  /// No description provided for @alwaysShowWelcomePageDesc.
  ///
  /// In en, this message translates to:
  /// **'Show the welcome page on every launch instead of opening the last vault directly'**
  String get alwaysShowWelcomePageDesc;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get shortcuts;

  /// No description provided for @pressNewShortcut.
  ///
  /// In en, this message translates to:
  /// **'Press new shortcut...'**
  String get pressNewShortcut;

  /// No description provided for @resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetToDefaults;

  /// No description provided for @shortcutsReset.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts reset to defaults'**
  String get shortcutsReset;

  /// No description provided for @shortcutConflict.
  ///
  /// In en, this message translates to:
  /// **'Shortcut conflict'**
  String get shortcutConflict;

  /// No description provided for @shortcutConflictMsg.
  ///
  /// In en, this message translates to:
  /// **'\"{shortcut}\" is already bound to \"{action}\"'**
  String shortcutConflictMsg(String shortcut, String action);

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @aiDegradedToLocal.
  ///
  /// In en, this message translates to:
  /// **'AI switched to local model (offline)'**
  String get aiDegradedToLocal;

  /// No description provided for @noLocalModel.
  ///
  /// In en, this message translates to:
  /// **'No local model available for offline use'**
  String get noLocalModel;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count} changes pending sync'**
  String syncPending(int count);

  /// No description provided for @dragDropHint.
  ///
  /// In en, this message translates to:
  /// **'Drag text or notes here'**
  String get dragDropHint;

  /// No description provided for @syncScroll.
  ///
  /// In en, this message translates to:
  /// **'Sync Scroll'**
  String get syncScroll;

  /// No description provided for @markdownHighlight.
  ///
  /// In en, this message translates to:
  /// **'Markdown Highlight'**
  String get markdownHighlight;

  /// No description provided for @unsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get unsaved;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @editMode.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editMode;

  /// No description provided for @previewMode.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewMode;

  /// No description provided for @splitView.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get splitView;

  /// No description provided for @heading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get heading;

  /// No description provided for @bold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get bold;

  /// No description provided for @italic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get italic;

  /// No description provided for @strikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get strikethrough;

  /// No description provided for @inlineCode.
  ///
  /// In en, this message translates to:
  /// **'Inline Code'**
  String get inlineCode;

  /// No description provided for @codeBlock.
  ///
  /// In en, this message translates to:
  /// **'Code Block'**
  String get codeBlock;

  /// No description provided for @bulletList.
  ///
  /// In en, this message translates to:
  /// **'Bullet List'**
  String get bulletList;

  /// No description provided for @numberedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered List'**
  String get numberedList;

  /// No description provided for @quote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quote;

  /// No description provided for @taskList.
  ///
  /// In en, this message translates to:
  /// **'Task List'**
  String get taskList;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @wikiLink.
  ///
  /// In en, this message translates to:
  /// **'Wiki Link'**
  String get wikiLink;

  /// No description provided for @embedNote.
  ///
  /// In en, this message translates to:
  /// **'Embed Note'**
  String get embedNote;

  /// No description provided for @horizontalRule.
  ///
  /// In en, this message translates to:
  /// **'Horizontal Rule'**
  String get horizontalRule;

  /// No description provided for @table.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get table;

  /// No description provided for @charCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String charCount(Object count);

  /// No description provided for @wordCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wordCount(Object count);

  /// No description provided for @hasUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Has unsaved changes'**
  String get hasUnsavedChanges;

  /// No description provided for @dropHere.
  ///
  /// In en, this message translates to:
  /// **'Drop here'**
  String get dropHere;

  /// No description provided for @startWritingHint.
  ///
  /// In en, this message translates to:
  /// **'Start writing... Use [[note title]] to link other notes'**
  String get startWritingHint;

  /// No description provided for @embedTarget.
  ///
  /// In en, this message translates to:
  /// **'Embed: {target}'**
  String embedTarget(Object target);

  /// No description provided for @backToNotePreview.
  ///
  /// In en, this message translates to:
  /// **'Back to note preview'**
  String get backToNotePreview;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @think.
  ///
  /// In en, this message translates to:
  /// **'Think'**
  String get think;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @openOtherVault.
  ///
  /// In en, this message translates to:
  /// **'Open Other Vault'**
  String get openOtherVault;

  /// No description provided for @createNewVault.
  ///
  /// In en, this message translates to:
  /// **'Create New Vault'**
  String get createNewVault;

  /// No description provided for @recentlyOpened.
  ///
  /// In en, this message translates to:
  /// **'Recently Opened'**
  String get recentlyOpened;

  /// No description provided for @selectVaultLocation.
  ///
  /// In en, this message translates to:
  /// **'Select Vault Location'**
  String get selectVaultLocation;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @webPage.
  ///
  /// In en, this message translates to:
  /// **'Web Page'**
  String get webPage;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes...'**
  String get searchNotes;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolder;

  /// No description provided for @newSubfolder.
  ///
  /// In en, this message translates to:
  /// **'New Subfolder'**
  String get newSubfolder;

  /// No description provided for @newBookmarkFolder.
  ///
  /// In en, this message translates to:
  /// **'New Bookmark Folder'**
  String get newBookmarkFolder;

  /// No description provided for @newSubBookmarkFolder.
  ///
  /// In en, this message translates to:
  /// **'New Subfolder'**
  String get newSubBookmarkFolder;

  /// No description provided for @newConversation.
  ///
  /// In en, this message translates to:
  /// **'New Conversation'**
  String get newConversation;

  /// No description provided for @createNote.
  ///
  /// In en, this message translates to:
  /// **'Create Note'**
  String get createNote;

  /// No description provided for @searchOrEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Search or enter URL...'**
  String get searchOrEnterUrl;

  /// No description provided for @enterMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message... (use @ to reference)'**
  String get enterMessage;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @bookmarkFolderName.
  ///
  /// In en, this message translates to:
  /// **'Bookmark folder name'**
  String get bookmarkFolderName;

  /// No description provided for @quickMoveExampleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Translate'**
  String get quickMoveExampleHint;

  /// No description provided for @noteCount.
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String noteCount(int count);

  /// No description provided for @bookmarkCount.
  ///
  /// In en, this message translates to:
  /// **'{count} bookmarks'**
  String bookmarkCount(int count);

  /// No description provided for @noNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get noNotes;

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get noBookmarks;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @rootDirectory.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get rootDirectory;

  /// No description provided for @bookmarksBar.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks Bar'**
  String get bookmarksBar;

  /// No description provided for @openVaultToExplore.
  ///
  /// In en, this message translates to:
  /// **'Open a vault folder to start exploring and learning'**
  String get openVaultToExplore;

  /// No description provided for @openVaultToManageNotes.
  ///
  /// In en, this message translates to:
  /// **'Open a vault to manage notes'**
  String get openVaultToManageNotes;

  /// No description provided for @openInEditor.
  ///
  /// In en, this message translates to:
  /// **'Open in Editor'**
  String get openInEditor;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @unbookmark.
  ///
  /// In en, this message translates to:
  /// **'Unbookmark'**
  String get unbookmark;

  /// No description provided for @bookmarkThisPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark this page'**
  String get bookmarkThisPage;

  /// No description provided for @bookmarkTo.
  ///
  /// In en, this message translates to:
  /// **'Bookmark to:'**
  String get bookmarkTo;

  /// No description provided for @bookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked: {title}'**
  String bookmarked(String title);

  /// No description provided for @unbookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed'**
  String get unbookmarked;

  /// No description provided for @bookmarkHint.
  ///
  /// In en, this message translates to:
  /// **'Click ⭐ while browsing to bookmark'**
  String get bookmarkHint;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add Bookmark'**
  String get addBookmark;

  /// No description provided for @clipFailed.
  ///
  /// In en, this message translates to:
  /// **'Clip failed: {error}'**
  String clipFailed(String error);

  /// No description provided for @selectTextFirst.
  ///
  /// In en, this message translates to:
  /// **'Select text on the page first to clip'**
  String get selectTextFirst;

  /// No description provided for @clipTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} · Clip'**
  String clipTitle(String title);

  /// No description provided for @clipFullPage.
  ///
  /// In en, this message translates to:
  /// **'Clip Full Page'**
  String get clipFullPage;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @savedToKnowledgeBase.
  ///
  /// In en, this message translates to:
  /// **'Saved to knowledge base'**
  String get savedToKnowledgeBase;

  /// No description provided for @clipSource.
  ///
  /// In en, this message translates to:
  /// **'Source: [{title}]({url})'**
  String clipSource(String title, String url);

  /// No description provided for @clippedAt.
  ///
  /// In en, this message translates to:
  /// **'Clipped at {date}'**
  String clippedAt(String date);

  /// No description provided for @selectedClip.
  ///
  /// In en, this message translates to:
  /// **'Selected Clip'**
  String get selectedClip;

  /// No description provided for @savedAsNote.
  ///
  /// In en, this message translates to:
  /// **'Saved as note: {title}'**
  String savedAsNote(String title);

  /// No description provided for @saveAsNote.
  ///
  /// In en, this message translates to:
  /// **'Save as Note'**
  String get saveAsNote;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @allNotes.
  ///
  /// In en, this message translates to:
  /// **'All Notes'**
  String get allNotes;

  /// No description provided for @hasLinks.
  ///
  /// In en, this message translates to:
  /// **'Has Links'**
  String get hasLinks;

  /// No description provided for @hasAttachments.
  ///
  /// In en, this message translates to:
  /// **'Has Attachments'**
  String get hasAttachments;

  /// No description provided for @unlinkedMentions.
  ///
  /// In en, this message translates to:
  /// **'Unlinked Mentions'**
  String get unlinkedMentions;

  /// No description provided for @knowledgeGraph.
  ///
  /// In en, this message translates to:
  /// **'Knowledge Graph'**
  String get knowledgeGraph;

  /// No description provided for @localGraph.
  ///
  /// In en, this message translates to:
  /// **'Local Graph'**
  String get localGraph;

  /// No description provided for @graphView.
  ///
  /// In en, this message translates to:
  /// **'Graph View'**
  String get graphView;

  /// No description provided for @canvasView.
  ///
  /// In en, this message translates to:
  /// **'Canvas View'**
  String get canvasView;

  /// No description provided for @graphWillShowAfterNotes.
  ///
  /// In en, this message translates to:
  /// **'Graph will appear after creating notes'**
  String get graphWillShowAfterNotes;

  /// No description provided for @canvasWillShowAfterCards.
  ///
  /// In en, this message translates to:
  /// **'Canvas will appear after adding cards'**
  String get canvasWillShowAfterCards;

  /// No description provided for @switchToForceLayout.
  ///
  /// In en, this message translates to:
  /// **'Switch to force layout'**
  String get switchToForceLayout;

  /// No description provided for @createLinkedNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Create notes with [[links]] to see connections'**
  String get createLinkedNotesHint;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get addCard;

  /// No description provided for @clearCanvas.
  ///
  /// In en, this message translates to:
  /// **'Clear Canvas'**
  String get clearCanvas;

  /// No description provided for @clearCanvasConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove all cards and connections? This cannot be undone.'**
  String get clearCanvasConfirm;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @autoConnectOn.
  ///
  /// In en, this message translates to:
  /// **'Auto Connect: On'**
  String get autoConnectOn;

  /// No description provided for @autoConnectOff.
  ///
  /// In en, this message translates to:
  /// **'Auto Connect: Off'**
  String get autoConnectOff;

  /// No description provided for @newCanvas.
  ///
  /// In en, this message translates to:
  /// **'New Canvas'**
  String get newCanvas;

  /// No description provided for @canvasName.
  ///
  /// In en, this message translates to:
  /// **'Canvas Name'**
  String get canvasName;

  /// No description provided for @renameCanvas.
  ///
  /// In en, this message translates to:
  /// **'Rename Canvas'**
  String get renameCanvas;

  /// No description provided for @deleteCanvas.
  ///
  /// In en, this message translates to:
  /// **'Delete Canvas'**
  String get deleteCanvas;

  /// No description provided for @deleteCanvasConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This action cannot be undone.'**
  String deleteCanvasConfirm(String name);

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @noteCard.
  ///
  /// In en, this message translates to:
  /// **'Note Card'**
  String get noteCard;

  /// No description provided for @textCard.
  ///
  /// In en, this message translates to:
  /// **'Text Card'**
  String get textCard;

  /// No description provided for @imageCard.
  ///
  /// In en, this message translates to:
  /// **'Image Card'**
  String get imageCard;

  /// No description provided for @linkCard.
  ///
  /// In en, this message translates to:
  /// **'Link Card'**
  String get linkCard;

  /// No description provided for @fromKnowledgeNote.
  ///
  /// In en, this message translates to:
  /// **'From Knowledge Note'**
  String get fromKnowledgeNote;

  /// No description provided for @editCard.
  ///
  /// In en, this message translates to:
  /// **'Edit Card'**
  String get editCard;

  /// No description provided for @duplicateCard.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Card'**
  String get duplicateCard;

  /// No description provided for @deleteCard.
  ///
  /// In en, this message translates to:
  /// **'Delete Card'**
  String get deleteCard;

  /// No description provided for @changeColor.
  ///
  /// In en, this message translates to:
  /// **'Change Color'**
  String get changeColor;

  /// No description provided for @searchCards.
  ///
  /// In en, this message translates to:
  /// **'Search Cards'**
  String get searchCards;

  /// No description provided for @connectFrom.
  ///
  /// In en, this message translates to:
  /// **'Connect From'**
  String get connectFrom;

  /// No description provided for @manageConnections.
  ///
  /// In en, this message translates to:
  /// **'Manage Connections'**
  String get manageConnections;

  /// No description provided for @autoConnection.
  ///
  /// In en, this message translates to:
  /// **'Auto Connection'**
  String get autoConnection;

  /// No description provided for @manualConnection.
  ///
  /// In en, this message translates to:
  /// **'Manual Connection'**
  String get manualConnection;

  /// No description provided for @cardColor.
  ///
  /// In en, this message translates to:
  /// **'Card Color'**
  String get cardColor;

  /// No description provided for @editCardType.
  ///
  /// In en, this message translates to:
  /// **'Edit {type} Card'**
  String editCardType(String type);

  /// No description provided for @imagePath.
  ///
  /// In en, this message translates to:
  /// **'Image Path'**
  String get imagePath;

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @selectNote.
  ///
  /// In en, this message translates to:
  /// **'Select Note'**
  String get selectNote;

  /// No description provided for @noNotesInKnowledgeBase.
  ///
  /// In en, this message translates to:
  /// **'No notes in knowledge base'**
  String get noNotesInKnowledgeBase;

  /// No description provided for @newName.
  ///
  /// In en, this message translates to:
  /// **'New Name'**
  String get newName;

  /// No description provided for @startBrowsing.
  ///
  /// In en, this message translates to:
  /// **'Start Browsing'**
  String get startBrowsing;

  /// No description provided for @openNewTabExplore.
  ///
  /// In en, this message translates to:
  /// **'Open a new tab to explore the web'**
  String get openNewTabExplore;

  /// No description provided for @selectNoteToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a note to start editing'**
  String get selectNoteToEdit;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @askMeAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything'**
  String get askMeAnything;

  /// No description provided for @aiSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get aiSummary;

  /// No description provided for @aiSuggestion.
  ///
  /// In en, this message translates to:
  /// **'AI Suggestion'**
  String get aiSuggestion;

  /// No description provided for @aiSourceSummary.
  ///
  /// In en, this message translates to:
  /// **'AI {source} Summary'**
  String aiSourceSummary(String source);

  /// No description provided for @generateSummary.
  ///
  /// In en, this message translates to:
  /// **'Generate Summary'**
  String get generateSummary;

  /// No description provided for @generateSourceSummary.
  ///
  /// In en, this message translates to:
  /// **'Generate {source} Summary'**
  String generateSourceSummary(String source);

  /// No description provided for @clickToGenerateSummary.
  ///
  /// In en, this message translates to:
  /// **'Click the button to generate AI {source} summary'**
  String clickToGenerateSummary(String source);

  /// No description provided for @clickAiForSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Click AI button for suggestions'**
  String get clickAiForSuggestion;

  /// No description provided for @insertWikilink.
  ///
  /// In en, this message translates to:
  /// **'Insert Wikilink'**
  String get insertWikilink;

  /// No description provided for @clickNoteToPreview.
  ///
  /// In en, this message translates to:
  /// **'Click a note on the left to preview'**
  String get clickNoteToPreview;

  /// No description provided for @notePreview.
  ///
  /// In en, this message translates to:
  /// **'Note Preview'**
  String get notePreview;

  /// No description provided for @noteSummary.
  ///
  /// In en, this message translates to:
  /// **'Note Summary'**
  String get noteSummary;

  /// No description provided for @webPageSummary.
  ///
  /// In en, this message translates to:
  /// **'Web Page Summary'**
  String get webPageSummary;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'{source} Summary - {title}'**
  String summaryTitle(String source, String title);

  /// No description provided for @switchSummaryTarget.
  ///
  /// In en, this message translates to:
  /// **'Switch summary target'**
  String get switchSummaryTarget;

  /// No description provided for @selectNoteForSummary.
  ///
  /// In en, this message translates to:
  /// **'Select a note to use AI summary'**
  String get selectNoteForSummary;

  /// No description provided for @openPageForSummary.
  ///
  /// In en, this message translates to:
  /// **'Open a web page to use AI summary'**
  String get openPageForSummary;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @closePanel.
  ///
  /// In en, this message translates to:
  /// **'Close Panel'**
  String get closePanel;

  /// No description provided for @editNote.
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get editNote;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generating;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @nodeDetail.
  ///
  /// In en, this message translates to:
  /// **'Node Detail'**
  String get nodeDetail;

  /// No description provided for @clickNodeForDetail.
  ///
  /// In en, this message translates to:
  /// **'Click a graph node to see details'**
  String get clickNodeForDetail;

  /// No description provided for @modifiedTime.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get modifiedTime;

  /// No description provided for @contentPreview.
  ///
  /// In en, this message translates to:
  /// **'Content Preview'**
  String get contentPreview;

  /// No description provided for @restoreDefaultCommands.
  ///
  /// In en, this message translates to:
  /// **'Restore Default Commands'**
  String get restoreDefaultCommands;

  /// No description provided for @restoreDefaultCommandsDesc.
  ///
  /// In en, this message translates to:
  /// **'All deleted preset commands will be restored. Your custom commands will not be affected.'**
  String get restoreDefaultCommandsDesc;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed, please check file format'**
  String get importFailed;

  /// No description provided for @deleteCommand.
  ///
  /// In en, this message translates to:
  /// **'Delete Command'**
  String get deleteCommand;

  /// No description provided for @deleteCommandConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete command \"{name}\"?'**
  String deleteCommandConfirm(String name);

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get deleteNote;

  /// No description provided for @deleteNoteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String deleteNoteConfirm(String title);

  /// No description provided for @deleteFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete Folder'**
  String get deleteFolder;

  /// No description provided for @deleteFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{path}\" and its {count} notes? This cannot be undone.'**
  String deleteFolderConfirm(String path, int count);

  /// No description provided for @deleteBookmarkFolder.
  ///
  /// In en, this message translates to:
  /// **'Delete Bookmark Folder'**
  String get deleteBookmarkFolder;

  /// No description provided for @deleteBookmarkFolderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Bookmarks inside will move to \"Uncategorized\".'**
  String deleteBookmarkFolderConfirm(String name);

  /// No description provided for @renameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename Folder'**
  String get renameFolder;

  /// No description provided for @renameBookmarkFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename Bookmark Folder'**
  String get renameBookmarkFolder;

  /// No description provided for @moveTo.
  ///
  /// In en, this message translates to:
  /// **'Move To'**
  String get moveTo;

  /// No description provided for @moveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to Folder'**
  String get moveToFolder;

  /// No description provided for @cmdNewNote.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get cmdNewNote;

  /// No description provided for @cmdNewTab.
  ///
  /// In en, this message translates to:
  /// **'New Tab'**
  String get cmdNewTab;

  /// No description provided for @cmdOpenDailyNote.
  ///
  /// In en, this message translates to:
  /// **'Open Daily Note'**
  String get cmdOpenDailyNote;

  /// No description provided for @cmdSwitchTheme.
  ///
  /// In en, this message translates to:
  /// **'Switch Theme'**
  String get cmdSwitchTheme;

  /// No description provided for @cmdSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get cmdSettings;

  /// No description provided for @cmdGraphView.
  ///
  /// In en, this message translates to:
  /// **'Graph View'**
  String get cmdGraphView;

  /// No description provided for @cmdCanvasView.
  ///
  /// In en, this message translates to:
  /// **'Canvas View'**
  String get cmdCanvasView;

  /// No description provided for @welcomeToRfbrowser.
  ///
  /// In en, this message translates to:
  /// **'Welcome to RFBrowser'**
  String get welcomeToRfbrowser;

  /// No description provided for @obsidianCompatible.
  ///
  /// In en, this message translates to:
  /// **'Supports Obsidian-compatible Markdown files'**
  String get obsidianCompatible;

  /// No description provided for @addToCanvas.
  ///
  /// In en, this message translates to:
  /// **'Add to Canvas'**
  String get addToCanvas;

  /// No description provided for @notesOnCanvas.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesOnCanvas;

  /// No description provided for @dragOrClickToAdd.
  ///
  /// In en, this message translates to:
  /// **'Click or drag to add note to canvas'**
  String get dragOrClickToAdd;

  /// No description provided for @alreadyOnCanvas.
  ///
  /// In en, this message translates to:
  /// **'Already on canvas'**
  String get alreadyOnCanvas;

  /// No description provided for @resizeHandle.
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get resizeHandle;

  /// No description provided for @viewOriginalPage.
  ///
  /// In en, this message translates to:
  /// **'View Original Page'**
  String get viewOriginalPage;

  /// No description provided for @viewScreenshot.
  ///
  /// In en, this message translates to:
  /// **'View Screenshot'**
  String get viewScreenshot;

  /// No description provided for @originalPageViewHint.
  ///
  /// In en, this message translates to:
  /// **'This is the original page view. JavaScript is disabled for security.'**
  String get originalPageViewHint;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in Browser'**
  String get openInBrowser;

  /// No description provided for @loadingOriginalPage.
  ///
  /// In en, this message translates to:
  /// **'Loading original page...'**
  String get loadingOriginalPage;

  /// No description provided for @noOriginalPage.
  ///
  /// In en, this message translates to:
  /// **'No original page saved'**
  String get noOriginalPage;

  /// No description provided for @pageScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Page Screenshot'**
  String get pageScreenshot;

  /// No description provided for @screenshotNotFound.
  ///
  /// In en, this message translates to:
  /// **'Screenshot file not found'**
  String get screenshotNotFound;

  /// No description provided for @connectionProperties.
  ///
  /// In en, this message translates to:
  /// **'Connection Properties'**
  String get connectionProperties;

  /// No description provided for @fromCard.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromCard;

  /// No description provided for @toCard.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toCard;

  /// No description provided for @pathType.
  ///
  /// In en, this message translates to:
  /// **'Path Type'**
  String get pathType;

  /// No description provided for @endArrow.
  ///
  /// In en, this message translates to:
  /// **'End Arrow'**
  String get endArrow;

  /// No description provided for @startArrow.
  ///
  /// In en, this message translates to:
  /// **'Start Arrow'**
  String get startArrow;

  /// No description provided for @arrowSize.
  ///
  /// In en, this message translates to:
  /// **'Arrow Size'**
  String get arrowSize;

  /// No description provided for @labelFontSize.
  ///
  /// In en, this message translates to:
  /// **'Label Font Size'**
  String get labelFontSize;

  /// No description provided for @lineWidth.
  ///
  /// In en, this message translates to:
  /// **'Line Width'**
  String get lineWidth;

  /// No description provided for @lineColor.
  ///
  /// In en, this message translates to:
  /// **'Line Color'**
  String get lineColor;

  /// No description provided for @lineJump.
  ///
  /// In en, this message translates to:
  /// **'Line Jump'**
  String get lineJump;

  /// No description provided for @flowAnimation.
  ///
  /// In en, this message translates to:
  /// **'Flow Animation'**
  String get flowAnimation;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @connectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Connection label'**
  String get connectionLabel;

  /// No description provided for @deleteConnection.
  ///
  /// In en, this message translates to:
  /// **'Delete Connection'**
  String get deleteConnection;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
