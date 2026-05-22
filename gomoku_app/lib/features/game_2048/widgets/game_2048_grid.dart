import 'package:flutter/material.dart';
import 'package:gomoku_app/features/game_2048/constants/game_2048_constants.dart';

/// 2048 网格组件
class Game2048Grid extends StatelessWidget {
  final List<int> grid;

  const Game2048Grid({
    super.key,
    required this.grid,
  });

  @override
  Widget build(BuildContext context) {
    final size = Game2048Constants.gridSize;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.brown.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: size,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: size * size,
            itemBuilder: (context, index) {
              final value = grid.length > index ? grid[index] : 0;
              return _Tile(value: value);
            },
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final int value;

  const _Tile({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _tileColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: value == 0
            ? null
            : Text(
                '$value',
                style: TextStyle(
                  fontSize: value >= 1024 ? 18 : value >= 128 ? 22 : 26,
                  fontWeight: FontWeight.bold,
                  color: value <= 4 ? Colors.grey.shade700 : Colors.white,
                ),
              ),
      ),
    );
  }

  Color get _tileColor {
    if (value == 0) return Colors.brown.shade100;
    const colors = {
      2: 0xFFEEE4DA,
      4: 0xFFEDE0C8,
      8: 0xFFF2B179,
      16: 0xFFF59563,
      32: 0xFFF67C5F,
      64: 0xFFF65E3B,
      128: 0xFFEDCF72,
      256: 0xFFEDCC61,
      512: 0xFFEDC850,
      1024: 0xFFEDC53F,
      2048: 0xFFEDC22E,
      4096: 0xFFFF6347,
      8192: 0xFFFF4500,
      16384: 0xFFFF0000,
      32768: 0xFF8B0000,
      65536: 0xFF4B0082,
    };
    return Color(colors[value] ?? 0xFF3C3A32);
  }
}
