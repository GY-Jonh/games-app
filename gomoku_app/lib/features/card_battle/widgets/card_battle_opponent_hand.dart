/// 扑克收集战 — 对手手牌区（仅显示背面）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_card_widget.dart';

class CardBattleOpponentHand extends ConsumerWidget {
  const CardBattleOpponentHand({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);

    if (state.opponentHand.isEmpty) {
      return const SizedBox(
        height: 55,
        child: Center(
          child: Text('无手牌', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 55,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: state.opponentHand.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: CardBattleCardWidget(
              card: state.opponentHand[index],
              faceDown: true,
              width: 38,
              height: 52,
            ),
          );
        },
      ),
    );
  }
}
