/// 扑克收集战 — 主界面。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/card_battle/card_battle_providers.dart';
import 'package:gomoku_app/features/card_battle/constants/card_battle_constants.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_state.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_opponent_hand.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_player_hand.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_result_overlay.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_status_bar.dart';
import 'package:gomoku_app/features/card_battle/widgets/card_battle_table_area.dart';
import 'package:gomoku_app/models/network_message.dart';

class CardBattleScreen extends ConsumerWidget {
  final String opponentName;
  final void Function(NetworkMessage)? onSendMessage;

  const CardBattleScreen({
    super.key,
    this.opponentName = '对手',
    this.onSendMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cardBattleStateProvider);

    // 显示加载中
    if (state.status == CardBattleStatus.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('扑克收集战'),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        actions: [
          if (state.isGameOver)
            TextButton.icon(
              onPressed: () {
                ref.read(cardBattleStateProvider.notifier).rematch();
                ref.read(cardBattleSelectedProvider.notifier).state = [];
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('重玩', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade900,
              Colors.green.shade900,
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // 对手手牌（背面朝上）
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: CardBattleStatusBar(opponentName: opponentName),
                ),
                const SizedBox(height: 4),
                CardBattleOpponentHand(),

                const Spacer(),

                // 台面（本轮出牌区）
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: CardBattleTableArea(),
                ),

                const Spacer(),

                // 操作按钮
                _buildActionButtons(context, ref, state),

                // 玩家手牌
                const CardBattlePlayerHand(),
                const SizedBox(height: 8),
              ],
            ),

            // 结果覆盖层
            const CardBattleResultOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    CardBattleState state,
  ) {
    if (!state.isPlayerTurn) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          state.isOpponentTurn ? '等待对手出牌...' : '',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      );
    }

    final selectedIndices = ref.watch(cardBattleSelectedProvider);
    final hasSelection = selectedIndices.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 出牌按钮
          ElevatedButton.icon(
            onPressed: hasSelection
                ? () {
                    final cards = selectedIndices
                        .map((i) => state.playerHand[i])
                        .toList();
                    ref
                        .read(cardBattleStateProvider.notifier)
                        .playerPlay(cards);
                    ref.read(cardBattleSelectedProvider.notifier).state = [];
                  }
                : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              hasSelection ? '出牌 (${selectedIndices.length})' : '选择手牌',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // "过"按钮
          if (state.canPass && state.tableCards.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                ref.read(cardBattleStateProvider.notifier).playerPass();
                ref.read(cardBattleSelectedProvider.notifier).state = [];
              },
              icon: const Icon(Icons.block),
              label: const Text('过'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade300,
                side: BorderSide(color: Colors.orange.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          const SizedBox(width: 12),
          // 清除选择
          if (hasSelection)
            IconButton(
              onPressed: () {
                ref.read(cardBattleSelectedProvider.notifier).state = [];
              },
              icon: const Icon(Icons.clear),
              color: Colors.white54,
              tooltip: '清除选择',
            ),
        ],
      ),
    );
  }
}
