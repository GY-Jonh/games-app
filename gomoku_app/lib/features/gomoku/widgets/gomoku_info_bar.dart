import 'package:flutter/material.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';
import 'package:gomoku_app/features/gomoku/models/stone.dart';

class GomokuInfoBar extends StatelessWidget {
  final String playerName;
  final String opponentName;
  final Stone myStone;
  final Stone currentTurn;
  final int moveCount;
  final bool isMyTurn;
  final int timeRemaining;

  const GomokuInfoBar({
    super.key,
    required this.playerName,
    required this.opponentName,
    required this.myStone,
    required this.currentTurn,
    required this.moveCount,
    required this.isMyTurn,
    this.timeRemaining = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Player (me)
          Expanded(
            child: _PlayerCard(
              name: playerName,
              stone: myStone,
              isActive: isMyTurn,
              timeRemaining: timeRemaining,
              alignment: CrossAxisAlignment.start,
            ),
          ),
          // Move count in center
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                moveCount > 0 ? '第 $moveCount 手' : '游戏开始',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isMyTurn
                      ? AppTheme.onlineGreen.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isMyTurn ? '你的回合' : '等待对方',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isMyTurn ? AppTheme.onlineGreen : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Opponent
          Expanded(
            child: _PlayerCard(
              name: opponentName,
              stone: myStone == Stone.black ? Stone.white : Stone.black,
              isActive: !isMyTurn,
              timeRemaining: 60,
              alignment: CrossAxisAlignment.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final String name;
  final Stone stone;
  final bool isActive;
  final int timeRemaining;
  final CrossAxisAlignment alignment;

  const _PlayerCard({
    required this.name,
    required this.stone,
    required this.isActive,
    required this.timeRemaining,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final timeColor = timeRemaining <= 10
        ? Colors.red
        : timeRemaining <= 30
            ? Colors.orange
            : Colors.grey.shade600;

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (alignment == CrossAxisAlignment.end) ...[
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stone == Stone.black
                    ? AppTheme.blackStone
                    : AppTheme.whiteStone,
                border: Border.all(
                  color: stone == Stone.black
                      ? Colors.transparent
                      : Colors.grey.shade400,
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: (stone == Stone.black
                                  ? AppTheme.blackStone
                                  : Colors.orange)
                              .withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            if (alignment == CrossAxisAlignment.start) ...[
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _formatTime(timeRemaining),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: timeColor,
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
