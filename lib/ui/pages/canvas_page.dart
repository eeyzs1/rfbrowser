// ignore_for_file: unused_element, unused_element_parameter
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/canvas_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../services/settings_service.dart';
import '../../services/shortcut_service.dart';
import '../../data/models/canvas_model.dart';
import '../../data/models/note.dart';
import '../../data/stores/vault_store.dart';
import '../../core/link/link_resolver.dart';
import '../../core/logging/app_logger.dart';
import '../../core/graph/canvas_geometry.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/canvas_painter.dart';
import '../layout/keyboard_util.dart';
import '../widgets/canvas/hover_popup_menu.dart';
import '../widgets/canvas/minimap_painter.dart';
import 'canvas/dialogs/add_tag_dialog.dart';
import 'canvas/dialogs/background_color_picker_dialog.dart';
import 'canvas/dialogs/color_picker_dialog.dart';
import 'canvas/dialogs/layer_panel_dialog.dart';
import 'canvas/dialogs/move_to_layer_dialog.dart';
import 'canvas/dialogs/remove_tag_dialog.dart';
import 'canvas/dialogs/scratchpad_dialog.dart';

part 'canvas/canvas_input_handlers.dart';
part 'canvas/canvas_input_hittest.dart';
part 'canvas/canvas_alignment_guides.dart';
part 'canvas/canvas_input_gestures_scale.dart';
part 'canvas/canvas_input_gestures_tap.dart';
part 'canvas/canvas_input_gestures_pointer.dart';
part 'canvas/canvas_toolbar.dart';
part 'canvas/canvas_toolbar_popups.dart';
part 'canvas/canvas_toolbar_popups_more.dart';
part 'canvas/canvas_panels.dart';
part 'canvas/canvas_canvas_mgmt.dart';
part 'canvas/canvas_context_menus.dart';
part 'canvas/canvas_context_menu_cards.dart';
part 'canvas/canvas_context_menu_card_ops.dart';
part 'canvas/canvas_dialogs.dart';
part 'canvas/canvas_dialogs_connections.dart';
part 'canvas/canvas_dialogs_edit.dart';
part 'canvas/canvas_dialogs_edit_rich.dart';
part 'canvas/canvas_dialogs_settings.dart';
part 'canvas/canvas_export_panels.dart';
part 'canvas/canvas_state_base.dart';
part 'canvas/canvas_view_build.dart';

enum _ResizeEdge { none, right, bottom, corner }

class _CameraNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class CanvasView extends ConsumerStatefulWidget {
  const CanvasView({super.key});

  @override
  ConsumerState<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends _CanvasViewStateBase
    with
        _CanvasInputHandlersMixin,
        _CanvasInputHitTestMixin,
        _CanvasAlignmentGuidesMixin,
        _CanvasScaleGesturesMixin,
        _CanvasTapGesturesMixin,
        _CanvasPointerGesturesMixin,
        _CanvasToolbarMixin,
        _CanvasToolbarPopupsMixin,
        _CanvasToolbarPopupsMoreMixin,
        _CanvasPanelsMixin,
        _CanvasCanvasMgmtMixin,
        _CanvasContextMenusMixin,
        _CanvasContextMenuCardsMixin,
        _CanvasContextMenuCardOpsMixin,
        _CanvasDialogsMixin,
        _CanvasDialogsConnectionsMixin,
        _CanvasDialogsEditRichMixin,
        _CanvasDialogsEditMixin,
        _CanvasDialogsSettingsMixin,
        _CanvasExportPanelsMixin,
        _CanvasViewBuildMixin {
  @override
  void initState() {
    super.initState();
    _inlineTitleCtrl = TextEditingController();
    _inlineContentCtrl = TextEditingController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCanvas());
  }

  @override
  Future<void> _initCanvas() async {
    final notifier = ref.read(canvasProvider.notifier);
    await notifier.initialize();
    if (mounted) {
      _centerOrFitView();
      _loadImageCards(ref.read(canvasProvider).cards);
      // 检查是否首次打开画布，决定是否显示交互引导。
      await _checkCanvasGuide();
    }
  }

  Future<void> _checkCanvasGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('hasSeenCanvasGuide') ?? false;
      if (!seen && mounted) {
        setState(() => _showCanvasGuide = true);
      }
    } catch (_) {
      // 读取失败时不显示引导，避免阻塞画布初始化。
    }
  }

  Future<void> _dismissCanvasGuide() async {
    setState(() => _showCanvasGuide = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenCanvasGuide', true);
    } catch (_) {
      // 持久化失败不影响关闭引导。
    }
  }

  @override
  void _centerOrFitView() {
    final cards = ref.read(canvasProvider).cards;
    if (cards.isEmpty) {
      _cameraX = 0;
      _cameraY = 0;
      _scale = 1.0;
      _cameraNotifier.notify();
    } else {
      _fitToContent();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraNotifier.dispose();
    _inlineTitleCtrl.dispose();
    _inlineContentCtrl.dispose();
    _inlineTitleFocus?.dispose();
    _inlineContentFocus?.dispose();
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _hoverThrottle?.cancel();
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
    super.dispose();
  }

  @override
  void _startInlineEditing(String cardId) {
    final card = ref.read(canvasProvider.notifier).cardById(cardId);
    if (card == null) return;
    _inlineTitleFocus?.dispose();
    _inlineContentFocus?.dispose();
    _inlineTitleFocus = FocusNode();
    _inlineContentFocus = FocusNode();
    _inlineTitleCtrl.text = card.title;
    _inlineContentCtrl.text = card.content;
    ref.read(canvasProvider.notifier).startInlineEditing(cardId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inlineTitleFocus?.requestFocus();
    });
  }

  @override
  void _finishInlineEditing() {
    final editingId = _inlineEditingCardId;
    if (editingId == null) return;
    final card = ref.read(canvasProvider.notifier).cardById(editingId);
    if (card != null) {
      final newTitle = _inlineTitleCtrl.text.trim();
      final newContent = _inlineContentCtrl.text.trim();
      if (newTitle != card.title || newContent != card.content) {
        ref
            .read(canvasProvider.notifier)
            .updateCard(card.copyWith(title: newTitle, content: newContent));
      }
    }
    ref.read(canvasProvider.notifier).finishInlineEditing();
  }

  /// 构建首次打开画布时的交互引导浮层。
  /// 半透明背景 + 居中卡片，说明画布的基本操作方式。
  Widget _buildCanvasGuideOverlay(ThemeData theme, AppLocalizations l) {
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.canvasGuideTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GuideItem(
                    icon: Icons.pan_tool_outlined,
                    title: l.canvasGuidePanTitle,
                    desc: l.canvasGuidePanDesc,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _GuideItem(
                    icon: Icons.zoom_in_outlined,
                    title: l.canvasGuideZoomTitle,
                    desc: l.canvasGuideZoomDesc,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _GuideItem(
                    icon: Icons.add_box_outlined,
                    title: l.canvasGuideAddCardTitle,
                    desc: l.canvasGuideAddCardDesc,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _GuideItem(
                    icon: Icons.timeline,
                    title: l.canvasGuideConnectTitle,
                    desc: l.canvasGuideConnectDesc,
                    theme: theme,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _dismissCanvasGuide,
                      child: Text(l.canvasGuideDismiss),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvasData = ref.watch(canvasProvider);
    final knowledgeState = ref.watch(knowledgeProvider);
    final linkResolver = ref.watch(linkResolverProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(canvasProvider.notifier);
    final l = AppLocalizations.of(context)!;

    final autoEnabled = canvasData.settings.autoConnectionsEnabled;

    if (!identical(_lastCards, canvasData.cards) ||
        !identical(_lastNotes, knowledgeState.notes) ||
        _lastAutoEnabled != autoEnabled ||
        !identical(_lastLinkResolver, linkResolver)) {
      _lastCards = canvasData.cards;
      _lastNotes = knowledgeState.notes;
      _lastAutoEnabled = autoEnabled;
      _lastLinkResolver = linkResolver;
      _cachedAutoConnections = notifier.deriveAutoConnections(
        knowledgeState.notes,
        linkResolver,
      );
    }
    final autoConns = _cachedAutoConnections;

    final hasFlowAnimation = canvasData.connections.any(
      (c) =>
          (c.style?.flowAnimation ?? FlowAnimationStyle.none) !=
          FlowAnimationStyle.none,
    );
    if (hasFlowAnimation != _hadFlowAnimation) {
      _hadFlowAnimation = hasFlowAnimation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (hasFlowAnimation) {
          if (!_animController.isAnimating) _animController.repeat();
        } else {
          _animController.stop();
          _animController.reset();
        }
      });
    }

    final canvasBindings = _buildCanvasBindings();

    return CallbackShortcuts(
      bindings: canvasBindings,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            if (event is KeyDownEvent) {
              _altKeyPressed = true;
            } else if (event is KeyUpEvent) {
              _altKeyPressed = false;
              setState(() => _alignmentGuides = []);
            }
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              _buildToolbar(theme, canvasData, autoEnabled, notifier, l),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _canvasW = constraints.maxWidth;
                          _canvasH = constraints.maxHeight;

                          final visibleWorldRect = Rect.fromLTWH(
                            _cameraX -
                                _viewW / 2 / _scale -
                                _CanvasViewStateBase._gridSize,
                            _cameraY -
                                _viewH / 2 / _scale -
                                _CanvasViewStateBase._gridSize,
                            _viewW / _scale +
                                _CanvasViewStateBase._gridSize * 2,
                            _viewH / _scale +
                                _CanvasViewStateBase._gridSize * 2,
                          );

                          return Stack(
                            children: [
                              MouseRegion(
                                cursor: _getCursor(),
                                onHover: _onHover,
                                child: Listener(
                                  onPointerSignal: _onPointerSignal,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onScaleStart: _onScaleStart,
                                    onScaleUpdate: _onScaleUpdate,
                                    onScaleEnd: _onScaleEnd,
                                    onTapUp: _onTapUp,
                                    onDoubleTapDown: _onDoubleTapDown,
                                    onSecondaryTapUp: _onSecondaryTapUp,
                                    child: ClipRect(
                                      child: SizedBox.expand(
                                        child: RepaintBoundary(
                                          key: _canvasPaintKey,
                                          child: ListenableBuilder(
                                            listenable: Listenable.merge([
                                              _animController,
                                              _cameraNotifier,
                                            ]),
                                            builder: (context, _) => CustomPaint(
                                              painter: CanvasPainter(
                                                cards: canvasData.cards,
                                                connections:
                                                    canvasData.connections,
                                                autoConnections: autoConns,
                                                cameraX: _cameraX,
                                                cameraY: _cameraY,
                                                scale: _scale,
                                                viewW: _viewW,
                                                viewH: _viewH,
                                                gridSize: _CanvasViewStateBase
                                                    ._gridSize,
                                                visibleWorldRect:
                                                    visibleWorldRect,
                                                selectedCardIds:
                                                    canvasData.selectedCardIds,
                                                connectingFromCardId:
                                                    _connectingFromCardId,
                                                connectingFromSide:
                                                    _connectingFromSide,
                                                connectingFromSideOffset:
                                                    _connectingFromSideOffset,
                                                searchMatchedIds:
                                                    _searchMatchedIds,
                                                searchActiveIndex:
                                                    _searchActiveIndex,
                                                connectingPreviewEnd:
                                                    _connectingPreviewEnd,
                                                hoveredCardId: _hoverCardId,
                                                hoveredConnectionSide:
                                                    _hoveredConnectionSide,
                                                selectedConnectionId: canvasData
                                                    .selectedConnectionId,
                                                primaryColor:
                                                    theme.colorScheme.primary,
                                                dividerColor:
                                                    theme.dividerColor,
                                                scaffoldBg: theme
                                                    .scaffoldBackgroundColor,
                                                isDark:
                                                    theme.brightness ==
                                                    Brightness.dark,
                                                hintColor: theme.hintColor,
                                                bodySmallStyle:
                                                    theme.textTheme.bodySmall,
                                                bodyMediumStyle:
                                                    theme.textTheme.bodyMedium,
                                                knowledgeState: knowledgeState,
                                                baseFontSize:
                                                    settings.editorFontSize,
                                                gridVisible: canvasData
                                                    .settings
                                                    .gridVisible,
                                                inlineEditingCardId:
                                                    _inlineEditingCardId,
                                                groups: canvasData.groups,
                                                layers: canvasData.layers,
                                                selectionRect: _selectionRect,
                                                alignmentGuides:
                                                    _alignmentGuides,
                                                backgroundColorValue: canvasData
                                                    .settings
                                                    .backgroundColorValue,
                                                rulersVisible: canvasData
                                                    .settings
                                                    .rulersVisible,
                                                animationValue:
                                                    _animController.value,
                                                selectedLayerId:
                                                    canvasData.selectedLayerId,
                                                cardImageCache: _imageCache,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ListenableBuilder(
                                listenable: _cameraNotifier,
                                builder: (context, _) => Consumer(
                                  builder: (context, ref, _) {
                                    final cd = ref.watch(canvasProvider);
                                    return _buildMinimap(theme, cd);
                                  },
                                ),
                              ),
                              _buildActiveFilterBanner(theme, canvasData),
                              ListenableBuilder(
                                listenable: _cameraNotifier,
                                builder: (context, _) =>
                                    _buildZoomControls(theme),
                              ),
                              if (_inlineEditingCardId != null)
                                _buildInlineEditor(theme, canvasData, settings),
                              if (_showCanvasGuide)
                                _buildCanvasGuideOverlay(theme, l),
                              if (notifier.isAutoLayouting)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black26,
                                    alignment: Alignment.center,
                                    child: const Card(
                                      child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CanvasPage extends ConsumerWidget {
  const CanvasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CanvasView();
  }
}

/// 交互引导浮层中的单条说明项（图标 + 标题 + 描述）。
class _GuideItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final ThemeData theme;
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
