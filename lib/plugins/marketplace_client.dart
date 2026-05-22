import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PluginMarketEntry {
  final String id;
  final String name;
  final String description;
  final String author;
  final String version;
  final String repo;
  final List<String> tags;
  final int downloads;

  PluginMarketEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.version,
    required this.repo,
    this.tags = const [],
    this.downloads = 0,
  });

  factory PluginMarketEntry.fromJson(Map<String, dynamic> json) {
    return PluginMarketEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? '',
      version: json['version'] as String? ?? '0.1.0',
      repo: json['repo'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
      downloads: json['downloads'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'author': author,
    'version': version,
    'repo': repo,
    'tags': tags,
    'downloads': downloads,
  };
}

class PluginMarketplaceClient {
  static const _defaultIndexUrl =
      'https://raw.githubusercontent.com/eeyzs1/rfbrowser-marketplace/main';

  final String _baseUrl;

  PluginMarketplaceClient([String? baseUrl]) : _baseUrl = baseUrl ?? _defaultIndexUrl;

  Future<List<PluginMarketEntry>> fetchIndex() async {
    final uri = Uri.parse('$_baseUrl/index.json');
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch marketplace index: HTTP ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final list = jsonDecode(body) as List;
      return list
          .map((e) => PluginMarketEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('MarketplaceClient: failed to fetch index: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
}