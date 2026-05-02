import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/canvas_service.dart';
import '../../services/knowledge_service.dart';
import '../../services/browser_service.dart';
import '../../core/model/canvas_model.dart';

class CanvasView extends ConsumerStatefulWidget {
  const CanvasView({super.key});

  @override
  ConsumerState<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends ConsumerState<CanvasView> {
  final TransformationController _transformController = TransformationController();
  String? _selectedCardId;
  String? _connectingFromCardId;
  Offset? _connectingPreviewEnd;

  static const double _gridSize = 20;
  static const double _canvasSize = 10000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(canvasProvider.notifier).loadCanvas();
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasData = ref.watch(canvasProvider);
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildToolbar(theme, canvasData),
          Expanded(
            child: GestureDetector(
              onSecondaryTapUp: (details) =>
                  _showContextMenu(context, details, canvasData),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.1,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(_canvasSize / 2),
                child: SizedBox(
                  width: _canvasSize,
                  height: _canvasSize,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(_canvasSize, _canvasSize),
                        painter: _GridPainter(
                          gridSize: _gridSize,
                          color: theme.dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      CustomPaint(
                        size: const Size(_canvasSize, _canvasSize),
                        painter: _ConnectionPainter(
                          cards: canvasData.cards,
                          connections: canvasData.connections,
                          color: theme.colorScheme.primary,
                          previewFrom: _connectingFromCardId != null
                              ? canvasData.cards
                                  .where((c) => c.id == _connectingFromCardId)
                                  .firstOrNull
                                  ?.center
                              : null,
                          previewTo: _connectingPreviewEnd,
                        ),
                      ),
                      ...canvasData.cards.map((card) => _buildCard(
                            theme,
                            card,
                            isSelected: card.id == _selectedCardId,
                            isConnecting: card.id == _connectingFromCardId,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme, CanvasData canvasData) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Canvas',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          _toolbarButton(theme, Icons.add, 'Add Card', () {
            final offset = _screenToCanvas(Offset(
              MediaQuery.of(context).size.width / 2,
              MediaQuery.of(context).size.height / 2,
            ));
            _addCardAt(offset);
          }),
          _toolbarButton(theme, Icons.link, 'Connect', () {
            if (_selectedCardId != null) {
              setState(() => _connectingFromCardId = _selectedCardId);
            }
          }),
          const Spacer(),
          Text(
            '${canvasData.cards.length} cards',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          _toolbarButton(theme, Icons.fit_screen, 'Fit', _fitToContent),
          _toolbarButton(theme, Icons.delete_outline, 'Clear', () {
            ref.read(canvasProvider.notifier).clearCanvas();
            setState(() {
              _selectedCardId = null;
              _connectingFromCardId = null;
            });
          }),
        ],
      ),
    );
  }

  Widget _toolbarButton(ThemeData theme, IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 14),
      onPressed: onTap,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      color: theme.hintColor,
    );
  }

  Widget _buildCard(ThemeData theme, CanvasCard card, {required bool isSelected, required bool isConnecting}) {
    final cardColor = Color(card.colorValue);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? cardColor.withValues(alpha: 0.08)
        : cardColor.withValues(alpha: 0.04);
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : isConnecting
            ? theme.colorScheme.tertiary
            : theme.dividerColor;

    return Positioned(
      left: card.x,
      top: card.y,
      child: GestureDetector(
        onPanUpdate: (details) {
          final scale = _transformController.value[0];
          ref.read(canvasProvider.notifier).updateCardInMemory(card.copyWith(
            x: card.x + details.delta.dx / scale,
            y: card.y + details.delta.dy / scale,
          ));
        },
        onPanEnd: (_) {
          setState(() => _selectedCardId = card.id);
          ref.read(canvasProvider.notifier).persist();
        },
        onTap: () {
          if (_connectingFromCardId != null && _connectingFromCardId != card.id) {
            _createConnection(_connectingFromCardId!, card.id);
            setState(() => _connectingFromCardId = null);
          } else {
            setState(() => _selectedCardId = card.id);
          }
        },
        onDoubleTap: () => _openCardContent(card),
        child: MouseRegion(
          onEnter: (_) {
            if (_connectingFromCardId != null) {
              setState(() => _connectingPreviewEnd = card.center);
            }
          },
          onExit: (_) {
            if (_connectingFromCardId != null) {
              setState(() => _connectingPreviewEnd = null);
            }
          },
          child: Container(
            width: card.width,
            height: card.height,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  ),
                  child: Row(
                    children: [
                      Icon(card.type.icon, size: 12, color: theme.hintColor),
                      if (card.noteId != null) ...[
                        const SizedBox(width: 2),
                        Icon(Icons.link, size: 10, color: theme.colorScheme.primary),
                      ],
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          card.title.isEmpty ? card.type.label : card.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        GestureDetector(
                          onTap: () {
                            ref.read(canvasProvider.notifier).removeCard(card.id);
                            setState(() => _selectedCardId = null);
                          },
                          child: Icon(Icons.close, size: 12, color: theme.hintColor),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _buildCardContent(theme, card),
                  ),
                ),
                if (isSelected)
                  GestureDetector(
                    onPanUpdate: (details) {
                      final scale = _transformController.value[0];
                      final newW = (card.width + details.delta.dx / scale).clamp(120.0, 800.0);
                      final newH = (card.height + details.delta.dy / scale).clamp(80.0, 600.0);
                      ref.read(canvasProvider.notifier).updateCardInMemory(
                            card.copyWith(width: newW, height: newH),
                          );
                    },
                    onPanEnd: (_) {
                      ref.read(canvasProvider.notifier).persist();
                    },
                    child: Container(
                      height: 12,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
                      ),
                      child: Center(
                        child: Icon(Icons.drag_handle, size: 10, color: theme.hintColor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(ThemeData theme, CanvasCard card) {
    return switch (card.type) {
      CanvasCardType.note => Text(
          card.content.isEmpty ? 'Empty note' : card.content,
          style: theme.textTheme.bodySmall?.copyWith(
            color: card.content.isEmpty ? theme.hintColor : null,
            fontSize: 12,
          ),
          maxLines: null,
          overflow: TextOverflow.fade,
        ),
      CanvasCardType.text => Text(
          card.content.isEmpty ? 'Type something...' : card.content,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: card.content.isEmpty ? theme.hintColor : null,
          ),
        ),
      CanvasCardType.image => card.content.isEmpty
          ? Center(
              child: Icon(Icons.image, size: 32, color: theme.hintColor.withValues(alpha: 0.3)),
            )
          : Center(
              child: Icon(Icons.image, size: 32, color: theme.colorScheme.primary),
            ),
      CanvasCardType.link => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_browser, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              card.content.isEmpty ? 'No URL' : card.content,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
    };
  }

  void _showContextMenu(BuildContext context, TapUpDetails details, CanvasData canvasData) {
    final canvasPos = _screenToCanvas(details.globalPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx + 1,
        details.globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(value: 'note', child: Row(children: [Icon(Icons.description, size: 16), const SizedBox(width: 8), const Text('Note Card')])),
        PopupMenuItem(value: 'text', child: Row(children: [Icon(Icons.text_fields, size: 16), const SizedBox(width: 8), const Text('Text Card')])),
        PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.image, size: 16), const SizedBox(width: 8), const Text('Image Card')])),
        PopupMenuItem(value: 'link', child: Row(children: [Icon(Icons.link, size: 16), const SizedBox(width: 8), const Text('Link Card')])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'fromNote', child: Row(children: [Icon(Icons.library_books, size: 16), const SizedBox(width: 8), const Text('From Knowledge Note')])),
        if (_selectedCardId != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), const SizedBox(width: 8), const Text('Edit Card')])),
          PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.red), const SizedBox(width: 8), const Text('Delete Card')])),
        ],
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'note':
          _addCardAt(canvasPos, type: CanvasCardType.note);
          break;
        case 'text':
          _addCardAt(canvasPos, type: CanvasCardType.text);
          break;
        case 'image':
          _addCardAt(canvasPos, type: CanvasCardType.image);
          break;
        case 'link':
          _addCardAt(canvasPos, type: CanvasCardType.link);
          break;
        case 'fromNote':
          _addCardFromNote(canvasPos);
          break;
        case 'edit':
          if (_selectedCardId != null) _editCard(_selectedCardId!);
          break;
        case 'delete':
          if (_selectedCardId != null) {
            ref.read(canvasProvider.notifier).removeCard(_selectedCardId!);
            setState(() => _selectedCardId = null);
          }
          break;
      }
    });
  }

  void _addCardAt(Offset pos, {CanvasCardType type = CanvasCardType.note}) {
    final card = CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      x: pos.dx - 120,
      y: pos.dy - 80,
      width: 240,
      height: 160,
      title: '',
      content: '',
    );
    ref.read(canvasProvider.notifier).addCard(card);
    setState(() => _selectedCardId = card.id);
    _editCard(card.id);
  }

  void _addCardFromNote(Offset pos) {
    final notes = ref.read(knowledgeProvider).notes;
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes in knowledge base')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Note'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notes.length,
            itemBuilder: (ctx, index) {
              final note = notes[index];
              return ListTile(
                dense: true,
                title: Text(note.title, overflow: TextOverflow.ellipsis),
                onTap: () {
                  final card = CanvasCard(
                    id: 'card_${DateTime.now().millisecondsSinceEpoch}',
                    type: CanvasCardType.note,
                    x: pos.dx - 120,
                    y: pos.dy - 80,
                    width: 280,
                    height: 200,
                    title: note.title,
                    content: note.content.length > 500 ? '${note.content.substring(0, 500)}...' : note.content,
                    noteId: note.id,
                  );
                  ref.read(canvasProvider.notifier).addCard(card);
                  setState(() => _selectedCardId = card.id);
                  Navigator.pop(ctx);
                },
              );
            },
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

  void _openCardContent(CanvasCard card) {
    if (card.type == CanvasCardType.link && card.content.isNotEmpty) {
      ref.read(browserProvider.notifier).createTab(url: card.content);
      return;
    }

    if (card.noteId != null) {
      ref.read(knowledgeProvider.notifier).openNote(card.noteId!);
      return;
    }

    _editCard(card.id);
  }

  void _editCard(String cardId) {
    final card = ref.read(canvasProvider.notifier).cardById(cardId);
    if (card == null) return;

    final titleController = TextEditingController(text: card.title);
    final contentController = TextEditingController(text: card.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${card.type.label}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                decoration: InputDecoration(
                  labelText: switch (card.type) {
                    CanvasCardType.note => 'Content',
                    CanvasCardType.text => 'Text',
                    CanvasCardType.image => 'Image path',
                    CanvasCardType.link => 'URL',
                  },
                ),
                maxLines: card.type == CanvasCardType.note || card.type == CanvasCardType.text ? 5 : 1,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(canvasProvider.notifier).updateCard(
                    card.copyWith(
                      title: titleController.text.trim(),
                      content: contentController.text.trim(),
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _createConnection(String fromId, String toId) {
    final fromCard = ref.read(canvasProvider.notifier).cardById(fromId);
    final toCard = ref.read(canvasProvider.notifier).cardById(toId);
    if (fromCard == null || toCard == null) return;

    final dx = toCard.center.dx - fromCard.center.dx;
    final dy = toCard.center.dy - fromCard.center.dy;

    final fromSide = dx.abs() > dy.abs()
        ? (dx > 0 ? ConnectionSide.right : ConnectionSide.left)
        : (dy > 0 ? ConnectionSide.bottom : ConnectionSide.top);
    final toSide = dx.abs() > dy.abs()
        ? (dx > 0 ? ConnectionSide.left : ConnectionSide.right)
        : (dy > 0 ? ConnectionSide.top : ConnectionSide.bottom);

    final conn = CanvasConnection(
      id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
      fromCardId: fromId,
      toCardId: toId,
      fromSide: fromSide,
      toSide: toSide,
    );
    ref.read(canvasProvider.notifier).addConnection(conn);
  }

  Offset _screenToCanvas(Offset screenPos) {
    final transform = _transformController.value;
    final inverse = Matrix4.inverted(transform);
    final translated = screenPos.translate(0, 36);
    final x = inverse.entry(0, 0) * translated.dx +
        inverse.entry(0, 1) * translated.dy +
        inverse.entry(0, 3);
    final y = inverse.entry(1, 0) * translated.dx +
        inverse.entry(1, 1) * translated.dy +
        inverse.entry(1, 3);
    return Offset(x, y);
  }

  void _fitToContent() {
    final cards = ref.read(canvasProvider).cards;
    if (cards.isEmpty) {
      _transformController.value = Matrix4.identity();
      return;
    }

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final card in cards) {
      minX = math.min(minX, card.x);
      minY = math.min(minY, card.y);
      maxX = math.max(maxX, card.x + card.width);
      maxY = math.max(maxY, card.y + card.height);
    }

    final contentW = maxX - minX + 100;
    final contentH = maxY - minY + 100;
    final viewW = MediaQuery.of(context).size.width;
    final viewH = MediaQuery.of(context).size.height - 36;
    final scale = math.min(viewW / contentW, viewH / contentH).clamp(0.1, 2.0);

    final tx = (viewW - contentW * scale) / 2 - minX * scale + 50 * scale;
    final ty = (viewH - contentH * scale) / 2 - minY * scale + 50 * scale;

    final matrix = Matrix4.identity();
    matrix[0] = scale;
    matrix[5] = scale;
    matrix[10] = 1.0;
    matrix[12] = tx;
    matrix[13] = ty;
    matrix[15] = 1.0;
    _transformController.value = matrix;
  }
}

class _GridPainter extends CustomPainter {
  final double gridSize;
  final Color color;

  _GridPainter({required this.gridSize, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.color != color;
}

class _ConnectionPainter extends CustomPainter {
  final List<CanvasCard> cards;
  final List<CanvasConnection> connections;
  final Color color;
  final Offset? previewFrom;
  final Offset? previewTo;

  _ConnectionPainter({
    required this.cards,
    required this.connections,
    required this.color,
    this.previewFrom,
    this.previewTo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final conn in connections) {
      final fromCard = cards.where((c) => c.id == conn.fromCardId).firstOrNull;
      final toCard = cards.where((c) => c.id == conn.toCardId).firstOrNull;
      if (fromCard == null || toCard == null) continue;

      final from = conn.fromSide.point(fromCard.rect);
      final to = conn.toSide.point(toCard.rect);
      _drawBezierLine(canvas, from, to, paint, arrowPaint);
    }

    if (previewFrom != null && previewTo != null) {
      final previewPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      _drawBezierLine(canvas, previewFrom!, previewTo!, previewPaint, arrowPaint);
    }
  }

  void _drawBezierLine(Canvas canvas, Offset from, Offset to, Paint paint, Paint arrowPaint) {
    final dx = (to.dx - from.dx).abs();
    final dy = (to.dy - from.dy).abs();
    final cp = math.max(dx, dy) * 0.4;

    Offset cp1, cp2;
    if (dx > dy) {
      final dir = to.dx > from.dx ? 1.0 : -1.0;
      cp1 = Offset(from.dx + cp * dir, from.dy);
      cp2 = Offset(to.dx - cp * dir, to.dy);
    } else {
      final dir = to.dy > from.dy ? 1.0 : -1.0;
      cp1 = Offset(from.dx, from.dy + cp * dir);
      cp2 = Offset(to.dx, to.dy - cp * dir);
    }

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);

    canvas.drawPath(path, paint);
    _drawArrowHead(canvas, cp2, to, arrowPaint);
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const arrowLen = 8.0;
    const arrowAngle = math.pi / 6;

    final p1 = Offset(
      to.dx - arrowLen * math.cos(angle - arrowAngle),
      to.dy - arrowLen * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      to.dx - arrowLen * math.cos(angle + arrowAngle),
      to.dy - arrowLen * math.sin(angle + arrowAngle),
    );

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter old) =>
      old.cards != cards ||
      old.connections != connections ||
      old.previewFrom != previewFrom ||
      old.previewTo != previewTo;
}
