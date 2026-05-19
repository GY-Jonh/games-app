import 'package:flutter/material.dart';
import 'package:gomoku_app/core/constants/game_constants.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';

class GomokuGameOverDialog extends StatelessWidget {
  final GameStatus status;
  final VoidCallback? onRematch;
  final VoidCallback onQuit;

  const GomokuGameOverDialog({
    super.key,
    required this.status,
    this.onRematch,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon, color) = switch (status) {
      GameStatus.won => (
        '你赢了！',
        '恭喜！漂亮的棋局',
        Icons.emoji_events,
        Colors.amber,
      ),
      GameStatus.lost => (
        '你输了',
        '再接再厉，下次加油',
        Icons.sentiment_dissatisfied,
        Colors.grey,
      ),
      GameStatus.draw => (
        '平局',
        '势均力敌！',
        Icons.handshake,
        Colors.blue,
      ),
      GameStatus.disconnected => (
        '连接断开',
        '对方已离线',
        Icons.wifi_off,
        Colors.red,
      ),
      _ => ('游戏结束', '', Icons.info, Colors.grey),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: onQuit,
                  child: const Text('返回大厅'),
                ),
                if (onRematch != null)
                  ElevatedButton(
                    onPressed: onRematch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('再来一局'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
