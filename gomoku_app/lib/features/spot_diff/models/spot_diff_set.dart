import 'package:gomoku_app/features/spot_diff/models/spot_diff_region.dart';

/// 找茬图集：两张图片 + 差异列表。
/// 用于 P2P 同步（创建方序列化后发送给对手）。
class SpotDiffSet {
  final String id; // e.g. "daily_20260520_001" or "bundled_001"
  final String title; // e.g. "春日花园"
  final String imageUrlA; // 远程 URL 或 asset 路径
  final String imageUrlB;
  final List<SpotDiffRegion> differences;
  final bool isBundled; // true = 内置资源, false = 缓存/远程

  const SpotDiffSet({
    required this.id,
    required this.title,
    required this.imageUrlA,
    required this.imageUrlB,
    required this.differences,
    this.isBundled = true,
  });

  List<int> get differenceIndices =>
      List.generate(differences.length, (i) => i);

  factory SpotDiffSet.fromJson(Map<String, dynamic> json) {
    return SpotDiffSet(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      imageUrlA: json['imageUrlA'] as String,
      imageUrlB: json['imageUrlB'] as String,
      differences: (json['differences'] as List)
          .map((d) => SpotDiffRegion.fromJson(d as Map<String, dynamic>))
          .toList(),
      isBundled: json['isBundled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imageUrlA': imageUrlA,
        'imageUrlB': imageUrlB,
        'differences': differences.map((d) => d.toJson()).toList(),
        'isBundled': isBundled,
      };
}
