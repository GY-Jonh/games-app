/// 虚拟方向键 (D-Pad) 控件。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';

class TankBattleDpad extends StatefulWidget {
  final void Function(Direction?) onDirectionChanged;

  const TankBattleDpad({super.key, required this.onDirectionChanged});

  @override
  State<TankBattleDpad> createState() => _TankBattleDpadState();
}

class _TankBattleDpadState extends State<TankBattleDpad> {
  Direction? _activeDirection;
  int? _pointerId;

  void _setDirection(Direction? dir) {
    if (_activeDirection != dir) {
      _activeDirection = dir;
      widget.onDirectionChanged(dir);
    }
  }

  Direction _directionFromOffset(Offset offset, double size) {
    final cx = size / 2;
    final cy = size / 2;
    final dx = offset.dx - cx;
    final dy = offset.dy - cy;
    if (dx.abs() > dy.abs()) {
      return dx > 0 ? Direction.right : Direction.left;
    } else {
      return dy > 0 ? Direction.down : Direction.up;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointerId != null) return;
          _pointerId = event.pointer;
          final dir = _directionFromOffset(event.localPosition, 180);
          _setDirection(dir);
        },
        onPointerMove: (event) {
          if (event.pointer != _pointerId) return;
          final dir = _directionFromOffset(event.localPosition, 180);
          _setDirection(dir);
        },
        onPointerUp: (event) {
          if (event.pointer != _pointerId) return;
          _pointerId = null;
          _setDirection(null);
        },
        onPointerCancel: (event) {
          if (event.pointer != _pointerId) return;
          _pointerId = null;
          _setDirection(null);
        },
        child: Stack(
          children: [
            // 背景圆
            Center(
              child: Container(
                width: 165,
                height: 165,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade800.withValues(alpha: 0.3),
                ),
              ),
            ),
            // 上
            _buildArrow(Alignment.topCenter, Direction.up, Icons.arrow_upward),
            // 下
            _buildArrow(
                Alignment.bottomCenter, Direction.down, Icons.arrow_downward),
            // 左
            _buildArrow(
                Alignment.centerLeft, Direction.left, Icons.arrow_back),
            // 右
            _buildArrow(
                Alignment.centerRight, Direction.right, Icons.arrow_forward),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(Alignment alignment, Direction dir, IconData icon) {
    final isActive = _activeDirection == dir;
    return Align(
      alignment: alignment,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.5),
          size: 30,
        ),
      ),
    );
  }
}
