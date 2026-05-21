import 'package:flutter/material.dart';
import 'package:gomoku_app/features/lights_out/constants/lights_out_constants.dart';

/// 点灯游戏 5×5 网格组件
class LightsOutGrid extends StatelessWidget {
  final int gridBits;
  final bool canTap;
  final void Function(int row, int col) onTap;

  const LightsOutGrid({
    super.key,
    required this.gridBits,
    required this.canTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = LightsOutConstants.gridSize;
    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: size,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: size * size,
          itemBuilder: (context, index) {
            final row = index ~/ size;
            final col = index % size;
            final isLit = (gridBits & (1 << index)) != 0;
            return _LightCell(
              isLit: isLit,
              canTap: canTap,
              onTap: () => onTap(row, col),
            );
          },
        ),
      ),
    );
  }
}

class _LightCell extends StatelessWidget {
  final bool isLit;
  final bool canTap;
  final VoidCallback onTap;

  const _LightCell({
    required this.isLit,
    required this.canTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canTap ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isLit ? Colors.amber.shade400 : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isLit
              ? [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
        ),
        child: Center(
          child: Icon(
            isLit ? Icons.lightbulb : Icons.lightbulb_outline,
            color: isLit ? Colors.yellow.shade50 : Colors.grey.shade600,
            size: 32,
          ),
        ),
      ),
    );
  }
}
