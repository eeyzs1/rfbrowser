part of 'settings_service.dart';

/// Memory-related setters for [SettingsNotifier].
///
/// Declares [_updateSetting] as an abstract member so the mixin can reuse the
/// host class's persistence helper. All memory setters persist to
/// SharedPreferences with the legacy `memory*` key names and update the
/// `memory` field of [AppSettings] via [MemorySettings.copyWith].
mixin _MemorySettersMixin on Notifier<AppSettings> {
  Future<void> _updateSetting<T>({
    required String key,
    required T value,
    required Future<void> Function(SharedPreferences, String, T) persist,
    required AppSettings Function(AppSettings, T) update,
  });

  Future<void> setMemoryInjectContext(bool v) async {
    await _updateSetting(
      key: 'memoryInjectContext',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(injectContext: val)),
    );
  }

  Future<void> setMemoryShortToMidThreshold(double v) async {
    await _updateSetting(
      key: 'memoryShortToMidThreshold',
      value: v,
      persist: (p, k, val) => p.setDouble(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(shortToMidThreshold: val)),
    );
  }

  Future<void> setMemoryMidToLongThreshold(double v) async {
    await _updateSetting(
      key: 'memoryMidToLongThreshold',
      value: v,
      persist: (p, k, val) => p.setDouble(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(midToLongThreshold: val)),
    );
  }

  Future<void> setMemoryShortMaxAgeDays(int v) async {
    await _updateSetting(
      key: 'memoryShortMaxAgeDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(shortMaxAgeDays: val)),
    );
  }

  Future<void> setMemoryMidMaxAgeDays(int v) async {
    await _updateSetting(
      key: 'memoryMidMaxAgeDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(midMaxAgeDays: val)),
    );
  }

  Future<void> setMemoryHebbianCoAccessMinutes(int v) async {
    await _updateSetting(
      key: 'memoryHebbianCoAccessMinutes',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(hebbianCoAccessMinutes: val)),
    );
  }

  Future<void> setMemoryHebbianDecayDays(int v) async {
    await _updateSetting(
      key: 'memoryHebbianDecayDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(hebbianDecayDays: val)),
    );
  }

  Future<void> setMemoryAutoExportEveryNMessages(int v) async {
    await _updateSetting(
      key: 'memoryAutoExportEveryNMessages',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(autoExportEveryNMessages: val)),
    );
  }

  Future<void> setMemoryDreamingEnabled(bool v) async {
    await _updateSetting(
      key: 'memoryDreamingEnabled',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(dreamingEnabled: val)),
    );
  }

  Future<void> setMemoryCreatedRecencyHalfLifeDays(int v) async {
    await _updateSetting(
      key: 'memoryCreatedRecencyHalfLifeDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) => s.copyWith(
        memory: s.memory.copyWith(createdRecencyHalfLifeDays: val),
      ),
    );
  }

  Future<void> setMemoryAccessRecencyHalfLifeDays(int v) async {
    await _updateSetting(
      key: 'memoryAccessRecencyHalfLifeDays',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(accessRecencyHalfLifeDays: val)),
    );
  }

  Future<void> setMemoryUseLastAccessForRecency(bool v) async {
    await _updateSetting(
      key: 'memoryUseLastAccessForRecency',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(useLastAccessForRecency: val)),
    );
  }

  Future<void> setMemoryContextBudget(int v) async {
    await _updateSetting(
      key: 'memoryContextBudget',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(contextBudget: val)),
    );
  }

  Future<void> setMemoryUseLlmSummarizer(bool v) async {
    await _updateSetting(
      key: 'memoryUseLlmSummarizer',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(useLlmSummarizer: val)),
    );
  }

  Future<void> setMemoryUseLlmRerank(bool v) async {
    await _updateSetting(
      key: 'memoryUseLlmRerank',
      value: v,
      persist: (p, k, val) => p.setBool(k, val),
      update: (s, val) =>
          s.copyWith(memory: s.memory.copyWith(useLlmRerank: val)),
    );
  }
}
