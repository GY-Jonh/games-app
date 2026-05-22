/// HUD 信息栏 — 显示生命、剩余敌人、关卡、分数。
library;

import 'package:flutter/material.dart';

class TankBattleHud extends StatelessWidget {
  final int lives;
  final int enemiesRemaining;
  final int currentLevel;
  final int score;
  final bool isSolo;
  final String opponentName;

  const TankBattleHud({
    super.key,
    required this.lives,
    required this.enemiesRemaining,
    required this.currentLevel,
    required this.score,
    required this.isSolo,
    this.opponentName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade900,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左: 生命 + 分数
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, color: Colors.red.shade400, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'x$lives',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$score',
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // 中: 关卡
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STAGE $currentLevel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isSolo)
                Text(
                  opponentName,
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 11,
                  ),
                ),
            ],
          ),

          // 右: 剩余敌人
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$enemiesRemaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.warning_amber,
                      color: Colors.orange.shade400, size: 14),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '剩余敌人',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
