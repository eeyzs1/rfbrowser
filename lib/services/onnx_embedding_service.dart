import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/logging/app_logger.dart';
import 'dio_factory.dart';

class ModelDownloader {
  // Candidate endpoints for downloading the MiniLM model. Order matters:
  // the HF_ENDPOINT env var (if set) is tried first, then the China mirror
  // (hf-mirror.com) which is reachable from mainland China, then the
  // official huggingface.co as a last resort.
  static const _candidateEndpoints = <String>[
    'https://hf-mirror.com',
    'https://huggingface.co',
  ];
  static const _modelRelativePath =
      '/sentence-transformers/all-MiniLM-L6-v2/resolve/main/onnx/model.onnx';
  static const _vocabRelativePath =
      '/sentence-transformers/all-MiniLM-L6-v2/resolve/main/vocab.txt';
  static const _modelFileName = 'all-MiniLM-L6-v2.onnx';
  static const _vocabFileName = 'all-MiniLM-L6-v2-vocab.txt';
  // Probe timeout for endpoint speed test: keep it short so a dead source
  // does not stall startup.
  static const _probeTimeout = Duration(seconds: 5);

  final Dio _dio = DioFactory.instance;
  // Cached best endpoint after speed test. Null means not selected yet.
  String? _selectedEndpoint;

  /// Returns the list of candidate endpoints, with the HF_ENDPOINT env var
  /// (if set) prepended so it takes priority.
  List<String> get _endpoints {
    final env = Platform.environment['HF_ENDPOINT'];
    if (env != null && env.isNotEmpty) {
      return [env.trim().replaceAll(RegExp(r'/$'), ''), ..._candidateEndpoints];
    }
    return _candidateEndpoints;
  }

  /// Probes each candidate endpoint in parallel by issuing a HEAD request to
  /// the model URL, then returns the endpoint with the lowest latency.
  /// Falls back to the first candidate if all probes fail (the download will
  /// then surface the real error).
  Future<String> _selectBestEndpoint() async {
    if (_selectedEndpoint != null) return _selectedEndpoint!;

    final endpoints = _endpoints;
    appLog.debug(
      'OnnxEmbedding: probing ${endpoints.length} download endpoints...',
    );

    final probes = <Future<_EndpointProbe>>[];
    for (final ep in endpoints) {
      probes.add(_probeEndpoint(ep));
    }

    final results = await Future.wait(probes);
    final reachable =
        results.where((r) => r.ok).toList()..sort((a, b) => a.ms.compareTo(b.ms));

    if (reachable.isNotEmpty) {
      _selectedEndpoint = reachable.first.endpoint;
      appLog.debug(
        'OnnxEmbedding: selected fastest endpoint '
        '$_selectedEndpoint (${reachable.first.ms}ms)',
      );
    } else {
      // All probes failed; fall back to first candidate. The actual download
      // attempt will produce a clearer error for the user.
      _selectedEndpoint = endpoints.first;
      appLog.warning(
        'OnnxEmbedding: all endpoint probes failed, '
        'falling back to $_selectedEndpoint',
      );
    }
    return _selectedEndpoint!;
  }

  Future<_EndpointProbe> _probeEndpoint(String endpoint) async {
    final sw = Stopwatch()..start();
    try {
      // HEAD request to the model URL; we only care about reachability.
      await _dio.head(
        '$endpoint$_modelRelativePath',
        options: Options(
          receiveTimeout: _probeTimeout,
          sendTimeout: _probeTimeout,
          followRedirects: true,
          maxRedirects: 3,
        ),
      );
      sw.stop();
      return _EndpointProbe(endpoint, true, sw.elapsedMilliseconds);
    } catch (e) {
      sw.stop();
      appLog.debug('OnnxEmbedding: probe $endpoint failed: $e');
      return _EndpointProbe(endpoint, false, sw.elapsedMilliseconds);
    }
  }

  Future<String> _modelUrl() async {
    final ep = await _selectBestEndpoint();
    return '$ep$_modelRelativePath';
  }

  Future<String> _vocabUrl() async {
    final ep = await _selectBestEndpoint();
    return '$ep$_vocabRelativePath';
  }

  Future<String> getModelPath() async {
    final dir = await getApplicationSupportDirectory();
    final modelDir = p.join(dir.path, 'models');
    await Directory(modelDir).create(recursive: true);
    return p.join(modelDir, _modelFileName);
  }

  Future<String> getVocabPath() async {
    final dir = await getApplicationSupportDirectory();
    final modelDir = p.join(dir.path, 'models');
    await Directory(modelDir).create(recursive: true);
    return p.join(modelDir, _vocabFileName);
  }

  Future<bool> isModelDownloaded() async {
    final path = await getModelPath();
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 1000000;
  }

  Future<bool> isVocabDownloaded() async {
    final path = await getVocabPath();
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 10000;
  }

  Future<String> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    final path = await getModelPath();
    if (await isModelDownloaded()) return path;

    appLog.debug('OnnxEmbedding: downloading MiniLM model (~23MB)...');
    final url = await _modelUrl();
    await _download(url, path, onProgress: onProgress);
    appLog.debug('OnnxEmbedding: model downloaded to $path');
    return path;
  }

  Future<String> downloadVocab({
    void Function(double progress)? onProgress,
  }) async {
    final path = await getVocabPath();
    if (await isVocabDownloaded()) return path;

    final url = await _vocabUrl();
    await _download(url, path, onProgress: onProgress);
    return path;
  }

  Future<void> _download(
    String url,
    String filePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (count, total) {
          if (total > 0) {
            onProgress?.call(count / total);
          }
        },
      );
    } catch (e) {
      appLog.error('OnnxEmbedding: download failed from $url', error: e);
      rethrow;
    }
  }
}

/// Result of probing a single download endpoint.
class _EndpointProbe {
  final String endpoint;
  final bool ok;
  final int ms;
  _EndpointProbe(this.endpoint, this.ok, this.ms);
}

class BertTokenizer {
  final Map<String, int> _vocab = {};
  final List<String> _idToToken = [];
  bool _loaded = false;
  static const int _maxSeqLen = 256;
  static const String _unkToken = '[UNK]';
  static const String _clsToken = '[CLS]';
  static const String _sepToken = '[SEP]';
  static const String _padToken = '[PAD]';

  bool get isLoaded => _loaded;

  Future<void> load(String vocabPath) async {
    final file = File(vocabPath);
    final lines = await file.readAsLines();
    for (var i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      _vocab[token] = i;
      _idToToken.add(token);
    }
    _loaded = true;
  }

  TokenizedInput tokenize(String text, {int maxLen = _maxSeqLen}) {
    if (text.isEmpty) text = ' ';

    final tokens = _basicTokenize(text);
    final subTokens = <String>[];
    for (final token in tokens) {
      if (_vocab.containsKey(token)) {
        subTokens.add(token);
      } else {
        _wordpieceTokenize(token, subTokens);
      }
    }

    final inputTokens = [_clsToken, ...subTokens, _sepToken];
    if (inputTokens.length > maxLen) {
      inputTokens.removeRange(maxLen, inputTokens.length);
      inputTokens[inputTokens.length - 1] = _sepToken;
    }
    final actualLen = inputTokens.length;

    final padId = _vocab[_padToken] ?? 0;
    final inputIds = Int64List(maxLen);
    final attentionMask = Int64List(maxLen);
    final tokenTypeIds = Int64List(maxLen);

    for (var i = 0; i < maxLen; i++) {
      if (i < actualLen) {
        inputIds[i] = (_vocab[inputTokens[i]] ?? _vocab[_unkToken])!;
        attentionMask[i] = 1;
        tokenTypeIds[i] = 0;
      } else {
        inputIds[i] = padId;
        attentionMask[i] = 0;
        tokenTypeIds[i] = 0;
      }
    }

    return TokenizedInput(
      inputIds: inputIds,
      attentionMask: attentionMask,
      tokenTypeIds: tokenTypeIds,
      length: actualLen,
    );
  }

  List<String> _basicTokenize(String text) {
    final cleaned = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return [];

    final tokens = <String>[];
    final chars = cleaned.split('');
    var current = '';

    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      final isCJK =
          char.codeUnitAt(0) >= 0x4E00 && char.codeUnitAt(0) <= 0x9FFF;

      if (isCJK) {
        if (current.isNotEmpty) {
          tokens.add(current.trim());
          current = '';
        }
        tokens.add(char);
      } else if (char == ' ') {
        if (current.isNotEmpty) {
          tokens.add(current.trim());
          current = '';
        }
      } else {
        current += char;
      }
    }
    if (current.isNotEmpty) {
      tokens.add(current.trim());
    }

    return tokens.where((t) => t.isNotEmpty).toList();
  }

  void _wordpieceTokenize(String token, List<String> result) {
    if (token.length > 100) {
      result.add(_unkToken);
      return;
    }

    var start = 0;
    while (start < token.length) {
      var end = token.length;
      var found = false;
      var curSubstr = '';

      while (start < end) {
        var substr = token.substring(start, end);
        if (start > 0) substr = '##$substr';

        if (_vocab.containsKey(substr)) {
          curSubstr = substr;
          found = true;
          break;
        }
        end--;
      }

      if (!found) {
        result.add(_unkToken);
        return;
      }

      result.add(curSubstr);
      start = end;
    }
  }
}

class TokenizedInput {
  final Int64List inputIds;
  final Int64List attentionMask;
  final Int64List tokenTypeIds;
  final int length;

  TokenizedInput({
    required this.inputIds,
    required this.attentionMask,
    required this.tokenTypeIds,
    required this.length,
  });
}

class OnnxEmbeddingService {
  final ModelDownloader _downloader = ModelDownloader();
  final OnnxRuntime _ort = OnnxRuntime();
  final BertTokenizer _tokenizer = BertTokenizer();
  OrtSession? _session;
  bool _initialized = false;
  bool _initFailed = false;
  List<String> _inputNames = [];
  String? _outputName;

  bool get isAvailable => _initialized && _session != null;
  bool get initFailed => _initFailed;

  Future<void> initialize() async {
    if (_initialized || _initFailed) return;

    try {
      final modelPath = await _downloader.downloadModel();
      final vocabPath = await _downloader.downloadVocab();
      await _tokenizer.load(vocabPath);

      _session = await _ort.createSession(
        modelPath,
        options: OrtSessionOptions(
          intraOpNumThreads: 2,
          providers: [OrtProvider.CPU],
        ),
      );

      _inputNames = List<String>.from(_session!.inputNames);
      final outputNames = List<String>.from(_session!.outputNames);
      _outputName = outputNames.isNotEmpty ? outputNames.first : null;

      _initialized = true;
    } catch (e) {
      _initFailed = true;
      appLog.warning('OnnxEmbedding: initialization failed', error: e);
      appLog.warning(
        'OnnxEmbedding: falling back to local n-gram hashing for embeddings',
      );
    }
  }

  Future<List<double>> embed(String text) async {
    if (!_initialized || _session == null) {
      throw StateError('OnnxEmbeddingService not initialized');
    }

    final tokenized = _tokenizer.tokenize(text);

    final inputMap = <String, OrtValue>{};
    Map<String, OrtValue>? outputs;
    try {
      if (_inputNames.contains('input_ids')) {
        inputMap['input_ids'] = await OrtValue.fromList(tokenized.inputIds, [
          1,
          BertTokenizer._maxSeqLen,
        ]);
      }
      if (_inputNames.contains('attention_mask')) {
        inputMap['attention_mask'] = await OrtValue.fromList(
          tokenized.attentionMask,
          [1, BertTokenizer._maxSeqLen],
        );
      }
      if (_inputNames.contains('token_type_ids')) {
        inputMap['token_type_ids'] = await OrtValue.fromList(
          tokenized.tokenTypeIds,
          [1, BertTokenizer._maxSeqLen],
        );
      }

      outputs = await _session!.run(inputMap);

      OrtValue? outputTensor;
      if (_outputName != null && outputs.containsKey(_outputName)) {
        outputTensor = outputs[_outputName];
      } else if (outputs.isNotEmpty) {
        outputTensor = outputs.values.first;
      }

      if (outputTensor == null) {
        throw StateError('No output tensor found');
      }

      final outputData = await outputTensor.asFlattenedList();
      final embedding = outputData.map((e) => (e as num).toDouble()).toList();

      // Validate output: all-MiniLM-L6-v2 produces either:
      //  - last_hidden_state: [1, 256, 384] = 98304 elements (needs mean pooling)
      //  - pooled output: [1, 384] = 384 elements (already pooled)
      // Any other length is unexpected and likely indicates a model issue.
      const expectedHiddenSize = 384;
      var pooled = embedding;
      if (pooled.length > expectedHiddenSize) {
        // Derive seqLen from the actual output length, NOT tokenized.length.
        // Using tokenized.length can cause a RangeError if the model's
        // internal seq_len differs from our tokenization (e.g. the model
        // truncated or padded to a different length).
        final actualSeqLen = pooled.length ~/ expectedHiddenSize;
        if (actualSeqLen > 0 && pooled.length == actualSeqLen * expectedHiddenSize) {
          // Clamp to tokenized length to avoid averaging over padding tokens,
          // but never exceed actualSeqLen to avoid RangeError.
          final effectiveSeqLen = tokenized.length < actualSeqLen
              ? tokenized.length
              : actualSeqLen;
          pooled = _meanPool(pooled, expectedHiddenSize, effectiveSeqLen);
        } else {
          throw StateError(
            'Unexpected ONNX output length: ${pooled.length} '
            '(expected $expectedHiddenSize or a multiple of it)',
          );
        }
      }

      final norm = pooled.fold(0.0, (sum, v) => sum + v * v);
      if (norm > 0) {
        final sqrtNorm = sqrt(norm);
        for (var i = 0; i < pooled.length; i++) {
          pooled[i] /= sqrtNorm;
        }
      }

      for (final tensor in inputMap.values) {
        await tensor.dispose();
      }
      for (final tensor in outputs.values) {
        await tensor.dispose();
      }

      return pooled;
    } catch (e) {
      for (final tensor in inputMap.values) {
        await tensor.dispose();
      }
      for (final tensor in outputs?.values ?? <OrtValue>[]) {
        await tensor.dispose();
      }
      rethrow;
    }
  }

  List<double> _meanPool(
    List<double> hiddenStates,
    int hiddenSize,
    int seqLen,
  ) {
    if (seqLen <= 0) seqLen = 1;
    // Guard against out-of-bounds: never access beyond hiddenStates.length.
    final maxSeqLen = hiddenStates.length ~/ hiddenSize;
    if (seqLen > maxSeqLen) seqLen = maxSeqLen;
    if (seqLen <= 0) seqLen = 1;

    final pooled = List<double>.filled(hiddenSize, 0.0);
    for (var i = 0; i < seqLen; i++) {
      for (var j = 0; j < hiddenSize; j++) {
        pooled[j] += hiddenStates[i * hiddenSize + j];
      }
    }
    for (var j = 0; j < hiddenSize; j++) {
      pooled[j] /= seqLen;
    }
    return pooled;
  }

  Future<void> dispose() async {
    if (_session != null) {
      try {
        await _session!.close();
      } catch (e) {
        appLog.error('OnnxEmbedding: error closing session', error: e);
      }
      _session = null;
    }
    _initialized = false;
  }
}
