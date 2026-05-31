/// 扑克收集战 — 状态栏（牌堆剩余、收集牌数）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';

class CardBattleStatusBar extends ConsumerWidget {
  final String opponentName;

  const CardBattleStatusBar({super.key, this.opponentName = '对手'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 我方收集牌数
          _buildPile(
            label: '我',
            count: state.playerCollectedCount,
            color: Colors.green.shade300,
            icon: Icons.arrow_downward,
          ),
          // 牌堆剩余
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '牌堆',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.deckRemaining}',
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '回合 ${state.roundNumber}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          // 对手收集牌数
          _buildPile(
            label: opponentName,
            count: state.opponentCollectedCount,
            color: Colors.orange.shade300,
            icon: Icons.arrow_upward,
          ),
        ],
      ),
    );
  }

  Widget _buildPile({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
          ),
        ),
        Icon(icon, color: color, size: 14),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
