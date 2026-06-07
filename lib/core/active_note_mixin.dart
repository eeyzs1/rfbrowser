import '../data/models/note.dart';

mixin ActiveNoteMixin {
  List<Note> get notes;
  String? get activeNoteId;

  Note? get activeNote {
    if (activeNoteId == null) return null;
    try {
      return notes.firstWhere((n) => n.id == activeNoteId);
    } catch (_) {
      return null;
    }
  }
}