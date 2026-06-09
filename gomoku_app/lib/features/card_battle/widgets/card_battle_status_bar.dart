/// 扑克收集战 — 状态栏（牌堆剩余、收集牌数）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_state.dart';

class CardBattleStatusBar extends ConsumerWidget {

  const CardBattleStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // PvP 连接状态指示
          if (!state.isSolo) ... _buildConnectionIndicator(state),
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
        ],
      ),
    );
  }

  List<Widget> _buildConnectionIndicator(CardBattleState state) {
    final isConnected = state.status != CardBattleStatus.disconnected;
    return [
      Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isConnected
              ? Colors.green.shade900.withValues(alpha: 0.4)
              : Colors.red.shade900.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isConnected
                ? Colors.green.shade400.withValues(alpha: 0.6)
                : Colors.red.shade400.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.green.shade300 : Colors.red.shade300,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isConnected ? '已连接' : '已断线',
              style: TextStyle(
                color: isConnected ? Colors.green.shade200 : Colors.red.shade200,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    ];
  }

}
