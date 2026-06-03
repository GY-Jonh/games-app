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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.diamond,
                color: Colors.indigo.shade300.withValues(alpha: 0.5),
                size: width * 0.3,
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.diamond,
                color: Colors.indigo.shade300.withValues(alpha: 0.3),
                size: width * 0.18,
              ),
            ],
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
        : (isPlayable ? Colors.blue.shade300 : Colors.grey.shade400);
    final borderWidth = isSelected ? 2.5 : (isPlayable ? 1.5 : 0.8);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.amber.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: isSelected ? 8 : 3,
              offset: Offset(0, isSelected ? 0 : 2),
            ),
          ],
        ),
        child: card!.isJoker ? _buildJokerFace(color) : _buildSuitFace(color),
      ),
    );
  }

  Widget _buildJokerFace(Color color) {
    final label = card!.rankLabel; // "小" or "大"
    return Stack(
      children: [
        // 背景色块
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  card!.isBigJoker ? Colors.red.shade100 : Colors.grey.shade200,
                  card!.isBigJoker ? Colors.red.shade50 : Colors.grey.shade100,
                ],
              ),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        // 左上角标签
        Positioned(
          left: 4,
          top: 2,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: width * 0.16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 右下标
        Positioned(
          right: 4,
          bottom: 2,
          child: Transform.rotate(
            angle: 3.14159,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: width * 0.16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // 中心图标
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card!.isBigJoker ? '大王' : '小王',
                style: TextStyle(
                  color: color,
                  fontSize: width * 0.22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                card!.isBigJoker ? Icons.star : Icons.star_half,
                color: color,
                size: width * 0.28,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuitFace(Color color) {
    final rankStr = card!.rankLabel;
    final suitStr = card!.suitSymbol;
    final isFaceCard = ['J', 'Q', 'K', 'A', '2'].contains(rankStr);
    final cornerSize = width * 0.17;
    final centerSize = isFaceCard ? width * 0.26 : width * 0.35;

    return Stack(
      children: [
        // 左上角：点数 + 花色
        Positioned(
          left: 4,
          top: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rankStr,
                style: TextStyle(
                  color: color,
                  fontSize: cornerSize,
                  fontWeight: FontWeight.bold,
                  height: 0.9,
                ),
              ),
              Text(
                suitStr,
                style: TextStyle(
                  color: color,
                  fontSize: cornerSize * 0.7,
                  height: 0.8,
                ),
              ),
            ],
          ),
        ),
        // 右下角（旋转）
        Positioned(
          right: 4,
          bottom: 2,
          child: Transform.rotate(
            angle: 3.14159,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rankStr,
                  style: TextStyle(
                    color: color,
                    fontSize: cornerSize,
                    fontWeight: FontWeight.bold,
                    height: 0.9,
                  ),
                ),
                Text(
                  suitStr,
                  style: TextStyle(
                    color: color,
                    fontSize: cornerSize * 0.7,
                    height: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 中心：大花色符号（花牌显示牌面文字）
        Center(
          child: isFaceCard
              ? SizedBox(
                  width: width * 0.4,
                  height: width * 0.4,
                  child: Center(
                    child: Text(
                      rankStr,
                      style: TextStyle(
                        color: color,
                        fontSize: centerSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : Text(
                  suitStr,
                  style: TextStyle(
                    color: color,
                    fontSize: centerSize,
                  ),
                ),
        ),
      ],
    );
  }
}
