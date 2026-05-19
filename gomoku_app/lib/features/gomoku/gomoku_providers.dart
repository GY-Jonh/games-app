import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/constants/game_constants.dart';
import 'package:gomoku_app/features/gomoku/models/stone.dart';
import 'package:gomoku_app/features/gomoku/constants/gomoku_constants.dart';
import 'package:gomoku_app/features/gomoku/models/gomoku_move.dart';
import 'package:gomoku_app/features/gomoku/gomoku_engine.dart';

class GomokuState {
  final List<List<Stone>> board;
  final Stone currentTurn;
  final Stone? myStone;
  final Stone? winner;
  final GameStatus status;
  final List<GomokuMove> moveHistory;
  final String opponentName;
  final int moveCount;
  final bool isMyTurn;
  final int? selectedRow;
  final int? selectedCol;
  final int? lastMoveRow;
  final int? lastMoveCol;

  const GomokuState({
    required this.board,
    required this.currentTurn,
    this.myStone,
    this.winner,
    required this.status,
    this.moveHistory = const [],
    this.opponentName = '',
    this.moveCount = 0,
    this.isMyTurn = false,
    this.selectedRow,
    this.selectedCol,
    this.lastMoveRow,
    this.lastMoveCol,
  });

  factory GomokuState.initial() {
    return GomokuState(
      board: List.generate(
        gomokuBoardSize,
        (_) => List.filled(gomokuBoardSize, Stone.empty),
      ),
      currentTurn: Stone.black,
      status: GameStatus.waiting,
    );
  }
}

class GomokuStateNotifier extends StateNotifier<GomokuState> {
  late GomokuEngine _engine;
  bool _isProcessingMove = false;

  GomokuStateNotifier() : super(GomokuState.initial()) {
    _engine = GomokuEngine();
  }

  GomokuEngine get engine => _engine;

  void startGame(Stone myStone, String opponentName) {
    _isProcessingMove = false;
    _engine = GomokuEngine();
    state = GomokuState(
      board: _serializeBoard(),
      currentTurn: _engine.currentTurn,
      myStone: myStone,
      status: GameStatus.playing,
      opponentName: opponentName,
      isMyTurn: myStone == _engine.currentTurn,
      selectedRow: null,
      selectedCol: null,
    );
  }

  bool placeStone(int row, int col) {
    if (_isProcessingMove) return false;
    if (!_engine.isValidMove(row, col, state.myStone!)) return false;
    _isProcessingMove = true;
    final result = _engine.placeStone(row, col, state.myStone!);
    _updateStateAfterMove(result);
    _isProcessingMove = false;
    return true;
  }

  void receiveMove(int row, int col, Stone stone) {
    if (_isProcessingMove) return;
    if (state.status != GameStatus.playing) return;
    if (!_engine.isValidMove(row, col, stone)) return;
    _isProcessingMove = true;
    final result = _engine.placeStone(row, col, stone);
    _updateStateAfterMove(result);
    _isProcessingMove = false;
  }

  void _updateStateAfterMove(GomokuResult? result) {
    GameStatus newStatus;
    Stone? winner;
    if (result != null && result.isGameOver) {
      if (result.isDraw) {
        newStatus = GameStatus.draw;
      } else if (result.winner == state.myStone) {
        newStatus = GameStatus.won;
      } else {
        newStatus = GameStatus.lost;
      }
      winner = result.winner;
    } else {
      newStatus = GameStatus.playing;
    }

    final lastMove = _engine.moveHistory.isNotEmpty
        ? _engine.moveHistory.last
        : null;

    state = GomokuState(
      board: _serializeBoard(),
      currentTurn: _engine.currentTurn,
      myStone: state.myStone,
      winner: winner,
      status: newStatus,
      moveHistory: _engine.moveHistory,
      opponentName: state.opponentName,
      moveCount: _engine.moveCount,
      isMyTurn: state.myStone == _engine.currentTurn,
      selectedRow: null,
      selectedCol: null,
      lastMoveRow: lastMove?.row,
      lastMoveCol: lastMove?.col,
    );
  }

  void selectPosition(int row, int col) {
    if (_isProcessingMove) return;
    if (state.status != GameStatus.playing) return;
    if (state.selectedRow == row && state.selectedCol == col) return;
    state = GomokuState(
      board: state.board,
      currentTurn: state.currentTurn,
      myStone: state.myStone,
      winner: state.winner,
      status: state.status,
      moveHistory: state.moveHistory,
      opponentName: state.opponentName,
      moveCount: state.moveCount,
      isMyTurn: state.isMyTurn,
      selectedRow: row,
      selectedCol: col,
      lastMoveRow: state.lastMoveRow,
      lastMoveCol: state.lastMoveCol,
    );
  }

  void clearSelectedPosition() {
    if (state.selectedRow == null && state.selectedCol == null) return;
    state = GomokuState(
      board: state.board,
      currentTurn: state.currentTurn,
      myStone: state.myStone,
      winner: state.winner,
      status: state.status,
      moveHistory: state.moveHistory,
      opponentName: state.opponentName,
      moveCount: state.moveCount,
      isMyTurn: state.isMyTurn,
      selectedRow: null,
      selectedCol: null,
      lastMoveRow: state.lastMoveRow,
      lastMoveCol: state.lastMoveCol,
    );
  }

  void resetGame() {
    _isProcessingMove = false;
    _engine = GomokuEngine();
    state = GomokuState.initial();
  }

  void endGame() {
    state = GomokuState(
      board: _serializeBoard(),
      currentTurn: _engine.currentTurn,
      myStone: state.myStone,
      status: GameStatus.disconnected,
      opponentName: state.opponentName,
      moveCount: _engine.moveCount,
      selectedRow: null,
      selectedCol: null,
      lastMoveRow: null,
      lastMoveCol: null,
    );
  }

  /// 己方超时判负
  void timeout() {
    if (state.status != GameStatus.playing) return;
    state = GomokuState(
      board: _serializeBoard(),
      currentTurn: _engine.currentTurn,
      myStone: state.myStone,
      winner: state.myStone == Stone.black ? Stone.white : Stone.black,
      status: GameStatus.lost,
      moveHistory: _engine.moveHistory,
      opponentName: state.opponentName,
      moveCount: _engine.moveCount,
      isMyTurn: false,
      selectedRow: null,
      selectedCol: null,
      lastMoveRow: null,
      lastMoveCol: null,
    );
  }

  /// 对方超时己方获胜
  void opponentTimeout() {
    if (state.status != GameStatus.playing) return;
    state = GomokuState(
      board: _serializeBoard(),
      currentTurn: _engine.currentTurn,
      myStone: state.myStone,
      winner: state.myStone,
      status: GameStatus.won,
      moveHistory: _engine.moveHistory,
      opponentName: state.opponentName,
      moveCount: _engine.moveCount,
      isMyTurn: false,
      selectedRow: null,
      selectedCol: null,
      lastMoveRow: state.lastMoveRow,
      lastMoveCol: state.lastMoveCol,
    );
  }

  bool isValidMove(int row, int col) {
    return _engine.isValidMove(row, col, state.myStone ?? Stone.black);
  }

  List<List<Stone>> _serializeBoard() {
    return List.generate(
      gomokuBoardSize,
      (r) => List.generate(
        gomokuBoardSize,
        (c) => _engine.getStoneAt(r, c),
      ),
    );
  }
}

final gomokuStateProvider =
    StateNotifierProvider<GomokuStateNotifier, GomokuState>((ref) {
  return GomokuStateNotifier();
});

// ========== 五子棋重开协议状态 ==========

enum GomokuRematchStatus { none, waiting, received }

class GomokuRematchRequestDetails {
  final String fromName;
  final Stone previousStone;

  const GomokuRematchRequestDetails({
    required this.fromName,
    required this.previousStone,
  });
}

final gomokuRematchStatusProvider =
    StateProvider<GomokuRematchStatus>((ref) => GomokuRematchStatus.none);

final gomokuRematchRequestDetailsProvider =
    StateProvider<GomokuRematchRequestDetails?>((ref) => null);

/// 用于传递重开相关的 toast 消息给五子棋页面显示
final gomokuRematchToastProvider = StateProvider<String?>((ref) => null);

/// 对方断线后通知五子棋页面自动退出
final gomokuAutoExitGameProvider = StateProvider<bool>((ref) => false);
