import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/logging/app_logger.dart';
import '../data/models/ai_provider.dart';
import '../core/shared_prefs_aware.dart';

/// State holder for the AI provider/model configuration.
///
/// Extracted from `settings_service.dart` to keep `SettingsNotifier` (UI/app
/// settings) and `AIConfigNotifier` (AI provider/model configuration) in
/// separate files. This file is re-exported by `settings_service.dart` so
/// existing imports continue to work.
class AIConfigState {
  final List<AIProvider> providers;
  final List<AIModel> models;
  final ActiveAIConfig? activeConfig;

  AIConfigState({
    this.providers = const [],
    this.models = const [],
    this.activeConfig,
  });

  AIProvider? get activeProvider {
    if (activeConfig == null) return null;
    try {
      return providers.firstWhere((p) => p.id == activeConfig!.providerId);
    } catch (_) {
      return null;
    }
  }

  AIModel? get activeModel {
    if (activeConfig == null) return null;
    try {
      return models.firstWhere(
        (m) =>
            m.id == activeConfig!.modelId &&
            m.providerId == activeConfig!.providerId,
      );
    } catch (_) {
      return null;
    }
  }

  List<AIModel> modelsForProvider(String providerId) =>
      models.where((m) => m.providerId == providerId).toList();

  AIProvider? providerById(String id) {
    try {
      return providers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  AIConfigState copyWith({
    List<AIProvider>? providers,
    List<AIModel>? models,
    ActiveAIConfig? activeConfig,
    bool clearActiveConfig = false,
  }) {
    return AIConfigState(
      providers: providers ?? this.providers,
      models: models ?? this.models,
      activeConfig: clearActiveConfig
          ? null
          : (activeConfig ?? this.activeConfig),
    );
  }
}

class AIConfigNotifier extends Notifier<AIConfigState> with SharedPrefsAware {
  final _secureStorage = const FlutterSecureStorage();

  @override
  AIConfigState build() => AIConfigState();

  Future<void> loadConfig() async {
    final prefs = await ensurePrefs;
    await _loadProviders(prefs);
    await _loadModels(prefs);
    await _loadActiveConfig(prefs);
    await _loadApiKeys();
  }

  Future<void> _loadProviders(SharedPreferences prefs) async {
    final json = prefs.getString('ai_providers');
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        final providers = list
            .map((e) => AIProvider.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(providers: providers);
      } catch (_) {
        appLog.error('AI config: failed to parse providers JSON');
      }
    }
  }

  Future<void> _loadModels(SharedPreferences prefs) async {
    final json = prefs.getString('ai_models');
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        final models = list
            .map((e) => AIModel.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(models: models);
      } catch (_) {
        appLog.error('AI config: failed to parse models JSON');
      }
    }
  }

  Future<void> _loadActiveConfig(SharedPreferences prefs) async {
    final json = prefs.getString('ai_active_config');
    if (json != null) {
      try {
        final config = ActiveAIConfig.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        state = state.copyWith(activeConfig: config);
      } catch (_) {
        appLog.error('AI config: failed to parse active config JSON');
      }
    }
  }

  Future<void> _loadApiKeys() async {
    try {
      final updatedProviders = <AIProvider>[];
      for (final provider in state.providers) {
        if (provider.requiresApiKey) {
          final key = await _secureStorage.read(key: 'ai_key_${provider.id}');
          updatedProviders.add(provider.copyWith(apiKey: key));
        } else {
          updatedProviders.add(provider);
        }
      }
      state = state.copyWith(providers: updatedProviders);
    } catch (e, st) {
      // flutter_secure_storage can throw on Windows (DPAPI / Credential Vault
      // unavailable, locked session, corporate policy). Don't let it abort
      // app startup — API keys will simply be unavailable until re-entered.
      appLog.error('AI config: failed to load API keys from secure storage',
          error: e, stackTrace: st);
    }
  }

  Future<void> _saveProviders() async {
    final prefs = await ensurePrefs;
    final json = jsonEncode(state.providers.map((p) => p.toJson()).toList());
    await prefs.setString('ai_providers', json);
  }

  Future<void> _saveModels() async {
    final prefs = await ensurePrefs;
    final json = jsonEncode(state.models.map((m) => m.toJson()).toList());
    await prefs.setString('ai_models', json);
  }

  Future<void> _saveActiveConfig() async {
    final prefs = await ensurePrefs;
    if (state.activeConfig != null) {
      await prefs.setString(
        'ai_active_config',
        jsonEncode(state.activeConfig!.toJson()),
      );
    } else {
      await prefs.remove('ai_active_config');
    }
  }

  Future<String?> getApiKeyForProvider(String providerId) async {
    return await _secureStorage.read(key: 'ai_key_$providerId');
  }

  Future<void> addProvider(AIProvider provider) async {
    var providers = List<AIProvider>.from(state.providers);
    providers.removeWhere((p) => p.id == provider.id);
    if (provider.requiresApiKey && provider.apiKey != null) {
      await _secureStorage.write(
        key: 'ai_key_${provider.id}',
        value: provider.apiKey,
      );
    }
    providers.add(provider.copyWith(apiKey: null));
    state = state.copyWith(providers: providers);
    await _saveProviders();
  }

  Future<void> updateProvider(AIProvider provider) async {
    final idx = state.providers.indexWhere((p) => p.id == provider.id);
    if (idx >= 0) {
      if (provider.requiresApiKey && provider.apiKey != null) {
        await _secureStorage.write(
          key: 'ai_key_${provider.id}',
          value: provider.apiKey,
        );
      }
      final providers = List<AIProvider>.from(state.providers);
      providers[idx] = provider.copyWith(apiKey: null);
      state = state.copyWith(providers: providers);
      await _saveProviders();
    }
  }

  Future<void> removeProvider(String providerId) async {
    final providers = state.providers.where((p) => p.id != providerId).toList();
    final models = state.models
        .where((m) => m.providerId != providerId)
        .toList();
    try {
      await _secureStorage.delete(key: 'ai_key_$providerId');
    } catch (_) {
      // Secure storage may not be available (e.g., in tests)
    }
    final clearActive = state.activeConfig?.providerId == providerId;
    state = state.copyWith(
      providers: providers,
      models: models,
      clearActiveConfig: clearActive,
    );
    if (clearActive) await _saveActiveConfig();
    await _saveProviders();
    await _saveModels();
  }

  Future<void> setProviderEnabled(String providerId, bool enabled) async {
    final idx = state.providers.indexWhere((p) => p.id == providerId);
    if (idx >= 0) {
      final providers = List<AIProvider>.from(state.providers);
      providers[idx] = providers[idx].copyWith(isEnabled: enabled);
      state = state.copyWith(providers: providers);
      await _saveProviders();
    }
  }

  Future<void> setModelsForProvider(
    String providerId,
    List<AIModel> newModels,
  ) async {
    var models = state.models
        .where((m) => m.providerId != providerId || m.isCustom)
        .toList();
    models.addAll(newModels);
    state = state.copyWith(models: models);
    await _saveModels();
  }

  Future<void> addCustomModel(AIModel model) async {
    var models = List<AIModel>.from(state.models);
    models.removeWhere(
      (m) => m.id == model.id && m.providerId == model.providerId,
    );
    models.add(model);
    state = state.copyWith(models: models);
    await _saveModels();
  }

  Future<void> removeModel(String modelId, String providerId) async {
    final models = state.models
        .where((m) => !(m.id == modelId && m.providerId == providerId))
        .toList();
    final clearActive =
        state.activeConfig?.modelId == modelId &&
        state.activeConfig?.providerId == providerId;
    state = state.copyWith(models: models, clearActiveConfig: clearActive);
    if (clearActive) await _saveActiveConfig();
    await _saveModels();
  }

  Future<void> setActiveConfig(ActiveAIConfig config) async {
    state = state.copyWith(activeConfig: config);
    await _saveActiveConfig();
  }

  Future<void> clearActiveConfig() async {
    state = state.copyWith(clearActiveConfig: true);
    await _saveActiveConfig();
  }
}

final aiConfigProvider = NotifierProvider<AIConfigNotifier, AIConfigState>(
  AIConfigNotifier.new,
);
