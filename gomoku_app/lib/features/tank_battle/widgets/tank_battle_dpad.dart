/// 虚拟摇杆 (Joystick) 方向控制控件。
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';

class TankBattleDpad extends StatefulWidget {
  final void Function(Direction?) onDirectionChanged;

  const TankBattleDpad({super.key, required this.onDirectionChanged});

  @override
  State<TankBattleDpad> createState() => _TankBattleDpadState();
}

class _TankBattleDpadState extends State<TankBattleDpad> {
  static const double _outerRadius = 85;
  static const double _innerRadius = 26;
  static const double _deadZoneRadius = 12;

  Direction? _activeDirection;
  int? _pointerId;
  Offset _thumbOffset = Offset.zero; // 相对于中心

  void _setDirection(Direction? dir) {
    if (_activeDirection != dir) {
      _activeDirection = dir;
      widget.onDirectionChanged(dir);
    }
  }

  /// 根据偏移角度计算方向，带 45° 扇形区和死区
  Direction? _directionFromOffset(Offset offset) {
    final distance = offset.distance;
    if (distance < _deadZoneRadius) return null;

    final angle = atan2(offset.dy, offset.dx); // -π ~ π, 0=右
    const pi4 = pi / 4;
    if (angle > -pi4 && angle <= pi4) return Direction.right;
    if (angle > pi4 && angle <= 3 * pi4) return Direction.down;
    if (angle > 3 * pi4 || angle <= -3 * pi4) return Direction.left;
    return Direction.up;
  }

  void _handlePointerMove(Offset localPosition) {
    final size = context.size;
    if (size == null) return;

    final center = Offset(size.width / 2, size.height / 2);
    final offset = localPosition - center;

    // 将拇指限制在外圈内
    final maxDist = _outerRadius - _innerRadius - 4;
    final distance = offset.distance;
    _thumbOffset = distance > maxDist ? Offset(offset.dx / distance * maxDist, offset.dy / distance * maxDist) : offset;

    _setDirection(_directionFromOffset(offset));
  }

  void _resetThumb() {
    _thumbOffset = Offset.zero;
    _setDirection(null);
  }

  @override
  Widget build(BuildContext context) {
    const total = _outerRadius * 2 + 24;
    return SizedBox(
      width: total,
      height: total,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointerId != null) return;
          _pointerId = event.pointer;
          _handlePointerMove(event.localPosition);
        },
        onPointerMove: (event) {
          if (event.pointer != _pointerId) return;
          _handlePointerMove(event.localPosition);
        },
        onPointerUp: (event) {
          if (event.pointer != _pointerId) return;
          _pointerId = null;
          _resetThumb();
        },
        onPointerCancel: (event) {
          if (event.pointer != _pointerId) return;
          _pointerId = null;
          _resetThumb();
        },
        child: CustomPaint(
          size: const Size(total, total),
          painter: _JoystickPainter(
            activeDirection: _activeDirection,
            thumbOffset: _thumbOffset,
            outerRadius: _outerRadius,
            innerRadius: _innerRadius,
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Direction? activeDirection;
  final Offset thumbOffset;
  final double outerRadius;
  final double innerRadius;

  _JoystickPainter({
    required this.activeDirection,
    required this.thumbOffset,
    required this.outerRadius,
    required this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 外圈底色
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()..color = Colors.grey.shade800.withValues(alpha: 0.25),
    );

    // 外圈边框
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 4 个方向标记点
    _drawDirectionMarkers(canvas, center, outerRadius - 14);

    // 十字参考线 (微弱)
    _drawCrosshair(canvas, center);

    // 拇指（摇杆头）
    final thumbCenter = center + thumbOffset;
    final thumbPaint = Paint()
      ..color = Colors.white.withValues(alpha: activeDirection != null ? 0.55 : 0.30);
    canvas.drawCircle(thumbCenter, innerRadius, thumbPaint);

    // 拇指边框
    canvas.drawCircle(
      thumbCenter,
      innerRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: activeDirection != null ? 0.85 : 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 拇指上的方向指示点
    if (activeDirection != null) {
      final indicatorOffset = _dirOffset(activeDirection!, innerRadius * 0.55);
      canvas.drawCircle(
        thumbCenter + indicatorOffset,
        innerRadius * 0.28,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  void _drawDirectionMarkers(Canvas canvas, Offset center, double radius) {
    const dirs = [
      (Direction.up, -pi / 2),
      (Direction.down, pi / 2),
      (Direction.left, pi),
      (Direction.right, 0),
    ];

    for (final (dir, angle) in dirs) {
      final active = dir == activeDirection;
      final pos = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      final markerRadius = active ? 7.0 : 4.5;
      canvas.drawCircle(
        pos,
        markerRadius,
        Paint()..color = Colors.white.withValues(alpha: active ? 0.7 : 0.2),
      );
    }
  }

  void _drawCrosshair(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - outerRadius + 10, center.dy),
      Offset(center.dx + outerRadius - 10, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - outerRadius + 10),
      Offset(center.dx, center.dy + outerRadius - 10),
      paint,
    );
  }

  Offset _dirOffset(Direction dir, double dist) => switch (dir) {
        Direction.up => Offset(0, -dist),
        Direction.down => Offset(0, dist),
        Direction.left => Offset(-dist, 0),
        Direction.right => Offset(dist, 0),
      };

  @override
  bool shouldRepaint(covariant _JoystickPainter old) =>
      activeDirection != old.activeDirection || thumbOffset != old.thumbOffset;
}
