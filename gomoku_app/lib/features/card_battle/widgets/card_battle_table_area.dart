/// 扑克收集战 — 台面区域（本轮已出牌）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_card.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_combination.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_state.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_card_widget.dart';

class CardBattleTableArea extends ConsumerWidget {
  const CardBattleTableArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);
    final opponentCards = state.opponentTableCards;
    final playerCards = state.playerTableCards;
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
          if (currentCombo != null) ... _buildComboLabel(currentCombo),
          const SizedBox(height: 4),
          // 对手出的牌（上排）
          if (opponentCards.isNotEmpty)
            _buildCardRow(opponentCards, isOpponent: true),
          if (opponentCards.isNotEmpty && playerCards.isNotEmpty)
            const SizedBox(height: 6),
          // 我方出的牌（下排）
          if (playerCards.isNotEmpty)
            _buildCardRow(playerCards, isOpponent: false),
          // 无牌时的提示
          if (opponentCards.isEmpty && playerCards.isEmpty) ... _buildEmptyHint(state),
        ],
      ),
    );
  }

  List<Widget> _buildComboLabel(CardCombo combo) {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          combo.label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildEmptyHint(CardBattleState state) {
    if (state.lastRoundPassed) {
      return [
        Text(
          state.turnPlayerIndex == 0 ? '对方已过牌' : '你已过牌',
          style: const TextStyle(color: Colors.orange, fontSize: 14),
        ),
      ];
    }
    return [
      const Text(
        '等待出牌...',
        style: TextStyle(color: Colors.white38, fontSize: 14),
      ),
    ];
  }

  Widget _buildCardRow(List<GameCard> cards, {required bool isOpponent}) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: cards.map((card) => CardBattleCardWidget(
        card: card,
        faceDown: false,
        width: isOpponent ? 44 : 50,
        height: isOpponent ? 62 : 70,
      )).toList(),
    );
  }
}
