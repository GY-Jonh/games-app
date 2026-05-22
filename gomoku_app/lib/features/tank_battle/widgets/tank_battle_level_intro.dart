/// 关卡介绍过场 — "STAGE X" 黑底白字。
library;

import 'package:flutter/material.dart';

class TankBattleLevelIntro extends StatelessWidget {
  final int level;

  const TankBattleLevelIntro({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STAGE $level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'READY',
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
