import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:rfbrowser/services/dreaming_service.dart';
import 'package:rfbrowser/services/memory_service.dart';
import 'package:rfbrowser/services/settings_service.dart';
import '../helpers/sqflite_test_setup.dart';

void main() {
  setUpAll(setupSqfliteForTests);

  group('AppSettings memory fields', () {
    test('defaults match the OpenLoomi policy', () {
      final s = AppSettings();
      expect(s.memory.injectContext, isTrue);
      expect(s.memory.shortToMidThreshold, 0.65);
      expect(s.memory.midToLongThreshold, 0.45);
      expect(s.memory.shortMaxAgeDays, 7);
      expect(s.memory.midMaxAgeDays, 30);
      expect(s.memory.hebbianCoAccessMinutes, 5);
      expect(s.memory.hebbianDecayDays, 30);
      expect(s.memory.autoExportEveryNMessages, 16);
      expect(s.memory.dreamingEnabled, isTrue);
    });

    test('copyWith round-trips memory fields', () {
      final s = AppSettings();
      final s2 = s.copyWith(
        memory: s.memory.copyWith(
          injectContext: false,
          shortToMidThreshold: 0.5,
          dreamingEnabled: false,
        ),
      );
      expect(s2.memory.injectContext, isFalse);
      expect(s2.memory.shortToMidThreshold, 0.5);
      expect(s2.memory.dreamingEnabled, isFalse);
      // Untouched fields keep their previous value.
      expect(s2.memory.midToLongThreshold, s.memory.midToLongThreshold);
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
