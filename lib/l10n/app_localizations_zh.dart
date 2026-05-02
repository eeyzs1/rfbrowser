// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'RFBrowser';

  @override
  String get home => '首页';

  @override
  String get browser => '浏览器';

  @override
  String get editor => '编辑器';

  @override
  String get graph => '图谱';

  @override
  String get canvas => '画布';

  @override
  String get aiChat => 'AI 对话';

  @override
  String get settings => '设置';

  @override
  String get plugins => '插件';

  @override
  String get search => '搜索';

  @override
  String get newNote => '新建笔记';

  @override
  String get newTab => '新建标签页';

  @override
  String get closeTab => '关闭标签页';

  @override
  String get closeAllTabs => '关闭所有标签页';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get move => '移动';

  @override
  String get copy => '复制';

  @override
  String get paste => '粘贴';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get cut => '剪切';

  @override
  String get selectAll => '全选';

  @override
  String get backlinks => '反向链接';

  @override
  String get outline => '大纲';

  @override
  String get tags => '标签';

  @override
  String get untagged => '未标签';

  @override
  String get dailyNotes => '日记';

  @override
  String get clippings => '剪藏';

  @override
  String get attachments => '附件';

  @override
  String get templates => '模板';

  @override
  String get skills => '技能';

  @override
  String get agent => '智能体';

  @override
  String get sync => '同步';

  @override
  String get gitSync => 'Git 同步';

  @override
  String get webdavSync => 'WebDAV 同步';

  @override
  String get language => '语言';

  @override
  String get english => '英文';

  @override
  String get chinese => '中文';

  @override
  String get followSystem => '跟随系统';

  @override
  String get darkMode => '深色模式';

  @override
  String get toggleDarkLight => '切换深色/浅色主题';

  @override
  String get lightMode => '浅色模式';

  @override
  String get theme => '主题';

  @override
  String get accentColor => '强调色';

  @override
  String get customColor => '自定义颜色';

  @override
  String get components => '组件';

  @override
  String get buttonShape => '按钮形状';

  @override
  String get rounded => '圆角';

  @override
  String get sharp => '直角';

  @override
  String get pill => '胶囊';

  @override
  String get cornerRadius => '圆角半径';

  @override
  String get density => '密度';

  @override
  String get compact => '紧凑';

  @override
  String get comfortable => '舒适';

  @override
  String get spacious => '宽松';

  @override
  String get iconSize => '图标大小';

  @override
  String get small => '小';

  @override
  String get medium => '中';

  @override
  String get large => '大';

  @override
  String get fontSize => '字体大小';

  @override
  String get preview => '预览';

  @override
  String get filled => '填充按钮';

  @override
  String get outlined => '描边按钮';

  @override
  String get aiModels => 'AI 模型';

  @override
  String get openaiApiKey => 'OpenAI API 密钥';

  @override
  String get notSet => '未设置';

  @override
  String get activeModel => '当前模型';

  @override
  String get localModelOllama => '本地模型 (Ollama)';

  @override
  String get configureLocalModel => '配置本地模型端点';

  @override
  String get ollamaEndpoint => 'Ollama 端点';

  @override
  String get ollamaHint => '使用本地模型前请确保 Ollama 已在本地运行。';

  @override
  String get editorSection => '编辑器';

  @override
  String get syncSection => '同步';

  @override
  String get configureGitRemote => '配置 Git 远程仓库进行知识库同步';

  @override
  String get configureWebdav => '配置 WebDAV 服务器进行知识库同步';

  @override
  String get remoteUrl => '远程地址';

  @override
  String get serverUrl => '服务器地址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get about => '关于';

  @override
  String get versionInfo => 'v0.2.0 - AI 驱动的知识浏览器';

  @override
  String get license => '许可证';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get selectModel => '选择模型';

  @override
  String get componentDensity => '组件密度';

  @override
  String get apply => '应用';

  @override
  String get customAccentColor => '自定义强调色';

  @override
  String get noVaultConnected => '未连接知识库';

  @override
  String get openVaultToStart => '打开知识库开始编写笔记';

  @override
  String get noNoteSelected => '未选择笔记';

  @override
  String get createOrSelectNote => '新建笔记或从侧边栏选择一篇';

  @override
  String get edit => '编辑';

  @override
  String get startWriting => '开始写作...';

  @override
  String get splitRight => '向右分割';

  @override
  String get splitLeft => '向左分割';

  @override
  String get splitUp => '向上分割';

  @override
  String get splitDown => '向下分割';

  @override
  String get changeView => '切换视图';

  @override
  String get close => '关闭';

  @override
  String get changeViewTitle => '打开视图';

  @override
  String get notes => '笔记';

  @override
  String get tabs => '标签页';

  @override
  String get ready => '就绪';

  @override
  String get noVault => '无知识库';

  @override
  String notesCount(int count) {
    return '$count 篇笔记';
  }

  @override
  String tabsCount(int count) {
    return '$count 个标签页';
  }

  @override
  String get clearChat => '清空对话';

  @override
  String get typeMessage => '输入消息...';

  @override
  String get askAnything => '问任何事... (Ctrl+K)';

  @override
  String get noResults => '未找到结果';

  @override
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get confirm => '确认';

  @override
  String get warning => '警告';

  @override
  String get info => '信息';

  @override
  String get vault => '知识库';

  @override
  String get openVault => '打开知识库';

  @override
  String get createVault => '创建知识库';

  @override
  String get selectVault => '选择知识库位置';

  @override
  String get welcome => '欢迎使用 RFBrowser';

  @override
  String get welcomeDesc => '打开已有知识库或创建新的知识库开始使用。';

  @override
  String get recentVaults => '最近的知识库';

  @override
  String get tabGroups => '标签组';

  @override
  String get newGroup => '新建分组';

  @override
  String get ungrouped => '未分组';

  @override
  String get clipPage => '剪藏页面';

  @override
  String get clipSelection => '剪藏选区';

  @override
  String get clipBookmark => '添加书签';

  @override
  String get commandBar => '命令栏';

  @override
  String get runCommand => '运行命令';

  @override
  String get noBacklinks => '暂无反向链接';

  @override
  String get noOutline => '暂无大纲';

  @override
  String get noteSaved => '笔记已保存';

  @override
  String get noteDeleted => '笔记已删除';

  @override
  String get vaultOpened => '知识库已打开';

  @override
  String get syncComplete => '同步完成';

  @override
  String get syncFailed => '同步失败';

  @override
  String get agentRunning => '智能体运行中...';

  @override
  String get agentCompleted => '智能体任务完成';

  @override
  String get agentFailed => '智能体任务失败';

  @override
  String get newNoteTitle => '新建笔记';

  @override
  String get noteTitle => '笔记标题';

  @override
  String get create => '创建';

  @override
  String get comingInPhase4 => '第四阶段推出';

  @override
  String get gitSyncConfig => 'Git 同步配置';

  @override
  String get webdavConfig => 'WebDAV 配置';

  @override
  String get providers => '提供商';

  @override
  String get addProvider => '添加提供商';

  @override
  String get providerName => '提供商名称';

  @override
  String get providerNameHint => '我的 OpenAI、公司 Azure 等';

  @override
  String get protocol => '协议';

  @override
  String get baseUrl => '基础 URL';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get leaveEmptyToKeep => '留空保持不变';

  @override
  String get editProvider => '编辑提供商';

  @override
  String get deleteProvider => '删除提供商';

  @override
  String get deleteProviderConfirm => '删除提供商及其所有模型？';

  @override
  String get addCustomModel => '添加自定义模型';

  @override
  String get modelId => '模型 ID';

  @override
  String get displayName => '显示名称';

  @override
  String get displayNameHint => '我的自定义模型';

  @override
  String get refreshModels => '刷新模型';

  @override
  String get refresh => '刷新';

  @override
  String get noProvidersHint => '尚未配置提供商，请添加一个以开始使用。';

  @override
  String get noModelsFound => '未找到模型';

  @override
  String get modelsRefreshed => '发现';

  @override
  String get disabled => '已禁用';

  @override
  String get enable => '启用';

  @override
  String get custom => '自定义';

  @override
  String get appSubtitle => 'AI 驱动的知识浏览器';

  @override
  String get removeVault => '移除知识库';

  @override
  String removeVaultConfirm(String name) {
    return '从最近列表中移除「$name」？';
  }

  @override
  String get remove => '移除';

  @override
  String get alwaysShowWelcomePage => '总是显示欢迎页';

  @override
  String get alwaysShowWelcomePageDesc => '每次启动时显示欢迎页，而不是直接打开上次的知识库';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String daysAgo(int count) {
    return '$count 天前';
  }
}
