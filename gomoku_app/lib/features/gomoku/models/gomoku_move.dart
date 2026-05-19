import 'package:gomoku_app/features/gomoku/models/stone.dart';

class GomokuMove {
  final int row;
  final int col;
  final Stone stone;
  final int moveNumber;
  final int timestamp;

  const GomokuMove({
    required this.row,
    required this.col,
    required this.stone,
    required this.moveNumber,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'stone': stone.index,
        'moveNumber': moveNumber,
        'timestamp': timestamp,
      };

  factory GomokuMove.fromJson(Map<String, dynamic> json) => GomokuMove(
        row: json['row'] as int,
        col: json['col'] as int,
        stone: Stone.values[json['stone'] as int],
        moveNumber: json['moveNumber'] as int,
        timestamp: json['timestamp'] as int,
      );
}
