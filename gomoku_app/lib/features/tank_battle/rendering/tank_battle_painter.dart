/// 坦克大战 CustomPainter — 绘制整个战场。
library;

import 'dart:ui';
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';
import 'package:gomoku_app/features/tank_battle/models/tank_battle_state.dart';
import 'package:gomoku_app/features/tank_battle/rendering/pixel_sprites.dart';

class TankBattlePainter extends CustomPainter {
  final TankBattleState state;
  final double tileSize;

  TankBattlePainter({required this.state, required this.tileSize});

  @override
  void paint(Canvas canvas, Size size) {
    final gridSize = TankBattleConstants.gridSize;
    final totalSize = tileSize * gridSize;

    // 居中偏移
    final offsetX = (size.width - totalSize) / 2;
    final offsetY = (size.height - totalSize) / 2;
    if (offsetX > 0 || offsetY > 0) {
      canvas.translate(offsetX, offsetY);
    }

    // 1. 黑色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, totalSize, totalSize),
      Paint()..color = const Color(0xFF000000),
    );

    // 2. 地面瓦片 (非森林)
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final tile = state.map[row][col];
        if (tile == TileType.empty || tile == TileType.forest) continue;

        final rect = Rect.fromLTWH(
          col * tileSize,
          row * tileSize,
          tileSize,
          tileSize,
        );

        switch (tile) {
          case TileType.brick:
            PixelSprites.drawBrick(canvas, rect);
          case TileType.steel:
            PixelSprites.drawSteel(canvas, rect);
          case TileType.water:
            PixelSprites.drawWater(canvas, rect, state.gameTick ~/ 10);
          case TileType.ice:
            PixelSprites.drawIce(canvas, rect);
          case TileType.base:
            PixelSprites.drawBase(canvas, rect);
          case TileType.baseDestroyed:
            PixelSprites.drawBase(canvas, rect, destroyed: true);
          default:
            break;
        }
      }
    }

    // 3. 子弹 (bullet.x/y 已是中心坐标，不需 +0.5)
    for (final bullet in state.bullets) {
      final center = Offset(
        bullet.x * tileSize,
        bullet.y * tileSize,
      );
      PixelSprites.drawBullet(canvas, center, tileSize);
    }

    // 4. 坦克
    for (final tank in state.tanks) {
      if (!tank.isAlive) continue;
      final center = Offset(
        (tank.x + 0.5) * tileSize,
        (tank.y + 0.5) * tileSize,
      );
      PixelSprites.drawTank(
        canvas,
        center,
        tileSize,
        tank.direction,
        tank.type,
        state.gameTick,
        tank.isMoving,
        tank.invincibleFrames > 0,
      );
    }

    // 5. 森林覆盖层 (在坦克上方)
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        if (state.map[row][col] != TileType.forest) continue;
        final rect = Rect.fromLTWH(
          col * tileSize,
          row * tileSize,
          tileSize,
          tileSize,
        );
        PixelSprites.drawForest(canvas, rect);
      }
    }

    // 6. 爆炸 (最上层)
    for (final exp in state.explosions) {
      final center = Offset(
        (exp.x + 0.5) * tileSize,
        (exp.y + 0.5) * tileSize,
      );
      PixelSprites.drawExplosion(canvas, center, tileSize, exp.frame, exp.isLarge);
    }
  }

  @override
  bool shouldRepaint(TankBattlePainter oldDelegate) {
    return oldDelegate.state.gameTick != state.gameTick;
  }
}
