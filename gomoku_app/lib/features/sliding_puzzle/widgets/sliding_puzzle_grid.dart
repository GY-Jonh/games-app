import 'package:flutter/material.dart';
import 'package:gomoku_app/features/sliding_puzzle/constants/sliding_puzzle_constants.dart';

/// 数字华容道网格组件
class SlidingPuzzleGrid extends StatelessWidget {
  final List<int> tiles;
  final bool canTap;
  final void Function(int position) onTap;

  const SlidingPuzzleGrid({
    super.key,
    required this.tiles,
    required this.canTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = SlidingPuzzleConstants.gridSize;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(6),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: size,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: size * size,
            itemBuilder: (context, index) {
              final value = tiles.length > index ? tiles[index] : 0;
              return _PuzzleTile(
                value: value,
                canTap: canTap && value != 0,
                onTap: () => onTap(index),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  final int value;
  final bool canTap;
  final VoidCallback onTap;

  const _PuzzleTile({
    required this.value,
    required this.canTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (value == 0) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _tileColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: value <= 4 ? Colors.white : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Color get _tileColor {
    const colors = [
      Color(0xFF4CAF50), // 1
      Color(0xFF2196F3), // 2
      Color(0xFFF44336), // 3
      Color(0xFF9C27B0), // 4
      Color(0xFFFF9800), // 5
      Color(0xFF00BCD4), // 6
      Color(0xFFE91E63), // 7
      Color(0xFF3F51B5), // 8
      Color(0xFF8BC34A), // 9
      Color(0xFFFF5722), // 10
      Color(0xFF009688), // 11
      Color(0xFF673AB7), // 12
      Color(0xFFFFC107), // 13
      Color(0xFF795548), // 14
      Color(0xFF607D8B), // 15
    ];
    return colors[(value - 1) % colors.length];
  }
}
