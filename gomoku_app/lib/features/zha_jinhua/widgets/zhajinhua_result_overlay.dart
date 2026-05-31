/// 摊牌/回合结束结果覆盖层。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/features/zha_jinhua/constants/zha_jinhua_constants.dart';
import 'package:gomoku_app/features/zha_jinhua/models/playing_card.dart';
import 'package:gomoku_app/features/zha_jinhua/widgets/zhajinhua_card_widget.dart';

class ZhaJinhuaResultOverlay extends StatelessWidget {
  final ZhaJinhuaGameStatus status;
  final List<PlayingCard> playerCards;
  final List<PlayingCard> opponentCards;
  final bool playerCardsRevealed;
  final bool opponentCardsRevealed;
  final String? resultMessage;
  final bool canContinue;
  final int playerChips;
  final int opponentChips;
  final bool isSolo;
  final VoidCallback onNextRound;
  final VoidCallback onQuit;

  const ZhaJinhuaResultOverlay({
    super.key,
    required this.status,
    required this.playerCards,
    required this.opponentCards,
    required this.playerCardsRevealed,
    required this.opponentCardsRevealed,
    this.resultMessage,
    required this.canContinue,
    required this.playerChips,
    required this.opponentChips,
    required this.isSolo,
    required this.onNextRound,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _statusColor.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 状态标题
              Icon(
                _statusIcon,
                size: 40,
                color: _statusColor,
              ),
              const SizedBox(height: 8),
              Text(
                _statusText,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 双方手牌 - 上下布局（对手在上，你在下）
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 对手
                  _handColumn(
                    '对手',
                    opponentCards,
                    opponentCardsRevealed,
                    opponentChips,
                  ),
                  const SizedBox(height: 12),
                  // VS
                  Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 玩家
                  _handColumn(
                    '你',
                    playerCards,
                    playerCardsRevealed,
                    playerChips,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // 结果消息
              if (resultMessage != null)
                Text(
                  resultMessage!,
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 20),
              // 按钮
              if (canContinue)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onNextRound,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('下一轮', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (canContinue) const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onQuit,
                  icon: const Icon(Icons.exit_to_app, size: 18),
                  label: Text(
                    canContinue ? '退出' : '返回大厅',
                    style: const TextStyle(fontSize: 15),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade400,
                    side: BorderSide(color: Colors.grey.shade700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handColumn(
      String label, List<PlayingCard> cards, bool revealed, int chips) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: cards.map((card) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ZhaJinhuaCardWidget(
                card: card,
                faceDown: !revealed,
                width: 52,
                height: 74,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          '$chips 筹码',
          style: TextStyle(
            color: Colors.amber.shade300,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String get _statusText => switch (status) {
        ZhaJinhuaGameStatus.won => '你赢了！',
        ZhaJinhuaGameStatus.lost => '你输了',
        ZhaJinhuaGameStatus.draw => '平局',
        ZhaJinhuaGameStatus.disconnected => '连接断开',
        _ => '',
      };

  IconData get _statusIcon => switch (status) {
        ZhaJinhuaGameStatus.won => Icons.emoji_events,
        ZhaJinhuaGameStatus.lost => Icons.sentiment_dissatisfied,
        ZhaJinhuaGameStatus.draw => Icons.handshake,
        ZhaJinhuaGameStatus.disconnected => Icons.wifi_off,
        _ => Icons.info,
      };

  Color get _statusColor => switch (status) {
        ZhaJinhuaGameStatus.won => Colors.amber,
        ZhaJinhuaGameStatus.lost => Colors.red.shade400,
        ZhaJinhuaGameStatus.draw => Colors.blue.shade300,
        ZhaJinhuaGameStatus.disconnected => Colors.grey,
        _ => Colors.white,
      };
}
