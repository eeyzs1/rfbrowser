part of '../note_sidebar.dart';

mixin _SidebarNoteActionsMixin on _NoteSidebarStateBase {
  @override
  void _createNoteFolder(String parentPath) async {
    final l = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l.newFolder),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l.folderName, isDense: true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l.create),
            ),
          ],
        );
      },
    );
    if (name != null && name.isNotEmpty) {
      final vaultState = ref.read(vaultProvider);
      if (vaultState.currentVault != null) {
        final fullPath = parentPath.isEmpty ? name : '$parentPath/$name';
        final dir = Directory('${vaultState.currentVault!.path}/$fullPath');
        if (!await dir.exists()) await dir.create(recursive: true);
        setState(() {
          _expandedNoteFolders.add(parentPath);
          _expandedNoteFolders.add(fullPath);
        });
        await _scanDiskFolders();
      }
    }
  }

  @override
  void _createNewNote(String folderPath) async {
    final title = await showCreateNoteDialog(context);
    if (title != null && title.isNotEmpty) {
      if (folderPath.isNotEmpty) {
        final vaultState = ref.read(vaultProvider);
        if (vaultState.currentVault != null) {
          final fileName = title
              .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
              .replaceAll(RegExp(r'\s+'), '-');
          final relativePath = '$folderPath/$fileName.md';
          final note = Note(
            title: title,
            filePath: relativePath,
            content: '# $title\n\n',
          );
          final file = File('${vaultState.currentVault!.path}/$relativePath');
          final dir = Directory('${vaultState.currentVault!.path}/$folderPath');
          if (!await dir.exists()) await dir.create(recursive: true);
          await file.writeAsString(note.toMarkdown());
          await ref.read(knowledgeProvider.notifier).loadAllNotes();
          ref.read(knowledgeProvider.notifier).openNote(note.id);
          if (widget.onNotePreview != null) {
            widget.onNotePreview!(note.id);
          } else {
            widget.onNoteOpened?.call();
          }
        }
      } else {
        await ref.read(knowledgeProvider.notifier).createNote(title: title);
      }
    }
  }

  @override
  void _renameNoteFolder(String folderPath) async {
    final l = AppLocalizations.of(context)!;
    final parts = folderPath.split('/');
    final oldName = parts.last;
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.renameFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final vaultState = ref.read(vaultProvider);
      if (vaultState.currentVault != null) {
        final parentPath = parts.length > 1
            ? parts.sublist(0, parts.length - 1).join('/')
            : '';
        final newFolderPath = parentPath.isEmpty
            ? newName
            : '$parentPath/$newName';
        final oldDir = Directory(
          '${vaultState.currentVault!.path}/$folderPath',
        );
        final newDir = Directory(
          '${vaultState.currentVault!.path}/$newFolderPath',
        );
        if (await oldDir.exists() && !await newDir.exists()) {
          await oldDir.rename(newDir.path);
        }
        if (_expandedNoteFolders.contains(folderPath)) {
          _expandedNoteFolders.remove(folderPath);
          _expandedNoteFolders.add(newFolderPath);
        }
        await ref.read(knowledgeProvider.notifier).loadAllNotes();
        await _scanDiskFolders();
      }
    }
  }

  @override
  void _confirmDeleteNoteFolder(String folderPath) async {
    final l = AppLocalizations.of(context)!;
    final knowledgeState = ref.read(knowledgeProvider);
    final count = knowledgeState.notes
        .where((n) => n.filePath.startsWith('$folderPath/'))
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteFolder),
        content: Text(l.deleteFolderConfirm(folderPath, count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final vaultState = ref.read(vaultProvider);
      if (vaultState.currentVault != null) {
        final dir = Directory('${vaultState.currentVault!.path}/$folderPath');
        if (await dir.exists()) await dir.delete(recursive: true);
        _expandedNoteFolders.remove(folderPath);
        await ref.read(knowledgeProvider.notifier).loadAllNotes();
        await _scanDiskFolders();
      }
    }
  }

  @override
  void _showMoveNoteDialog(Note note) async {
    final l = AppLocalizations.of(context)!;
    final knowledgeState = ref.read(knowledgeProvider);
    final allFolders = _getAllFolderPaths(knowledgeState.notes);
    final currentFolder = note.filePath.split('/').length > 1
        ? note.filePath
              .split('/')
              .sublist(0, note.filePath.split('/').length - 1)
              .join('/')
        : '';

    final targetFolder = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.moveToFolder),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(l.rootDirectory),
          ),
          ...allFolders
              .where((f) => f != currentFolder)
              .map(
                (f) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, f),
                  child: Text(f),
                ),
              ),
        ],
      ),
    );
    if (targetFolder != null && targetFolder != currentFolder) {
      await ref
          .read(knowledgeProvider.notifier)
          .moveNote(note.id, targetFolder);
      await _scanDiskFolders();
    }
  }

  List<String> _getAllFolderPaths(List<Note> notes) {
    final folders = <String>{};
    for (final note in notes) {
      final parts = note.filePath.split('/');
      for (var i = 1; i < parts.length; i++) {
        folders.add(parts.sublist(0, i).join('/'));
      }
    }
    for (final f in _diskFolders) {
      folders.add(f);
    }
    return folders.toList()..sort();
  }

  @override
  void _confirmDeleteNote(String title, String noteId) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteNote),
        content: Text(l.deleteNoteConfirm(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // 删除前保存笔记内容，用于撤销恢复
      final knowledgeState = ref.read(knowledgeProvider);
      final matchingNotes = knowledgeState.notes
          .where((n) => n.id == noteId)
          .toList();
      String? savedFilePath;
      String? savedMarkdown;
      if (matchingNotes.isNotEmpty) {
        savedFilePath = matchingNotes.first.filePath;
        savedMarkdown = matchingNotes.first.toMarkdown();
      }

      // 执行删除
      ref.read(knowledgeProvider.notifier).deleteNote(noteId);

      // 显示带撤销按钮的 SnackBar，5 秒内可恢复
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.noteDeleted),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () async {
              if (savedFilePath == null || savedMarkdown == null) return;
              final vaultState = ref.read(vaultProvider);
              if (vaultState.currentVault == null) return;
              final file = File(
                '${vaultState.currentVault!.path}/$savedFilePath',
              );
              final dir = Directory(file.parent.path);
              if (!await dir.exists()) {
                await dir.create(recursive: true);
              }
              await file.writeAsString(savedMarkdown);
              await ref.read(knowledgeProvider.notifier).loadAllNotes();
            },
          ),
        ),
      );
    }
  }
}
