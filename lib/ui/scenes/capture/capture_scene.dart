import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/browser_service.dart';
import '../../../services/knowledge_service.dart';
import '../../../services/ai_service.dart';
import '../../../data/models/note.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/note_sidebar.dart';
import '../../widgets/resizable_panel.dart';
import '../../pages/browser_page.dart';

part 'capture_panels.dart';
part 'capture_ai_summary.dart';
part 'capture_ai_summary_build.dart';

enum _RightPanelMode { summary, notePreview }

class CaptureScene extends ConsumerStatefulWidget {
  final bool leftPanelExpanded;
  final bool rightPanelExpanded;
  final VoidCallback? onToggleLeftPanel;
  final VoidCallback? onToggleRightPanel;
  final VoidCallback? onNoteOpened;

  const CaptureScene({
    super.key,
    this.leftPanelExpanded = true,
    this.rightPanelExpanded = true,
    this.onToggleLeftPanel,
    this.onToggleRightPanel,
    this.onNoteOpened,
  });

  @override
  ConsumerState<CaptureScene> createState() => _CaptureSceneState();
}

class _CaptureSceneState extends ConsumerState<CaptureScene> {
  _RightPanelMode _rightPanelMode = _RightPanelMode.summary;

  void _onNotePreview(String noteId) {
    setState(() => _rightPanelMode = _RightPanelMode.notePreview);
    if (!widget.rightPanelExpanded) {
      widget.onToggleRightPanel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(browserProvider);
    final knowledgeState = ref.watch(knowledgeProvider);

    return Stack(
      children: [
        Row(
          children: [
            AnimatedSize(
              duration: DesignDuration.panelSlide,
              curve: Curves.easeInOut,
              alignment: Alignment.centerLeft,
              child: widget.leftPanelExpanded
                  ? ResizablePanel(
                      initialWidth: 240,
                      minWidth: 180,
                      maxWidth: 400,
                      child: NoteSidebar(
                        onNoteOpened: widget.onNoteOpened,
                        onNotePreview: _onNotePreview,
                        onBookmarkOpened: (url) {
                          final bs = ref.read(browserProvider);
                          final existingTab = bs.tabs
                              .where((t) => t.url == url)
                              .firstOrNull;
                          if (existingTab != null) {
                            ref
                                .read(browserProvider.notifier)
                                .setActiveTab(existingTab.id);
                          } else {
                            ref
                                .read(browserProvider.notifier)
                                .createTab(url: url);
                          }
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (!widget.leftPanelExpanded)
              _PanelCollapseButton(
                alignment: Alignment.centerLeft,
                icon: Icons.chevron_right,
                onTap: widget.onToggleLeftPanel,
              ),
            Expanded(child: BrowserView()),
            if (!widget.rightPanelExpanded)
              _PanelCollapseButton(
                alignment: Alignment.centerRight,
                icon: Icons.chevron_left,
                onTap: widget.onToggleRightPanel,
              ),
            AnimatedSize(
              duration: DesignDuration.panelSlide,
              curve: Curves.easeInOut,
              alignment: Alignment.centerRight,
              child: widget.rightPanelExpanded
                  ? ResizablePanel(
                      initialWidth: 320,
                      minWidth: 200,
                      maxWidth: 450,
                      isLeft: false,
                      child: _rightPanelMode == _RightPanelMode.notePreview
                          ? _NotePreviewPanel(
                              note: knowledgeState.activeNote,
                              onClose: widget.onToggleRightPanel,
                              onEdit: widget.onNoteOpened,
                              onBack: () => setState(
                                () => _rightPanelMode = _RightPanelMode.summary,
                              ),
                            )
                          : _AiSummaryPanel(
                              url: browserState.activeTab?.url,
                              pageTitle: browserState.activeTab?.title,
                              activeNote: knowledgeState.activeNote,
                              onClose: widget.onToggleRightPanel,
                              onBack: knowledgeState.activeNote != null
                                  ? () => setState(
                                      () => _rightPanelMode =
                                          _RightPanelMode.notePreview,
                                    )
                                  : null,
                            ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}
