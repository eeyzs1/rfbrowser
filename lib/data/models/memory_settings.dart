import 'package:shared_preferences/shared_preferences.dart';

/// Memory subsystem settings — progressive forgetting + Hebbian learning.
///
/// Extracted from [AppSettings] to group all memory-related configuration
/// in one immutable value object. Persisted to `SharedPreferences` with
/// the same keys as before (backward compatible with existing installs).
class MemorySettings {
  /// Whether the ambient [RequestContext] is injected into AI prompts.
  final bool injectContext;

  /// Threshold below which a `short`-tier fragment is migrated to `mid`.
  final double shortToMidThreshold;

  /// Threshold below which a `mid`-tier fragment is migrated to `long`.
  final double midToLongThreshold;

  /// Days a fragment must live in `short` tier before migration to `mid`.
  final int shortMaxAgeDays;

  /// Days a fragment must live in `mid` tier before migration to `long`.
  final int midMaxAgeDays;

  /// Co-access window for Hebbian edge reinforcement (minutes).
  final int hebbianCoAccessMinutes;

  /// Hebbian edge decay constant (days to fall to 1/e).
  final int hebbianDecayDays;

  /// How many chat messages between auto-Markdown exports. 0 disables.
  final int autoExportEveryNMessages;

  /// Whether the dreaming engine runs in the background automatically.
  final bool dreamingEnabled;

  /// Half-life of the createdAt recency signal (days). Default 180.
  final int createdRecencyHalfLifeDays;

  /// Half-life of the lastAccessAt recency signal (days). Default 30.
  final int accessRecencyHalfLifeDays;

  /// Master switch for dual-time-signal scoring.
  final bool useLastAccessForRecency;

  /// Approximate token budget for memory context injection. Default 800.
  final int contextBudget;

  /// When true, the LLM summarizes fragments during dreaming cycles.
  final bool useLlmSummarizer;

  /// When true, recall is re-ranked by the LLM after FTS+Hebbian pass.
  final bool useLlmRerank;

  const MemorySettings({
    this.injectContext = true,
    this.shortToMidThreshold = 0.65,
    this.midToLongThreshold = 0.45,
    this.shortMaxAgeDays = 7,
    this.midMaxAgeDays = 30,
    this.hebbianCoAccessMinutes = 5,
    this.hebbianDecayDays = 30,
    this.autoExportEveryNMessages = 16,
    this.dreamingEnabled = true,
    this.createdRecencyHalfLifeDays = 180,
    this.accessRecencyHalfLifeDays = 30,
    this.useLastAccessForRecency = true,
    this.contextBudget = 800,
    this.useLlmSummarizer = false,
    this.useLlmRerank = false,
  });

  /// Reads memory settings from [prefs], falling back to defaults.
  factory MemorySettings.fromPrefs(SharedPreferences prefs) {
    return MemorySettings(
      injectContext: prefs.getBool('memoryInjectContext') ?? true,
      shortToMidThreshold:
          prefs.getDouble('memoryShortToMidThreshold') ?? 0.65,
      midToLongThreshold: prefs.getDouble('memoryMidToLongThreshold') ?? 0.45,
      shortMaxAgeDays: prefs.getInt('memoryShortMaxAgeDays') ?? 7,
      midMaxAgeDays: prefs.getInt('memoryMidMaxAgeDays') ?? 30,
      hebbianCoAccessMinutes: prefs.getInt('memoryHebbianCoAccessMinutes') ?? 5,
      hebbianDecayDays: prefs.getInt('memoryHebbianDecayDays') ?? 30,
      autoExportEveryNMessages:
          prefs.getInt('memoryAutoExportEveryNMessages') ?? 16,
      dreamingEnabled: prefs.getBool('memoryDreamingEnabled') ?? true,
      createdRecencyHalfLifeDays:
          prefs.getInt('memoryCreatedRecencyHalfLifeDays') ?? 180,
      accessRecencyHalfLifeDays:
          prefs.getInt('memoryAccessRecencyHalfLifeDays') ?? 30,
      useLastAccessForRecency:
          prefs.getBool('memoryUseLastAccessForRecency') ?? true,
      contextBudget: prefs.getInt('memoryContextBudget') ?? 800,
      useLlmSummarizer: prefs.getBool('memoryUseLlmSummarizer') ?? false,
      useLlmRerank: prefs.getBool('memoryUseLlmRerank') ?? false,
    );
  }

  /// Persists all fields to [prefs] using the legacy key names.
  Future<void> saveToPrefs(SharedPreferences prefs) async {
    await prefs.setBool('memoryInjectContext', injectContext);
    await prefs.setDouble('memoryShortToMidThreshold', shortToMidThreshold);
    await prefs.setDouble('memoryMidToLongThreshold', midToLongThreshold);
    await prefs.setInt('memoryShortMaxAgeDays', shortMaxAgeDays);
    await prefs.setInt('memoryMidMaxAgeDays', midMaxAgeDays);
    await prefs.setInt('memoryHebbianCoAccessMinutes', hebbianCoAccessMinutes);
    await prefs.setInt('memoryHebbianDecayDays', hebbianDecayDays);
    await prefs.setInt('memoryAutoExportEveryNMessages', autoExportEveryNMessages);
    await prefs.setBool('memoryDreamingEnabled', dreamingEnabled);
    await prefs.setInt('memoryCreatedRecencyHalfLifeDays', createdRecencyHalfLifeDays);
    await prefs.setInt('memoryAccessRecencyHalfLifeDays', accessRecencyHalfLifeDays);
    await prefs.setBool('memoryUseLastAccessForRecency', useLastAccessForRecency);
    await prefs.setInt('memoryContextBudget', contextBudget);
    await prefs.setBool('memoryUseLlmSummarizer', useLlmSummarizer);
    await prefs.setBool('memoryUseLlmRerank', useLlmRerank);
  }

  MemorySettings copyWith({
    bool? injectContext,
    double? shortToMidThreshold,
    double? midToLongThreshold,
    int? shortMaxAgeDays,
    int? midMaxAgeDays,
    int? hebbianCoAccessMinutes,
    int? hebbianDecayDays,
    int? autoExportEveryNMessages,
    bool? dreamingEnabled,
    int? createdRecencyHalfLifeDays,
    int? accessRecencyHalfLifeDays,
    bool? useLastAccessForRecency,
    int? contextBudget,
    bool? useLlmSummarizer,
    bool? useLlmRerank,
  }) {
    return MemorySettings(
      injectContext: injectContext ?? this.injectContext,
      shortToMidThreshold: shortToMidThreshold ?? this.shortToMidThreshold,
      midToLongThreshold: midToLongThreshold ?? this.midToLongThreshold,
      shortMaxAgeDays: shortMaxAgeDays ?? this.shortMaxAgeDays,
      midMaxAgeDays: midMaxAgeDays ?? this.midMaxAgeDays,
      hebbianCoAccessMinutes: hebbianCoAccessMinutes ?? this.hebbianCoAccessMinutes,
      hebbianDecayDays: hebbianDecayDays ?? this.hebbianDecayDays,
      autoExportEveryNMessages: autoExportEveryNMessages ?? this.autoExportEveryNMessages,
      dreamingEnabled: dreamingEnabled ?? this.dreamingEnabled,
      createdRecencyHalfLifeDays: createdRecencyHalfLifeDays ?? this.createdRecencyHalfLifeDays,
      accessRecencyHalfLifeDays: accessRecencyHalfLifeDays ?? this.accessRecencyHalfLifeDays,
      useLastAccessForRecency: useLastAccessForRecency ?? this.useLastAccessForRecency,
      contextBudget: contextBudget ?? this.contextBudget,
      useLlmSummarizer: useLlmSummarizer ?? this.useLlmSummarizer,
      useLlmRerank: useLlmRerank ?? this.useLlmRerank,
    );
  }
}
