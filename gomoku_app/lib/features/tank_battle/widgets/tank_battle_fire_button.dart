/// 开火按钮控件。
library;

import 'package:flutter/material.dart';

class TankBattleFireButton extends StatefulWidget {
  final void Function(bool firing) onFiringChanged;

  const TankBattleFireButton({super.key, required this.onFiringChanged});

  @override
  State<TankBattleFireButton> createState() => _TankBattleFireButtonState();
}

class _TankBattleFireButtonState extends State<TankBattleFireButton> {
  bool _isFiring = false;
  int? _pointerId;

  void _setFiring(bool firing) {
    if (_isFiring != firing) {
      _isFiring = firing;
      widget.onFiringChanged(firing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_pointerId != null) return;
        _pointerId = event.pointer;
        _setFiring(true);
      },
      onPointerUp: (event) {
        if (event.pointer != _pointerId) return;
        _pointerId = null;
        _setFiring(false);
      },
      onPointerCancel: (event) {
        if (event.pointer != _pointerId) return;
        _pointerId = null;
        _setFiring(false);
      },
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isFiring
              ? Colors.red.withValues(alpha: 0.8)
              : Colors.red.withValues(alpha: 0.5),
          border: Border.all(
            color: Colors.red.shade300.withValues(alpha: 0.6),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            'FIRE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: _isFiring ? 1.0 : 0.7),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
