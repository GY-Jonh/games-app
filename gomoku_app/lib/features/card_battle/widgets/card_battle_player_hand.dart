/// 扑克收集战 — 玩家手牌区。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_card_widget.dart';

class CardBattlePlayerHand extends ConsumerWidget {
  const CardBattlePlayerHand({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);
    final selectedIndices = ref.watch(cardBattleSelectedProvider);
    final isPlayerTurn = state.isPlayerTurn;

    if (state.playerHand.isEmpty) {
      return const SizedBox(
        height: 110,
        child: Center(
          child: Text('无手牌', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: state.playerHand.length,
        itemBuilder: (context, index) {
          final card = state.playerHand[index];
          final isSelected = selectedIndices.contains(index);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: CardBattleCardWidget(
              card: card,
              faceDown: false,
              width: 64,
              height: 88,
              isSelected: isSelected,
              isPlayable: isPlayerTurn,
              onTap: isPlayerTurn
                  ? () {
                      final notifier =
                          ref.read(cardBattleSelectedProvider.notifier);
                      if (isSelected) {
                        notifier.state =
                            selectedIndices.where((i) => i != index).toList();
                      } else {
                        notifier.state = [...selectedIndices, index];
                      }
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }
}
