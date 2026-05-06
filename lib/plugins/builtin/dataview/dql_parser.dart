enum QueryType { list, table, task }

enum SortDirection { asc, desc }

abstract class QueryFilter {}

class TagFilter extends QueryFilter {
  final String tag;
  TagFilter(this.tag);
}

class DateFilter extends QueryFilter {
  final String field;
  final String operator;
  final DateTime value;
  DateFilter(this.field, this.operator, this.value);
}

class FieldFilter extends QueryFilter {
  final String field;
  final String operator;
  final String value;
  FieldFilter(this.field, this.operator, this.value);
}

class QuerySort {
  final String field;
  final SortDirection direction;
  QuerySort(this.field, this.direction);
}

class DqlQuery {
  final QueryType type;
  final List<String> fields;
  final List<QueryFilter> filters;
  final List<QuerySort> sorts;
  final int? limit;

  DqlQuery({
    required this.type,
    this.fields = const [],
    this.filters = const [],
    this.sorts = const [],
    this.limit,
  });
}

class DqlParser {
  static final _tagFilterRegex = RegExp(r'tag\s*=\s*#(\w+)', caseSensitive: false);
  static final _dateFilterRegex =
      RegExp(r'(\w+)\s*(>=|<=|>|<|=)\s*(\d{4}-\d{2}-\d{2})', caseSensitive: false);
  static final _sortRegex = RegExp(r'(\w+)\s+(ASC|DESC)', caseSensitive: false);

  DqlQuery parse(String input) {
    final trimmed = input.trim();
    final upper = trimmed.toUpperCase();

    QueryType type;
    if (upper.startsWith('TABLE')) {
      type = QueryType.table;
    } else if (upper.startsWith('TASK')) {
      type = QueryType.task;
    } else {
      type = QueryType.list;
    }

    List<String> fields = [];
    if (type == QueryType.table) {
      final afterTable = trimmed.substring(5).trim();
      final whereIdx = afterTable.toUpperCase().indexOf('WHERE');
      final sortIdx = afterTable.toUpperCase().indexOf('SORT');
      int fieldsEnd = afterTable.length;
      if (whereIdx >= 0) fieldsEnd = whereIdx;
      if (sortIdx >= 0 && sortIdx < fieldsEnd) fieldsEnd = sortIdx;
      final fieldsStr = afterTable.substring(0, fieldsEnd).trim();
      fields = fieldsStr
          .split(',')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty)
          .toList();
    }

    final filters = <QueryFilter>[];
    final whereKeywordIdx = _findKeyword(upper, 'WHERE');
    if (whereKeywordIdx >= 0) {
      final sortKeywordIdx = _findKeyword(upper, 'SORT');
      final filterEnd = sortKeywordIdx >= 0 ? sortKeywordIdx : trimmed.length;
      final filterStr = trimmed.substring(whereKeywordIdx + 5, filterEnd).trim();
      filters.addAll(_parseFilters(filterStr));
    }

    final sorts = <QuerySort>[];
    final sortKeywordIdx = _findKeyword(upper, 'SORT');
    if (sortKeywordIdx >= 0) {
      final afterSort = trimmed.substring(sortKeywordIdx + 4).trim();
      sorts.addAll(_parseSorts(afterSort));
    }

    return DqlQuery(
      type: type,
      fields: fields,
      filters: filters,
      sorts: sorts,
    );
  }

  List<QueryFilter> _parseFilters(String filterStr) {
    final filters = <QueryFilter>[];

    final tagMatches = _tagFilterRegex.allMatches(filterStr);
    for (final m in tagMatches) {
      filters.add(TagFilter(m.group(1)!));
    }

    final dateMatches = _dateFilterRegex.allMatches(filterStr);
    for (final m in dateMatches) {
      final field = m.group(1)!;
      final op = m.group(2)!;
      final dateStr = m.group(3)!;
      if (field.toLowerCase() != 'tag') {
        filters.add(DateFilter(field, op, DateTime.parse(dateStr)));
      }
    }

    return filters;
  }

  List<QuerySort> _parseSorts(String sortStr) {
    final sorts = <QuerySort>[];
    final matches = _sortRegex.allMatches(sortStr);
    for (final m in matches) {
      final field = m.group(1)!;
      final dir = m.group(2)!.toUpperCase() == 'DESC'
          ? SortDirection.desc
          : SortDirection.asc;
      sorts.add(QuerySort(field, dir));
    }
    return sorts;
  }

  int _findKeyword(String upperInput, String keyword) {
    final pattern = RegExp('\\b$keyword\\b', caseSensitive: false);
    final match = pattern.firstMatch(upperInput);
    return match?.start ?? -1;
  }
}
