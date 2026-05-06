import 'package:flutter/material.dart';
import 'dql_parser.dart';
import 'query_engine.dart';

class ResultRenderer {
  Widget render(DqlQuery query, QueryResult result) {
    switch (query.type) {
      case QueryType.table:
        return _renderTable(result);
      case QueryType.list:
        return _renderList(result);
      case QueryType.task:
        return _renderTaskList(result);
    }
  }

  Widget _renderTable(QueryResult result) {
    if (result.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No results found'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: result.fields.map((f) => DataColumn(label: Text(f))).toList(),
        rows: result.rows
            .map((row) => DataRow(
                  cells: result.fields
                      .map((f) => DataCell(Text('${row[f] ?? ''}')))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }

  Widget _renderList(QueryResult result) {
    if (result.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No results found'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result.rows.map((row) {
        final title = row['title']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              const Icon(Icons.note, size: 16),
              const SizedBox(width: 4),
              Text(title),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _renderTaskList(QueryResult result) {
    if (result.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No tasks found'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result.rows.map((row) {
        final title = row['title']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Checkbox(value: false, onChanged: (_) {}),
              const SizedBox(width: 4),
              Expanded(child: Text(title)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
