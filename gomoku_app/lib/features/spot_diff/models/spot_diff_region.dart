/// 差异区域（归一化坐标，值域 0.0–1.0）。
/// 运行时将点击坐标归一化后与各差异圆心计算欧氏距离，
/// 距离 <= [radius] 即为命中。
class SpotDiffRegion {
  final double x; // 0.0–1.0, 相对于图片宽度的比例
  final double y; // 0.0–1.0, 相对于图片高度的比例
  final double radius; // 0.0–1.0, 相对于图片宽度的容差半径

  const SpotDiffRegion({
    required this.x,
    required this.y,
    required this.radius,
  });

  factory SpotDiffRegion.fromJson(Map<String, dynamic> json) {
    return SpotDiffRegion(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'radius': radius,
      };
}
