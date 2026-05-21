import 'package:flutter/material.dart';

/// 信息栏：分数、计时器、已找到数量。
class SpotDiffInfoBar extends StatelessWidget {
  final String selfName;
  final String opponentName;
  final int myScore;
  final int opponentScore;
  final int totalDiffs;
  final int timeRemaining;
  final bool isSolo;

  const SpotDiffInfoBar({
    super.key,
    required this.selfName,
    this.opponentName = '',
    required this.myScore,
    this.opponentScore = 0,
    required this.totalDiffs,
    required this.timeRemaining,
    this.isSolo = true,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = timeRemaining ~/ 60;
    final seconds = timeRemaining % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isLowTime = timeRemaining <= 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // 己方分数
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selfName.isNotEmpty ? selfName : '我',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$myScore',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: myScore > opponentScore
                        ? Colors.green
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // 倒计时
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: isLowTime ? Colors.red : Colors.black87,
                ),
              ),
              if (!isSolo)
                Text(
                  '$totalDiffs 处差异',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                )
              else
                Text(
                  '已找到 $myScore/$totalDiffs',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          // 对方分数 / 单人模式显示已找到数
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSolo)
                  Text(
                    '目标',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    opponentName.isNotEmpty ? opponentName : '对手',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                if (isSolo)
                  Text(
                    '$totalDiffs',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  )
                else
                  Text(
                    '$opponentScore',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: opponentScore > myScore
                          ? Colors.green
                          : Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
