import 'agent_tool.dart';

class NavigateTool extends AgentTool {
  final Future<String> Function(String url) _navigate;

  NavigateTool(this._navigate)
      : super(
          name: 'navigate',
          description: 'Navigate to a URL using the headless browser',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'description': 'The URL to navigate to',
              },
            },
            'required': ['url'],
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) {
      return ToolResult.failure('url is required');
    }
    try {
      final result = await _navigate(url);
      return ToolResult.success(result);
    } catch (e) {
      return ToolResult.failure('Navigation failed: $e');
    }
  }
}

class ExtractTextTool extends AgentTool {
  final Future<String> Function(String url) _extractText;

  ExtractTextTool(this._extractText)
      : super(
          name: 'extract_text',
          description: 'Extract text content from a web page at the given URL',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'description': 'The URL to extract text from',
              },
            },
            'required': ['url'],
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) {
      return ToolResult.failure('url is required');
    }
    try {
      final text = await _extractText(url);
      return ToolResult.success(text);
    } catch (e) {
      return ToolResult.failure('Text extraction failed: $e');
    }
  }
}

class CreateNoteTool extends AgentTool {
  final Future<String> Function(String title, String content) _createNote;

  CreateNoteTool(this._createNote)
      : super(
          name: 'create_note',
          description: 'Create a new note in the knowledge base with a title and content',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'The title for the new note',
              },
              'content': {
                'type': 'string',
                'description': 'The Markdown content for the note',
              },
            },
            'required': ['title'],
          },
          isDestructive: false,
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    if (title == null || title.isEmpty) {
      return ToolResult.failure('title is required');
    }
    final content = args['content'] as String? ?? '';
    try {
      final result = await _createNote(title, content);
      return ToolResult.success(result);
    } catch (e) {
      return ToolResult.failure('Note creation failed: $e');
    }
  }
}

class SearchNotesTool extends AgentTool {
  final Future<List<Map<String, dynamic>>> Function(String query) _search;

  SearchNotesTool(this._search)
      : super(
          name: 'search_notes',
          description: 'Search notes in the knowledge base by query string',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': 'The search query to find relevant notes',
              },
            },
            'required': ['query'],
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final query = args['query'] as String?;
    if (query == null || query.isEmpty) {
      return ToolResult.failure('query is required');
    }
    try {
      final results = await _search(query);
      if (results.isEmpty) {
        return ToolResult.success('No notes found matching "$query"');
      }
      final output = results.take(10).map((r) {
        final title = r['title'] ?? r['path'] ?? 'Untitled';
        final score = r['score'] ?? '';
        return '- $title (score: $score)';
      }).join('\n');
      return ToolResult.success(
        'Found ${results.length} notes:\n$output',
        metadata: {'count': results.length, 'results': results.take(10).toList()},
      );
    } catch (e) {
      return ToolResult.failure('Search failed: $e');
    }
  }
}

class AIReasonTool extends AgentTool {
  final Future<String> Function(String prompt, String? systemPrompt) _chat;

  AIReasonTool(this._chat)
      : super(
          name: 'ai_reason',
          description:
              'Use AI to reason about information, summarize content, answer questions, or generate text. '
              'Provide a clear prompt describing what you need the AI to do.',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'prompt': {
                'type': 'string',
                'description': 'The prompt or question for the AI to process',
              },
              'system_prompt': {
                'type': 'string',
                'description':
                    'Optional system prompt to set AI behavior context',
              },
            },
            'required': ['prompt'],
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final prompt = args['prompt'] as String?;
    if (prompt == null || prompt.isEmpty) {
      return ToolResult.failure('prompt is required');
    }
    final systemPrompt = args['system_prompt'] as String?;
    try {
      final response = await _chat(prompt, systemPrompt);
      return ToolResult.success(response);
    } catch (e) {
      return ToolResult.failure('AI reasoning failed: $e');
    }
  }
}

class WebClipTool extends AgentTool {
  final Future<String> Function(String url, String format) _clip;

  WebClipTool(this._clip)
      : super(
          name: 'web_clip',
          description: 'Clip a web page and save it as a note in the knowledge base',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'description': 'The URL of the web page to clip',
              },
              'format': {
                'type': 'string',
                'description': 'Clip format: markdown, html, or plaintext',
                'enum': ['markdown', 'html', 'plaintext'],
              },
            },
            'required': ['url'],
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final url = args['url'] as String?;
    if (url == null || url.isEmpty) {
      return ToolResult.failure('url is required');
    }
    final format = args['format'] as String? ?? 'markdown';
    try {
      final result = await _clip(url, format);
      return ToolResult.success(result);
    } catch (e) {
      return ToolResult.failure('Web clip failed: $e');
    }
  }
}

class DeleteNoteTool extends AgentTool {
  final Future<bool> Function(String title) _deleteNote;

  DeleteNoteTool(this._deleteNote)
      : super(
          name: 'delete_note',
          description: 'Delete a note from the knowledge base by title',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'The title of the note to delete',
              },
            },
            'required': ['title'],
          },
          isDestructive: true,
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    if (title == null || title.isEmpty) {
      return ToolResult.failure('title is required');
    }
    try {
      final deleted = await _deleteNote(title);
      if (deleted) {
        return ToolResult.success('Note "$title" deleted');
      }
      return ToolResult.failure('Note "$title" not found');
    } catch (e) {
      return ToolResult.failure('Delete failed: $e');
    }
  }
}

class UpdateNoteTool extends AgentTool {
  final Future<String> Function(String title, String content) _updateNote;

  UpdateNoteTool(this._updateNote)
      : super(
          name: 'update_note',
          description: 'Update the content of an existing note by title',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'The title of the note to update',
              },
              'content': {
                'type': 'string',
                'description': 'The new content for the note',
              },
            },
            'required': ['title', 'content'],
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    final content = args['content'] as String?;
    if (title == null || title.isEmpty) {
      return ToolResult.failure('title is required');
    }
    if (content == null) {
      return ToolResult.failure('content is required');
    }
    try {
      final result = await _updateNote(title, content);
      return ToolResult.success(result);
    } catch (e) {
      return ToolResult.failure('Update failed: $e');
    }
  }
}

class ListNotesTool extends AgentTool {
  final Future<String> Function(String? tag, int limit) _listNotes;

  ListNotesTool(this._listNotes)
      : super(
          name: 'list_notes',
          description: 'List notes in the knowledge base, optionally filtered by tag',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'tag': {
                'type': 'string',
                'description': 'Optional tag to filter notes by',
              },
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of notes to return (default 20)',
              },
            },
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final tag = args['tag'] as String?;
    final limit = (args['limit'] as int?) ?? 20;
    try {
      final result = await _listNotes(tag, limit);
      return ToolResult.success(result);
    } catch (e) {
      return ToolResult.failure('List notes failed: $e');
    }
  }
}

class GetTagsTool extends AgentTool {
  final Future<String> Function() _getTags;

  GetTagsTool(this._getTags)
      : super(
          name: 'get_tags',
          description: 'Get all tags used across notes in the knowledge base',
          parametersSchema: const {
            'type': 'object',
            'properties': {},
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final result = await _getTags();
      return ToolResult.success(result);
    } catch (e) {
      return ToolResult.failure('Get tags failed: $e');
    }
  }
}

class MoveNoteTool extends AgentTool {
  final Future<String> Function(String title, String folder) _moveNote;

  MoveNoteTool(this._moveNote)
      : super(
          name: 'move_note',
          description: 'Move a note to a different folder',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'The title of the note to move',
              },
              'folder': {
                'type': 'string',
                'description': 'The target folder path',
              },
            },
            'required': ['title', 'folder'],
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final title = args['title'] as String?;
    final folder = args['folder'] as String?;
    if (title == null || title.isEmpty) {
      return ToolResult.failure('title is required');
    }
    if (folder == null || folder.isEmpty) {
      return ToolResult.failure('folder is required');
    }
    try {
      final result = await _moveNote(title, folder);
      return ToolResult.success(result);
    } catch (e) {
      return ToolResult.failure('Move failed: $e');
    }
  }
}

class RenameNoteTool extends AgentTool {
  final Future<String> Function(String oldTitle, String newTitle) _renameNote;

  RenameNoteTool(this._renameNote)
      : super(
          name: 'rename_note',
          description: 'Rename a note',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'old_title': {
                'type': 'string',
                'description': 'The current title of the note',
              },
              'new_title': {
                'type': 'string',
                'description': 'The new title for the note',
              },
            },
            'required': ['old_title', 'new_title'],
          },
        );

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final oldTitle = args['old_title'] as String?;
    final newTitle = args['new_title'] as String?;
    if (oldTitle == null || oldTitle.isEmpty) {
      return ToolResult.failure('old_title is required');
    }
    if (newTitle == null || newTitle.isEmpty) {
      return ToolResult.failure('new_title is required');
    }
    try {
      final result = await _renameNote(oldTitle, newTitle);
      return ToolResult.success(result);
    } catch (e) {
      return ToolResult.failure('Rename failed: $e');
    }
  }
}
