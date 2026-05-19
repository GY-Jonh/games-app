import 'package:flutter/material.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';
import 'package:gomoku_app/features/gomoku/models/stone.dart';
import 'package:gomoku_app/features/gomoku/constants/gomoku_constants.dart';

class GomokuBoardWidget extends StatelessWidget {
  final List<List<Stone>> board;
  final bool isMyTurn;
  final void Function(int row, int col)? onTap;
  final int? selectedRow;
  final int? selectedCol;
  final Stone? myStone;
  final int? lastMoveRow;
  final int? lastMoveCol;

  const GomokuBoardWidget({
    super.key,
    required this.board,
    this.isMyTurn = false,
    this.onTap,
    this.selectedRow,
    this.selectedCol,
    this.myStone,
    this.lastMoveRow,
    this.lastMoveCol,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onTapUp: (details) {
          if (!isMyTurn || onTap == null) return;
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox == null || !renderBox.hasSize) return;
          final boardSizePx = renderBox.size.shortestSide;
          final cellSize = boardSizePx / (gomokuBoardSize + 1);
          final offset = details.localPosition;
          final col = ((offset.dx - cellSize) / cellSize).round();
          final row = ((offset.dy - cellSize) / cellSize).round();
          if (row >= 0 && row < gomokuBoardSize && col >= 0 && col < gomokuBoardSize) {
            onTap!(row, col);
          }
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: _GomokuBoardPainter(
            board,
            selectedRow: selectedRow,
            selectedCol: selectedCol,
            myStone: myStone,
            lastMoveRow: lastMoveRow,
            lastMoveCol: lastMoveCol,
          ),
        ),
      ),
    );
  }
}

class _GomokuBoardPainter extends CustomPainter {
  final List<List<Stone>> board;
  final int? selectedRow;
  final int? selectedCol;
  final Stone? myStone;
  final int? lastMoveRow;
  final int? lastMoveCol;

  _GomokuBoardPainter(this.board, {this.selectedRow, this.selectedCol, this.myStone, this.lastMoveRow, this.lastMoveCol});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / (gomokuBoardSize + 1);
    final offset = cellSize;
    final boardPixelSize = cellSize * (gomokuBoardSize - 1);
    final stoneRadius = cellSize * 0.42;

    // Draw background
    final bgPaint = Paint()..color = AppTheme.boardBackground;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw grid lines
    final linePaint = Paint()
      ..color = AppTheme.boardLine
      ..strokeWidth = 1.0;

    for (int i = 0; i < gomokuBoardSize; i++) {
      final x = offset + i * cellSize;
      final y = offset + i * cellSize;
      // Horizontal line
      canvas.drawLine(
        Offset(offset, y),
        Offset(offset + boardPixelSize, y),
        linePaint,
      );
      // Vertical line
      canvas.drawLine(
        Offset(x, offset),
        Offset(x, offset + boardPixelSize),
        linePaint,
      );
    }

    // Draw star points (hoshi)
    final starPoints = [
      (3, 3), (3, 8), (3, 13),
      (8, 3), (8, 8), (8, 13),
      (13, 3), (13, 8), (13, 13),
    ];
    final starPaint = Paint()..color = AppTheme.boardLine;
    for (final (r, c) in starPoints) {
      canvas.drawCircle(
        Offset(offset + c * cellSize, offset + r * cellSize),
        3.0,
        starPaint,
      );
    }

    // Draw stones
    for (int row = 0; row < gomokuBoardSize; row++) {
      for (int col = 0; col < gomokuBoardSize; col++) {
        if (board[row][col] == Stone.empty) continue;

        final center = Offset(
          offset + col * cellSize,
          offset + row * cellSize,
        );

        if (board[row][col] == Stone.black) {
          final paint = Paint()
            ..color = AppTheme.blackStone
            ..style = PaintingStyle.fill;
          canvas.drawCircle(center, stoneRadius, paint);

          // Highlight
          final highlight = Paint()
            ..color = Colors.white.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(center.dx - stoneRadius * 0.2, center.dy - stoneRadius * 0.2),
            stoneRadius * 0.35,
            highlight,
          );
        } else {
          final paint = Paint()
            ..color = AppTheme.whiteStone
            ..style = PaintingStyle.fill;
          canvas.drawCircle(center, stoneRadius, paint);

          final borderPaint = Paint()
            ..color = Colors.grey.shade400
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawCircle(center, stoneRadius, borderPaint);

          // Highlight for white stones
          final highlight = Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(center.dx - stoneRadius * 0.2, center.dy - stoneRadius * 0.2),
            stoneRadius * 0.35,
            highlight,
          );
        }
      }
    }

    // Draw last move highlight marker
    if (lastMoveRow != null &&
        lastMoveCol != null &&
        lastMoveRow! >= 0 &&
        lastMoveRow! < gomokuBoardSize &&
        lastMoveCol! >= 0 &&
        lastMoveCol! < gomokuBoardSize &&
        board[lastMoveRow!][lastMoveCol!] != Stone.empty) {
      final center = Offset(
        offset + lastMoveCol! * cellSize,
        offset + lastMoveRow! * cellSize,
      );
      final markerPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, stoneRadius * 0.28, markerPaint);
    }

    // Draw preview stone at selected position
    if (selectedRow != null &&
        selectedCol != null &&
        myStone != null &&
        selectedRow! >= 0 &&
        selectedRow! < gomokuBoardSize &&
        selectedCol! >= 0 &&
        selectedCol! < gomokuBoardSize &&
        board[selectedRow!][selectedCol!] == Stone.empty) {
      final center = Offset(
        offset + selectedCol! * cellSize,
        offset + selectedRow! * cellSize,
      );
      if (myStone == Stone.black) {
        final paint = Paint()
          ..color = AppTheme.blackStone.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, stoneRadius, paint);
      } else {
        final paint = Paint()
          ..color = AppTheme.whiteStone.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, stoneRadius, paint);
        final borderPaint = Paint()
          ..color = Colors.grey.shade400.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(center, stoneRadius, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GomokuBoardPainter oldDelegate) => true;
}
