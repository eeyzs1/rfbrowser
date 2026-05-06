import 'dql_parser.dart';
import '../../../data/models/note.dart';

class QueryResult {
  final List<String> fields;
  final List<Map<String, dynamic>> rows;

  QueryResult({required this.fields, required this.rows});
}

class QueryEngine {
  final List<Note> _notes;

  QueryEngine(this._notes);

  QueryResult execute(DqlQuery query) {
    var filtered = _applyFilters(_notes, query.filters);
    filtered = _applySorts(filtered, query.sorts);

    final limit = query.limit ?? 100;
    if (filtered.length > limit) {
      filtered = filtered.sublist(0, limit);
    }

    final fields = query.fields.isNotEmpty
        ? query.fields
        : ['title', 'tags', 'created', 'modified'];

    final rows = filtered.map((note) {
      final row = <String, dynamic>{};
      for (final field in fields) {
        row[field] = _getNoteField(note, field);
      }
      return row;
    }).toList();

    return QueryResult(fields: fields, rows: rows);
  }

  List<Note> _applyFilters(List<Note> notes, List<QueryFilter> filters) {
    var result = notes;
    for (final filter in filters) {
      result = result.where((note) => _matchesFilter(note, filter)).toList();
    }
    return result;
  }

  bool _matchesFilter(Note note, QueryFilter filter) {
    if (filter is TagFilter) {
      return note.tags.any((t) => t.toLowerCase() == filter.tag.toLowerCase());
    }
    if (filter is DateFilter) {
      final fieldValue = _getNoteField(note, filter.field);
      if (fieldValue is DateTime) {
        return _compareDate(fieldValue, filter.operator, filter.value);
      }
    }
    if (filter is FieldFilter) {
      final fieldValue = _getNoteField(note, filter.field);
      final strValue = fieldValue?.toString() ?? '';
      return _compareField(strValue, filter.operator, filter.value);
    }
    return true;
  }

  bool _compareDate(DateTime field, String op, DateTime value) {
    final fieldDate = DateTime(field.year, field.month, field.day);
    final valueDate = DateTime(value.year, value.month, value.day);
    switch (op) {
      case '>=':
        return fieldDate.isAfter(valueDate) || fieldDate == valueDate;
      case '<=':
        return fieldDate.isBefore(valueDate) || fieldDate == valueDate;
      case '>':
        return fieldDate.isAfter(valueDate);
      case '<':
        return fieldDate.isBefore(valueDate);
      case '=':
        return fieldDate == valueDate;
      default:
        return true;
    }
  }

  bool _compareField(String fieldValue, String op, String value) {
    switch (op) {
      case '=':
        return fieldValue.toLowerCase() == value.toLowerCase();
      case '!=':
        return fieldValue.toLowerCase() != value.toLowerCase();
      default:
        return fieldValue.toLowerCase().contains(value.toLowerCase());
    }
  }

  List<Note> _applySorts(List<Note> notes, List<QuerySort> sorts) {
    if (sorts.isEmpty) return notes;
    final sorted = List<Note>.from(notes);
    for (final sort in sorts.reversed) {
      sorted.sort((a, b) {
        final va = _getNoteField(a, sort.field);
        final vb = _getNoteField(b, sort.field);
        final cmp = _compareValues(va, vb);
        return sort.direction == SortDirection.desc ? -cmp : cmp;
      });
    }
    return sorted;
  }

  int _compareValues(dynamic a, dynamic b) {
    if (a is DateTime && b is DateTime) {
      return a.compareTo(b);
    }
    if (a is String && b is String) {
      return a.compareTo(b);
    }
    return 0;
  }

  dynamic _getNoteField(Note note, String field) {
    switch (field.toLowerCase()) {
      case 'title':
        return note.title;
      case 'tags':
        return note.tags.join(', ');
      case 'created':
        return note.created;
      case 'modified':
        return note.modified;
      case 'id':
        return note.id;
      case 'filepath':
      case 'file_path':
        return note.filePath;
      case 'content':
        return note.content;
      case 'sourceurl':
      case 'source_url':
        return note.sourceUrl ?? '';
      default:
        return '';
    }
  }
}
