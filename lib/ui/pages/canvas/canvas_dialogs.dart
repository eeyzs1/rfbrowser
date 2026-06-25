part of '../canvas_page.dart';

/// Card-level dialogs: color picker, duplicate, add card, container,
/// scratchpad, promote-to-note, and card content navigation.
mixin _CanvasDialogsMixin on _CanvasViewStateBase {
  @override
  void _showColorPicker(CanvasCard card) {
    final selectedIds = _selectedCardIds;
    final isMulti = selectedIds.length > 1;
    showDialog<Color>(
      context: context,
      builder: (ctx) => ColorPickerDialog(
        currentColorValue: card.colorValue,
        isMulti: isMulti,
        selectedCount: selectedIds.length,
      ),
    ).then((color) {
      if (color == null) return;
      final notifier = ref.read(canvasProvider.notifier);
      if (isMulti) {
        notifier.batchUpdateCardColor(selectedIds, color.toARGB32());
      } else {
        notifier.updateCard(card.copyWith(colorValue: color.toARGB32()));
      }
    });
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
  Future<void> _addCardAt(
    Offset pos, {
    CanvasCardType type = CanvasCardType.note,
  }) async {
    final snappedX = _snapToGrid(pos.dx - type.defaultWidth / 2);
    final snappedY = _snapToGrid(pos.dy - type.defaultHeight / 2);

    String? imagePath;
    if (type == CanvasCardType.image) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.isNotEmpty) {
        imagePath = result.files.single.path;
      }
    }

    final card = CanvasCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      x: snappedX,
      y: snappedY,
      width: type.defaultWidth,
      height: type.defaultHeight,
      title: '',
      content: imagePath ?? '',
      imagePath: imagePath,
    );
    ref.read(canvasProvider.notifier).addCard(card);

    if (imagePath != null) {
      _loadImageCards([card]);
    }

    if (type != CanvasCardType.image) {
      _startInlineEditing(card.id);
    }
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
                final snappedX = _snapToGrid(
                  pos.dx - cardType.defaultWidth / 2,
                );
                final snappedY = _snapToGrid(
                  pos.dy - cardType.defaultHeight / 2,
                );
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
}
