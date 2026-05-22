/// 程序化像素精灵绘制 — NES 复古风格。
library;

import 'dart:ui';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';

/// 像素精灵绘制工具类。
/// 所有精灵基于 8x8 像素网格定义，缩放到实际瓦片大小。
class PixelSprites {
  PixelSprites._();

  // ========== 颜色定义 ==========

  static const Color _bgColor = Color(0xFF000000);
  static const Color _brickColor = Color(0xFFAA4400);
  static const Color _brickDark = Color(0xFF663300);
  static const Color _steelColor = Color(0xFFCCCCCC);
  static const Color _steelDark = Color(0xFF999999);
  static const Color _waterColor = Color(0xFF0044CC);
  static const Color _waterLight = Color(0xFF2266EE);
  static const Color _forestColor = Color(0xFF006600);
  static const Color _forestLight = Color(0xFF008800);
  static const Color _iceColor = Color(0xFFAADDFF);
  static const Color _iceLight = Color(0xFFCCEEFF);
  static const Color _baseColor = Color(0xFFFF4444);
  static const Color _baseDark = Color(0xFF882222);
  static const Color _player1Color = Color(0xFFFFCC00);
  static const Color _player2Color = Color(0xFF00CC00);
  static const Color _enemyBasicColor = Color(0xFFAAAAAA);
  static const Color _enemyFastColor = Color(0xFFCC6600);
  static const Color _enemyArmorColor = Color(0xFF00AA00);
  static const Color _enemyHeavyColor = Color(0xFFCC0000);

  static Color tankColor(TankType type) => switch (type) {
        TankType.player1 => _player1Color,
        TankType.player2 => _player2Color,
        TankType.enemyBasic => _enemyBasicColor,
        TankType.enemyFast => _enemyFastColor,
        TankType.enemyArmor => _enemyArmorColor,
        TankType.enemyHeavy => _enemyHeavyColor,
      };

  // ========== 瓦片绘制 ==========

  static void drawBrick(Canvas canvas, Rect tileRect) {
    final p = tileRect.width / 8;
    // 底色
    canvas.drawRect(tileRect, Paint()..color = _brickColor);
    // 砖缝 (横线)
    final paint = Paint()..color = _brickDark;
    for (int row = 0; row < 8; row += 2) {
      canvas.drawRect(
        Rect.fromLTWH(
            tileRect.left, tileRect.top + row * p, tileRect.width, p * 0.3),
        paint,
      );
    }
    // 砖缝 (竖线，交错)
    for (int row = 0; row < 8; row += 2) {
      final offset = (row % 4 == 0) ? 0.0 : 4.0;
      for (int col = 0; col < 8; col += 4) {
        canvas.drawRect(
          Rect.fromLTWH(tileRect.left + (col + offset) * p,
              tileRect.top + row * p, p * 0.3, p * 2),
          paint,
        );
      }
    }
  }

  static void drawSteel(Canvas canvas, Rect tileRect) {
    final p = tileRect.width / 8;
    canvas.drawRect(tileRect, Paint()..color = _steelDark);
    // 金属高光
    final paint = Paint()..color = _steelColor;
    for (int row = 1; row < 7; row += 2) {
      for (int col = 1; col < 7; col += 2) {
        canvas.drawRect(
          Rect.fromLTWH(tileRect.left + col * p, tileRect.top + row * p,
              p * 1.5, p * 1.5),
          paint,
        );
      }
    }
  }

  static void drawWater(Canvas canvas, Rect tileRect, int frame) {
    final p = tileRect.width / 8;
    canvas.drawRect(tileRect, Paint()..color = _waterColor);
    final paint = Paint()..color = _waterLight;
    final offset = frame % 2;
    for (int row = 1 + offset; row < 8; row += 3) {
      for (int col = 0; col < 8; col += 4) {
        canvas.drawRect(
          Rect.fromLTWH(tileRect.left + col * p, tileRect.top + row * p,
              p * 2, p * 0.5),
          paint,
        );
      }
    }
  }

  static void drawForest(Canvas canvas, Rect tileRect) {
    final p = tileRect.width / 8;
    canvas.drawRect(tileRect, Paint()..color = _forestColor);
    final paint = Paint()..color = _forestLight;
    // 树叶图案
    for (int row = 0; row < 8; row += 2) {
      for (int col = (row % 4 == 0 ? 0 : 1); col < 8; col += 2) {
        canvas.drawRect(
          Rect.fromLTWH(tileRect.left + col * p, tileRect.top + row * p,
              p * 1.2, p * 1.2),
          paint,
        );
      }
    }
  }

  static void drawIce(Canvas canvas, Rect tileRect) {
    final p = tileRect.width / 8;
    canvas.drawRect(tileRect, Paint()..color = _iceColor);
    final paint = Paint()..color = _iceLight;
    // 冰面高光
    for (int row = 1; row < 8; row += 3) {
      for (int col = 0; col < 7; col += 3) {
        canvas.drawRect(
          Rect.fromLTWH(tileRect.left + col * p, tileRect.top + row * p,
              p * 2, p * 0.4),
          paint,
        );
      }
    }
  }

  static void drawBase(Canvas canvas, Rect tileRect, {bool destroyed = false}) {
    final p = tileRect.width / 8;
    if (destroyed) {
      canvas.drawRect(tileRect, Paint()..color = _baseDark);
      // 碎片
      final paint = Paint()..color = _baseColor.withValues(alpha: 0.5);
      canvas.drawRect(
        Rect.fromLTWH(tileRect.left + 2 * p, tileRect.top + 2 * p,
            p * 2, p * 2),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(tileRect.left + 5 * p, tileRect.top + 4 * p,
            p * 1.5, p * 1.5),
        paint,
      );
      return;
    }
    // 完好基地 — 鹰/旗帜图案
    canvas.drawRect(tileRect, Paint()..color = _bgColor);
    final paint = Paint()..color = _baseColor;
    // 旗杆
    canvas.drawRect(
      Rect.fromLTWH(tileRect.left + 3.5 * p, tileRect.top + 1 * p,
          p * 1, p * 6),
      paint,
    );
    // 旗面
    canvas.drawRect(
      Rect.fromLTWH(tileRect.left + 4.5 * p, tileRect.top + 1 * p,
          p * 3, p * 3),
      paint,
    );
    // 底座
    canvas.drawRect(
      Rect.fromLTWH(tileRect.left + 2 * p, tileRect.top + 6.5 * p,
          p * 4, p * 1),
      paint,
    );
  }

  // ========== 坦克绘制 ==========

  /// 绘制坦克 (根据朝向旋转)。
  static void drawTank(
    Canvas canvas,
    Offset center,
    double tileSize,
    Direction direction,
    TankType type,
    int tickCount,
    bool isMoving,
    bool isInvincible,
  ) {
    // 无敌闪烁 (每 4 帧切换)
    if (isInvincible && (tickCount ~/ 4) % 2 == 0) return;

    final color = tankColor(type);
    final darkColor = Color.fromARGB(
      255,
      (color.r * 255.0 * 0.6).round().clamp(0, 255),
      (color.g * 255.0 * 0.6).round().clamp(0, 255),
      (color.b * 255.0 * 0.6).round().clamp(0, 255),
    );

    final size = tileSize * 0.9;
    final half = size / 2;
    final left = center.dx - half;
    final top = center.dy - half;
    final p = size / 8;

    // 根据朝向绘制
    // 基础模板: 朝上，然后旋转
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final angle = switch (direction) {
      Direction.up => 0.0,
      Direction.right => 1.5708, // pi/2
      Direction.down => 3.1416, // pi
      Direction.left => 4.7124, // 3*pi/2
    };
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);

    // 坦克主体 (中心大方块)
    final bodyPaint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(left + 2 * p, top + 2 * p, 4 * p, 4 * p),
      bodyPaint,
    );

    // 炮管 (朝上方向)
    canvas.drawRect(
      Rect.fromLTWH(left + 3.5 * p, top + 0.5 * p, p, 2.5 * p),
      bodyPaint,
    );

    // 履带 (两侧)
    final trackPaint = Paint()..color = darkColor;
    // 左履带
    canvas.drawRect(
      Rect.fromLTWH(left + 0.5 * p, top + 1.5 * p, 1.5 * p, 5 * p),
      trackPaint,
    );
    // 右履带
    canvas.drawRect(
      Rect.fromLTWH(left + 6 * p, top + 1.5 * p, 1.5 * p, 5 * p),
      trackPaint,
    );

    // 履带纹理 (移动时交替)
    final trackFrame = isMoving ? (tickCount ~/ 4) % 2 : 0;
    final detailPaint = Paint()..color = color;
    for (int i = 0; i < 4; i++) {
      final y = top + (2 + i * 1.2 + trackFrame * 0.6) * p;
      canvas.drawRect(
        Rect.fromLTWH(left + 0.5 * p, y, 1.5 * p, p * 0.4),
        detailPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(left + 6 * p, y, 1.5 * p, p * 0.4),
        detailPaint,
      );
    }

    // 装甲/重型坦克额外标记
    if (type == TankType.enemyArmor || type == TankType.enemyHeavy) {
      canvas.drawRect(
        Rect.fromLTWH(left + 3 * p, top + 3 * p, 2 * p, 2 * p),
        trackPaint,
      );
    }
    if (type == TankType.enemyHeavy) {
      // 重型坦克双层装甲标记
      canvas.drawRect(
        Rect.fromLTWH(left + 3.5 * p, top + 3.5 * p, p, p),
        detailPaint,
      );
    }

    canvas.restore();
  }

  // ========== 子弹绘制 ==========

  static void drawBullet(Canvas canvas, Offset center, double tileSize) {
    final size = tileSize * 0.25;
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: size, height: size),
      paint,
    );
  }

  // ========== 爆炸绘制 ==========

  static void drawExplosion(
    Canvas canvas,
    Offset center,
    double tileSize,
    int frame,
    bool isLarge,
  ) {
    final maxRadius = isLarge ? tileSize * 1.2 : tileSize * 0.5;
    final progress = frame / TankBattleConstants.explosionDurationTicks;

    // 外圈 (橙色)
    final outerRadius = maxRadius * (progress < 0.5
        ? progress * 2
        : 2 - progress * 2);
    final outerPaint = Paint()
      ..color = const Color(0xFFFF6600)
          .withValues(alpha: (1 - progress).clamp(0.0, 1.0));
    canvas.drawCircle(center, outerRadius, outerPaint);

    // 内圈 (黄色)
    if (progress < 0.7) {
      final innerRadius = outerRadius * 0.5;
      final innerPaint = Paint()
        ..color = const Color(0xFFFFCC00)
            .withValues(alpha: (1 - progress * 1.2).clamp(0.0, 1.0));
      canvas.drawCircle(center, innerRadius, innerPaint);
    }
  }
}
