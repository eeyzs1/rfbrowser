import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/logging/app_logger.dart';

class VaultConfig {
  final String path;
  final String name;
  final DateTime lastOpened;

  VaultConfig({
    required this.path,
    required this.name,
    required this.lastOpened,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'lastOpened': lastOpened.toIso8601String(),
  };

  factory VaultConfig.fromJson(Map<String, dynamic> json) => VaultConfig(
    path: json['path'] as String,
    name: json['name'] as String,
    lastOpened: DateTime.parse(json['lastOpened'] as String),
  );
}

class VaultState {
  final VaultConfig? currentVault;
  final List<VaultConfig> recentVaults;
  final bool isLoading;
  final String? error;

  VaultState({
    this.currentVault,
    this.recentVaults = const [],
    this.isLoading = false,
    this.error,
  });

  VaultState copyWith({
    VaultConfig? currentVault,
    List<VaultConfig>? recentVaults,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearCurrentVault = false,
  }) {
    return VaultState(
      currentVault: clearCurrentVault
          ? null
          : (currentVault ?? this.currentVault),
      recentVaults: recentVaults ?? this.recentVaults,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VaultNotifier extends Notifier<VaultState> {
  @override
  VaultState build() => VaultState();

  Future<String> get _vaultConfigPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'vaults.json');
  }

  Future<Map<String, dynamic>> _loadVaultConfig() async {
    final path = await _vaultConfigPath;
    final file = File(path);
    if (await file.exists()) {
      try {
        return Map<String, dynamic>.from(
          jsonDecode(await file.readAsString()) as Map,
        );
      } catch (_) {
        appLog.warning('VaultStore: failed to read vaults.json');
      }
    }
    return {};
  }

  Future<void> _saveVaultConfig(Map<String, dynamic> config) async {
    final path = await _vaultConfigPath;
    final file = File(path);
    final dir = Directory(p.dirname(path));
    if (!await dir.exists()) await dir.create(recursive: true);
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(config));
  }

  static const _recentVaultsKey = 'recent_vaults';
  static const _currentVaultKey = 'current_vault';

  Future<void> loadRecentVaults() async {
    final config = await _loadVaultConfig();
    final vaultsJson = (config[_recentVaultsKey] as List?) ?? [];
    final seen = <String>{};
    final vaults = vaultsJson
        .map((j) {
          try {
            return VaultConfig.fromJson(Map<String, dynamic>.from(j as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<VaultConfig>()
        .where((v) => seen.add(_normalizePath(v.path)))
        .toList();

    VaultConfig? currentVault;
    final currentVaultPath = config[_currentVaultKey] as String?;
    if (currentVaultPath != null) {
      try {
        currentVault = vaults.firstWhere(
          (v) => _normalizePath(v.path) == _normalizePath(currentVaultPath),
        );
      } catch (_) {
        appLog.warning('VaultStore: current vault not found in vault list');
      }
    }

    state = state.copyWith(recentVaults: vaults, currentVault: currentVault);
  }

  String _normalizePath(String path) => p.normalize(p.absolute(path));

  Future<void> openVault(String vaultPath) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dir = Directory(vaultPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final rfbrowserDir = Directory(p.join(vaultPath, '.rfbrowser'));
      if (!await rfbrowserDir.exists()) {
        await rfbrowserDir.create(recursive: true);
      }

      final subdirs = [
        'cache',
        'plugins',
        'skills',
        'templates',
        'themes',
        'sync',
      ];
      for (final subdir in subdirs) {
        final d = Directory(p.join(rfbrowserDir.path, subdir));
        if (!await d.exists()) {
          await d.create(recursive: true);
        }
      }

      final vaultName = p.basename(vaultPath);
      final config = VaultConfig(
        path: vaultPath,
        name: vaultName,
        lastOpened: DateTime.now(),
      );

      await _saveToRecent(config);

      state = state.copyWith(currentVault: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createVault(String vaultPath, {String name = ''}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dir = Directory(vaultPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final subdirs = ['daily-notes', 'clippings', 'attachments'];
      for (final subdir in subdirs) {
        final d = Directory(p.join(vaultPath, subdir));
        if (!await d.exists()) {
          await d.create(recursive: true);
        }
      }

      // 自动生成 Welcome.md 示例笔记，帮助新用户快速上手
      await _generateWelcomeNote(vaultPath);

      await openVault(vaultPath);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 生成 Welcome.md 示例笔记，包含应用简介、功能导览、快捷键和 Markdown 语法示例。
  Future<void> _generateWelcomeNote(String vaultPath) async {
    final welcomePath = p.join(vaultPath, 'Welcome.md');
    final welcomeFile = File(welcomePath);
    // 如果已存在则不覆盖
    if (await welcomeFile.exists()) return;

    const content = '''# 欢迎使用 RFBrowser 👋

RFBrowser 是一款 **AI 驱动的知识浏览器**，集笔记编辑、网页浏览、AI 对话、记忆系统、画布和知识图谱于一体。

---

## 🧭 核心功能导览

| 功能 | 说明 |
|------|------|
| 📝 **笔记编辑** | 使用 Markdown 编写笔记，支持双向链接、标签和实时预览 |
| 🌐 **浏览器** | 内置浏览器，支持剪藏网页内容到知识库 |
| 🤖 **AI 对话** | 与 AI 助手对话，支持引用笔记和网页内容 |
| 🧠 **记忆系统** | AI 自动提取记忆片段，构建长期记忆网络 |
| 🎨 **画布** | 在无限画布上组织笔记卡片和灵感 |
| 🔗 **知识图谱** | 可视化笔记之间的关联关系 |

---

## ⌨️ 常用快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl + N` | 新建笔记 |
| `Ctrl + S` | 保存笔记 |
| `Ctrl + K` | 打开命令栏（搜索） |
| `Ctrl + T` | 新建标签页 |
| `Ctrl + 1` | 切换到「捕捉」场景 |
| `Ctrl + 2` | 切换到「思考」场景 |
| `Ctrl + 3` | 切换到「连接」场景 |
| `Ctrl + D` | 创建今日日记 |

---

## ✍️ Markdown 语法示例

### 标题
```
# 一级标题
## 二级标题
### 三级标题
```

### 文本格式
**粗体文本**、*斜体文本*、~~删除线~~、`行内代码`

### 列表
- 无序列表项
- 无序列表项
  - 嵌套列表项

1. 有序列表项
2. 有序列表项

### 链接
[外部链接](https://www.example.com)
[[Wiki 链接]] — 链接到知识库中的其他笔记

### 引用
> 这是一段引用文本。
> 可以跨多行。

### 代码块
```dart
void main() {
  print('Hello, RFBrowser!');
}
```

### 任务列表
- [x] 已完成的任务
- [ ] 未完成的任务

---

> 💡 **提示**：你可以随时删除这篇笔记。它不会影响应用的任何功能。
''';

    await welcomeFile.writeAsString(content);
  }

  Future<void> _saveToRecent(VaultConfig vaultConfig) async {
    final config = await _loadVaultConfig();
    final vaultsJson = (config[_recentVaultsKey] as List?) ?? [];
    final seen = <String>{};
    final existing = vaultsJson
        .map((j) {
          try {
            return VaultConfig.fromJson(Map<String, dynamic>.from(j as Map));
          } catch (_) {
            return null;
          }
        })
        .whereType<VaultConfig>()
        .where((v) => seen.add(_normalizePath(v.path)))
        .toList();

    existing.removeWhere(
      (v) => _normalizePath(v.path) == _normalizePath(vaultConfig.path),
    );
    existing.insert(0, vaultConfig);
    if (existing.length > 10) existing.removeRange(10, existing.length);

    config[_recentVaultsKey] = existing.map((v) => v.toJson()).toList();
    config[_currentVaultKey] = vaultConfig.path;
    await _saveVaultConfig(config);

    state = state.copyWith(recentVaults: existing);
  }

  Future<void> closeVault() async {
    final config = await _loadVaultConfig();
    config.remove(_currentVaultKey);
    await _saveVaultConfig(config);
    state = state.copyWith(clearCurrentVault: true);
  }

  Future<void> removeFromRecent(String vaultPath) async {
    final vaults = List<VaultConfig>.from(state.recentVaults)
      ..removeWhere((v) => _normalizePath(v.path) == _normalizePath(vaultPath));

    final config = await _loadVaultConfig();
    config[_recentVaultsKey] = vaults.map((v) => v.toJson()).toList();

    if (_normalizePath(state.currentVault?.path ?? '') ==
        _normalizePath(vaultPath)) {
      config.remove(_currentVaultKey);
      await _saveVaultConfig(config);
      state = state.copyWith(clearCurrentVault: true, recentVaults: vaults);
    } else {
      await _saveVaultConfig(config);
      state = state.copyWith(recentVaults: vaults);
    }
  }
}

final vaultProvider = NotifierProvider<VaultNotifier, VaultState>(
  VaultNotifier.new,
);
