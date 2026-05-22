import 'package:flutter/material.dart';

/// 记忆翻牌单张卡片组件
class MemoryMatchCard extends StatelessWidget {
  final String symbol;
  final bool isFaceUp;
  final bool isMatched;
  final bool canTap;
  final VoidCallback onTap;

  const MemoryMatchCard({
    super.key,
    required this.symbol,
    required this.isFaceUp,
    required this.isMatched,
    required this.canTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (canTap && !isMatched) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _borderColor,
            width: isMatched ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isFaceUp ? 0.1 : 0.25),
              blurRadius: isFaceUp ? 4 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isFaceUp
              ? Text(
                  symbol,
                  style: TextStyle(
                    fontSize: isMatched ? 28 : 32,
                    color: isMatched ? Colors.grey : Colors.black87,
                  ),
                )
              : const Icon(
                  Icons.help_outline,
                  color: Colors.white70,
                  size: 28,
                ),
        ),
      ),
    );
  }

  Color get _backgroundColor {
    if (isMatched) return Colors.green.shade100;
    if (isFaceUp) return Colors.white;
    return Colors.indigo.shade400;
  }

  Color get _borderColor {
    if (isMatched) return Colors.green.shade300;
    if (isFaceUp) return Colors.grey.shade300;
    return Colors.indigo.shade600;
  }
}
