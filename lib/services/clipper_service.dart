import '../data/models/note.dart';
import '../data/repositories/note_repository.dart';
import 'knowledge_service.dart';

class ClipperService {
  final NoteRepository _noteRepo;
  final KnowledgeNotifier _knowledgeNotifier;

  ClipperService(this._noteRepo, this._knowledgeNotifier);

  Future<Note> clipFullPage({
    required String url,
    required String title,
    required String htmlContent,
    required String textContent,
  }) async {
    final markdownContent = _htmlToMarkdown(textContent);
    final note = await _noteRepo.clipToNote(
      url: url,
      title: title,
      content: markdownContent,
    );
    await _knowledgeNotifier.loadAllNotes();
    return note;
  }

  Future<Note> clipSelection({
    required String url,
    required String title,
    required String selectedText,
  }) async {
    final note = await _noteRepo.clipToNote(
      url: url,
      title: title,
      content: selectedText,
      selectedText: selectedText,
    );
    await _knowledgeNotifier.loadAllNotes();
    return note;
  }

  Future<Note> clipBookmark({
    required String url,
    required String title,
  }) async {
    final note = await _noteRepo.clipToNote(
      url: url,
      title: title,
      content: '# $title\n\n> Source: [$title]($url)\n',
    );
    await _knowledgeNotifier.loadAllNotes();
    return note;
  }

  String _htmlToMarkdown(String html) {
    var text = html;
    text = text.replaceAll(RegExp(r'<h1[^>]*>(.*?)</h1>'), '# \$1\n\n');
    text = text.replaceAll(RegExp(r'<h2[^>]*>(.*?)</h2>'), '## \$1\n\n');
    text = text.replaceAll(RegExp(r'<h3[^>]*>(.*?)</h3>'), '### \$1\n\n');
    text = text.replaceAll(RegExp(r'<h4[^>]*>(.*?)</h4>'), '#### \$1\n\n');
    text = text.replaceAll(RegExp(r'<b[^>]*>(.*?)</b>'), '**\$1**');
    text = text.replaceAll(RegExp(r'<strong[^>]*>(.*?)</strong>'), '**\$1**');
    text = text.replaceAll(RegExp(r'<i[^>]*>(.*?)</i>'), '*\$1*');
    text = text.replaceAll(RegExp(r'<em[^>]*>(.*?)</em>'), '*\$1*');
    text = text.replaceAll(RegExp(r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>'), '[\$2](\$1)');
    text = text.replaceAll(RegExp(r'<li[^>]*>(.*?)</li>'), '- \$1\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<p[^>]*>(.*?)</p>'), '\$1\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
