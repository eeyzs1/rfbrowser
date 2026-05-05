import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/skill_service.dart';
import '../../core/model/ai_provider.dart';
import '../../core/context/assembler.dart';
import '../../core/context/reference_parser.dart';

class AIChatPanel extends ConsumerStatefulWidget {
  const AIChatPanel({super.key});

  @override
  ConsumerState<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends ConsumerState<AIChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  List<_AutocompleteItem> _autocompleteItems = [];
  bool _showAutocomplete = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) {
      setState(() => _showAutocomplete = false);
      return;
    }

    final textBeforeCursor = text.substring(0, cursorPos);
    final atMatch = RegExp(r'@(\w*)$').firstMatch(textBeforeCursor);

    if (atMatch != null) {
      final query = atMatch.group(1) ?? '';
      _updateAutocomplete(query);
    } else {
      setState(() => _showAutocomplete = false);
    }
  }

  void _updateAutocomplete(String query) {
    final items = <_AutocompleteItem>[];

    items.add(
      _AutocompleteItem(
        label: '@note[...]',
        description: 'Reference a note',
        type: ContextRefType.note,
        insertText: '@note[]',
        cursorOffset: -1,
      ),
    );
    items.add(
      _AutocompleteItem(
        label: '@web[current]',
        description: 'Reference current web page',
        type: ContextRefType.web,
        insertText: '@web[current]',
        cursorOffset: 0,
      ),
    );
    items.add(
      _AutocompleteItem(
        label: '@clip[...]',
        description: 'Reference a web clip',
        type: ContextRefType.clip,
        insertText: '@clip[]',
        cursorOffset: -1,
      ),
    );

    if (query.isNotEmpty) {
      final knowledge = ref.read(knowledgeProvider);
      final noteResults = knowledge.notes
          .where(
            (n) =>
                n.title.toLowerCase().contains(query.toLowerCase()),
          )
          .take(10)
          .toList();
      for (final note in noteResults) {
        items.add(
          _AutocompleteItem(
            label: '@note[${note.title}]',
            description: note.content.length > 50
                ? '${note.content.substring(0, 50)}...'
                : note.content,
            type: ContextRefType.note,
            insertText: '@note[${note.title}]',
            cursorOffset: 0,
          ),
        );
      }
    }

    setState(() {
      _autocompleteItems = items;
      _showAutocomplete = items.isNotEmpty;
    });
  }

  void _applyAutocomplete(_AutocompleteItem item) {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final atMatch = RegExp(r'@\w*$').firstMatch(textBeforeCursor);

    if (atMatch != null) {
      final before = text.substring(0, atMatch.start);
      final after = text.substring(cursorPos);
      final newText = '$before${item.insertText}$after';
      _controller.text = newText;
      final newCursorPos = atMatch.start + item.insertText.length + item.cursorOffset;
      _controller.selection = TextSelection.collapsed(
        offset: newCursorPos.clamp(0, newText.length),
      );
    }

    setState(() {
      _showAutocomplete = false;
      _autocompleteItems = [];
    });
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiProvider);
    final theme = Theme.of(context);

    ref.listen<AIState>(aiProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          (prev?.messages.isNotEmpty == true &&
              next.messages.isNotEmpty &&
              prev!.messages.last.content != next.messages.last.content)) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        Expanded(
          child: aiState.messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.psychology,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('AI Assistant', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('Ask me anything', style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: aiState.messages.length,
                  itemBuilder: (context, index) {
                    final msg = aiState.messages[index];
                    return _buildMessage(theme, msg);
                  },
                ),
        ),
        if (aiState.error != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aiState.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: () => ref.read(aiProvider.notifier).clearError(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              _buildModelSelector(theme, aiState),
              const SizedBox(width: 4),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.auto_awesome, size: 12),
                  onPressed: () => _showSkillPicker(theme),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: 'Skills',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 12),
                  onPressed: () =>
                      ref.read(aiProvider.notifier).clearMessages(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  tooltip: 'Clear Chat',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showAutocomplete && _autocompleteItems.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _autocompleteItems.length,
                    itemBuilder: (context, index) {
                      final item = _autocompleteItems[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          _iconForRefType(item.type),
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          item.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: item.description.isNotEmpty
                            ? Text(
                                item.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => _applyAutocomplete(item),
                      );
                    },
                  ),
                ),
              if (_showAutocomplete) const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Type a message... (use @ to reference)',
                        hintStyle: theme.textTheme.bodySmall,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: aiState.isLoading
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    onPressed: aiState.isLoading ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(ThemeData theme, ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: isUser
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.all(8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isUser
              ? null
              : Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: isUser
            ? SelectableText(msg.content, style: theme.textTheme.bodyMedium)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: msg.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                      code: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        backgroundColor: theme.colorScheme.surface,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      a: TextStyle(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                      listBullet: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (msg.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () => _saveAsNote(msg.content),
                        icon: const Icon(Icons.save, size: 12),
                        label: Text(
                          'Save as Note',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  if (msg.isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Streaming...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildModelSelector(ThemeData theme, AIState aiState) {
    final aiConfig = ref.read(aiConfigProvider);
    final providers = aiConfig.providers
        .where((p) => p.isEnabled)
        .toList();
    final activeModel = aiState.activeModel ?? aiConfig.activeModel;
    final activeProvider =
        aiState.activeProvider ?? aiConfig.activeProvider;

    if (providers.isEmpty) {
      return TextButton.icon(
        onPressed: () => _showAddProviderDialog(theme),
        icon: const Icon(Icons.add, size: 14),
        label: Text('Add Provider', style: theme.textTheme.bodySmall),
      );
    }

    final selectWidget = activeModel != null && activeProvider != null
        ? _buildActiveModelChip(theme, activeProvider, activeModel)
        : _buildSelectModelButton(theme);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        selectWidget,
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            icon: const Icon(Icons.add, size: 12),
            onPressed: () => _showAddProviderDialog(theme),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: 'Add Provider',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              side: BorderSide(color: theme.dividerColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveModelChip(
    ThemeData theme,
    AIProvider provider,
    AIModel model,
  ) {
    return InkWell(
      onTap: () => _showModelPicker(theme),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(provider.protocol.icon, size: 12, color: theme.hintColor),
            const SizedBox(width: 4),
            Text(
              model.displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (model.supportsVision) ...[
              const SizedBox(width: 2),
              Icon(Icons.visibility, size: 10, color: theme.hintColor),
            ],
            const SizedBox(width: 2),
            Icon(Icons.unfold_more, size: 12, color: theme.hintColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectModelButton(ThemeData theme) {
    return InkWell(
      onTap: () => _showModelPicker(theme),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select', style: theme.textTheme.bodySmall),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 12, color: theme.hintColor),
          ],
        ),
      ),
    );
  }

  void _showModelPicker(ThemeData theme) {
    final aiConfig = ref.read(aiConfigProvider);
    final providers = aiConfig.providers
        .where((p) => p.isEnabled)
        .toList();
    final activeConfig = aiConfig.activeConfig;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Model'),
        contentPadding: const EdgeInsets.only(top: 16),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: providers.map((provider) {
              final models = aiConfig.modelsForProvider(provider.id);
              final isActiveProvider = activeConfig?.providerId == provider.id;
              return ExpansionTile(
                initiallyExpanded: isActiveProvider,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: 4,
                ),
                leading: Icon(
                  provider.protocol.icon,
                  size: 16,
                  color: theme.hintColor,
                ),
                title: Text(
                  provider.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActiveProvider
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                trailing: models.isEmpty
                    ? Text(
                        '0 models',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      )
                    : null,
                children: models.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'No models. Refresh in Settings.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ]
                    : models.map((model) {
                        final isActive =
                            isActiveProvider &&
                            activeConfig?.modelId == model.id;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isActive
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.hintColor,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  model.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              ...model.capabilities.map(
                                (cap) => Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: Icon(
                                    cap == ModelCapability.vision
                                        ? Icons.visibility
                                        : Icons.text_fields,
                                    size: 12,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            ref
                                .read(aiProvider.notifier)
                                .setActiveModel(provider, model);
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddProviderDialog(ThemeData theme) {
    final nameController = TextEditingController();
    final baseUrlController = TextEditingController(
      text: ApiProtocol.openaiCompatible.defaultBaseUrl,
    );
    final apiKeyController = TextEditingController();
    ApiProtocol selectedProtocol = ApiProtocol.openaiCompatible;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add Provider'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Provider Name',
                        hintText: 'My OpenAI, Work Azure, etc.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ApiProtocol>(
                      key: ValueKey(selectedProtocol),
                      initialValue: selectedProtocol,
                      decoration: const InputDecoration(labelText: 'Protocol'),
                      items: ApiProtocol.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.label),
                            ),
                          )
                          .toList(),
                      onChanged: (p) {
                        if (p != null) {
                          setState(() {
                            selectedProtocol = p;
                            if (baseUrlController.text.isEmpty ||
                                ApiProtocol.values.any(
                                  (proto) =>
                                      baseUrlController.text ==
                                      proto.defaultBaseUrl,
                                )) {
                              baseUrlController.text = p.defaultBaseUrl;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Base URL',
                        hintText: 'https://api.example.com',
                      ),
                    ),
                    if (selectedProtocol.requiresApiKey) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText:
                              selectedProtocol == ApiProtocol.openaiCompatible
                              ? 'sk-...'
                              : '',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final provider = AIProvider(
                    id: 'provider_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    protocol: selectedProtocol,
                    baseUrl: baseUrlController.text.trim().replaceAll(
                      RegExp(r'/$'),
                      '',
                    ),
                    apiKey: selectedProtocol.requiresApiKey
                        ? apiKeyController.text.trim()
                        : null,
                  );
                  ref.read(aiConfigProvider.notifier).addProvider(provider);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final knowledge = ref.read(knowledgeProvider);
    final browser = ref.read(browserProvider);
    final assembler = ref.read(assemblerProvider);

    final assembly = await assembler.assemble(
      text,
      currentNote: knowledge.activeNote,
      currentWebUrl: browser.activeTab?.url,
      currentWebTitle: browser.activeTab?.title,
      allNotes: knowledge.notes,
    );

    final contextStr = assembly.toPrompt();
    final effectiveContext =
        contextStr.isNotEmpty ? contextStr : null;

    if (assembly.truncated && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Context truncated to fit token limit'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
    }

    ref.read(aiProvider.notifier).sendMessage(text, context: effectiveContext);
  }

  void _showSkillPicker(ThemeData theme) async {
    final skillService = ref.read(skillServiceProvider);
    if (skillService == null) return;

    final skills = await skillService.getAllSkills();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Skills'),
          ],
        ),
        contentPadding: const EdgeInsets.only(top: 16),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: skills.map((skill) {
              return ListTile(
                dense: true,
                leading: Icon(
                  skill.isBuiltin ? Icons.bolt : Icons.extension,
                  size: 16,
                  color: skill.isBuiltin
                      ? theme.colorScheme.primary
                      : theme.hintColor,
                ),
                title: Text(
                  skill.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: skill.description.isNotEmpty
                    ? Text(
                        skill.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _executeSkill(skill);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _executeSkill(dynamic skill) {
    final knowledge = ref.read(knowledgeProvider);
    final browser = ref.read(browserProvider);
    final activeNote = knowledge.activeNote;
    final activeTab = browser.activeTab;

    var prompt = skill.prompt as String;

    prompt = prompt.replaceAll(
      '@note[current]',
      activeNote != null
          ? 'Note "${activeNote.title}":\n${activeNote.content.length > 3000 ? '${activeNote.content.substring(0, 3000)}...(truncated)' : activeNote.content}'
          : '(No note currently open)',
    );

    prompt = prompt.replaceAll(
      '@web[current]',
      activeTab != null && activeTab.url.isNotEmpty
          ? 'Web page "${activeTab.title}" (${activeTab.url})'
          : '(No web page currently open)',
    );

    prompt = prompt.replaceAll('@note[daily]', '(Daily note not loaded)');

    if (skill.params != null && skill.params.isNotEmpty) {
      _promptForParams(skill, prompt);
    } else {
      final contextBuffer = StringBuffer();
      if (activeNote != null) {
        contextBuffer.writeln('[Current Note: ${activeNote.title}]');
      }
      if (activeTab != null && activeTab.url.isNotEmpty) {
        contextBuffer.writeln('[Current Page: ${activeTab.title}]');
      }
      ref
          .read(aiProvider.notifier)
          .sendMessage(
            prompt,
            context: contextBuffer.isNotEmpty ? contextBuffer.toString() : null,
          );
    }
  }

  void _saveAsNote(String content) async {
    final browser = ref.read(browserProvider);
    final activeTab = browser.activeTab;

    await ref.read(knowledgeProvider.notifier).clipToNote(
          url: activeTab?.url ?? '',
          title: 'AI Response — ${DateTime.now().toString().substring(0, 16)}',
          content: content,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved as note')),
      );
    }
  }

  void _promptForParams(dynamic skill, String basePrompt) {
    final controllers = <String, TextEditingController>{};
    for (final param in skill.params.values) {
      controllers[param.name] = TextEditingController();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(skill.name),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: skill.params.values.map((param) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[param.name],
                  decoration: InputDecoration(
                    labelText: param.name,
                    hintText: param.description,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              var prompt = basePrompt;
              controllers.forEach((key, controller) {
                prompt = prompt.replaceAll('{{$key}}', controller.text.trim());
              });
              Navigator.pop(ctx);
              ref.read(aiProvider.notifier).sendMessage(prompt);
            },
            child: const Text('Run'),
          ),
        ],
      ),
    );
  }

  IconData _iconForRefType(ContextRefType type) {
    switch (type) {
      case ContextRefType.note:
        return Icons.description;
      case ContextRefType.web:
        return Icons.language;
      case ContextRefType.clip:
        return Icons.content_cut;
      case ContextRefType.file:
        return Icons.insert_drive_file;
      case ContextRefType.agent:
        return Icons.smart_toy;
    }
  }
}

class _AutocompleteItem {
  final String label;
  final String description;
  final ContextRefType type;
  final String insertText;
  final int cursorOffset;

  _AutocompleteItem({
    required this.label,
    this.description = '',
    required this.type,
    required this.insertText,
    this.cursorOffset = 0,
  });
}
