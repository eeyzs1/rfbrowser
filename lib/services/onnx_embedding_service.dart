import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dio_factory.dart';

class ModelDownloader {
  static const _modelUrl =
      'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/onnx/model.onnx';
  static const _vocabUrl =
      'https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/vocab.txt';
  static const _modelFileName = 'all-MiniLM-L6-v2.onnx';
  static const _vocabFileName = 'all-MiniLM-L6-v2-vocab.txt';

  final Dio _dio = DioFactory.instance;

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

  Future<String> downloadModel({void Function(double progress)? onProgress}) async {
    final path = await getModelPath();
    if (await isModelDownloaded()) return path;

    debugPrint('OnnxEmbedding: downloading MiniLM model (~23MB)...');
    await _download(_modelUrl, path, onProgress: onProgress);
    debugPrint('OnnxEmbedding: model downloaded to $path');
    return path;
  }

  Future<String> downloadVocab({void Function(double progress)? onProgress}) async {
    final path = await getVocabPath();
    if (await isVocabDownloaded()) return path;

    debugPrint('OnnxEmbedding: downloading vocabulary...');
    await _download(_vocabUrl, path, onProgress: onProgress);
    debugPrint('OnnxEmbedding: vocabulary downloaded to $path');
    return path;
  }

  Future<void> _download(String url, String filePath, {void Function(double progress)? onProgress}) async {
    try {
      await _dio.download(url, filePath, onReceiveProgress: (count, total) {
        if (total > 0) {
          onProgress?.call(count / total);
        }
      });
    } catch (e) {
      debugPrint('OnnxEmbedding: download failed: $e');
      rethrow;
    }
  }
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
    debugPrint('OnnxEmbedding: vocabulary loaded (${_vocab.length} tokens)');
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
      final isCJK = char.codeUnitAt(0) >= 0x4E00 && char.codeUnitAt(0) <= 0x9FFF;

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
      debugPrint(
        'OnnxEmbedding: initialized (inputs: $_inputNames, output: $_outputName)',
      );
    } catch (e) {
      _initFailed = true;
      debugPrint('OnnxEmbedding: initialization failed: $e');
      debugPrint(
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
    try {
      if (_inputNames.contains('input_ids')) {
        inputMap['input_ids'] = await OrtValue.fromList(tokenized.inputIds, [1, BertTokenizer._maxSeqLen]);
      }
      if (_inputNames.contains('attention_mask')) {
        inputMap['attention_mask'] = await OrtValue.fromList(tokenized.attentionMask, [1, BertTokenizer._maxSeqLen]);
      }
      if (_inputNames.contains('token_type_ids')) {
        inputMap['token_type_ids'] = await OrtValue.fromList(tokenized.tokenTypeIds, [1, BertTokenizer._maxSeqLen]);
      }

      final outputs = await _session!.run(inputMap);

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

      var pooled = embedding;
      if (pooled.length > 384) {
        pooled = _meanPool(pooled, 384, tokenized.length);
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
      rethrow;
    }
  }

  List<double> _meanPool(List<double> hiddenStates, int hiddenSize, int seqLen) {
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
        debugPrint('OnnxEmbedding: error closing session: $e');
      }
      _session = null;
    }
    _initialized = false;
  }
}