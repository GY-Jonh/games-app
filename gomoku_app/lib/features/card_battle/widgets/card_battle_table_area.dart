/// 扑克收集战 — 台面区域（本轮已出牌）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_card_widget.dart';

class CardBattleTableArea extends ConsumerWidget {
  const CardBattleTableArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);
    final tableCards = state.tableCards;
    final currentCombo = state.currentCombo;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade800.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.shade600.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 牌型标签
          if (currentCombo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                currentCombo.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 8),
          // 桌面牌
          if (tableCards.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: tableCards.map((card) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: CardBattleCardWidget(
                    card: card,
                    faceDown: false,
                    width: 54,
                    height: 76,
                  ),
                );
              }).toList(),
            )
          else
            const Text(
              '等待出牌...',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
        ],
      ),
    );
  }
}
