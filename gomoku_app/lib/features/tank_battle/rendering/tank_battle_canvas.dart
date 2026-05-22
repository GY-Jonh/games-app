/// 坦克大战画布 Widget。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';
import 'package:gomoku_app/features/tank_battle/models/tank_battle_state.dart';
import 'package:gomoku_app/features/tank_battle/rendering/tank_battle_painter.dart';

class TankBattleCanvas extends StatelessWidget {
  final TankBattleState state;

  const TankBattleCanvas({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDim = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final tileSize = maxDim / TankBattleConstants.gridSize;

        return RepaintBoundary(
          child: CustomPaint(
            size: Size(
              tileSize * TankBattleConstants.gridSize,
              tileSize * TankBattleConstants.gridSize,
            ),
            painter: TankBattlePainter(state: state, tileSize: tileSize),
          ),
        );
      },
    );
  }
}
