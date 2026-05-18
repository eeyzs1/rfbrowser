part of '../canvas_page.dart';

mixin _CanvasDialogsMixin on _CanvasViewStateBase {
    @override
    void _showColorPicker(CanvasCard card) {
      final theme = Theme.of(context);
      final l = AppLocalizations.of(context)!;
      final selectedIds = _selectedCardIds;
      final isMulti = selectedIds.length > 1;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            isMulti
                ? 'Change Color (${selectedIds.length} cards)'
                : l.changeColor,
          ),
          content: SizedBox(
            width: 280,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _CanvasViewStateBase._cardColorPresets
                  .map(
                    (color) => GestureDetector(
                      onTap: () {
                        if (isMulti) {
                          ref
                              .read(canvasProvider.notifier)
                              .batchUpdateCardColor(
                                selectedIds,
                                color.toARGB32(),
                              );
                        } else {
                          ref
                              .read(canvasProvider.notifier)
                              .updateCard(
                                card.copyWith(colorValue: color.toARGB32()),
                              );
                        }
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: card.colorValue == color.toARGB32()
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                            width: card.colorValue == color.toARGB32() ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: card.colorValue == color.toARGB32()
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
          ],
        ),
      );
    }

    @override
    void _showConnectionListDialog(
      CanvasCard card,
      List<({CanvasConnection conn, bool isAuto})> allConns,
    ) {
      final l = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.manageConnections),
          content: SizedBox(
            width: 320,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: allConns.length,
              itemBuilder: (ctx, i) {
                final e = allConns[i];
                final otherCardId = e.conn.fromCardId == card.id
                    ? e.conn.toCardId
                    : e.conn.fromCardId;
                final otherCard = ref
                    .read(canvasProvider.notifier)
                    .cardById(otherCardId);
                final connStyle = e.conn.style ?? CanvasConnectionStyle.defaults;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    e.isAuto ? Icons.auto_fix_high : Icons.link,
                    size: 16,
                    color: e.isAuto ? theme.hintColor : theme.colorScheme.primary,
                  ),
                  title: Text(
                    otherCard?.title ?? otherCardId,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    e.conn.label.isNotEmpty
                        ? e.conn.label
                        : (e.isAuto
                              ? l.autoConnection
                              : '${connStyle.pathType.name} · ${connStyle.arrowStyle.name}'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!e.isAuto)
                        IconButton(
                          icon: Icon(
                            Icons.tune,
                            size: 14,
                            color: theme.hintColor,
                          ),
                          tooltip: l.editStyle,
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showConnectionStyleDialog(e.conn);
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () {
                          if (e.isAuto) {
                            ref
                                .read(canvasProvider.notifier)
                                .addConnection(e.conn.copyWith(isAuto: false));
                          } else {
                            ref
                                .read(canvasProvider.notifier)
                                .removeConnection(e.conn.id);
                          }
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (final e in allConns) {
                  try {
                    ref.read(canvasProvider.notifier).removeConnection(e.conn.id);
                  } catch (_) {}
                }
                Navigator.pop(ctx);
              },
              child: Text(
                l.deleteAll,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
          ],
        ),
      );
    }

    @override
    void _showConnectionStyleDialog(CanvasConnection conn) {
      final theme = Theme.of(context);
      final l = AppLocalizations.of(context)!;
      final currentStyle = conn.style ?? CanvasConnectionStyle.defaults;
      ConnectionPath pathType = currentStyle.pathType;
      ArrowStyle arrowStyle = currentStyle.arrowStyle;
      double strokeWidth = currentStyle.strokeWidth;
      int colorValue = currentStyle.colorValue;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l.connectionStyle),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ConnectionPath>(
                    // ignore: deprecated_member_use
                    value: pathType,
                    key: ValueKey(pathType),
                    decoration: InputDecoration(
                      labelText: l.pathType,
                      isDense: true,
                    ),
                    items: ConnectionPath.values
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => pathType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ArrowStyle>(
                    // ignore: deprecated_member_use
                    value: arrowStyle,
                    key: ValueKey(arrowStyle),
                    decoration: InputDecoration(
                      labelText: l.arrowStyle,
                      isDense: true,
                    ),
                    items: ArrowStyle.values
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text(v.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => arrowStyle = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(l.width, style: theme.textTheme.bodySmall),
                      Expanded(
                        child: Slider(
                          value: strokeWidth,
                          min: 0.5,
                          max: 6,
                          divisions: 11,
                          label: strokeWidth.toStringAsFixed(1),
                          onChanged: (v) => setDialogState(() => strokeWidth = v),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          strokeWidth.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: colorValue,
                    key: ValueKey(colorValue),
                    decoration: InputDecoration(
                      labelText: l.color,
                      isDense: true,
                    ),
                    items:
                        [
                              0xFF000000,
                              0xFF1565C0,
                              0xFF2E7D32,
                              0xFFE65100,
                              0xFFC62828,
                              0xFF6A1B9A,
                              0xFF00838F,
                              0xFF4E342E,
                            ]
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Color(v),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '#${v.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => colorValue = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () {
                  ref
                      .read(canvasProvider.notifier)
                      .addConnection(
                        conn.copyWith(
                          style: CanvasConnectionStyle(
                            pathType: pathType,
                            arrowStyle: arrowStyle,
                            strokeWidth: strokeWidth,
                            colorValue: colorValue,
                          ),
                          clearStyle: false,
                        ),
                      );
                  ref.read(canvasProvider.notifier).removeConnection(conn.id);
                  Navigator.pop(ctx);
                },
                child: Text(l.save),
              ),
            ],
          ),
        ),
      );
    }

    @override
    void _duplicateCard(String cardId, Offset pos) {
      final card = ref.read(canvasProvider.notifier).cardById(cardId);
      if (card == null) return;
      final newCard = CanvasCard(
        id: 'card_${DateTime.now().millisecondsSinceEpoch}',
        type: card.type,
        x: pos.dx,
        y: pos.dy,
        width: card.width,
        height: card.height,
        title: card.title,
        content: card.content,
        colorValue: card.colorValue,
        fontSize: card.fontSize,
      );
      ref.read(canvasProvider.notifier).addCard(newCard);
      ref.read(canvasProvider.notifier).selectCard(newCard.id);
    }

    @override
    void _addCardAt(Offset pos, {CanvasCardType type = CanvasCardType.note}) {
      final snappedX = _snapToGrid(pos.dx - type.defaultWidth / 2);
      final snappedY = _snapToGrid(pos.dy - type.defaultHeight / 2);
      final card = CanvasCard(
        id: 'card_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        x: snappedX,
        y: snappedY,
        width: type.defaultWidth,
        height: type.defaultHeight,
        title: '',
        content: '',
      );
      ref.read(canvasProvider.notifier).addCard(card);
      _startInlineEditing(card.id);
    }

    @override
    void _addContainerAt(Offset pos) {
      final l = AppLocalizations.of(context)!;
      final snappedX = _snapToGrid(pos.dx - 200);
      final snappedY = _snapToGrid(pos.dy - 100);
      final container = CanvasCard(
        id: 'card_${DateTime.now().millisecondsSinceEpoch}',
        type: CanvasCardType.container,
        x: snappedX,
        y: snappedY,
        width: 400,
        height: 300,
        title: l.container,
        childIds: const [],
        collapsed: false,
      );
      ref.read(canvasProvider.notifier).addCard(container);
      ref.read(canvasProvider.notifier).selectCard(container.id);
    }

    @override
    void _toggleContainerCollapse(String cardId) {
      final card = ref.read(canvasProvider.notifier).cardById(cardId);
      if (card == null || card.type != CanvasCardType.container) return;
      ref
          .read(canvasProvider.notifier)
          .updateCard(card.copyWith(collapsed: !card.collapsed));
    }

    @override
    void _saveCardToScratchpad(CanvasCard card) async {
      final l = AppLocalizations.of(context)!;
      final nameCtrl = TextEditingController(
        text: card.title.isEmpty ? card.type.label : card.title,
      );
      final categoryCtrl = TextEditingController(text: l.general);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.saveToScratchpad),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l.templateName),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryCtrl,
                  decoration: InputDecoration(
                    labelText: l.category,
                    hintText: l.general,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final item = ScratchpadItem(
                  id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim().isEmpty
                      ? card.type.label
                      : nameCtrl.text.trim(),
                  type: card.type,
                  width: card.width,
                  height: card.height,
                  colorValue: card.colorValue,
                  style: card.style,
                  category: categoryCtrl.text.trim().isEmpty
                      ? l.general
                      : categoryCtrl.text.trim(),
                );
                await ref.read(canvasProvider.notifier).saveScratchpadItem(item);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.savedToScratchpad(item.name)),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Text(l.save),
            ),
          ],
        ),
      );
    }

    @override
    void _promoteCardToNote(CanvasCard card) async {
      final l = AppLocalizations.of(context)!;
      final knowledgeNotifier = ref.read(knowledgeProvider.notifier);
      final baseTitle = card.title.isNotEmpty ? card.title : 'Untitled';
      final uniqueTitle = await knowledgeNotifier.getUniqueTitle(baseTitle);
      final content = StringBuffer();
      if (card.content.isNotEmpty) {
        content.writeln(card.content);
      }
      if (card.tags.isNotEmpty) {
        content.writeln();
        for (final tag in card.tags) {
          content.writeln('- #$tag');
        }
      }
      final note = await knowledgeNotifier.createNote(
        title: uniqueTitle,
        content: content.toString(),
      );
      final notifier = ref.read(canvasProvider.notifier);
      notifier.updateCard(card.copyWith(noteId: note.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.promoteToNoteSuccess),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: l.view,
              onPressed: () => knowledgeNotifier.openNote(note.id),
            ),
          ),
        );
      }
    }

    @override
    void _showMoveToLayerDialog(CanvasCard card) {
      final l = AppLocalizations.of(context)!;
      final canvasData = ref.read(canvasProvider);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.moveToLayer),
          content: SizedBox(
            width: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  dense: true,
                  title: Text(l.noLayerDefault),
                  leading: Radio<String?>(
                    // ignore: deprecated_member_use
                    value: null,
                    // ignore: deprecated_member_use
                    groupValue: card.layerId,
                    // ignore: deprecated_member_use
                    onChanged: (_) {
                      ref
                          .read(canvasProvider.notifier)
                          .moveCardToLayer(card.id, null);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                ...canvasData.layers.map(
                  (layer) => ListTile(
                    dense: true,
                    title: Text(layer.name),
                    leading: Radio<String?>(
                      // ignore: deprecated_member_use
                      value: layer.id,
                      // ignore: deprecated_member_use
                      groupValue: card.layerId,
                      // ignore: deprecated_member_use
                      onChanged: (_) {
                        ref
                            .read(canvasProvider.notifier)
                            .moveCardToLayer(card.id, layer.id);
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
          ],
        ),
      );
    }

    @override
    void _showBackgroundColorPicker() {
      final l = AppLocalizations.of(context)!;
      final notifier = ref.read(canvasProvider.notifier);
      final canvasData = ref.read(canvasProvider);
      final current = canvasData.settings.backgroundColorValue;
      showDialog(
        context: context,
        builder: (ctx) {
          final ctxTheme = Theme.of(ctx);
          return AlertDialog(
            title: Text(l.backgroundColor),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            Colors.white,
                            Colors.grey[100]!,
                            Colors.grey[200]!,
                            Colors.blue[50]!,
                            Colors.green[50]!,
                            Colors.orange[50]!,
                            Colors.purple[50]!,
                            Colors.red[50]!,
                            Colors.grey[800]!,
                            Colors.grey[900]!,
                            Colors.blue[900]!,
                            Colors.green[900]!,
                          ]
                          .map(
                            (c) => GestureDetector(
                              onTap: () {
                                notifier.setBackgroundColor(c.toARGB32());
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: current == c.toARGB32()
                                        ? ctxTheme.colorScheme.primary
                                        : ctxTheme.dividerColor,
                                    width: current == c.toARGB32() ? 2 : 1,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  notifier.setBackgroundColor(null);
                  Navigator.pop(ctx);
                },
                child: Text(l.clear),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
            ],
          );
        },
      );
    }

    @override
    void _showDefaultStyleDialog() {
      final l = AppLocalizations.of(context)!;
      final notifier = ref.read(canvasProvider.notifier);
      final canvasData = ref.read(canvasProvider);
      final currentCardStyle =
          canvasData.settings.defaultCardStyle ?? CanvasCardStyle.defaults;
      showDialog(
        context: context,
        builder: (ctx) {
          final ctxTheme = Theme.of(ctx);
          return AlertDialog(
            title: Text(l.defaultCardStyle),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.fillColor, style: ctxTheme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        [
                              0xFFFFFFFF,
                              0xFFF5F5F5,
                              0xFFE3F2FD,
                              0xFFE8F5E9,
                              0xFFFFF3E0,
                              0xFFFCE4EC,
                              0xFFF3E5F5,
                              0xFFE0E0E0,
                            ]
                            .map(
                              (v) => GestureDetector(
                                onTap: () => notifier.setDefaultCardStyle(
                                  currentCardStyle.copyWith(fillColor: v),
                                ),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Color(v),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: currentCardStyle.fillColor == v
                                          ? ctxTheme.colorScheme.primary
                                          : ctxTheme.dividerColor,
                                      width: currentCardStyle.fillColor == v
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(l.borderRadius, style: ctxTheme.textTheme.bodySmall),
                  Slider(
                    value: currentCardStyle.borderRadius,
                    min: 0,
                    max: 24,
                    divisions: 12,
                    label: currentCardStyle.borderRadius.round().toString(),
                    onChanged: (v) => notifier.setDefaultCardStyle(
                      currentCardStyle.copyWith(borderRadius: v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l.borderWidth, style: ctxTheme.textTheme.bodySmall),
                  Slider(
                    value: currentCardStyle.borderWidth,
                    min: 0,
                    max: 4,
                    divisions: 8,
                    label: currentCardStyle.borderWidth.toStringAsFixed(1),
                    onChanged: (v) => notifier.setDefaultCardStyle(
                      currentCardStyle.copyWith(borderWidth: v),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  notifier.setDefaultCardStyle(null);
                  Navigator.pop(ctx);
                },
                child: Text(l.reset),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.close),
              ),
            ],
          );
        },
      );
    }

    @override
    void _showAddTagDialog(CanvasCard card) {
      final l = AppLocalizations.of(context)!;
      final ctrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.addTag),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: l.tagName),
            onSubmitted: (_) => Navigator.pop(ctx, ctrl.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(l.add),
            ),
          ],
        ),
      ).then((tag) {
        if (tag != null && tag.isNotEmpty) {
          ref.read(canvasProvider.notifier).addTag(card.id, tag);
        }
      });
    }

    @override
    void _showRemoveTagDialog(CanvasCard card) {
      final l = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        builder: (ctx) {
          final ctxTheme = Theme.of(ctx);
          return SimpleDialog(
            title: Text(l.removeTag),
            children: card.tags
                .map(
                  (tag) => SimpleDialogOption(
                    onPressed: () {
                      ref.read(canvasProvider.notifier).removeTag(card.id, tag);
                      Navigator.pop(ctx);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.label, size: 14, color: ctxTheme.hintColor),
                        const SizedBox(width: 8),
                        Text(tag),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
    }

    @override
    void _showImportDialog(String format) {
      final l = AppLocalizations.of(context)!;
      final ctrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.importFormat(format.toUpperCase())),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: format == 'csv'
                    ? 'Name,Relation\nAlice,Bob\nBob,Charlie'
                    : format == 'mermaid'
                    ? 'graph TD\n    A-->B\n    B-->C'
                    : '<svg>...</svg>',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final data = switch (format) {
                  'csv' => CanvasNotifier.importFromCsv(ctrl.text),
                  'mermaid' => CanvasNotifier.importFromMermaid(ctrl.text),
                  'svg' => CanvasNotifier.importFromSvg(ctrl.text),
                  _ => null,
                };
                Navigator.pop(ctx);
                if (data != null) {
                  ref.read(canvasProvider.notifier).loadFromData(data);
                }
              },
              child: Text(l.import),
            ),
          ],
        ),
      );
    }

    @override
    void _shareViaUrl() {
      final l = AppLocalizations.of(context)!;
      final url = ref.read(canvasProvider.notifier).encodeToUrl();
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.shareUrlCopied),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    @override
    void _addCardFromNote(Offset pos) {
      final l = AppLocalizations.of(context)!;
      final notes = ref.read(knowledgeProvider).notes;
      if (notes.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.noNotesInKnowledgeBase)));
        return;
      }
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.selectNote),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: notes.length,
              itemBuilder: (ctx, i) => ListTile(
                dense: true,
                title: Text(notes[i].title, overflow: TextOverflow.ellipsis),
                onTap: () {
                  final note = notes[i];
                  final cardType = CanvasCardType.note;
                  final snappedX = _snapToGrid(pos.dx - cardType.defaultWidth / 2);
                  final snappedY = _snapToGrid(pos.dy - cardType.defaultHeight / 2);
                  final card = CanvasCard(
                    id: 'card_${DateTime.now().millisecondsSinceEpoch}',
                    type: cardType,
                    x: snappedX,
                    y: snappedY,
                    width: cardType.defaultWidth,
                    height: cardType.defaultHeight,
                    title: note.title,
                    content: note.content.length > 500
                        ? '${note.content.substring(0, 500)}...'
                        : note.content,
                    noteId: note.id,
                  );
                  ref.read(canvasProvider.notifier).addCard(card);
                  ref.read(canvasProvider.notifier).selectCard(card.id);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
          ],
        ),
      );
    }

    @override
    void _openCardContent(CanvasCard card) {
      if (card.type == CanvasCardType.container) {
        _toggleContainerCollapse(card.id);
        return;
      }
      if (card.type == CanvasCardType.link && card.content.isNotEmpty) {
        ref.read(browserProvider.notifier).createTab(url: card.content);
        return;
      }
      if (card.noteId != null) {
        ref.read(knowledgeProvider.notifier).openNote(card.noteId!);
        return;
      }
      _startInlineEditing(card.id);
    }

    @override
    void _editCard(String cardId) {
      final card = ref.read(canvasProvider.notifier).cardById(cardId);
      if (card == null) return;
      final settings = ref.read(settingsProvider);
      final l = AppLocalizations.of(context)!;
      final dialogTheme = Theme.of(context);
      final titleCtrl = TextEditingController(text: card.title);
      final titleFocus = FocusNode();
      final contentCtrl = TextEditingController(text: card.content);
      double cardFontSize = card.fontSize > 0
          ? card.fontSize
          : settings.editorFontSize * 0.85;
      int selectedColorValue = card.colorValue;
      int selectedTextColorValue = card.textColorValue;
      String selectedFontFamily = card.fontFamily;
      TextAlignH selectedAlignH = card.textAlignH;
      TextAlignV selectedAlignV = card.textAlignV;
      List<RichTextSegment> richSegments = List.from(card.richContent);
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l.editCardType(card.type.label)),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      focusNode: titleFocus,
                      decoration: InputDecoration(labelText: l.noteTitle),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentCtrl,
                      decoration: InputDecoration(
                        labelText: switch (card.type) {
                          CanvasCardType.note => l.contentPreview,
                          CanvasCardType.text => l.note,
                          CanvasCardType.image => l.imagePath,
                          CanvasCardType.link => l.url,
                          CanvasCardType.container => l.contentPreview,
                          _ => l.contentPreview,
                        },
                      ),
                      maxLines:
                          card.type == CanvasCardType.note ||
                              card.type == CanvasCardType.text
                          ? 5
                          : 1,
                    ),
                    const SizedBox(height: 12),
                    Text(l.richText, style: dialogTheme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.format_bold, size: 18),
                          tooltip: l.bold,
                          onPressed: () {
                            richSegments.add(
                              const RichTextSegment(
                                text: 'bold text',
                                type: RichTextSegmentType.bold,
                              ),
                            );
                            setDialogState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_italic, size: 18),
                          tooltip: l.italic,
                          onPressed: () {
                            richSegments.add(
                              const RichTextSegment(
                                text: 'italic text',
                                type: RichTextSegmentType.italic,
                              ),
                            );
                            setDialogState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_underlined, size: 18),
                          tooltip: l.underline,
                          onPressed: () {
                            richSegments.add(
                              const RichTextSegment(
                                text: 'underlined',
                                type: RichTextSegmentType.underline,
                              ),
                            );
                            setDialogState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.code, size: 18),
                          tooltip: l.code,
                          onPressed: () {
                            richSegments.add(
                              const RichTextSegment(
                                text: 'code',
                                type: RichTextSegmentType.code,
                              ),
                            );
                            setDialogState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.strikethrough_s, size: 18),
                          tooltip: l.strikethrough,
                          onPressed: () {
                            richSegments.add(
                              const RichTextSegment(
                                text: 'deleted',
                                type: RichTextSegmentType.strikethrough,
                              ),
                            );
                            setDialogState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          tooltip: l.text,
                          onPressed: () {
                            richSegments.add(const RichTextSegment(text: 'text'));
                            setDialogState(() {});
                          },
                        ),
                        const Spacer(),
                        if (richSegments.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: l.clear,
                            onPressed: () {
                              richSegments.clear();
                              setDialogState(() {});
                            },
                          ),
                      ],
                    ),
                    if (richSegments.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: dialogTheme.dividerColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Wrap(
                          spacing: 2,
                          runSpacing: 2,
                          children: richSegments.asMap().entries.map((e) {
                            final idx = e.key;
                            final seg = e.value;
                            final style = switch (seg.type) {
                              RichTextSegmentType.bold => const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              RichTextSegmentType.italic => const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                              RichTextSegmentType.underline => const TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                              RichTextSegmentType.code => const TextStyle(
                                fontFamily: 'monospace',
                                backgroundColor: Colors.black12,
                              ),
                              RichTextSegmentType.strikethrough =>
                                const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                ),
                              RichTextSegmentType.text => const TextStyle(),
                            };
                            return GestureDetector(
                              onDoubleTap: () {
                                final ctrl = TextEditingController(
                                  text: seg.text,
                                );
                                showDialog(
                                  context: ctx,
                                  builder: (dctx) => AlertDialog(
                                    title: Text(l.editSegment(seg.type.name)),
                                    content: TextField(
                                      controller: ctrl,
                                      autofocus: true,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dctx),
                                        child: Text(l.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          richSegments[idx] = RichTextSegment(
                                            text: ctrl.text,
                                            type: seg.type,
                                          );
                                          Navigator.pop(dctx);
                                          setDialogState(() {});
                                        },
                                        child: Text(l.ok),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Chip(
                                label: Text(
                                  seg.text,
                                  style: style.copyWith(fontSize: cardFontSize * 0.8),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 12),
                                onDeleted: () {
                                  richSegments.removeAt(idx);
                                  setDialogState(() {});
                                },
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(l.alignH, style: dialogTheme.textTheme.bodySmall),
                        const SizedBox(width: 4),
                        SegmentedButton<TextAlignH>(
                          segments: const [
                            ButtonSegment(
                              value: TextAlignH.left,
                              icon: Icon(Icons.format_align_left, size: 16),
                            ),
                            ButtonSegment(
                              value: TextAlignH.center,
                              icon: Icon(Icons.format_align_center, size: 16),
                            ),
                            ButtonSegment(
                              value: TextAlignH.right,
                              icon: Icon(Icons.format_align_right, size: 16),
                            ),
                          ],
                          selected: {selectedAlignH},
                          onSelectionChanged: (v) =>
                              setDialogState(() => selectedAlignH = v.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(l.alignV, style: dialogTheme.textTheme.bodySmall),
                        const SizedBox(width: 4),
                        SegmentedButton<TextAlignV>(
                          segments: const [
                            ButtonSegment(
                              value: TextAlignV.top,
                              icon: Icon(Icons.vertical_align_top, size: 16),
                            ),
                            ButtonSegment(
                              value: TextAlignV.middle,
                              icon: Icon(Icons.vertical_align_center, size: 16),
                            ),
                            ButtonSegment(
                              value: TextAlignV.bottom,
                              icon: Icon(Icons.vertical_align_bottom, size: 16),
                            ),
                          ],
                          selected: {selectedAlignV},
                          onSelectionChanged: (v) =>
                              setDialogState(() => selectedAlignV = v.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(l.font, style: dialogTheme.textTheme.bodySmall),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: selectedFontFamily.isEmpty
                              ? 'default'
                              : selectedFontFamily,
                          items: ['default', 'monospace', 'serif', 'sans-serif']
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontFamily: f == 'default' ? null : f,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setDialogState(
                            () => selectedFontFamily = v == 'default' ? '' : v!,
                          ),
                          isDense: true,
                          underline: const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(l.fontSize, style: dialogTheme.textTheme.bodySmall),
                        Expanded(
                          child: Slider(
                            value: cardFontSize,
                            min: 8,
                            max: 32,
                            divisions: 24,
                            label: cardFontSize.round().toString(),
                            onChanged: (v) =>
                                setDialogState(() => cardFontSize = v),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            cardFontSize.round().toString(),
                            style: dialogTheme.textTheme.bodySmall,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.textColor,
                        style: dialogTheme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children:
                          [
                                0xFF000000,
                                0xFF444444,
                                0xFF1565C0,
                                0xFF2E7D32,
                                0xFFE65100,
                                0xFFC62828,
                                0xFF6A1B9A,
                                0xFFFFFFFF,
                              ]
                              .map(
                                (v) => GestureDetector(
                                  onTap: () => setDialogState(
                                    () => selectedTextColorValue = v,
                                  ),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(v),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: selectedTextColorValue == v
                                            ? dialogTheme.colorScheme.primary
                                            : dialogTheme.dividerColor,
                                        width: selectedTextColorValue == v
                                            ? 2
                                            : 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.cardColor,
                        style: dialogTheme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _CanvasViewStateBase._cardColorPresets
                          .map(
                            (color) => GestureDetector(
                              onTap: () => setDialogState(
                                () => selectedColorValue = color.toARGB32(),
                              ),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: selectedColorValue == color.toARGB32()
                                        ? dialogTheme.colorScheme.primary
                                        : dialogTheme.dividerColor,
                                    width: selectedColorValue == color.toARGB32()
                                        ? 2.5
                                        : 1,
                                  ),
                                ),
                                child: selectedColorValue == color.toARGB32()
                                    ? Icon(
                                        Icons.check,
                                        size: 14,
                                        color: dialogTheme.colorScheme.primary,
                                      )
                                    : null,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final defaultSize = settings.editorFontSize * 0.85;
                  ref
                      .read(canvasProvider.notifier)
                      .updateCard(
                        card.copyWith(
                          title: titleCtrl.text.trim(),
                          content: contentCtrl.text.trim(),
                          fontSize: (cardFontSize - defaultSize).abs() < 0.5
                              ? 0
                              : cardFontSize,
                          colorValue: selectedColorValue,
                          textColorValue: selectedTextColorValue,
                          fontFamily: selectedFontFamily,
                          textAlignH: selectedAlignH,
                          textAlignV: selectedAlignV,
                          richContent: richSegments,
                        ),
                      );
                  Navigator.pop(ctx);
                },
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ).then((_) => titleFocus.dispose());
    }

    @override
    void _createConnection(String fromId, String toId) {
      final fromCard = ref.read(canvasProvider.notifier).cardById(fromId);
      final toCard = ref.read(canvasProvider.notifier).cardById(toId);
      if (fromCard == null || toCard == null) return;
      final (fromSide, toSide) = CanvasConnection.computeSides(fromCard, toCard);
      final conn = CanvasConnection(
        id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
        fromCardId: fromId,
        toCardId: toId,
        fromSide: fromSide,
        toSide: toSide,
        fromSideOffset: 0.5,
        toSideOffset: 0.5,
        isAuto: false,
      );
      ref.read(canvasProvider.notifier).addConnection(conn);
    }

    @override
    void _createConnectionWithSides(
      String fromId,
      String toId,
      ConnectionSide? fromSide,
      ConnectionSide? toSide, [
      double fromSideOffset = 0.5,
      double toSideOffset = 0.5,
    ]) {
      final fromCard = ref.read(canvasProvider.notifier).cardById(fromId);
      final toCard = ref.read(canvasProvider.notifier).cardById(toId);
      if (fromCard == null || toCard == null) return;
      final (computedFrom, computedTo) = CanvasConnection.computeSides(
        fromCard,
        toCard,
      );
      final conn = CanvasConnection(
        id: 'conn_${DateTime.now().millisecondsSinceEpoch}',
        fromCardId: fromId,
        toCardId: toId,
        fromSide: fromSide ?? computedFrom,
        toSide: toSide ?? computedTo,
        fromSideOffset: fromSideOffset,
        toSideOffset: toSideOffset,
        isAuto: false,
      );
      ref.read(canvasProvider.notifier).addConnection(conn);
      ref.read(canvasProvider.notifier).selectConnection(conn.id);
    }

}
