import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/plugins/builtin/dataview/dql_parser.dart';
import 'package:rfbrowser/plugins/builtin/dataview/query_engine.dart';
import 'package:rfbrowser/plugins/builtin/dataview/result_renderer.dart';
import 'package:rfbrowser/data/models/note.dart';

void main() {
  group('DqlParser', () {
    final parser = DqlParser();

    test('AC-P4-4-1: parse LIST WHERE tag = #project', () {
      final query = parser.parse('LIST WHERE tag = #project');
      expect(query.type, QueryType.list);
      expect(query.filters.length, 1);
      expect(query.filters.first, isA<TagFilter>());
      expect((query.filters.first as TagFilter).tag, 'project');
    });

    test('AC-P4-4-2: parse TABLE with fields, WHERE, SORT', () {
      final query = parser.parse(
        'TABLE title, created WHERE tag = #project SORT created DESC',
      );
      expect(query.type, QueryType.table);
      expect(query.fields, ['title', 'created']);
      final tagFilters = query.filters.whereType<TagFilter>().toList();
      expect(tagFilters.length, 1, reason: 'Expected 1 TagFilter but got filters: ${query.filters}');
      expect(tagFilters.first.tag, 'project');
      expect(query.sorts.length, 1);
      expect(query.sorts.first.field, 'created');
      expect(query.sorts.first.direction, SortDirection.desc);
    });

    test('parse TASK WHERE tag = #todo', () {
      final query = parser.parse('TASK WHERE tag = #todo');
      expect(query.type, QueryType.task);
      expect(query.filters.length, 1);
      expect((query.filters.first as TagFilter).tag, 'todo');
    });

    test('parse LIST without WHERE', () {
      final query = parser.parse('LIST');
      expect(query.type, QueryType.list);
      expect(query.filters.isEmpty, true);
    });

    test('parse TABLE without WHERE and SORT', () {
      final query = parser.parse('TABLE title, tags');
      expect(query.type, QueryType.table);
      expect(query.fields, ['title', 'tags']);
      expect(query.filters.isEmpty, true);
      expect(query.sorts.isEmpty, true);
    });

    test('parse date filter: created >= 2025-01-01', () {
      final query = parser.parse('LIST WHERE created >= 2025-01-01');
      expect(query.filters.length, 1);
      expect(query.filters.first, isA<DateFilter>());
      final df = query.filters.first as DateFilter;
      expect(df.field, 'created');
      expect(df.operator, '>=');
      expect(df.value.year, 2025);
    });

    test('parse multiple filters with tag and date', () {
      final query = parser.parse('LIST WHERE tag = #project AND created >= 2025-01-01');
      expect(query.filters.length, 2);
    });
  });

  group('QueryEngine', () {
    List<Note> createTestNotes() {
      return [
        Note(id: '1', title: 'Project A', filePath: 'a.md', content: 'Content A',
            tags: ['project', 'active'], aliases: [],
            created: DateTime(2025, 3, 15), modified: DateTime(2025, 4, 1)),
        Note(id: '2', title: 'Project B', filePath: 'b.md', content: 'Content B',
            tags: ['project'], aliases: [],
            created: DateTime(2024, 11, 1), modified: DateTime(2024, 12, 1)),
        Note(id: '3', title: 'Personal Note', filePath: 'c.md', content: 'Content C',
            tags: ['personal'], aliases: [],
            created: DateTime(2025, 1, 10), modified: DateTime(2025, 2, 1)),
        Note(id: '4', title: 'Project C', filePath: 'd.md', content: 'Content D',
            tags: ['project', 'archived'], aliases: [],
            created: DateTime(2025, 5, 20), modified: DateTime(2025, 6, 1)),
        Note(id: '5', title: 'Meeting Notes', filePath: 'e.md', content: 'Content E',
            tags: ['project', 'meeting'], aliases: [],
            created: DateTime(2025, 2, 28), modified: DateTime(2025, 3, 1)),
      ];
    }

    test('AC-P4-4-3: 5 notes with #project tag, LIST WHERE tag=#project returns 4', () {
      final engine = QueryEngine(createTestNotes());
      final query = DqlQuery(
        type: QueryType.list,
        filters: [TagFilter('project')],
      );
      final result = engine.execute(query);
      expect(result.rows.length, 4);
    });

    test('AC-P4-4-4: date filter created >= 2025-01-01 returns 4 results', () {
      final engine = QueryEngine(createTestNotes());
      final query = DqlQuery(
        type: QueryType.list,
        filters: [DateFilter('created', '>=', DateTime(2025, 1, 1))],
      );
      final result = engine.execute(query);
      expect(result.rows.length, 4);
    });

    test('AC-P4-4-6: results limited to 100 by default', () {
      final manyNotes = List.generate(
        200,
        (i) => Note(
          id: '$i', title: 'Note $i', filePath: 'n$i.md', content: 'C$i',
          tags: ['test'], aliases: [],
          created: DateTime(2025), modified: DateTime(2025),
        ),
      );
      final engine = QueryEngine(manyNotes);
      final query = DqlQuery(type: QueryType.list, filters: [TagFilter('test')]);
      final result = engine.execute(query);
      expect(result.rows.length, 100);
    });

    test('SORT created DESC orders correctly', () {
      final engine = QueryEngine(createTestNotes());
      final query = DqlQuery(
        type: QueryType.list,
        filters: [TagFilter('project')],
        sorts: [QuerySort('created', SortDirection.desc)],
      );
      final result = engine.execute(query);
      expect(result.rows.first['title'], 'Project C');
      expect(result.rows.last['title'], 'Project B');
    });

    test('TABLE query returns specified fields', () {
      final engine = QueryEngine(createTestNotes());
      final query = DqlQuery(
        type: QueryType.table,
        fields: ['title', 'tags'],
        filters: [TagFilter('project')],
      );
      final result = engine.execute(query);
      expect(result.fields, ['title', 'tags']);
      expect(result.rows.first.containsKey('title'), true);
      expect(result.rows.first.containsKey('tags'), true);
    });
  });

  group('ResultRenderer', () {
    test('AC-P4-4-5: render TABLE query returns Widget with DataTable', () {
      final renderer = ResultRenderer();
      final query = DqlQuery(type: QueryType.table, fields: ['title', 'tags']);
      final result = QueryResult(
        fields: ['title', 'tags'],
        rows: [
          {'title': 'Note 1', 'tags': 'project'},
          {'title': 'Note 2', 'tags': 'personal'},
        ],
      );

      final widget = renderer.render(query, result);
      expect(widget, isA<SingleChildScrollView>());
    });

    test('render LIST query returns Widget with Column', () {
      final renderer = ResultRenderer();
      final query = DqlQuery(type: QueryType.list);
      final result = QueryResult(
        fields: ['title'],
        rows: [
          {'title': 'Note 1'},
        ],
      );

      final widget = renderer.render(query, result);
      expect(widget, isA<Column>());
    });

    test('render empty result shows no results message', () {
      final renderer = ResultRenderer();
      final query = DqlQuery(type: QueryType.list);
      final result = QueryResult(fields: ['title'], rows: []);

      final widget = renderer.render(query, result);
      expect(widget, isA<Padding>());
    });
  });
}
