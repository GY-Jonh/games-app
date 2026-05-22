/// 游戏结束 / 过关面板。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';

class TankBattleGameOver extends StatelessWidget {
  final TankBattlePhase phase;
  final int score;
  final int currentLevel;
  final bool isSolo;
  final VoidCallback onRematch;
  final VoidCallback onQuit;
  final bool isWaitingRematch;
  final bool showAcceptRematch;
  final VoidCallback? onAcceptRematch;

  const TankBattleGameOver({
    super.key,
    required this.phase,
    required this.score,
    required this.currentLevel,
    required this.isSolo,
    required this.onRematch,
    required this.onQuit,
    this.isWaitingRematch = false,
    this.showAcceptRematch = false,
    this.onAcceptRematch,
  });

  @override
  Widget build(BuildContext context) {
    final isLevelComplete = phase == TankBattlePhase.levelComplete;
    final isLost = phase == TankBattlePhase.lost;
    final isDisconnected = phase == TankBattlePhase.disconnected;

    String title;
    Color titleColor;
    IconData icon;

    if (isLevelComplete) {
      title = '过关!';
      titleColor = Colors.green;
      icon = Icons.emoji_events;
    } else if (isLost) {
      title = 'GAME OVER';
      titleColor = Colors.red;
      icon = Icons.dangerous;
    } else if (isDisconnected) {
      title = '连接断开';
      titleColor = Colors.grey;
      icon = Icons.wifi_off;
    } else {
      title = '胜利!';
      titleColor = Colors.amber;
      icon = Icons.star;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: titleColor, size: 36),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '关卡: $currentLevel  |  分数: $score',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isSolo && showAcceptRematch && onAcceptRematch != null) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('接受重赛'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: onAcceptRematch,
                ),
                const SizedBox(width: 12),
              ] else ...[
                ElevatedButton.icon(
                  icon: Icon(
                    isLevelComplete ? Icons.arrow_forward : Icons.refresh,
                    size: 18,
                  ),
                  label: Text(isLevelComplete
                      ? '下一关'
                      : (isSolo ? '再来一局' : '重赛')),
                  onPressed: onRematch,
                ),
                const SizedBox(width: 12),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, size: 18),
                label: const Text('退出'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade300,
                ),
                onPressed: onQuit,
              ),
            ],
          ),
          if (!isSolo && isWaitingRematch)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '等待对方回应...',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
