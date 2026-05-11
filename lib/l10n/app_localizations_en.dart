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
  String get themeColor => 'Theme Color';

  @override
  String get backgroundColor => 'Background Color';

  @override
  String get surfaceColor => 'Surface';

  @override
  String get customColor => 'Custom Color';

  @override
  String get opacity => 'Opacity';

  @override
  String get themeTintOpacity => 'Theme Tint Intensity';

  @override
  String get surfaceOpacity => 'Surface Opacity';

  @override
  String get backgroundOpacity => 'Background Opacity';

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

  @override
  String get appSubtitle => 'AI-Powered Knowledge Browser';

  @override
  String get removeVault => 'Remove Vault';

  @override
  String removeVaultConfirm(String name) {
    return 'Remove \"$name\" from recent vaults?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get alwaysShowWelcomePage => 'Always Show Welcome Page';

  @override
  String get alwaysShowWelcomePageDesc =>
      'Show the welcome page on every launch instead of opening the last vault directly';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get shortcuts => 'Shortcuts';

  @override
  String get pressNewShortcut => 'Press new shortcut...';

  @override
  String get resetToDefaults => 'Reset to Defaults';

  @override
  String get shortcutsReset => 'Shortcuts reset to defaults';

  @override
  String get shortcutConflict => 'Shortcut conflict';

  @override
  String shortcutConflictMsg(String shortcut, String action) {
    return '\"$shortcut\" is already bound to \"$action\"';
  }

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get offline => 'Offline';

  @override
  String get online => 'Online';

  @override
  String get aiDegradedToLocal => 'AI switched to local model (offline)';

  @override
  String get noLocalModel => 'No local model available for offline use';

  @override
  String syncPending(int count) {
    return '$count changes pending sync';
  }

  @override
  String get dragDropHint => 'Drag text or notes here';

  @override
  String get syncScroll => 'Sync Scroll';

  @override
  String get markdownHighlight => 'Markdown Highlight';

  @override
  String get unsaved => 'Unsaved';

  @override
  String get saved => 'Saved';

  @override
  String get editMode => 'Edit';

  @override
  String get previewMode => 'Preview';

  @override
  String get splitView => 'Split';

  @override
  String get heading => 'Heading';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get strikethrough => 'Strikethrough';

  @override
  String get inlineCode => 'Inline Code';

  @override
  String get codeBlock => 'Code Block';

  @override
  String get bulletList => 'Bullet List';

  @override
  String get numberedList => 'Numbered List';

  @override
  String get quote => 'Quote';

  @override
  String get taskList => 'Task List';

  @override
  String get link => 'Link';

  @override
  String get wikiLink => 'Wiki Link';

  @override
  String get embedNote => 'Embed Note';

  @override
  String get horizontalRule => 'Horizontal Rule';

  @override
  String get table => 'Table';

  @override
  String charCount(Object count) {
    return '$count characters';
  }

  @override
  String wordCount(Object count) {
    return '$count words';
  }

  @override
  String get hasUnsavedChanges => 'Has unsaved changes';

  @override
  String get dropHere => 'Drop here';

  @override
  String get startWritingHint =>
      'Start writing... Use [[note title]] to link other notes';

  @override
  String embedTarget(Object target) {
    return 'Embed: $target';
  }

  @override
  String get backToNotePreview => 'Back to note preview';

  @override
  String get capture => 'Capture';

  @override
  String get think => 'Think';

  @override
  String get connect => 'Connect';

  @override
  String get openOtherVault => 'Open Other Vault';

  @override
  String get createNewVault => 'Create New Vault';

  @override
  String get recentlyOpened => 'Recently Opened';

  @override
  String get selectVaultLocation => 'Select Vault Location';

  @override
  String get note => 'Note';

  @override
  String get webPage => 'Web Page';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get searchNotes => 'Search notes...';

  @override
  String get newFolder => 'New Folder';

  @override
  String get newSubfolder => 'New Subfolder';

  @override
  String get newBookmarkFolder => 'New Bookmark Folder';

  @override
  String get newSubBookmarkFolder => 'New Subfolder';

  @override
  String get newConversation => 'New Conversation';

  @override
  String get createNote => 'Create Note';

  @override
  String get searchOrEnterUrl => 'Search or enter URL...';

  @override
  String get enterMessage => 'Type a message... (use @ to reference)';

  @override
  String get folderName => 'Folder name';

  @override
  String get bookmarkFolderName => 'Bookmark folder name';

  @override
  String get quickMoveExampleHint => 'e.g. Translate';

  @override
  String get quickMoves => 'Quick Moves';

  @override
  String noteCount(int count) {
    return '$count notes';
  }

  @override
  String bookmarkCount(int count) {
    return '$count bookmarks';
  }

  @override
  String get noNotes => 'No notes yet';

  @override
  String get noBookmarks => 'No bookmarks yet';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get rootDirectory => 'Root';

  @override
  String get bookmarksBar => 'Bookmarks Bar';

  @override
  String get openVaultToExplore =>
      'Open a vault folder to start exploring and learning';

  @override
  String get openVaultToManageNotes => 'Open a vault to manage notes';

  @override
  String get openInEditor => 'Open in Editor';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get unbookmark => 'Unbookmark';

  @override
  String get bookmarkThisPage => 'Bookmark this page';

  @override
  String get bookmarkTo => 'Bookmark to:';

  @override
  String bookmarked(String title) {
    return 'Bookmarked: $title';
  }

  @override
  String get unbookmarked => 'Bookmark removed';

  @override
  String get bookmarkHint => 'Click ⭐ while browsing to bookmark';

  @override
  String get addBookmark => 'Add Bookmark';

  @override
  String clipFailed(String error) {
    return 'Clip failed: $error';
  }

  @override
  String get selectTextFirst => 'Select text on the page first to clip';

  @override
  String clipTitle(String title) {
    return '$title · Clip';
  }

  @override
  String get clipFullPage => 'Clip Full Page';

  @override
  String get view => 'View';

  @override
  String get savedToKnowledgeBase => 'Saved to knowledge base';

  @override
  String clipSource(String title, String url) {
    return 'Source: [$title]($url)';
  }

  @override
  String clippedAt(String date) {
    return 'Clipped at $date';
  }

  @override
  String get selectedClip => 'Selected Clip';

  @override
  String savedAsNote(String title) {
    return 'Saved as note: $title';
  }

  @override
  String get saveAsNote => 'Save as Note';

  @override
  String get filter => 'Filter';

  @override
  String get allNotes => 'All Notes';

  @override
  String get hasLinks => 'Has Links';

  @override
  String get hasAttachments => 'Has Attachments';

  @override
  String get unlinkedMentions => 'Unlinked Mentions';

  @override
  String get knowledgeGraph => 'Knowledge Graph';

  @override
  String get localGraph => 'Local Graph';

  @override
  String get graphView => 'Graph View';

  @override
  String get canvasView => 'Canvas View';

  @override
  String get graphWillShowAfterNotes =>
      'Graph will appear after creating notes';

  @override
  String get canvasWillShowAfterCards =>
      'Canvas will appear after adding cards';

  @override
  String get switchToForceLayout => 'Switch to force layout';

  @override
  String get createLinkedNotesHint =>
      'Create notes with [[links]] to see connections';

  @override
  String get addCard => 'Add Card';

  @override
  String get clearCanvas => 'Clear Canvas';

  @override
  String get clearCanvasConfirm =>
      'Remove all cards and connections? This cannot be undone.';

  @override
  String get clear => 'Clear';

  @override
  String get autoConnectOn => 'Auto Connect: On';

  @override
  String get autoConnectOff => 'Auto Connect: Off';

  @override
  String get newCanvas => 'New Canvas';

  @override
  String get canvasName => 'Canvas Name';

  @override
  String get renameCanvas => 'Rename Canvas';

  @override
  String get deleteCanvas => 'Delete Canvas';

  @override
  String deleteCanvasConfirm(String name) {
    return 'Delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get deleteAll => 'Delete All';

  @override
  String get noteCard => 'Note Card';

  @override
  String get textCard => 'Text Card';

  @override
  String get imageCard => 'Image Card';

  @override
  String get linkCard => 'Link Card';

  @override
  String get fromKnowledgeNote => 'From Knowledge Note';

  @override
  String get editCard => 'Edit Card';

  @override
  String get duplicateCard => 'Duplicate Card';

  @override
  String get deleteCard => 'Delete Card';

  @override
  String get changeColor => 'Change Color';

  @override
  String get searchCards => 'Search Cards';

  @override
  String get connectFrom => 'Connect From';

  @override
  String get manageConnections => 'Manage Connections';

  @override
  String get autoConnection => 'Auto Connection';

  @override
  String get manualConnection => 'Manual Connection';

  @override
  String get cardColor => 'Card Color';

  @override
  String editCardType(String type) {
    return 'Edit $type Card';
  }

  @override
  String get imagePath => 'Image Path';

  @override
  String get url => 'URL';

  @override
  String get selectNote => 'Select Note';

  @override
  String get noNotesInKnowledgeBase => 'No notes in knowledge base';

  @override
  String get newName => 'New Name';

  @override
  String get startBrowsing => 'Start Browsing';

  @override
  String get openNewTabExplore => 'Open a new tab to explore the web';

  @override
  String get selectNoteToEdit => 'Select a note to start editing';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get askMeAnything => 'Ask me anything';

  @override
  String get aiSummary => 'AI Summary';

  @override
  String get aiSuggestion => 'AI Suggestion';

  @override
  String aiSourceSummary(String source) {
    return 'AI $source Summary';
  }

  @override
  String get generateSummary => 'Generate Summary';

  @override
  String generateSourceSummary(String source) {
    return 'Generate $source Summary';
  }

  @override
  String clickToGenerateSummary(String source) {
    return 'Click the button to generate AI $source summary';
  }

  @override
  String get clickAiForSuggestion => 'Click AI button for suggestions';

  @override
  String get insertWikilink => 'Insert Wikilink';

  @override
  String get clickNoteToPreview => 'Click a note on the left to preview';

  @override
  String get notePreview => 'Note Preview';

  @override
  String get noteSummary => 'Note Summary';

  @override
  String get webPageSummary => 'Web Page Summary';

  @override
  String summaryTitle(String source, String title) {
    return '$source Summary - $title';
  }

  @override
  String get switchSummaryTarget => 'Switch summary target';

  @override
  String get selectNoteForSummary => 'Select a note to use AI summary';

  @override
  String get openPageForSummary => 'Open a web page to use AI summary';

  @override
  String get goBack => 'Go Back';

  @override
  String get closePanel => 'Close Panel';

  @override
  String get editNote => 'Edit Note';

  @override
  String get generating => 'Generating...';

  @override
  String get retry => 'Retry';

  @override
  String get nodeDetail => 'Node Detail';

  @override
  String get clickNodeForDetail => 'Click a graph node to see details';

  @override
  String get modifiedTime => 'Modified';

  @override
  String get contentPreview => 'Content Preview';

  @override
  String get restoreDefaultCommands => 'Restore Default Commands';

  @override
  String get restoreDefaultCommandsDesc =>
      'All deleted preset commands will be restored. Your custom commands will not be affected.';

  @override
  String get restore => 'Restore';

  @override
  String get importSuccess => 'Import successful';

  @override
  String get importFailed => 'Import failed, please check file format';

  @override
  String get deleteCommand => 'Delete Command';

  @override
  String deleteCommandConfirm(String name) {
    return 'Delete command \"$name\"?';
  }

  @override
  String get deleteNote => 'Delete Note';

  @override
  String deleteNoteConfirm(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get deleteFolder => 'Delete Folder';

  @override
  String deleteFolderConfirm(String path, int count) {
    return 'Delete \"$path\" and its $count notes? This cannot be undone.';
  }

  @override
  String get deleteBookmarkFolder => 'Delete Bookmark Folder';

  @override
  String deleteBookmarkFolderConfirm(String name) {
    return 'Delete \"$name\"? Bookmarks inside will move to \"Uncategorized\".';
  }

  @override
  String get renameFolder => 'Rename Folder';

  @override
  String get renameBookmarkFolder => 'Rename Bookmark Folder';

  @override
  String get moveTo => 'Move To';

  @override
  String get moveToFolder => 'Move to Folder';

  @override
  String get cmdNewNote => 'New Note';

  @override
  String get cmdNewTab => 'New Tab';

  @override
  String get cmdOpenDailyNote => 'Open Daily Note';

  @override
  String get cmdSwitchTheme => 'Switch Theme';

  @override
  String get cmdSettings => 'Settings';

  @override
  String get cmdGraphView => 'Graph View';

  @override
  String get cmdCanvasView => 'Canvas View';

  @override
  String get welcomeToRfbrowser => 'Welcome to RFBrowser';

  @override
  String get obsidianCompatible =>
      'Supports Obsidian-compatible Markdown files';

  @override
  String get addToCanvas => 'Add to canvas';

  @override
  String get notesOnCanvas => 'Notes';

  @override
  String get dragOrClickToAdd => 'Click or drag to add note to canvas';

  @override
  String get alreadyOnCanvas => 'Already on canvas';

  @override
  String get resizeHandle => 'Resize';

  @override
  String get viewOriginalPage => 'View Original Page';

  @override
  String get viewScreenshot => 'View Screenshot';

  @override
  String get originalPageViewHint =>
      'This is the original page view. JavaScript is disabled for security.';

  @override
  String get openInBrowser => 'Open in Browser';

  @override
  String get loadingOriginalPage => 'Loading original page...';

  @override
  String get noOriginalPage => 'No original page saved';

  @override
  String get pageScreenshot => 'Page Screenshot';

  @override
  String get screenshotNotFound => 'Screenshot file not found';

  @override
  String get connectionProperties => 'Connection Properties';

  @override
  String get fromCard => 'From';

  @override
  String get toCard => 'To';

  @override
  String get pathType => 'Path Type';

  @override
  String get endArrow => 'End Arrow';

  @override
  String get startArrow => 'Start Arrow';

  @override
  String get arrowSize => 'Arrow Size';

  @override
  String get labelFontSize => 'Label Font Size';

  @override
  String get lineWidth => 'Line Width';

  @override
  String get lineColor => 'Line Color';

  @override
  String get lineJump => 'Line Jump';

  @override
  String get flowAnimation => 'Flow Animation';

  @override
  String get label => 'Label';

  @override
  String get connectionLabel => 'Connection label';

  @override
  String get deleteConnection => 'Delete Connection';

  @override
  String get alignLeft => 'Align Left';

  @override
  String get alignCenterH => 'Align Center H';

  @override
  String get alignRight => 'Align Right';

  @override
  String get alignTop => 'Align Top';

  @override
  String get alignCenterV => 'Align Center V';

  @override
  String get alignBottom => 'Align Bottom';

  @override
  String get distributeH => 'Distribute H';

  @override
  String get distributeV => 'Distribute V';

  @override
  String get rectangle => 'Rectangle';

  @override
  String get roundedRect => 'Rounded Rect';

  @override
  String get ellipse => 'Ellipse';

  @override
  String get diamond => 'Diamond';

  @override
  String get hexagon => 'Hexagon';

  @override
  String get parallelogram => 'Parallelogram';

  @override
  String get triangle => 'Triangle';

  @override
  String get cylinder => 'Cylinder';

  @override
  String get star => 'Star';

  @override
  String get swimlaneH => 'Swimlane H';

  @override
  String get swimlaneV => 'Swimlane V';

  @override
  String get freehand => 'Freehand';

  @override
  String get loadTemplate => 'Load Template';

  @override
  String get loadTemplateConfirm =>
      'This will replace the current canvas content. Continue?';

  @override
  String get flowchart => 'Flowchart';

  @override
  String get umlClass => 'UML Class';

  @override
  String get swimlane => 'Swimlane';

  @override
  String get mindMap => 'Mind Map';

  @override
  String get network => 'Network';

  @override
  String get erDiagram => 'ER Diagram';

  @override
  String get kanban => 'Kanban';

  @override
  String get orgChart => 'Org Chart';

  @override
  String get stateMachine => 'State Machine';

  @override
  String get vennDiagram => 'Venn Diagram';

  @override
  String get timeline => 'Timeline';

  @override
  String get gantt => 'Gantt';

  @override
  String get decisionTree => 'Decision Tree';

  @override
  String get forceDirected => 'Force Directed';

  @override
  String get hierarchical => 'Hierarchical';

  @override
  String get gridLayout => 'Grid';

  @override
  String get exportPng => 'Export PNG';

  @override
  String get exportSvg => 'Export SVG';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get exportMarkdown => 'Export Markdown';

  @override
  String get exportHtml => 'Export HTML';

  @override
  String get exportJpeg => 'Export JPEG';

  @override
  String get exportSvgWithData => 'Export SVG (with data)';

  @override
  String get clearBackground => 'Clear Background';

  @override
  String get defaultCardStyle => 'Default Card Style';

  @override
  String get enumerateShapes => 'Enumerate Shapes';

  @override
  String get importCsv => 'Import CSV';

  @override
  String get importMermaid => 'Import Mermaid';

  @override
  String get importSvg => 'Import SVG';

  @override
  String get shareViaUrl => 'Share via URL';

  @override
  String get shapes => 'Shapes';

  @override
  String get autoLayout => 'Auto Layout';

  @override
  String get canvasSettings => 'Canvas Settings';

  @override
  String get zoomIn => 'Zoom In';

  @override
  String get zoomOut => 'Zoom Out';

  @override
  String get resetZoom => 'Reset Zoom';

  @override
  String get connectionStyle => 'Connection Style';

  @override
  String get arrowStyle => 'Arrow Style';

  @override
  String get width => 'Width';

  @override
  String get color => 'Color';

  @override
  String get saveToScratchpad => 'Save to Scratchpad';

  @override
  String get templateName => 'Template Name';

  @override
  String get category => 'Category';

  @override
  String get general => 'General';

  @override
  String savedToScratchpad(String name) {
    return 'Saved \"$name\" to Scratchpad';
  }

  @override
  String get moveToLayer => 'Move to Layer';

  @override
  String get noLayerDefault => 'No Layer (Default)';

  @override
  String get reset => 'Reset';

  @override
  String get fillColor => 'Fill Color';

  @override
  String get borderRadius => 'Border Radius';

  @override
  String get borderWidth => 'Border Width';

  @override
  String get removeWaypoint => 'Remove Waypoint';

  @override
  String get removeAllWaypoints => 'Remove All Waypoints';

  @override
  String get container => 'Container';

  @override
  String get straightPath => 'Straight';

  @override
  String get curvedPath => 'Curved';

  @override
  String get orthogonalPath => 'Orthogonal';

  @override
  String get addWaypoint => 'Add Waypoint';

  @override
  String get clearWaypoints => 'Clear Waypoints';

  @override
  String get copyStyle => 'Copy Style';

  @override
  String get pasteStyle => 'Paste Style';

  @override
  String get addTag => 'Add Tag...';

  @override
  String get removeTag => 'Remove Tag...';

  @override
  String get groupSelection => 'Group Selection';

  @override
  String get ungroup => 'Ungroup';

  @override
  String get title => 'Title';

  @override
  String get editStyle => 'Edit Style';

  @override
  String get tagName => 'Tag name';

  @override
  String get layerName => 'Layer name';

  @override
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';

  @override
  String get deleteLayer => 'Delete Layer';

  @override
  String get renameLayer => 'Rename Layer';

  @override
  String get addLayer => 'Add Layer';

  @override
  String get layers => 'Layers';

  @override
  String get layer => 'Layer';

  @override
  String get scratchpad => 'Scratchpad';

  @override
  String get rulers => 'Rulers';

  @override
  String get styleBrush => 'Style Brush';

  @override
  String get gridOn => 'Grid: On';

  @override
  String get gridOff => 'Grid: Off';

  @override
  String get snapOn => 'Snap: On';

  @override
  String get snapOff => 'Snap: Off';

  @override
  String get fit => 'Fit';

  @override
  String get importData => 'Import Data';

  @override
  String get importDataHint =>
      'Paste CSV, Mermaid diagram, or SVG code here...';

  @override
  String get shareUrlCopied => 'Share URL copied to clipboard';

  @override
  String get exportFailedNotRendered => 'Export failed: canvas not rendered';

  @override
  String get exportFailedPng => 'Export failed: could not generate PNG';

  @override
  String exportedPngTo(String path) {
    return 'Exported PNG to $path';
  }

  @override
  String pngExportFailed(String error) {
    return 'PNG export failed: $error';
  }

  @override
  String exportedTo(String path) {
    return 'Exported to $path';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get selectedClickToEdit =>
      'Selected · Click to edit · Del to delete · Drag corner to resize';

  @override
  String get editingEsc => 'Editing · Esc to finish';

  @override
  String get clickToConnect => 'Click a card to connect · Esc to cancel';

  @override
  String get styleBrushHint =>
      'Style Brush: click a card to apply style · Esc to cancel';

  @override
  String changeColorMulti(int count) {
    return 'Change Color ($count cards)';
  }

  @override
  String get noteContent => 'Note content...';

  @override
  String get typeSomething => 'Type something...';

  @override
  String get richText => 'Rich Text';

  @override
  String get underline => 'Underline';

  @override
  String get code => 'Code';

  @override
  String get text => 'Text';

  @override
  String editSegment(String type) {
    return 'Edit $type';
  }

  @override
  String get alignH => 'Align H';

  @override
  String get alignV => 'Align V';

  @override
  String get font => 'Font';

  @override
  String get textColor => 'Text Color';

  @override
  String get noLayersYet => 'No layers yet';

  @override
  String get addLayersHint => 'Add layers to organize your cards';

  @override
  String get noTemplatesYet => 'No templates yet';

  @override
  String get saveToScratchpadHint => 'Right-click a card → Save to Scratchpad';

  @override
  String get renameLayerTitle => 'Rename Layer';

  @override
  String get ok => 'OK';

  @override
  String get unlock => 'Unlock';

  @override
  String get lock => 'Lock';

  @override
  String get all => 'All';

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get load => 'Load';

  @override
  String get straight => 'Straight';

  @override
  String get curved => 'Curved';

  @override
  String get orthogonal => 'Orthogonal';

  @override
  String get align => 'Align';

  @override
  String get group => 'Group';

  @override
  String importFormat(String format) {
    return 'Import $format';
  }

  @override
  String get import => 'Import';

  @override
  String get grid => 'Grid';

  @override
  String get export => 'Export';

  @override
  String canvasStatusCardsConnectionsGroups(
    int cardCount,
    int connectionCount,
    int groupCount,
  ) {
    return '$cardCount cards · $connectionCount connections · $groupCount groups';
  }

  @override
  String selectedGroupHint(int count) {
    return '$count selected · Ctrl+G group · Del delete';
  }

  @override
  String get selectedSingleHint =>
      'Selected · Click to edit · Del to delete · Drag corner to resize';

  @override
  String get editingHint => 'Editing · Esc to finish';

  @override
  String get connectCardHint => 'Click a card to connect · Esc to cancel';

  @override
  String get addLayersToOrganize => 'Add layers to organize your cards';

  @override
  String get scratchpadEmptyHint => 'Right-click a card → Save to Scratchpad';

  @override
  String get add => 'Add';

  @override
  String layerNameWithNumber(int number) {
    return 'Layer $number';
  }
}
