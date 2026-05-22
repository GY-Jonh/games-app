import 'package:flutter/material.dart';
import 'package:gomoku_app/features/minesweeper/constants/minesweeper_constants.dart';

class MinesweeperGrid extends StatelessWidget {
  final List<int> mines;
  final Set<int> revealed;
  final Set<int> flagged;
  final bool canTap;
  final void Function(int position) onTap;
  final void Function(int position) onLongPress;

  const MinesweeperGrid({
    super.key,
    required this.mines,
    required this.revealed,
    required this.flagged,
    required this.canTap,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MinesweeperConstants.cols,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: MinesweeperConstants.totalCells,
          itemBuilder: (context, index) {
            return _MineCell(
              mineValue: mines.length > index ? mines[index] : 0,
              isRevealed: revealed.contains(index),
              isFlagged: flagged.contains(index),
              canTap: canTap,
              onTap: () => onTap(index),
              onLongPress: () => onLongPress(index),
            );
          },
        ),
      ),
    );
  }
}

class _MineCell extends StatelessWidget {
  final int mineValue;
  final bool isRevealed;
  final bool isFlagged;
  final bool canTap;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MineCell({
    required this.mineValue,
    required this.isRevealed,
    required this.isFlagged,
    required this.canTap,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canTap ? onTap : null,
      onLongPress: canTap ? onLongPress : null,
      child: Container(
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isRevealed ? Colors.grey.shade300 : Colors.grey.shade500,
            width: 0.5,
          ),
        ),
        child: Center(
          child: isRevealed
              ? _buildRevealedContent()
              : isFlagged
                  ? const Icon(Icons.flag, color: Colors.red, size: 16)
                  : null,
        ),
      ),
    );
  }

  Widget _buildRevealedContent() {
    if (mineValue == -1) {
      return const Icon(Icons.circle, color: Colors.black87, size: 18);
    }
    if (mineValue == 0) return const SizedBox.shrink();
    return Text(
      '$mineValue',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: _numberColor,
      ),
    );
  }

  Color get _backgroundColor {
    if (!isRevealed) return Colors.grey.shade300;
    if (mineValue == -1) return Colors.red.shade200;
    return Colors.grey.shade100;
  }

  Color get _numberColor {
    const colors = [
      Colors.blue, // 1
      Colors.green, // 2
      Colors.red, // 3
      Colors.purple, // 4
      Colors.brown, // 5
      Colors.cyan, // 6
      Colors.black, // 7
      Colors.grey, // 8
    ];
    return colors[(mineValue - 1) % colors.length];
  }
}
