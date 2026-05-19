import 'package:gomoku_app/features/gomoku/models/gomoku_move.dart';
import 'package:gomoku_app/features/gomoku/models/stone.dart';
import 'package:gomoku_app/features/gomoku/constants/gomoku_constants.dart';

class GomokuResult {
  final Stone? winner;
  final bool isDraw;

  const GomokuResult({this.winner, this.isDraw = false});

  bool get isGameOver => winner != null || isDraw;
}

class GomokuEngine {
  final List<List<Stone>> _board;
  Stone _currentTurn;
  int _moveCount;
  final List<GomokuMove> _moveHistory;
  Stone? _winner;
  bool _gameOver;

  GomokuEngine()
      : _board = List.generate(
          gomokuBoardSize,
          (_) => List.filled(gomokuBoardSize, Stone.empty),
        ),
        _currentTurn = Stone.black,
        _moveCount = 0,
        _moveHistory = [],
        _winner = null,
        _gameOver = false;

  GomokuEngine.fromSerialized(
    List<List<int>> boardData,
    this._currentTurn,
    this._moveCount,
    this._winner,
    this._gameOver,
  )   : _board = boardData
            .map((row) => row.map((s) => Stone.values[s]).toList())
            .toList(),
        _moveHistory = [];

  Stone get currentTurn => _currentTurn;
  int get moveCount => _moveCount;
  bool get isGameOver => _gameOver;
  Stone? get winner => _winner;
  List<GomokuMove> get moveHistory => List.unmodifiable(_moveHistory);

  Stone getStoneAt(int row, int col) => _board[row][col];

  bool isValidMove(int row, int col, Stone stone) {
    if (row < 0 || row >= gomokuBoardSize || col < 0 || col >= gomokuBoardSize) {
      return false;
    }
    if (_board[row][col] != Stone.empty) return false;
    if (stone != _currentTurn) return false;
    if (_gameOver) return false;
    return true;
  }

  /// Place a stone and return the result. Returns null if move is invalid.
  GomokuResult? placeStone(int row, int col, Stone stone) {
    if (!isValidMove(row, col, stone)) return null;

    _board[row][col] = stone;
    _moveCount++;
    _moveHistory.add(GomokuMove(
      row: row,
      col: col,
      stone: stone,
      moveNumber: _moveCount,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    // Check win
    final winner = _checkWin(row, col, stone);
    if (winner != null) {
      _winner = winner;
      _gameOver = true;
      return GomokuResult(winner: winner);
    }

    // Check draw
    if (_moveCount >= gomokuBoardSize * gomokuBoardSize) {
      _gameOver = true;
      return const GomokuResult(isDraw: true);
    }

    // Switch turn
    _currentTurn = (stone == Stone.black) ? Stone.white : Stone.black;
    return null;
  }

  Stone? _checkWin(int row, int col, Stone stone) {
    const directions = [
      (0, 1), // horizontal
      (1, 0), // vertical
      (1, 1), // diagonal ↘
      (1, -1), // anti-diagonal ↙
    ];

    for (final (dr, dc) in directions) {
      int count = 1;

      // Count in positive direction
      for (int step = 1; step < gomokuWinStreak; step++) {
        final r = row + dr * step;
        final c = col + dc * step;
        if (r < 0 || r >= gomokuBoardSize || c < 0 || c >= gomokuBoardSize) break;
        if (_board[r][c] != stone) break;
        count++;
      }

      // Count in negative direction
      for (int step = 1; step < gomokuWinStreak; step++) {
        final r = row - dr * step;
        final c = col - dc * step;
        if (r < 0 || r >= gomokuBoardSize || c < 0 || c >= gomokuBoardSize) break;
        if (_board[r][c] != stone) break;
        count++;
      }

      if (count >= gomokuWinStreak) return stone;
    }

    return null;
  }

  List<List<int>> serializeBoard() => _board
      .map((row) => row.map((s) => s.index).toList())
      .toList();

  Map<String, dynamic> toJson() => {
        'board': serializeBoard(),
        'currentTurn': _currentTurn.index,
        'moveCount': _moveCount,
        'winner': _winner?.index,
        'gameOver': _gameOver,
      };

  factory GomokuEngine.fromJson(Map<String, dynamic> json) {
    final boardData = (json['board'] as List)
        .map((row) => (row as List).map((s) => s as int).toList())
        .toList();
    return GomokuEngine.fromSerialized(
      boardData,
      Stone.values[json['currentTurn'] as int],
      json['moveCount'] as int,
      json['winner'] != null ? Stone.values[json['winner'] as int] : null,
      json['gameOver'] as bool,
    );
  }

  void reset() {
    for (var row = 0; row < gomokuBoardSize; row++) {
      for (var col = 0; col < gomokuBoardSize; col++) {
        _board[row][col] = Stone.empty;
      }
    }
    _currentTurn = Stone.black;
    _moveCount = 0;
    _moveHistory.clear();
    _winner = null;
    _gameOver = false;
  }

  GomokuMove? undoLastMove() {
    if (_moveHistory.isEmpty) return null;
    final lastMove = _moveHistory.removeLast();
    _board[lastMove.row][lastMove.col] = Stone.empty;
    _moveCount--;
    _currentTurn = lastMove.stone;
    _winner = null;
    _gameOver = false;
    return lastMove;
  }
}
