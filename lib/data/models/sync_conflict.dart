enum ConflictResolution {
  keepLocal,
  keepRemote,
  keepBoth,
}

class SyncConflict {
  final String relativePath;
  final DateTime? localModified;
  final DateTime? remoteModified;
  final String? localContent;
  final String? remoteContent;

  SyncConflict({
    required this.relativePath,
    this.localModified,
    this.remoteModified,
    this.localContent,
    this.remoteContent,
  });
}

class SyncProgress {
  final int filesProcessed;
  final int totalFiles;
  final String currentFile;
  final bool isUploading;

  SyncProgress({
    this.filesProcessed = 0,
    this.totalFiles = 0,
    this.currentFile = '',
    this.isUploading = false,
  });

  SyncProgress copyWith({
    int? filesProcessed,
    int? totalFiles,
    String? currentFile,
    bool? isUploading,
  }) {
    return SyncProgress(
      filesProcessed: filesProcessed ?? this.filesProcessed,
      totalFiles: totalFiles ?? this.totalFiles,
      currentFile: currentFile ?? this.currentFile,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  double get progress => totalFiles > 0 ? filesProcessed / totalFiles : 0.0;
}
