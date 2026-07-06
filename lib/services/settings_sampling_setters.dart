part of 'settings_service.dart';

/// Sampling-related setters for [SettingsNotifier].
///
/// Declares [_updateSetting] as an abstract member so the mixin can reuse the
/// host class's persistence helper. All sampling setters persist to
/// SharedPreferences with the `sampling*` key prefix and update the
/// `sampling` field of [AppSettings] via [SamplingSettings.copyWith].
mixin _SamplingSettersMixin on Notifier<AppSettings> {
  Future<void> _updateSetting<T>({
    required String key,
    required T value,
    required Future<void> Function(SharedPreferences, String, T) persist,
    required AppSettings Function(AppSettings, T) update,
  });

  /// Provided by [SharedPrefsAware] on the host [SettingsNotifier].
  Future<SharedPreferences> get ensurePrefs;

  // ── Chat scene ──────────────────────────────────────────────────────

  Future<void> setSamplingChatTemperature(double v) async {
    await _updateSetting(
      key: 'samplingChatTemperature',
      value: v,
      persist: (p, k, val) => p.setDouble(k, val),
      update: (s, val) =>
          s.copyWith(sampling: s.sampling.copyWith(chatTemperature: val)),
    );
  }

  /// Live update for slider dragging — updates state without disk I/O.
  void setSamplingChatTemperatureLive(double v) {
    state = state.copyWith(
      sampling: state.sampling.copyWith(chatTemperature: v),
    );
  }

  Future<void> setSamplingChatMaxTokens(int? v) async {
    if (v == null) {
      // 清除值:删除 key 并置 null
      final prefs = await ensurePrefs;
      await prefs.remove('samplingChatMaxTokens');
      state = state.copyWith(
        sampling: state.sampling.copyWith(clearChatMaxTokens: true),
      );
    } else {
      await _updateSetting(
        key: 'samplingChatMaxTokens',
        value: v,
        persist: (p, k, val) => p.setInt(k, val),
        update: (s, val) =>
            s.copyWith(sampling: s.sampling.copyWith(chatMaxTokens: val)),
      );
    }
  }

  // ── Agent scene ─────────────────────────────────────────────────────

  Future<void> setSamplingAgentTemperature(double v) async {
    await _updateSetting(
      key: 'samplingAgentTemperature',
      value: v,
      persist: (p, k, val) => p.setDouble(k, val),
      update: (s, val) =>
          s.copyWith(sampling: s.sampling.copyWith(agentTemperature: val)),
    );
  }

  void setSamplingAgentTemperatureLive(double v) {
    state = state.copyWith(
      sampling: state.sampling.copyWith(agentTemperature: v),
    );
  }

  Future<void> setSamplingAgentMaxTokens(int v) async {
    await _updateSetting(
      key: 'samplingAgentMaxTokens',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(sampling: s.sampling.copyWith(agentMaxTokens: val)),
    );
  }

  // ── Dreaming scene ──────────────────────────────────────────────────

  Future<void> setSamplingDreamingTemperature(double v) async {
    await _updateSetting(
      key: 'samplingDreamingTemperature',
      value: v,
      persist: (p, k, val) => p.setDouble(k, val),
      update: (s, val) =>
          s.copyWith(sampling: s.sampling.copyWith(dreamingTemperature: val)),
    );
  }

  void setSamplingDreamingTemperatureLive(double v) {
    state = state.copyWith(
      sampling: state.sampling.copyWith(dreamingTemperature: v),
    );
  }

  Future<void> setSamplingDreamingMaxTokens(int v) async {
    await _updateSetting(
      key: 'samplingDreamingMaxTokens',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(sampling: s.sampling.copyWith(dreamingMaxTokens: val)),
    );
  }

  // ── Agent execution limits ──────────────────────────────────────────

  Future<void> setSamplingMaxToolLoops(int v) async {
    await _updateSetting(
      key: 'samplingMaxToolLoops',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(sampling: s.sampling.copyWith(maxToolLoops: val)),
    );
  }

  Future<void> setSamplingMaxReactIterations(int v) async {
    await _updateSetting(
      key: 'samplingMaxReactIterations',
      value: v,
      persist: (p, k, val) => p.setInt(k, val),
      update: (s, val) =>
          s.copyWith(sampling: s.sampling.copyWith(maxReactIterations: val)),
    );
  }
}
