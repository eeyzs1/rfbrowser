import 'package:dio/dio.dart';

class DioFactory {
  DioFactory._();

  static Dio? _instance;

  static Dio get instance {
    _instance ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Content-Type': 'application/json'},
    ));
    return _instance!;
  }

  static void resetForHotRestart() {
    _instance?.close();
    _instance = null;
  }
}
