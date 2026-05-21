import 'package:flutter/material.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_providers.dart';

/// 游戏结束底部面板。
class SpotDiffGameOverDialog extends StatelessWidget {
  final SpotDiffGameStatus status;
  final int myScore;
  final int opponentScore;
  final int totalDiffs;
  final bool isSolo;
  final VoidCallback? onRematch;
  final VoidCallback onQuit;

  const SpotDiffGameOverDialog({
    super.key,
    required this.status,
    required this.myScore,
    required this.opponentScore,
    required this.totalDiffs,
    this.isSolo = true,
    this.onRematch,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon, color) = _buildContent();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            const SizedBox(height: 16),
            // Score display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$myScore',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: myScore > opponentScore
                          ? Colors.green
                          : Colors.black87,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'vs',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  if (!isSolo)
                    Text(
                      '$opponentScore',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: opponentScore > myScore
                            ? Colors.green
                            : Colors.black87,
                      ),
                    )
                  else
                    Container(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '共找出 ${myScore + opponentScore} / $totalDiffs 处差异',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
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

  (String, String, IconData, Color) _buildContent() {
    switch (status) {
      case SpotDiffGameStatus.won:
        return (
          isSolo ? '全部找到！' : '你赢了！',
          isSolo ? '完美通关' : '你比对手找到更多差异',
          Icons.emoji_events,
          Colors.amber,
        );
      case SpotDiffGameStatus.lost:
        return (
          isSolo ? '时间到' : '你输了',
          isSolo ? '下次加油！' : '对方找到了更多差异',
          Icons.sentiment_dissatisfied,
          Colors.grey,
        );
      case SpotDiffGameStatus.draw:
        return (
          '平局',
          '势均力敌！',
          Icons.handshake,
          Colors.blue,
        );
      case SpotDiffGameStatus.disconnected:
        return (
          '连接断开',
          '对方已离线',
          Icons.wifi_off,
          Colors.red,
        );
      default:
        return ('游戏结束', '', Icons.info, Colors.grey);
    }
  }
}
