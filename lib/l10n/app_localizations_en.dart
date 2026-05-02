// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'RFBrowser';

  @override
  String get home => 'Home';

  @override
  String get browser => 'Browser';

  @override
  String get editor => 'Editor';

  @override
  String get graph => 'Graph';

  @override
  String get canvas => 'Canvas';

  @override
  String get aiChat => 'AI Chat';

  @override
  String get settings => 'Settings';

  @override
  String get plugins => 'Plugins';

  @override
  String get search => 'Search';

  @override
  String get newNote => 'New Note';

  @override
  String get newTab => 'New Tab';

  @override
  String get closeTab => 'Close Tab';

  @override
  String get closeAllTabs => 'Close All Tabs';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get move => 'Move';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get cut => 'Cut';

  @override
  String get selectAll => 'Select All';

  @override
  String get backlinks => 'Backlinks';

  @override
  String get outline => 'Outline';

  @override
  String get tags => 'Tags';

  @override
  String get untagged => 'Untagged';

  @override
  String get dailyNotes => 'Daily Notes';

  @override
  String get clippings => 'Clippings';

  @override
  String get attachments => 'Attachments';

  @override
  String get templates => 'Templates';

  @override
  String get skills => 'Skills';

  @override
  String get agent => 'Agent';

  @override
  String get sync => 'Sync';

  @override
  String get gitSync => 'Git Sync';

  @override
  String get webdavSync => 'WebDAV Sync';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get followSystem => 'Follow System';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get toggleDarkLight => 'Toggle dark/light theme';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get theme => 'Theme';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get customColor => 'Custom Color';

  @override
  String get components => 'Components';

  @override
  String get buttonShape => 'Button Shape';

  @override
  String get rounded => 'Rounded';

  @override
  String get sharp => 'Sharp';

  @override
  String get pill => 'Pill';

  @override
  String get cornerRadius => 'Corner Radius';

  @override
  String get density => 'Density';

  @override
  String get compact => 'Compact';

  @override
  String get comfortable => 'Comfortable';

  @override
  String get spacious => 'Spacious';

  @override
  String get iconSize => 'Icon Size';

  @override
  String get small => 'Small';

  @override
  String get medium => 'Medium';

  @override
  String get large => 'Large';

  @override
  String get fontSize => 'Font Size';

  @override
  String get preview => 'Preview';

  @override
  String get filled => 'Filled';

  @override
  String get outlined => 'Outlined';

  @override
  String get aiModels => 'AI Models';

  @override
  String get openaiApiKey => 'OpenAI API Key';

  @override
  String get notSet => 'Not set';

  @override
  String get activeModel => 'Active Model';

  @override
  String get localModelOllama => 'Local Model (Ollama)';

  @override
  String get configureLocalModel => 'Configure local model endpoint';

  @override
  String get ollamaEndpoint => 'Ollama Endpoint';

  @override
  String get ollamaHint =>
      'Make sure Ollama is running locally before using local models.';

  @override
  String get editorSection => 'Editor';

  @override
  String get syncSection => 'Sync';

  @override
  String get configureGitRemote => 'Configure Git remote for vault sync';

  @override
  String get configureWebdav => 'Configure WebDAV server for vault sync';

  @override
  String get remoteUrl => 'Remote URL';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get about => 'About';

  @override
  String get versionInfo => 'v0.2.0 - AI-Powered Knowledge Browser';

  @override
  String get license => 'License';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get selectModel => 'Select Model';

  @override
  String get componentDensity => 'Component Density';

  @override
  String get apply => 'Apply';

  @override
  String get customAccentColor => 'Custom Accent Color';

  @override
  String get noVaultConnected => 'No Vault Connected';

  @override
  String get openVaultToStart => 'Open a vault to start writing notes';

  @override
  String get noNoteSelected => 'No note selected';

  @override
  String get createOrSelectNote =>
      'Create a new note or select one from the sidebar';

  @override
  String get edit => 'Edit';

  @override
  String get startWriting => 'Start writing...';

  @override
  String get splitRight => 'Split Right';

  @override
  String get splitLeft => 'Split Left';

  @override
  String get splitUp => 'Split Up';

  @override
  String get splitDown => 'Split Down';

  @override
  String get changeView => 'Change View';

  @override
  String get close => 'Close';

  @override
  String get changeViewTitle => 'Open View';

  @override
  String get notes => 'Notes';

  @override
  String get tabs => 'Tabs';

  @override
  String get ready => 'Ready';

  @override
  String get noVault => 'No Vault';

  @override
  String notesCount(int count) {
    return '$count notes';
  }

  @override
  String tabsCount(int count) {
    return '$count tabs';
  }

  @override
  String get clearChat => 'Clear Chat';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get askAnything => 'Ask anything... (Ctrl+K)';

  @override
  String get noResults => 'No results found';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get confirm => 'Confirm';

  @override
  String get warning => 'Warning';

  @override
  String get info => 'Info';

  @override
  String get vault => 'Vault';

  @override
  String get openVault => 'Open Vault';

  @override
  String get createVault => 'Create Vault';

  @override
  String get selectVault => 'Select Vault Location';

  @override
  String get welcome => 'Welcome to RFBrowser';

  @override
  String get welcomeDesc =>
      'Open an existing vault or create a new one to get started.';

  @override
  String get recentVaults => 'Recent Vaults';

  @override
  String get tabGroups => 'Tab Groups';

  @override
  String get newGroup => 'New Group';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String get clipPage => 'Clip Page';

  @override
  String get clipSelection => 'Clip Selection';

  @override
  String get clipBookmark => 'Bookmark';

  @override
  String get commandBar => 'Command Bar';

  @override
  String get runCommand => 'Run Command';

  @override
  String get noBacklinks => 'No backlinks yet';

  @override
  String get noOutline => 'No outline available';

  @override
  String get noteSaved => 'Note saved';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get vaultOpened => 'Vault opened';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get agentRunning => 'Agent running...';

  @override
  String get agentCompleted => 'Agent task completed';

  @override
  String get agentFailed => 'Agent task failed';

  @override
  String get newNoteTitle => 'New Note';

  @override
  String get noteTitle => 'Note title';

  @override
  String get create => 'Create';

  @override
  String get comingInPhase4 => 'Coming in Phase 4';

  @override
  String get gitSyncConfig => 'Git Sync Configuration';

  @override
  String get webdavConfig => 'WebDAV Configuration';

  @override
  String get providers => 'Providers';

  @override
  String get addProvider => 'Add Provider';

  @override
  String get providerName => 'Provider Name';

  @override
  String get providerNameHint => 'My OpenAI, Work Azure, etc.';

  @override
  String get protocol => 'Protocol';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get apiKey => 'API Key';

  @override
  String get leaveEmptyToKeep => 'leave empty to keep current';

  @override
  String get editProvider => 'Edit Provider';

  @override
  String get deleteProvider => 'Delete Provider';

  @override
  String get deleteProviderConfirm => 'Delete provider and all its models?';

  @override
  String get addCustomModel => 'Add Custom Model';

  @override
  String get modelId => 'Model ID';

  @override
  String get displayName => 'Display Name';

  @override
  String get displayNameHint => 'My Custom Model';

  @override
  String get refreshModels => 'Refresh Models';

  @override
  String get refresh => 'Refresh';

  @override
  String get noProvidersHint =>
      'No providers configured. Add one to get started.';

  @override
  String get noModelsFound => 'No models found';

  @override
  String get modelsRefreshed => 'Found';

  @override
  String get disabled => 'Disabled';

  @override
  String get enable => 'Enable';

  @override
  String get custom => 'Custom';
}
