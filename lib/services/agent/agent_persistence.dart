import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/agent_task.dart';

class AgentPersistence {
  static const _fileName = 'agent_tasks.json';
  final String? basePath;

  AgentPersistence({this.basePath});

  Future<String> _getFilePath() async {
    if (basePath != null) {
      return '$basePath${Platform.pathSeparator}$_fileName';
    }
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}${Platform.pathSeparator}$_fileName';
  }

  Future<List<AgentTask>> loadTasks() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final json = jsonDecode(content) as List<dynamic>;
      final tasks = <AgentTask>[];
      for (final e in json) {
        if (e is Map<String, dynamic>) {
          try {
            tasks.add(AgentTask.fromJson(e));
          } catch (_) {}
        }
      }
      return tasks;
    } catch (e) {
      debugPrint('AgentPersistence.loadTasks error: $e');
      return [];
    }
  }

  Future<void> saveTasks(List<AgentTask> tasks) async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      await file.parent.create(recursive: true);
      final taskMaps = tasks.map((t) => t.toJson()).toList();
      await file.writeAsString(jsonEncode(taskMaps));
    } catch (e) {
      debugPrint('AgentPersistence.saveTasks error: $e');
    }
  }

  Future<void> clearTasks() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('AgentPersistence.clearTasks error: $e');
    }
  }
}
