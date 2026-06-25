import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initializes sqflite for unit tests, ensuring the sqlite3 dynamic library
/// is discoverable on Windows.
///
/// On Windows, `flutter test` runs in a clean environment where sqlite3.dll
/// (built by `flutter build`) is not on the DLL search path. This helper
/// locates the DLL and uses the Win32 `SetDllDirectoryW` API to add its
/// directory to the process's DLL search path before initializing
/// sqflite_ffi. This makes tests self-contained: they don't rely on the
/// user's PATH or a prior `flutter build` step copying DLLs next to the
/// test runner.
///
/// Call this in `setUpAll` of any test that touches sqflite.
void setupSqfliteForTests() {
  if (Platform.isWindows) {
    _addSqliteDllDirectory();
  }
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Win32 `SetDllDirectoryW` signature.
typedef _SetDllDirectoryNative = Int32 Function(Pointer<Utf16> lpPathName);
typedef _SetDllDirectoryDart = int Function(Pointer<Utf16> lpPathName);

/// Dynamically discovers candidate directories where sqlite3.dll may live
/// after a build. Scans `build/windows/<arch>/runner/<config>/` and
/// `build/windows/<arch>/plugins/sqlite3_flutter_libs/<config>/` for every
/// architecture (x64, arm64, ...) and config (Debug, Release, ...) that
/// exists on disk, so the helper does not hard-code a specific arch or
/// build type.
List<String> _dllCandidates() {
  final candidates = <String>[];
  final windowsBuild = Directory('build/windows');
  if (windowsBuild.existsSync()) {
    for (final archDir in windowsBuild.listSync()) {
      if (archDir is! Directory) continue;
      final arch = archDir.path;
      candidates.addAll([
        '$arch/runner/Debug/sqlite3.dll',
        '$arch/runner/Release/sqlite3.dll',
        '$arch/plugins/sqlite3_flutter_libs/Debug/sqlite3.dll',
        '$arch/plugins/sqlite3_flutter_libs/Release/sqlite3.dll',
      ]);
    }
  }
  candidates.add('build/install/sqlite3.dll');
  return candidates;
}

void _addSqliteDllDirectory() {
  for (final dll in _dllCandidates()) {
    if (File(dll).existsSync()) {
      final absDir = p.absolute(p.dirname(dll));
      _setDllDirectory(absDir);
      return;
    }
  }
  // If no candidate has the DLL, fall through to sqfliteFfiInit which will
  // surface the real load error.
}

void _setDllDirectory(String path) {
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final setDllDirectory = kernel32.lookupFunction<
      _SetDllDirectoryNative,
      _SetDllDirectoryDart>('SetDllDirectoryW');

  final pathPtr = path.toNativeUtf16();
  try {
    final result = setDllDirectory(pathPtr);
    if (result == 0) {
      // Non-fatal: sqfliteFfiInit will produce a clearer error if the DLL
      // still can't be loaded.
      stderr.writeln('warning: SetDllDirectoryW("$path") failed');
    }
  } finally {
    calloc.free(pathPtr);
  }
}
