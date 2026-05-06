# RFBrowser — Service 层设计

---

## 6.1 Browser Service

```dart
abstract class BrowserService {
  // 标签管理
  Future<List<TabGroup>> getTabGroups();
  Future<void> groupTabs(List<TabId> tabIds, String groupName);
  Future<void> autoGroupTabs();                    // AI 自动分组

  // 内容提取
  Future<WebContent> extractContent(TabId tabId);  // 提取网页正文
  Future<String> extractSelection(TabId tabId);    // 提取选中文本
  Future<Uint8List> captureScreenshot(TabId tabId);// 截图

  // 剪藏
  Future<Note> clipToNote(TabId tabId, {ClipMode mode});
  // ClipMode: fullPage | selection | bookmark | simplified

  // Agent 操作
  Future<void> navigateTo(TabId tabId, String url);
  Future<void> clickElement(TabId tabId, String selector);
  Future<void> fillForm(TabId tabId, Map<String, String> fields);
  Future<String> extractData(TabId tabId, String schema);
}
```

## 6.2 Knowledge Service

```dart
abstract class KnowledgeService {
  // 笔记 CRUD
  Future<Note> createNote(String title, {String? folder, String? template});
  Future<Note> getNote(String id);
  Future<void> updateNote(String id, String content);
  Future<void> deleteNote(String id);
  Future<List<Note>> searchNotes(String query);

  // 链接
  Future<List<Link>> getBacklinks(String noteId);
  Future<List<UnlinkedMention>> getUnlinkedMentions(String noteId);
  Future<void> createLink(String sourceId, String targetId, LinkType type);

  // 标签
  Future<List<TagWithCount>> getAllTags();
  Future<List<Note>> getNotesByTag(String tag);

  // 日记
  Future<Note> getOrCreateDailyNote(DateTime date);

  // 图谱
  Future<GraphData> getGlobalGraph({GraphFilter? filter});
  Future<GraphData> getLocalGraph(String noteId, {int depth = 2});
}
```

## 6.3 AI Service

```dart
abstract class AIService {
  // 对话
  Stream<AIResponse> chat(ContextAssembly context, String message);
  Future<AIResponse> chatSync(ContextAssembly context, String message);

  // 上下文引用
  ContextAssembly createContext();
  ContextAssembly addReference(ContextAssembly ctx, ContextItem item);

  // 模型管理
  Future<List<ModelInfo>> getAvailableModels();
  Future<void> setActiveModel(String modelId);
  Future<void> configureModel(ModelConfig config);

  // 本地模型
  Future<bool> isLocalModelAvailable(String modelId);
  Future<void> downloadLocalModel(String modelId);
  Future<void> startLocalModelServer(String modelId);
}
```

## 6.4 Agent Service

```dart
abstract class AgentService {
  // 任务管理
  Future<AgentTask> createTask(String name, String description, ContextAssembly context);
  Future<void> startTask(String taskId);
  Future<void> pauseTask(String taskId);
  Future<void> cancelTask(String taskId);
  Stream<AgentStep> watchTask(String taskId);

  // 预定义任务
  Future<AgentTask> research(String topic, {int depth = 3});
  Future<AgentTask> summarizeUrls(List<String> urls);
  Future<AgentTask> extractDataFromWeb(String url, String schema);
  Future<AgentTask> monitorChanges(String url, String selector);

  // Skill 执行
  Future<AgentTask> executeSkill(String skillId, Map<String, dynamic> params);
}
```

## 6.5 Plugin Service

```dart
abstract class PluginService {
  // 插件生命周期
  Future<List<Plugin>> getInstalledPlugins();
  Future<void> installPlugin(String source);       // URL 或本地路径
  Future<void> uninstallPlugin(String pluginId);
  Future<void> enablePlugin(String pluginId);
  Future<void> disablePlugin(String pluginId);

  // 插件 API
  Future<dynamic> callPluginApi(String pluginId, String method, Map<String, dynamic> args);

  // 插件市场
  Future<List<PluginManifest>> searchPlugins(String query);
  Future<PluginManifest> getPluginDetail(String pluginId);
}
```

## 6.6 Sync Service

```dart
abstract class SyncService {
  // Git 同步
  Future<void> gitInit(String remoteUrl);
  Future<void> gitPull();
  Future<void> gitPush();
  Future<void> gitCommit(String message);
  Future<SyncStatus> getGitStatus();

  // WebDAV 同步
  Future<void> webdavConfigure(String url, String username, String password);
  Future<void> webdavSync();
  Future<SyncStatus> getWebdavStatus();

  // 冲突处理
  Future<List<Conflict>> getConflicts();
  Future<void> resolveConflict(String conflictId, ConflictResolution resolution);
}
```
