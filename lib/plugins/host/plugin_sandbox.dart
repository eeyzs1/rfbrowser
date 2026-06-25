// ignore_for_file: unused_element, unused_element_parameter
part of 'plugin_host.dart';

class _ApiRequest {
  final String id;
  final String apiName;
  final Map<String, dynamic> args;
  final Permission requiredPermission;

  _ApiRequest({
    required this.id,
    required this.apiName,
    required this.args,
    required this.requiredPermission,
  });

  Map<String, dynamic> toMap() => {
    'type': 'apiRequest',
    'id': id,
    'apiName': apiName,
    'args': args,
    'requiredPermission': requiredPermission.name,
  };
}

class _ApiResponse {
  final String id;
  final bool success;
  final dynamic result;
  final String? error;

  _ApiResponse({
    required this.id,
    required this.success,
    this.result,
    this.error,
  });

  factory _ApiResponse.fromMap(Map<String, dynamic> map) => _ApiResponse(
    id: map['id'] as String? ?? '',
    success: map['success'] as bool? ?? false,
    result: map['result'],
    error: map['error'] as String?,
  );
}

class Sandbox {
  final String pluginId;
  final PluginManifest manifest;
  final CapabilityChecker _capabilityChecker;
  final _errorController = StreamController<String>.broadcast();
  final ApiHandler _apiHandler;
  final String? _entryPointCode;
  final ResourceQuota _quota;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _pluginSendPort;
  bool _isRunning = false;
  int _requestId = 0;
  final Map<String, Completer<_ApiResponse>> _pendingRequests = {};
  StreamSubscription? _receiveSubscription;
  Timer? _crashRecoveryTimer;
  int _crashCount = 0;
  static const int _maxCrashRecovery = 3;
  static const Duration _crashRecoveryDelay = Duration(seconds: 3);
  Completer<void>? _sendPortReady;

  // Resource quota tracking
  final List<DateTime> _callTimestamps = [];
  int _consecutiveErrors = 0;

  Sandbox({
    required this.pluginId,
    required this.manifest,
    required ApiHandler apiHandler,
    String? entryPointCode,
    ResourceQuota? quota,
  })  : _apiHandler = apiHandler,
        _entryPointCode = entryPointCode,
        _quota = quota ?? ResourceQuota.defaultQuota,
        _capabilityChecker = CapabilityChecker(
          pluginId: pluginId,
          manifest: manifest,
        );

  bool get isRunning => _isRunning;

  Stream<String> get onError => _errorController.stream;

  int get crashCount => _crashCount;

  Future<void> start() async {
    _receivePort = ReceivePort();
    _sendPortReady = Completer<void>();
    _receiveSubscription = _receivePort!.listen(_handleMessage);

    try {
      _isolate = await Isolate.spawn(
        _pluginEntryPoint,
        _PluginStartMessage(
          sendPort: _receivePort!.sendPort,
          manifestMap: manifest.toMap(),
          entryPointCode: _entryPointCode,
        ),
        errorsAreFatal: false,
        onError: _receivePort!.sendPort,
        onExit: _receivePort!.sendPort,
      );
      _isRunning = true;
      await _sendPortReady!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    } catch (e) {
      _isRunning = false;
      _errorController.add('Failed to start isolate: $e');
      rethrow;
    }
  }

  void _handleMessage(dynamic message) {
    if (message is SendPort) {
      _pluginSendPort = message;
      if (_sendPortReady != null && !_sendPortReady!.isCompleted) {
        _sendPortReady!.complete();
      }
      return;
    }

    if (message is List && message.length == 2) {
      final errorCode = message[0];
      final errorStack = message[1];
      _handleIsolateError(errorCode, errorStack);
      return;
    }

    if (message == null) {
      _handleIsolateExit();
      return;
    }

    if (message is Map<String, dynamic>) {
      final type = message['type'];
      if (type == 'apiRequest') {
        _handleApiRequest(message);
      } else if (type == 'apiResponse') {
        final response = _ApiResponse.fromMap(message);
        _pendingRequests.remove(response.id)?.complete(response);
      } else if (type == 'error') {
        _errorController.add(
          message['message'] as String? ?? 'Unknown plugin error',
        );
      }
    }
  }

  void _handleIsolateError(dynamic code, dynamic stack) {
    _isRunning = false;
    final errorMsg = 'Plugin isolate error: $code\n$stack';
    _errorController.add(errorMsg);
    _crashCount++;

    if (_crashCount <= _maxCrashRecovery) {
      _crashRecoveryTimer?.cancel();
      _crashRecoveryTimer = Timer(_crashRecoveryDelay, () async {
        try {
          await start();
        } catch (_) {
          appLog.error('PluginHost: failed to restart after crash recovery');
        }
      });
    }
  }

  void _handleIsolateExit() {
    _isRunning = false;
    if (_crashCount < _maxCrashRecovery) {
      _crashRecoveryTimer?.cancel();
      _crashRecoveryTimer = Timer(_crashRecoveryDelay, () async {
        try {
          await start();
        } catch (_) {
          appLog.error('PluginHost: failed to restart after isolate exit');
        }
      });
    }
  }

  Future<void> _handleApiRequest(Map<String, dynamic> requestMap) async {
    final requestId = requestMap['id'] as String? ?? '';
    final apiName = requestMap['apiName'] as String? ?? '';
    final args = requestMap['args'] as Map<String, dynamic>? ?? {};
    final permName = requestMap['requiredPermission'] as String? ?? '';

    final permission = Permission.values.firstWhere(
      (e) => e.name == permName,
      orElse: () => Permission.knowledgeRead,
    );

    _ApiResponse response;

    if (!_capabilityChecker.hasCapability(permission)) {
      response = _ApiResponse(
        id: requestId,
        success: false,
        error:
            'PermissionDeniedError: Plugin "${manifest.name}" lacks permission: ${permission.name}',
      );
    } else {
      try {
        final result = await _apiHandler(apiName, args);
        response = _ApiResponse(id: requestId, success: true, result: result);
      } catch (e) {
        response = _ApiResponse(
          id: requestId,
          success: false,
          error: e.toString(),
        );
      }
    }

    _pluginSendPort?.send({
      'type': 'apiResponse',
      'id': response.id,
      'success': response.success,
      'result': response.result,
      'error': response.error,
    });
  }

  Future<T?> callApi<T>(
    String apiName,
    Map<String, dynamic> args, {
    required Permission requiredPermission,
  }) async {
    if (!_isRunning) throw StateError('Sandbox is not running');

    if (!_capabilityChecker.hasCapability(requiredPermission)) {
      throw PermissionDeniedError(
        'Plugin "${manifest.name}" lacks permission: ${requiredPermission.name}',
      );
    }

    // --- Resource quota: rate limit ---
    _enforceRateLimit();

    // --- Resource quota: message size limit ---
    _enforceMessageSize(args);

    final requestId = '${pluginId}_${_requestId++}';
    final completer = Completer<_ApiResponse>();
    _pendingRequests[requestId] = completer;

    final request = _ApiRequest(
      id: requestId,
      apiName: apiName,
      args: args,
      requiredPermission: requiredPermission,
    );

    _pluginSendPort?.send(request.toMap());

    final response = await completer.future.timeout(
      _quota.maxExecutionDuration,
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return _ApiResponse(
          id: requestId,
          success: false,
          error: 'API call timeout after ${_quota.maxExecutionDuration.inSeconds}s',
        );
      },
    );

    _pendingRequests.remove(requestId);

    if (!response.success) {
      _consecutiveErrors++;
      _enforceConsecutiveErrorLimit();
      if (response.error?.contains('PermissionDeniedError') == true) {
        throw PermissionDeniedError(response.error!);
      }
      throw Exception(response.error ?? 'API call failed');
    }

    _consecutiveErrors = 0;
    return response.result as T?;
  }

  /// Sliding-window rate limiter. Removes timestamps older than 1 second,
  /// then checks if the remaining count exceeds [ResourceQuota.maxMessagesPerSecond].
  void _enforceRateLimit() {
    if (_quota.maxMessagesPerSecond <= 0) return;

    final now = DateTime.now();
    final oneSecondAgo = now.subtract(const Duration(seconds: 1));
    _callTimestamps.removeWhere((t) => t.isBefore(oneSecondAgo));

    if (_callTimestamps.length >= _quota.maxMessagesPerSecond) {
      throw ResourceQuotaExceededError(
        'Plugin "${manifest.name}" exceeded rate limit: '
        '${_quota.maxMessagesPerSecond} calls/second',
      );
    }
    _callTimestamps.add(now);
  }

  /// Checks the serialized size of [args] against [ResourceQuota.maxMessageSizeBytes].
  void _enforceMessageSize(Map<String, dynamic> args) {
    if (_quota.maxMessageSizeBytes <= 0) return;
    try {
      final encoded = jsonEncode(args);
      if (encoded.length > _quota.maxMessageSizeBytes) {
        throw ResourceQuotaExceededError(
          'Plugin "${manifest.name}" message too large: '
          '${encoded.length} bytes (max ${_quota.maxMessageSizeBytes})',
        );
      }
    } on ResourceQuotaExceededError {
      rethrow;
    } catch (_) {
      // If encoding fails, let the handler deal with it
    }
  }

  /// Auto-stops the sandbox when consecutive errors exceed the quota threshold.
  void _enforceConsecutiveErrorLimit() {
    if (_quota.maxConsecutiveErrors > 0 &&
        _consecutiveErrors >= _quota.maxConsecutiveErrors) {
      _errorController.add(
        'Plugin "${manifest.name}" exceeded consecutive error limit '
        '(${_quota.maxConsecutiveErrors}), auto-stopping sandbox',
      );
      _consecutiveErrors = 0;
      stop();
    }
  }

  void reportError(String error) {
    _errorController.add(error);
  }

  void simulateCrashForTest() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _handleIsolateError('test_crash', 'simulated crash for testing');
  }

  Future<void> stop() async {
    _crashRecoveryTimer?.cancel();
    _crashRecoveryTimer = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isRunning = false;
    _pluginSendPort = null;
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;
    _receivePort?.close();
    _receivePort = null;
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Sandbox stopped');
      }
    }
    _pendingRequests.clear();
    _callTimestamps.clear();
    _consecutiveErrors = 0;
    await _errorController.close();
  }

  static void _pluginEntryPoint(_PluginStartMessage message) {
    final receivePort = ReceivePort();
    message.sendPort.send(receivePort.sendPort);

    if (message.entryPointCode != null && message.entryPointCode!.isNotEmpty) {
      _runJsPlugin(message, receivePort);
    } else {
      _runEchoLoop(message, receivePort);
    }
  }

  /// Echo loop — backward-compatible pass-through used when no JS entry point
  /// is declared. The main process handles all API logic; the isolate just
  /// relays messages back so existing tests keep working.
  static void _runEchoLoop(_PluginStartMessage message, ReceivePort receivePort) {
    receivePort.listen((dynamic msg) {
      if (msg is Map<String, dynamic> && msg['type'] == 'apiRequest') {
        final requestId = msg['id'] as String? ?? '';
        final apiName = msg['apiName'] as String? ?? '';
        final args = msg['args'] as Map<String, dynamic>? ?? {};

        message.sendPort.send({
          'type': 'apiRequest',
          'id': requestId,
          'apiName': apiName,
          'args': args,
          'requiredPermission': msg['requiredPermission'] ?? '',
        });
      } else if (msg is Map<String, dynamic> && msg['type'] == 'apiResponse') {
        final response = _ApiResponse.fromMap(msg);
        message.sendPort.send({
          'type': 'apiResponse',
          'id': response.id,
          'success': response.success,
          'result': response.result,
          'error': response.error,
        });
      }
    });
  }

  /// JS plugin runtime — loads the plugin's entry-point code into a QuickJS
  /// engine running inside the isolate. The JS code registers handlers via
  /// `__pluginHandlers[apiName] = function(args) { return result; }`.
  ///
  /// When the host sends an `apiRequest`, the isolate looks up the registered
  /// handler, calls it synchronously, and sends the return value back as an
  /// `apiResponse`. If no handler is registered for that API name, the request
  /// is echoed back to the main process (hybrid mode: JS handlers take
  /// priority, host APIs serve as fallback).
  static void _runJsPlugin(_PluginStartMessage message, ReceivePort receivePort) {
    JavascriptRuntime? runtime;
    try {
      runtime = getJavascriptRuntime();
      // Inject the handler registry and a console shim.
      runtime.evaluate('''
        var __pluginHandlers = {};
        function registerHandler(apiName, fn) {
          __pluginHandlers[apiName] = fn;
        }
        var rfbrowser = {
          pluginId: "${message.manifestMap['id'] ?? ''}",
          registerHandler: registerHandler,
        };
      ''');
      // Evaluate the plugin's entry-point code. This should call
      // registerHandler('apiName', function(args) { ... }) to expose handlers.
      runtime.evaluate(message.entryPointCode!);

      final rt = runtime;
      receivePort.listen((dynamic msg) {
        if (msg is Map<String, dynamic> && msg['type'] == 'apiRequest') {
          final requestId = msg['id'] as String? ?? '';
          final apiName = msg['apiName'] as String? ?? '';
          final args = msg['args'] as Map<String, dynamic>? ?? {};

          // Check if a JS handler is registered for this API name.
          final hasHandler = rt.evaluate(
            "typeof __pluginHandlers['$apiName'] === 'function'",
          ).stringResult == 'true';

          if (hasHandler) {
            try {
              final argsJson = jsonEncode(args);
              final resultStr = rt.evaluate(
                "JSON.stringify(__pluginHandlers['$apiName']($argsJson))",
              ).stringResult;
              dynamic result;
              if (resultStr == 'undefined' || resultStr.isEmpty) {
                result = null;
              } else {
                result = jsonDecode(resultStr);
              }
              message.sendPort.send({
                'type': 'apiResponse',
                'id': requestId,
                'success': true,
                'result': result,
                'error': null,
              });
            } catch (e) {
              message.sendPort.send({
                'type': 'apiResponse',
                'id': requestId,
                'success': false,
                'result': null,
                'error': 'JS handler error: $e',
              });
            }
          } else {
            // No JS handler — echo to host as fallback.
            message.sendPort.send({
              'type': 'apiRequest',
              'id': requestId,
              'apiName': apiName,
              'args': args,
              'requiredPermission': msg['requiredPermission'] ?? '',
            });
          }
        } else if (msg is Map<String, dynamic> && msg['type'] == 'apiResponse') {
          // Host API response coming back (from fallback echo path).
          final response = _ApiResponse.fromMap(msg);
          message.sendPort.send({
            'type': 'apiResponse',
            'id': response.id,
            'success': response.success,
            'result': response.result,
            'error': response.error,
          });
        }
      });
    } catch (e) {
      message.sendPort.send({
        'type': 'error',
        'message': 'Failed to initialize JS runtime: $e',
      });
      // Fall back to echo loop so the sandbox remains functional.
      _runEchoLoop(message, receivePort);
    }
  }
}

class _PluginStartMessage {
  final SendPort sendPort;
  final Map<String, dynamic> manifestMap;
  final String? entryPointCode;

  _PluginStartMessage({
    required this.sendPort,
    required this.manifestMap,
    this.entryPointCode,
  });
}
