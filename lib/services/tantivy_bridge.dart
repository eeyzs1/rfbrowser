// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../../data/models/note.dart';

final DynamicLibrary _nativeLibrary = _loadLibrary();

DynamicLibrary _loadLibrary() {
  if (Platform.isWindows) {
    return DynamicLibrary.open('tantivy_bridge.dll');
  } else if (Platform.isMacOS) {
    return DynamicLibrary.open('libtantivy_bridge.dylib');
  } else if (Platform.isLinux) {
    return DynamicLibrary.open('libtantivy_bridge.so');
  }
  throw UnsupportedError('Tantivy bridge not supported on this platform');
}

typedef InitNative = Uint32 Function(Pointer<Utf8> indexPath);
typedef InitDart = int Function(Pointer<Utf8> indexPath);

typedef IndexNative = Int32 Function(
  Uint32 handle,
  Pointer<Utf8> id,
  Pointer<Utf8> title,
  Pointer<Utf8> content,
  Pointer<Utf8> tags,
  Pointer<Utf8> filePath,
);
typedef IndexDart = int Function(
  int handle,
  Pointer<Utf8> id,
  Pointer<Utf8> title,
  Pointer<Utf8> content,
  Pointer<Utf8> tags,
  Pointer<Utf8> filePath,
);

typedef SearchNative = Pointer<Utf8> Function(Uint32 handle, Pointer<Utf8> query, Uint32 topK);
typedef SearchDart = Pointer<Utf8> Function(int handle, Pointer<Utf8> query, int topK);

typedef RemoveNative = Int32 Function(Uint32 handle, Pointer<Utf8> noteId);
typedef RemoveDart = int Function(int handle, Pointer<Utf8> noteId);

typedef CloseNative = Int32 Function(Uint32 handle);
typedef CloseDart = int Function(int handle);

typedef FreeStringNative = Void Function(Pointer<Utf8> s);
typedef FreeStringDart = void Function(Pointer<Utf8> s);

class TantivyBridge {
  static bool _available = true;
  static bool _triedLoad = false;

  late final int _handle;
  final IndexDart _index;
  final SearchDart _search;
  final RemoveDart _remove;
  final CloseDart _close;
  final FreeStringDart _freeString;

  TantivyBridge._({
    required int handle,
    required IndexDart index,
    required SearchDart search,
    required RemoveDart remove,
    required CloseDart close,
    required FreeStringDart freeString,
  })  : _handle = handle,
        _index = index,
        _search = search,
        _remove = remove,
        _close = close,
        _freeString = freeString;

  static bool get isAvailable {
    if (_triedLoad) return _available;
    _triedLoad = true;
    try {
      _nativeLibrary;
      _available = true;
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  static Future<TantivyBridge?> initialize(String indexPath) async {
    if (!isAvailable) return null;
    try {
      final initFn = _nativeLibrary
          .lookupFunction<InitNative, InitDart>('tantivy_bridge_init');
      final indexFn = _nativeLibrary
          .lookupFunction<IndexNative, IndexDart>('tantivy_bridge_index');
      final searchFn = _nativeLibrary
          .lookupFunction<SearchNative, SearchDart>('tantivy_bridge_search');
      final removeFn = _nativeLibrary
          .lookupFunction<RemoveNative, RemoveDart>('tantivy_bridge_remove');
      final closeFn = _nativeLibrary
          .lookupFunction<CloseNative, CloseDart>('tantivy_bridge_close');
      final freeStr = _nativeLibrary.lookupFunction<FreeStringNative,
          FreeStringDart>('tantivy_bridge_free_string');

      final pathPtr = indexPath.toNativeUtf8();
      final handle = initFn(pathPtr);
      calloc.free(pathPtr);

      if (handle == 0) return null;

      return TantivyBridge._(
        handle: handle,
        index: indexFn,
        search: searchFn,
        remove: removeFn,
        close: closeFn,
        freeString: freeStr,
      );
    } catch (_) {
      return null;
    }
  }

  bool indexNote(Note note) {
    try {
      final idPtr = note.id.toNativeUtf8();
      final titlePtr = note.title.toNativeUtf8();
      final contentPtr = note.content.toNativeUtf8();
      final tagsPtr = note.tags.join(' ').toNativeUtf8();
      final filePathPtr = note.filePath.toNativeUtf8();

      final result = _index(
        _handle,
        idPtr,
        titlePtr,
        contentPtr,
        tagsPtr,
        filePathPtr,
      );

      calloc.free(idPtr);
      calloc.free(titlePtr);
      calloc.free(contentPtr);
      calloc.free(tagsPtr);
      calloc.free(filePathPtr);

      return result >= 0;
    } catch (_) {
      return false;
    }
  }

  void removeNote(String noteId) {
    try {
      final idPtr = noteId.toNativeUtf8();
      _remove(_handle, idPtr);
      calloc.free(idPtr);
    } catch (_) {
      print('Tantivy: failed to remove note "$noteId"');
    }
  }

  TantivySearchResults search(String query, {int topK = 20}) {
    try {
      final queryPtr = query.toNativeUtf8();
      final resultPtr = _search(_handle, queryPtr, topK);
      calloc.free(queryPtr);

      if (resultPtr == nullptr) {
        return TantivySearchResults(hits: [], totalCount: 0);
      }

      final jsonStr = resultPtr.toDartString();
      _freeString(resultPtr);

      return TantivySearchResults.fromJsonString(jsonStr);
    } catch (_) {
      return TantivySearchResults(hits: [], totalCount: 0);
    }
  }

  void close() {
    try {
      _close(_handle);
    } catch (_) {
      print('Tantivy: failed to close bridge');
    }
  }
}

class TantivySearchResults {
  final List<TantivyHit> hits;
  final int totalCount;

  TantivySearchResults({required this.hits, required this.totalCount});

  factory TantivySearchResults.fromJsonString(String json) {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final hitsList = data['hits'] as List<dynamic>? ?? [];
      final hits = hitsList.map((h) {
        final m = h as Map<String, dynamic>;
        return TantivyHit(
          noteId: m['note_id']?.toString() ?? '',
          title: m['title']?.toString() ?? '',
          snippet: m['snippet']?.toString() ?? '',
          score: (m['score'] as num?)?.toDouble() ?? 0.0,
          filePath: m['file_path']?.toString() ?? '',
        );
      }).toList();
      return TantivySearchResults(
        hits: hits,
        totalCount: (data['total_count'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return TantivySearchResults(hits: [], totalCount: 0);
    }
  }
}

class TantivyHit {
  final String noteId;
  final String title;
  final String snippet;
  final double score;
  final String filePath;

  TantivyHit({
    required this.noteId,
    required this.title,
    required this.snippet,
    required this.score,
    required this.filePath,
  });
}
