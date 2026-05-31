/// 对手区域组件。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/features/zha_jinhua/models/playing_card.dart';
import 'package:gomoku_app/features/zha_jinhua/widgets/zhajinhua_card_widget.dart';

class ZhaJinhuaOpponentArea extends StatelessWidget {
  final List<PlayingCard> cards;
  final bool faceDown;
  final bool hasPeeked;
  final String name;
  final int chips;

  const ZhaJinhuaOpponentArea({
    super.key,
    required this.cards,
    required this.faceDown,
    required this.hasPeeked,
    required this.name,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 对手信息
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.monetization_on,
                  size: 14, color: Colors.amber.shade400),
              const SizedBox(width: 2),
              Text(
                '$chips',
                style: TextStyle(
                  color: Colors.amber.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (hasPeeked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '已看牌',
                    style: TextStyle(
                        color: Colors.blue.shade200, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // 卡片
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: cards.map((card) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ZhaJinhuaCardWidget(
                  card: card,
                  faceDown: faceDown,
                  width: 60,
                  height: 84,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
