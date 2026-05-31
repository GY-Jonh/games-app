/// 单张扑克牌渲染组件。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/features/zha_jinhua/models/playing_card.dart';

class ZhaJinhuaCardWidget extends StatelessWidget {
  final PlayingCard? card;
  final bool faceDown;
  final double width;
  final double height;
  final bool isHighlighted;

  const ZhaJinhuaCardWidget({
    super.key,
    this.card,
    required this.faceDown,
    this.width = 64,
    this.height = 90,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    if (faceDown || card == null) {
      return _buildCardBack();
    }
    return _buildCardFace();
  }

  Widget _buildCardBack() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.blue.shade700
            : Colors.indigo.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? Colors.blue.shade300 : Colors.indigo.shade500,
          width: isHighlighted ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.person_3_outlined,
          color: Colors.indigo.shade300.withValues(alpha: 0.6),
          size: width * 0.4,
        ),
      ),
    );
  }

  Widget _buildCardFace() {
    if (card == null) return _buildCardBack();

    final color = (card!.suit == 1 || card!.suit == 3)
        ? Colors.red.shade400
        : Colors.black87;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? Colors.amber.shade400 : Colors.grey.shade300,
          width: isHighlighted ? 2.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左上角 rank 标记
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              card!.rankLabel,
              style: TextStyle(
                color: color,
                fontSize: width * 0.28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 中间花色
          Text(
            card!.suitSymbol,
            style: TextStyle(
              color: color,
              fontSize: width * 0.35,
            ),
          ),
          // 右下角 rank 标记 (倒置)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Transform.rotate(
              angle: 3.14159,
              child: Text(
                card!.rankLabel,
                style: TextStyle(
                  color: color,
                  fontSize: width * 0.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
