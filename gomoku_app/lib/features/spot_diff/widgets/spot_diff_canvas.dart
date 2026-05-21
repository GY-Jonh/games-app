import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gomoku_app/features/spot_diff/models/spot_diff_region.dart';
import 'package:gomoku_app/features/spot_diff/models/spot_diff_set.dart';

/// 双图显示 + 点击检测 + 差异标注画布。
class SpotDiffCanvas extends StatelessWidget {
  final SpotDiffSet set;
  final List<int> foundByMe;
  final List<int> foundByOpponent;
  final void Function(double normalizedX, double normalizedY) onTap;
  final bool canTap;

  const SpotDiffCanvas({
    super.key,
    required this.set,
    required this.foundByMe,
    required this.foundByOpponent,
    required this.onTap,
    this.canTap = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final maxHeight = constraints.maxHeight;
      // 上下排列，各占一半高度
      final halfHeight = maxHeight / 2;

      return Column(
        children: [
          SizedBox(
            width: maxWidth,
            height: halfHeight,
            child: _ImagePanel(
              imageUrl: set.imageUrlA,
              label: '图 A',
              differences: set.differences,
              foundByMe: foundByMe,
              foundByOpponent: foundByOpponent,
              canTap: canTap,
              onTap: onTap,
            ),
          ),
          const Divider(height: 1, thickness: 1),
          SizedBox(
            width: maxWidth,
            height: halfHeight,
            child: _ImagePanel(
              imageUrl: set.imageUrlB,
              label: '图 B',
              differences: set.differences,
              foundByMe: foundByMe,
              foundByOpponent: foundByOpponent,
              canTap: canTap,
              onTap: onTap,
            ),
          ),
        ],
      );
    });
  }
}

class _ImagePanel extends StatelessWidget {
  final String imageUrl;
  final String label;
  final List<SpotDiffRegion> differences;
  final List<int> foundByMe;
  final List<int> foundByOpponent;
  final bool canTap;
  final void Function(double normalizedX, double normalizedY) onTap;

  const _ImagePanel({
    required this.imageUrl,
    required this.label,
    required this.differences,
    required this.foundByMe,
    required this.foundByOpponent,
    required this.canTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (imageUrl.startsWith('assets/')) {
      // 内置资源
      final assetPath = imageUrl.startsWith('assets/')
          ? imageUrl
          : 'assets/$imageUrl';
      imageWidget = Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('图片加载失败', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    } else {
      // 缓存文件或远程图片
      final file = File(imageUrl);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
          ),
        );
      } else {
        imageWidget = Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
          ),
        );
      }
    }

    return GestureDetector(
      onTapUp: canTap
          ? (details) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox == null || !renderBox.hasSize) return;
              final localPos = details.localPosition;
              final normalizedX = localPos.dx / renderBox.size.width;
              final normalizedY = localPos.dy / renderBox.size.height;
              if (normalizedX >= 0 &&
                  normalizedX <= 1 &&
                  normalizedY >= 0 &&
                  normalizedY <= 1) {
                onTap(normalizedX, normalizedY);
              }
            }
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          // 差异标注层
          CustomPaint(
            size: Size.infinite,
            painter: _DiffMarkerPainter(
              differences: differences,
              foundByMe: foundByMe,
              foundByOpponent: foundByOpponent,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffMarkerPainter extends CustomPainter {
  final List<SpotDiffRegion> differences;
  final List<int> foundByMe;
  final List<int> foundByOpponent;

  _DiffMarkerPainter({
    required this.differences,
    required this.foundByMe,
    required this.foundByOpponent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final foundSet = {...foundByMe, ...foundByOpponent};

    for (int i = 0; i < differences.length; i++) {
      if (!foundSet.contains(i)) continue;

      final region = differences[i];
      final cx = region.x * size.width;
      final cy = region.y * size.height;
      final r = region.radius * size.width;

      final isMine = foundByMe.contains(i);
      final color = isMine
          ? Colors.green.withValues(alpha: 0.4)
          : Colors.grey.withValues(alpha: 0.4);

      // 半透明填充圆
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), r, fillPaint);

      // 边框
      final borderPaint = Paint()
        ..color = isMine ? Colors.green : Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset(cx, cy), r, borderPaint);

      // 对勾标记
      if (isMine) {
        final checkPaint = Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        final checkSize = r * 0.5;
        final checkPath = Path()
          ..moveTo(cx - checkSize * 0.4, cy)
          ..lineTo(cx - checkSize * 0.1, cy + checkSize * 0.4)
          ..lineTo(cx + checkSize * 0.5, cy - checkSize * 0.3);
        canvas.drawPath(checkPath, checkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DiffMarkerPainter oldDelegate) => true;
}
