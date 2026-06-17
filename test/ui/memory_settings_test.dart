import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:rfbrowser/services/dreaming_service.dart';
import 'package:rfbrowser/services/memory_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AppSettings memory fields', () {
    test('defaults match the OpenLoomi policy', () {
      final s = AppSettings();
      expect(s.memoryInjectContext, isTrue);
      expect(s.memoryShortToMidThreshold, 0.65);
      expect(s.memoryMidToLongThreshold, 0.45);
      expect(s.memoryShortMaxAgeDays, 7);
      expect(s.memoryMidMaxAgeDays, 30);
      expect(s.memoryHebbianCoAccessMinutes, 5);
      expect(s.memoryHebbianDecayDays, 30);
      expect(s.memoryAutoExportEveryNMessages, 16);
      expect(s.memoryDreamingEnabled, isTrue);
    });

    test('copyWith round-trips memory fields', () {
      final s = AppSettings();
      final s2 = s.copyWith(
        memoryInjectContext: false,
        memoryShortToMidThreshold: 0.5,
        memoryDreamingEnabled: false,
      );
      expect(s2.memoryInjectContext, isFalse);
      expect(s2.memoryShortToMidThreshold, 0.5);
      expect(s2.memoryDreamingEnabled, isFalse);
      // Untouched fields keep their previous value.
      expect(s2.memoryMidToLongThreshold, s.memoryMidToLongThreshold);
    });
  });

  group('DreamingService.setDreamingEnabled', () {
    test('defaults to enabled when no setter call has been made', () {
      final memory = _stubMemory();
      addTearDown(memory.close);
      final svc = DreamingService(memory);
      expect(svc.isDreamingEnabled, isTrue);
    });

    test('isDreamingEnabled reflects the last setter call', () {
      final memory = _stubMemory();
      addTearDown(memory.close);
      final svc = DreamingService(memory);
      svc.setDreamingEnabled(false);
      expect(svc.isDreamingEnabled, isFalse);
      svc.setDreamingEnabled(true);
      expect(svc.isDreamingEnabled, isTrue);
    });
  });
}

MemoryService _stubMemory() {
  final dir = Directory.systemTemp.createTempSync('rfbrowser_dream_');
  return MemoryService(p.join(dir.path, 'memory.db'));
}
