import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:gomoku_app/features/spot_diff/models/spot_diff_set.dart';

/// 找茬图片服务：网络获取 + 本地缓存 + 内置回退。
///
/// 每日从远程 JSON 端点获取图集，缓存到 [Directory.systemTemp]。
/// 远程获取失败时回退到内置 assets。
///
/// 缓存结构：
///   spot_diff_cache/
///     metadata.json          ← 记录 fetchDate + 各 set 的 id/路径
///     daily_20260520_001/    ← 每日图集
///       image_a.png
///       image_b.png
///       differences.json
class SpotDiffImageService {
  static const _cacheRoot = 'spot_diff_cache';
  static const _metadataFile = 'metadata.json';
  static const _maxCachedSets = 12;

  /// 远程 JSON 端点（可配置）
  static const String defaultRemoteUrl =
      'https://example.com/api/spot-diff/daily.json';

  // ========== Public API ==========

  /// 获取今天的图集列表。返回最多 [_maxCachedSets] 组。
  /// 自动触发每日更新并清理过期缓存。
  Future<List<SpotDiffSet>> getTodaySets() async {
    final cacheDir = await _ensureCacheDir();
    final metadata = await _loadMetadata(cacheDir);
    final now = DateTime.now();
    final todayStr = _dateString(now);

    if (metadata['fetchDate'] != todayStr) {
      // 尝试远程获取
      try {
        final sets = await _fetchRemote(cacheDir, todayStr);
        await _saveMetadata(cacheDir, todayStr, sets);
        await _cleanupOldSets(cacheDir, sets.length);
        return sets;
      } catch (_) {
        // 远程获取失败，回退
      }
    } else if (metadata['sets'] is List && (metadata['sets'] as List).isNotEmpty) {
      // 已有今日缓存，加载
      final sets = await _loadCachedSets(cacheDir, metadata['sets'] as List);
      if (sets.isNotEmpty) return sets;
    }

    // 回退到内置 assets
    return _loadBundledFallback();
  }

  /// 从缓存加载一个指定 set
  Future<SpotDiffSet?> loadCachedSet(String setId) async {
    final cacheDir = await _ensureCacheDir();
    final setDir = Directory('${cacheDir.path}/$setId');
    if (!await setDir.exists()) return null;
    return _readSetFromDir(setDir, setId);
  }

  /// 移除所有缓存
  Future<void> clearCache() async {
    final cacheDir = await _ensureCacheDir();
    await cacheDir.delete(recursive: true);
  }

  // ========== Remote Fetch ==========

  Future<List<SpotDiffSet>> _fetchRemote(
      Directory cacheDir, String dateStr) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(defaultRemoteUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final setsJson = json['sets'] as List;
      if (setsJson.isEmpty) throw Exception('No sets available');

      final List<SpotDiffSet> sets = [];
      for (final s in setsJson) {
        final setJson = s as Map<String, dynamic>;
        final setId = '${dateStr}_${setJson['id']}';
        final setDir = Directory('${cacheDir.path}/$setId');
        if (!await setDir.exists()) {
          await setDir.create(recursive: true);
        }

        // Download images
        await _downloadImage(
            setJson['imageUrlA'] as String, '${setDir.path}/image_a.png');
        await _downloadImage(
            setJson['imageUrlB'] as String, '${setDir.path}/image_b.png');

        // Write differences
        final diffJson = {
          'id': setId,
          'title': setJson['title'] as String? ?? '',
          'imageUrlA': '${setDir.path}/image_a.png',
          'imageUrlB': '${setDir.path}/image_b.png',
          'differences': setJson['differences'],
          'isBundled': false,
        };
        await File('${setDir.path}/differences.json')
            .writeAsString(jsonEncode(diffJson));

        sets.add(SpotDiffSet.fromJson(diffJson));
      }

      return sets;
    } finally {
      client.close();
    }
  }

  Future<void> _downloadImage(String url, String destPath) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final file = File(destPath);
        await file.openWrite().addStream(response);
      }
    } finally {
      client.close();
    }
  }

  // ========== Cache Management ==========

  Future<Directory> _ensureCacheDir() async {
    final dir = Directory('${Directory.systemTemp.path}/$_cacheRoot');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Map<String, dynamic>> _loadMetadata(Directory cacheDir) async {
    final file = File('${cacheDir.path}/$_metadataFile');
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {'fetchDate': '', 'sets': <Map<String, dynamic>>[]};
  }

  Future<void> _saveMetadata(Directory cacheDir, String dateStr,
      List<SpotDiffSet> sets) async {
    // 合并现有和新获取的 sets
    final existing = await _loadMetadata(cacheDir);
    final existingSets = (existing['sets'] as List?) ?? [];

    // 新 set IDs
    final newSetIds = sets.map((s) => s.id).toSet();

    // 保留不在新列表中的旧 set（不超过 _maxCachedSets）
    final oldSets =
        existingSets
            .where((s) => !newSetIds.contains(s is Map ? s['id'] : null))
            .take(_maxCachedSets - sets.length)
            .toList();

    final allSetEntries = [
      ...sets.map((s) => {
        'id': s.id,
        'title': s.title,
        'dir': '${cacheDir.path}/${s.id}',
      }),
      ...oldSets,
    ];

    final metadata = {
      'fetchDate': dateStr,
      'sets': allSetEntries,
    };
    await File('${cacheDir.path}/$_metadataFile')
        .writeAsString(jsonEncode(metadata));
  }

  Future<List<SpotDiffSet>> _loadCachedSets(
      Directory cacheDir, List setEntries) async {
    final sets = <SpotDiffSet>[];
    for (final entry in setEntries) {
      final setId = entry is Map ? entry['id'] as String : null;
      if (setId == null) continue;
      final set = await loadCachedSet(setId);
      if (set != null) sets.add(set);
    }
    return sets;
  }

  Future<void> _cleanupOldSets(Directory cacheDir, int newCount) async {
    final entries = await cacheDir.list().toList();
    // 只清理目录（不删 metadata.json）
    int total = 0;
    for (final entry in entries) {
      if (entry is Directory && entry.path.contains(_cacheRoot)) {
        total++;
      }
    }
    if (total <= _maxCachedSets) return;
    // 按修改时间排序删除最旧的
    final dirs = <Directory>[];
    for (final entry in entries) {
      if (entry is Directory && entry.path != cacheDir.path) {
        dirs.add(entry);
      }
    }
    dirs.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    while (dirs.length > _maxCachedSets) {
      await dirs.removeAt(0).delete(recursive: true);
    }
  }

  Future<SpotDiffSet?> _readSetFromDir(Directory setDir, String setId) async {
    try {
      final diffFile = File('${setDir.path}/differences.json');
      if (!await diffFile.exists()) return null;
      final content = await diffFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      json['id'] = setId;
      json['imageUrlA'] = '${setDir.path}/image_a.png';
      json['imageUrlB'] = '${setDir.path}/image_b.png';
      return SpotDiffSet.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // ========== Bundled Fallback ==========

  Future<List<SpotDiffSet>> _loadBundledFallback() async {
    final sets = <SpotDiffSet>[];
    // 扫描 assets/spot_diff/bundled_NNN/ 目录
    for (int i = 1; i <= 30; i++) {
      final setId = 'bundled_${i.toString().padLeft(3, '0')}';
      try {
        // 尝试加载差异配置
        final diffJson = await rootBundle.loadString(
            'assets/spot_diff/$setId/differences.json');
        final json = jsonDecode(diffJson) as Map<String, dynamic>;
        json['id'] = setId;
        json['imageUrlA'] = 'assets/spot_diff/$setId/image_a.png';
        json['imageUrlB'] = 'assets/spot_diff/$setId/image_b.png';
        json['isBundled'] = true;
        sets.add(SpotDiffSet.fromJson(json));
      } catch (_) {
        // 没有更多的内置图集
        break;
      }
    }
    return sets;
  }

  // ========== Utility ==========

  String _dateString(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
