part of '../ai_chat_panel.dart';

mixin _AIChatAutocompleteMixin on _AIChatPanelStateBase {
  @override
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
          .where((n) => n.title.toLowerCase().contains(query.toLowerCase()))
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

  @override
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
      final newCursorPos =
          atMatch.start + item.insertText.length + item.cursorOffset;
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
}
