/// 玩家区域组件。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/features/zha_jinhua/models/playing_card.dart';
import 'package:gomoku_app/features/zha_jinhua/widgets/zhajinhua_card_widget.dart';

class ZhaJinhuaPlayerArea extends StatelessWidget {
  final List<PlayingCard> cards;
  final bool faceDown;
  final bool hasPeeked;
  final String name;
  final int chips;
  final VoidCallback onPeek;

  const ZhaJinhuaPlayerArea({
    super.key,
    required this.cards,
    required this.faceDown,
    required this.hasPeeked,
    required this.name,
    required this.chips,
    required this.onPeek,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        border: Border(
          top: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 卡片
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: cards.map((card) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ZhaJinhuaCardWidget(
                  card: card,
                  faceDown: faceDown && !hasPeeked,
                  width: 64,
                  height: 90,
                  isHighlighted: hasPeeked && !faceDown,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // 信息行
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
              const SizedBox(width: 12),
              // 看牌按钮
              GestureDetector(
                onTap: onPeek,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasPeeked
                        ? Colors.blue.shade700
                        : Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasPeeked ? Icons.visibility : Icons.visibility_off,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        hasPeeked ? '盖牌' : '看牌',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
