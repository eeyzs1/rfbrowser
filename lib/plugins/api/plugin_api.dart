abstract class PluginAPI {
  KnowledgeAPI get knowledge;
  BrowserAPI get browser;
  AIAPI get ai;
  UIAPI get ui;
  AgentAPI get agent;
}

abstract class KnowledgeAPI {
  Future<Map<String, dynamic>?> getNote(String id);
  Future<List<Map<String, dynamic>>> queryNotes(Map<String, dynamic> spec);
  Future<List<Map<String, dynamic>>> searchNotes(String query);
  Future<Map<String, dynamic>> createNote(Map<String, dynamic> spec);
  Future<void> updateNote(String id, String content);
}

abstract class BrowserAPI {
  Future<String?> getCurrentUrl();
  Future<String> getPageContent();
  Future<void> navigateTo(String url);
}

abstract class AIAPI {
  Future<String> chat(String message, {String? systemPrompt});
  Future<String> complete(String prompt);
}

abstract class UIAPI {
  void showNotification(String message);
  void registerCommand(String id, String name, void Function() handler);
  void showPanel(String id, String title, dynamic content);
}

abstract class AgentAPI {
  Future<List<Map<String, dynamic>>> listTools();
  Future<void> registerTool(Map<String, dynamic> toolDefinition);
  Future<void> unregisterTool(String toolName);
  Future<Map<String, dynamic>> executeTask(Map<String, dynamic> taskSpec);
  Future<Map<String, dynamic>?> getTaskStatus(String taskId);
  Future<List<Map<String, dynamic>>> listTasks();
}
