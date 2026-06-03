/// 扑克收集战 — 对手手牌区（仅显示背面）+ 对手收集牌数。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_card_widget.dart';

class CardBattleOpponentHand extends ConsumerWidget {
  final String opponentName;

  const CardBattleOpponentHand({super.key, this.opponentName = '对手'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 对手收集牌数
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Spacer(),
              Icon(Icons.arrow_upward, size: 12, color: Colors.orange.shade300),
              const SizedBox(width: 4),
              Text(
                '$opponentName ',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
              Text(
                '${state.opponentCollectedCount}',
                style: TextStyle(
                  color: Colors.orange.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        // 对手手牌（背面）
        if (state.opponentHand.isEmpty)
          const SizedBox(
            height: 55,
            child: Center(
              child: Text('无手牌', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          SizedBox(
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
          ),
      ],
    );
  }
}
