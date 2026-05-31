/// 扑克收集战 — 单张牌渲染组件。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/features/card_battle/models/card_battle_card.dart';

class CardBattleCardWidget extends StatelessWidget {
  final GameCard? card;
  final bool faceDown;
  final double width;
  final double height;
  final bool isSelected;
  final bool isPlayable;
  final VoidCallback? onTap;

  const CardBattleCardWidget({
    super.key,
    this.card,
    required this.faceDown,
    this.width = 60,
    this.height = 85,
    this.isSelected = false,
    this.isPlayable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (faceDown || card == null) {
      return _buildCardBack();
    }
    return _buildCardFace();
  }

  Widget _buildCardBack() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade700,
              Colors.indigo.shade900,
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.indigo.shade400,
            width: 1.5,
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
            Icons.question_mark,
            color: Colors.indigo.shade300.withValues(alpha: 0.6),
            size: width * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace() {
    if (card == null) return _buildCardBack();

    final isRed = card!.isJoker ||
        card!.suit == 1 ||
        card!.suit == 3;
    final color = isRed ? Colors.red.shade400 : Colors.black87;
    final bgColor = isSelected ? Colors.amber.shade50 : Colors.white;
    final borderColor = isSelected
        ? Colors.amber.shade400
        : (isPlayable ? Colors.blue.shade300 : Colors.grey.shade300);
    final borderWidth = isSelected ? 2.5 : (isPlayable ? 1.5 : 0.8);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: isSelected ? 8 : 3,
              offset: Offset(0, isSelected ? 0 : 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 点数/王标签
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                card!.rankLabel,
                style: TextStyle(
                  color: color,
                  fontSize: width * 0.26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 花色/王标注
            if (card!.isJoker)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Icon(
                  card!.isBigJoker ? Icons.star : Icons.star_half,
                  color: color,
                  size: width * 0.3,
                ),
              )
            else
              Text(
                card!.suitSymbol,
                style: TextStyle(
                  color: color,
                  fontSize: width * 0.32,
                ),
              ),
            // 下方向旋转标签
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Transform.rotate(
                angle: 3.14159,
                child: Text(
                  card!.rankLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: width * 0.18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
