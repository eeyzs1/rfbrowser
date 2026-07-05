// ignore_for_file: unused_element, unused_element_parameter
part of 'capture_scene.dart';

enum _SummaryMode { idle, loading, done, error }

enum _ErrorType { network, rateLimit, noContent, unknown }

class _AiSummaryPanel extends ConsumerStatefulWidget {
  final String? url;
  final String? pageTitle;
  final Note? activeNote;
  final VoidCallback? onClose;
  final VoidCallback? onBack;

  const _AiSummaryPanel({
    this.url,
    this.pageTitle,
    this.activeNote,
    this.onClose,
    this.onBack,
  });

  @override
  ConsumerState<_AiSummaryPanel> createState() => _AiSummaryPanelState();
}

/// Base class declaring the contract used by the build mixin.
abstract class _AiSummaryPanelBase extends ConsumerState<_AiSummaryPanel> {
  _SummaryMode get summaryMode;
  String? get summaryText;
  String? get summaryError;
  _ErrorType get summaryErrorType;
  bool get summarizeNote;
  bool get canSummarize;

  String sourceLabel(AppLocalizations l);
  _ErrorType classifyError(String? error);
  String errorRecoveryHint(AppLocalizations l);
  void requestSummary();
  void saveAsNote();
  void reset();
  void setSummaryState({
    _SummaryMode? mode,
    String? text,
    String? error,
    _ErrorType? errorType,
  });
  void setSummarizeNote(bool value);
}

class _AiSummaryPanelState extends _AiSummaryPanelBase
    with _AiSummaryPanelBuildMixin {
  _SummaryMode _summaryMode = _SummaryMode.idle;
  String? _summaryText;
  String? _summaryError;
  _ErrorType _summaryErrorType = _ErrorType.unknown;
  bool _summarizeNote = false;

  @override
  _SummaryMode get summaryMode => _summaryMode;
  @override
  String? get summaryText => _summaryText;
  @override
  String? get summaryError => _summaryError;
  @override
  _ErrorType get summaryErrorType => _summaryErrorType;
  @override
  bool get summarizeNote => _summarizeNote;

  @override
  bool get canSummarize => _summarizeNote
      ? widget.activeNote != null
      : (widget.url != null && widget.url!.isNotEmpty);

  @override
  String sourceLabel(AppLocalizations l) => _summarizeNote ? l.note : l.webPage;

  @override
  _ErrorType classifyError(String? error) {
    if (error == null) return _ErrorType.unknown;
    final lower = error.toLowerCase();
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('socket')) {
      return _ErrorType.network;
    }
    if (lower.contains('rate') ||
        lower.contains('limit') ||
        lower.contains('429') ||
        lower.contains('quota')) {
      return _ErrorType.rateLimit;
    }
    if (lower.contains('empty') ||
        lower.contains('no content') ||
        lower.contains('no text')) {
      return _ErrorType.noContent;
    }
    return _ErrorType.unknown;
  }

  @override
  String errorRecoveryHint(AppLocalizations l) {
    return switch (_summaryErrorType) {
      _ErrorType.network => l.errorNetworkHint,
      _ErrorType.rateLimit => l.errorRateLimitHint,
      _ErrorType.noContent => l.errorNoContentHint,
      _ErrorType.unknown => l.errorUnknownHint,
    };
  }

  @override
  void requestSummary() {
    if (!canSummarize) return;

    setState(() {
      _summaryMode = _SummaryMode.loading;
      _summaryError = null;
    });

    final aiNotifier = ref.read(aiProvider.notifier);

    if (_summarizeNote && widget.activeNote != null) {
      final note = widget.activeNote!;
      aiNotifier.sendMessage(
        'Please summarize the main content and key points of this note in Chinese:\n\nTitle: ${note.title}\n\nContent:\n${note.content}',
        systemPrompt:
            'You are a helpful research assistant. Provide concise, well-structured summaries in Chinese. Focus on key arguments, findings, and insights.',
      );
    } else {
      final pageInfo = '${widget.pageTitle ?? 'Page'}\n${widget.url!}';
      aiNotifier.sendMessage(
        'Please summarize the main content and key points of this web page in Chinese:\n\n$pageInfo',
        systemPrompt:
            'You are a helpful research assistant. Provide concise, well-structured summaries in Chinese. Focus on key arguments, findings, and insights.',
      );
    }
  }

  @override
  void saveAsNote() async {
    if (_summaryText == null || _summaryText!.isEmpty) return;
    final l = AppLocalizations.of(context);
    if (l == null) return;
    final title = l.summaryTitle(
      sourceLabel(l),
      widget.pageTitle ?? widget.activeNote?.title ?? 'Untitled',
    );
    await ref
        .read(knowledgeProvider.notifier)
        .createNote(title: title, content: _summaryText!);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(l.savedAsNote(title)),
        ),
      );
    }
  }

  @override
  void reset() {
    setState(() {
      _summaryMode = _SummaryMode.idle;
      _summaryText = null;
      _summaryError = null;
    });
  }

  @override
  void setSummaryState({
    _SummaryMode? mode,
    String? text,
    String? error,
    _ErrorType? errorType,
  }) {
    setState(() {
      if (mode != null) _summaryMode = mode;
      if (text != null) _summaryText = text;
      if (error != null) _summaryError = error;
      if (errorType != null) _summaryErrorType = errorType;
    });
  }

  @override
  void setSummarizeNote(bool value) {
    setState(() {
      _summarizeNote = value;
    });
  }

  @override
  Widget build(BuildContext context) => buildAiSummaryPanel(context);
}
