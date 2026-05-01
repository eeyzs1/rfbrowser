import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppSettings {
  final String locale;
  final bool isDarkMode;
  final String activeModel;
  final double editorFontSize;
  final bool showLineNumbers;

  AppSettings({
    this.locale = 'en',
    this.isDarkMode = true,
    this.activeModel = 'gpt-4o',
    this.editorFontSize = 14.0,
    this.showLineNumbers = false,
  });

  AppSettings copyWith({
    String? locale,
    bool? isDarkMode,
    String? activeModel,
    double? editorFontSize,
    bool? showLineNumbers,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      activeModel: activeModel ?? this.activeModel,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final _secureStorage = const FlutterSecureStorage();
  String? _apiKey;

  SettingsNotifier() : super(AppSettings());

  String? get apiKey => _apiKey;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = await _secureStorage.read(key: 'api_key');
    state = AppSettings(
      locale: prefs.getString('locale') ?? 'en',
      isDarkMode: prefs.getBool('isDarkMode') ?? true,
      activeModel: prefs.getString('activeModel') ?? 'gpt-4o',
      editorFontSize: prefs.getDouble('editorFontSize') ?? 14.0,
      showLineNumbers: prefs.getBool('showLineNumbers') ?? false,
    );
  }

  Future<void> setLocale(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    state = state.copyWith(locale: locale);
  }

  Future<void> toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', !state.isDarkMode);
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: 'api_key', value: key);
    _apiKey = key;
  }

  Future<void> deleteApiKey() async {
    await _secureStorage.delete(key: 'api_key');
    _apiKey = null;
  }

  Future<void> setActiveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activeModel', model);
    state = state.copyWith(activeModel: model);
  }

  Future<void> setEditorFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('editorFontSize', size);
    state = state.copyWith(editorFontSize: size);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});
