part of '../ai_chat_panel.dart';

mixin _AIChatActionsMixin on _AIChatPanelStateBase {
  @override
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
    final effectiveContext = contextStr.isNotEmpty ? contextStr : null;

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

    ref
        .read(aiProvider.notifier)
        .sendMessage(
          text,
          context: effectiveContext,
          tools: _agentMode
              ? ref.read(agentChatBridgeProvider).toOpenAITools()
              : null,
          bridge: _agentMode ? ref.read(agentChatBridgeProvider) : null,
        );
  }

  @override
  void _saveAsNote(String content) async {
    final browser = ref.read(browserProvider);
    final activeTab = browser.activeTab;

    await ref
        .read(knowledgeProvider.notifier)
        .clipToNote(
          url: activeTab?.url ?? '',
          title: 'AI Response — ${DateTime.now().toString().substring(0, 16)}',
          content: content,
        );

    if (mounted) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.savedAsNoteToast)));
    }
  }
}
