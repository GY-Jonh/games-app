/// 扑克收集战 — 游戏结果覆盖层。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';

class CardBattleResultOverlay extends ConsumerWidget {
  const CardBattleResultOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);

    if (!state.isGameOver || state.resultMessage == null) {
      return const SizedBox.shrink();
    }

    final isWin = state.status == CardBattleStatus.won;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isWin
                ? Colors.green.shade800.withValues(alpha: 0.9)
                : Colors.red.shade800.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isWin ? Colors.green.shade400 : Colors.red.shade400,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                size: 60,
                color: isWin ? Colors.amber : Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                isWin ? '你赢了！' : '你输了',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.resultMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 收集牌数对比
                  _buildCountChip(
                    label: '我方',
                    count: state.playerCollectedCount,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(width: 16),
                  const Text('VS', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 16),
                  _buildCountChip(
                    label: '对方',
                    count: state.opponentCollectedCount,
                    color: Colors.orange.shade300,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(cardBattleStateProvider.notifier).rematch();
                  ref.read(cardBattleSelectedProvider.notifier).state = [];
                },
                icon: const Icon(Icons.refresh),
                label: const Text('再来一局'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isWin ? Colors.green.shade800 : Colors.red.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
