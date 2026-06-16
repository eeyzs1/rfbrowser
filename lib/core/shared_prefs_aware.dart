import 'package:shared_preferences/shared_preferences.dart';

mixin SharedPrefsAware {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get ensurePrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
}
