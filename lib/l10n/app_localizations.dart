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

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get customColor;

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
