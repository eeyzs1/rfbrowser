import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rfbrowser/data/models/memory_settings.dart';

/// The 15 legacy SharedPreferences keys that [MemorySettings] reads/writes.
/// These names must never change — existing installs depend on them.
const List<String> kLegacyKeys = [
  'memoryInjectContext',
  'memoryShortToMidThreshold',
  'memoryMidToLongThreshold',
  'memoryShortMaxAgeDays',
  'memoryMidMaxAgeDays',
  'memoryHebbianCoAccessMinutes',
  'memoryHebbianDecayDays',
  'memoryAutoExportEveryNMessages',
  'memoryDreamingEnabled',
  'memoryCreatedRecencyHalfLifeDays',
  'memoryAccessRecencyHalfLifeDays',
  'memoryUseLastAccessForRecency',
  'memoryContextBudget',
  'memoryUseLlmSummarizer',
  'memoryUseLlmRerank',
];

void main() {
  group('MemorySettings defaults', () {
    test('all 15 fields match documented defaults', () {
      const s = MemorySettings();
      expect(s.injectContext, isTrue);
      expect(s.shortToMidThreshold, 0.65);
      expect(s.midToLongThreshold, 0.45);
      expect(s.shortMaxAgeDays, 7);
      expect(s.midMaxAgeDays, 30);
      expect(s.hebbianCoAccessMinutes, 5);
      expect(s.hebbianDecayDays, 30);
      expect(s.autoExportEveryNMessages, 16);
      expect(s.dreamingEnabled, isTrue);
      expect(s.createdRecencyHalfLifeDays, 180);
      expect(s.accessRecencyHalfLifeDays, 30);
      expect(s.useLastAccessForRecency, isTrue);
      expect(s.contextBudget, 800);
      expect(s.useLlmSummarizer, isFalse);
      expect(s.useLlmRerank, isFalse);
    });
  });

  group('MemorySettings.fromPrefs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('falls back to defaults when prefs are empty', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = MemorySettings.fromPrefs(prefs);
      const expected = MemorySettings();
      expect(s.injectContext, expected.injectContext);
      expect(s.shortToMidThreshold, expected.shortToMidThreshold);
      expect(s.midToLongThreshold, expected.midToLongThreshold);
      expect(s.shortMaxAgeDays, expected.shortMaxAgeDays);
      expect(s.midMaxAgeDays, expected.midMaxAgeDays);
      expect(s.hebbianCoAccessMinutes, expected.hebbianCoAccessMinutes);
      expect(s.hebbianDecayDays, expected.hebbianDecayDays);
      expect(s.autoExportEveryNMessages, expected.autoExportEveryNMessages);
      expect(s.dreamingEnabled, expected.dreamingEnabled);
      expect(s.createdRecencyHalfLifeDays, expected.createdRecencyHalfLifeDays);
      expect(s.accessRecencyHalfLifeDays, expected.accessRecencyHalfLifeDays);
      expect(s.useLastAccessForRecency, expected.useLastAccessForRecency);
      expect(s.contextBudget, expected.contextBudget);
      expect(s.useLlmSummarizer, expected.useLlmSummarizer);
      expect(s.useLlmRerank, expected.useLlmRerank);
    });

    test('reads custom values from prefs using legacy keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('memoryInjectContext', false);
      await prefs.setDouble('memoryShortToMidThreshold', 0.5);
      await prefs.setDouble('memoryMidToLongThreshold', 0.3);
      await prefs.setInt('memoryShortMaxAgeDays', 14);
      await prefs.setInt('memoryMidMaxAgeDays', 60);
      await prefs.setInt('memoryHebbianCoAccessMinutes', 10);
      await prefs.setInt('memoryHebbianDecayDays', 90);
      await prefs.setInt('memoryAutoExportEveryNMessages', 32);
      await prefs.setBool('memoryDreamingEnabled', false);
      await prefs.setInt('memoryCreatedRecencyHalfLifeDays', 365);
      await prefs.setInt('memoryAccessRecencyHalfLifeDays', 60);
      await prefs.setBool('memoryUseLastAccessForRecency', false);
      await prefs.setInt('memoryContextBudget', 1500);
      await prefs.setBool('memoryUseLlmSummarizer', true);
      await prefs.setBool('memoryUseLlmRerank', true);

      final s = MemorySettings.fromPrefs(prefs);
      expect(s.injectContext, isFalse);
      expect(s.shortToMidThreshold, 0.5);
      expect(s.midToLongThreshold, 0.3);
      expect(s.shortMaxAgeDays, 14);
      expect(s.midMaxAgeDays, 60);
      expect(s.hebbianCoAccessMinutes, 10);
      expect(s.hebbianDecayDays, 90);
      expect(s.autoExportEveryNMessages, 32);
      expect(s.dreamingEnabled, isFalse);
      expect(s.createdRecencyHalfLifeDays, 365);
      expect(s.accessRecencyHalfLifeDays, 60);
      expect(s.useLastAccessForRecency, isFalse);
      expect(s.contextBudget, 1500);
      expect(s.useLlmSummarizer, isTrue);
      expect(s.useLlmRerank, isTrue);
    });
  });

  group('MemorySettings.saveToPrefs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('writes all 15 fields using legacy key names', () async {
      final prefs = await SharedPreferences.getInstance();
      const s = MemorySettings(
        injectContext: false,
        shortToMidThreshold: 0.5,
        midToLongThreshold: 0.3,
        shortMaxAgeDays: 14,
        midMaxAgeDays: 60,
        hebbianCoAccessMinutes: 10,
        hebbianDecayDays: 90,
        autoExportEveryNMessages: 32,
        dreamingEnabled: false,
        createdRecencyHalfLifeDays: 365,
        accessRecencyHalfLifeDays: 60,
        useLastAccessForRecency: false,
        contextBudget: 1500,
        useLlmSummarizer: true,
        useLlmRerank: true,
      );

      await s.saveToPrefs(prefs);

      // Verify every legacy key is present with the expected value.
      expect(prefs.getBool('memoryInjectContext'), isFalse);
      expect(prefs.getDouble('memoryShortToMidThreshold'), 0.5);
      expect(prefs.getDouble('memoryMidToLongThreshold'), 0.3);
      expect(prefs.getInt('memoryShortMaxAgeDays'), 14);
      expect(prefs.getInt('memoryMidMaxAgeDays'), 60);
      expect(prefs.getInt('memoryHebbianCoAccessMinutes'), 10);
      expect(prefs.getInt('memoryHebbianDecayDays'), 90);
      expect(prefs.getInt('memoryAutoExportEveryNMessages'), 32);
      expect(prefs.getBool('memoryDreamingEnabled'), isFalse);
      expect(prefs.getInt('memoryCreatedRecencyHalfLifeDays'), 365);
      expect(prefs.getInt('memoryAccessRecencyHalfLifeDays'), 60);
      expect(prefs.getBool('memoryUseLastAccessForRecency'), isFalse);
      expect(prefs.getInt('memoryContextBudget'), 1500);
      expect(prefs.getBool('memoryUseLlmSummarizer'), isTrue);
      expect(prefs.getBool('memoryUseLlmRerank'), isTrue);
    });

    test('round-trip: saveToPrefs → fromPrefs preserves all fields', () async {
      final prefs = await SharedPreferences.getInstance();
      const original = MemorySettings(
        injectContext: false,
        shortToMidThreshold: 0.42,
        midToLongThreshold: 0.33,
        shortMaxAgeDays: 3,
        midMaxAgeDays: 21,
        hebbianCoAccessMinutes: 15,
        hebbianDecayDays: 45,
        autoExportEveryNMessages: 8,
        dreamingEnabled: false,
        createdRecencyHalfLifeDays: 200,
        accessRecencyHalfLifeDays: 15,
        useLastAccessForRecency: false,
        contextBudget: 2048,
        useLlmSummarizer: true,
        useLlmRerank: true,
      );

      await original.saveToPrefs(prefs);
      final restored = MemorySettings.fromPrefs(prefs);

      expect(restored.injectContext, original.injectContext);
      expect(restored.shortToMidThreshold, original.shortToMidThreshold);
      expect(restored.midToLongThreshold, original.midToLongThreshold);
      expect(restored.shortMaxAgeDays, original.shortMaxAgeDays);
      expect(restored.midMaxAgeDays, original.midMaxAgeDays);
      expect(restored.hebbianCoAccessMinutes, original.hebbianCoAccessMinutes);
      expect(restored.hebbianDecayDays, original.hebbianDecayDays);
      expect(
        restored.autoExportEveryNMessages,
        original.autoExportEveryNMessages,
      );
      expect(restored.dreamingEnabled, original.dreamingEnabled);
      expect(
        restored.createdRecencyHalfLifeDays,
        original.createdRecencyHalfLifeDays,
      );
      expect(
        restored.accessRecencyHalfLifeDays,
        original.accessRecencyHalfLifeDays,
      );
      expect(
        restored.useLastAccessForRecency,
        original.useLastAccessForRecency,
      );
      expect(restored.contextBudget, original.contextBudget);
      expect(restored.useLlmSummarizer, original.useLlmSummarizer);
      expect(restored.useLlmRerank, original.useLlmRerank);
    });
  });

  group('MemorySettings.copyWith', () {
    test('updates only the specified field', () {
      const s = MemorySettings();
      final s2 = s.copyWith(contextBudget: 4096);
      expect(s2.contextBudget, 4096);
      // All other fields unchanged.
      expect(s2.injectContext, s.injectContext);
      expect(s2.shortToMidThreshold, s.shortToMidThreshold);
      expect(s2.dreamingEnabled, s.dreamingEnabled);
      expect(s2.useLlmSummarizer, s.useLlmSummarizer);
    });

    test('updates multiple fields at once', () {
      const s = MemorySettings();
      final s2 = s.copyWith(
        injectContext: false,
        dreamingEnabled: false,
        useLlmRerank: true,
        hebbianDecayDays: 99,
      );
      expect(s2.injectContext, isFalse);
      expect(s2.dreamingEnabled, isFalse);
      expect(s2.useLlmRerank, isTrue);
      expect(s2.hebbianDecayDays, 99);
      // Unchanged.
      expect(s2.contextBudget, s.contextBudget);
      expect(s2.shortMaxAgeDays, s.shortMaxAgeDays);
    });

    test('no-arg copyWith returns an equivalent instance', () {
      const s = MemorySettings(
        injectContext: false,
        contextBudget: 1000,
        dreamingEnabled: false,
      );
      final s2 = s.copyWith();
      expect(s2.injectContext, s.injectContext);
      expect(s2.contextBudget, s.contextBudget);
      expect(s2.dreamingEnabled, s.dreamingEnabled);
    });
  });

  group('Legacy key name regression guard', () {
    // This test prevents accidental renaming of SharedPreferences keys
    // during refactoring — existing installs would lose their settings.
    test('saveToPrefs writes exactly the 15 legacy keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const s = MemorySettings();
      await s.saveToPrefs(prefs);

      final writtenKeys = prefs.getKeys().toSet();
      for (final key in kLegacyKeys) {
        expect(
          writtenKeys,
          contains(key),
          reason:
              'Legacy key "$key" was not written by saveToPrefs. '
              'Existing installs depend on this key name.',
        );
      }
      expect(
        writtenKeys.length,
        kLegacyKeys.length,
        reason:
            'saveToPrefs wrote ${writtenKeys.length} keys, '
            'expected ${kLegacyKeys.length}. '
            'Extra keys: ${writtenKeys.difference(kLegacyKeys.toSet())}',
      );
    });
  });
}
