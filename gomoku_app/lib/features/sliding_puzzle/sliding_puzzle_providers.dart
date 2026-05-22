import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/sliding_puzzle/constants/sliding_puzzle_constants.dart';

// ========== Status Enum ==========

enum SlidingPuzzleStatus {
  loading,
  playing,
  won,
  lost,
  draw,
  disconnected,
}

// ========== Game State ==========

class SlidingPuzzleState {
  final SlidingPuzzleStatus status;
  final List<int> tiles; // 16 values, 1-15 are tiles, 0 is empty
  final int seed;
  final bool isSolo;
  final String selfName;
  final String opponentName;
  final int currentRound;
  final int moveCount;

  const SlidingPuzzleState({
    required this.status,
    this.tiles = const [],
    this.seed = 0,
    this.isSolo = true,
    this.selfName = '',
    this.opponentName = '',
    this.currentRound = 1,
    this.moveCount = 0,
  });

  int tileAt(int row, int col) {
    if (row < 0 || row >= SlidingPuzzleConstants.gridSize) return -1;
    if (col < 0 || col >= SlidingPuzzleConstants.gridSize) return -1;
    return tiles[row * SlidingPuzzleConstants.gridSize + col];
  }

  /// 获取空格（0）的位置
  int get emptyIndex => tiles.indexOf(0);

  factory SlidingPuzzleState.initial() {
    return const SlidingPuzzleState(status: SlidingPuzzleStatus.loading);
  }
}

// ========== State Notifier ==========

class SlidingPuzzleStateNotifier extends StateNotifier<SlidingPuzzleState> {
  SlidingPuzzleStateNotifier() : super(SlidingPuzzleState.initial());

  // ========== Puzzle Generation ==========

  /// 根据 seed 生成可解的打乱棋盘
  static List<int> generateTiles(int seed) {
    final random = Random(seed);
    // 从目标状态开始随机移动，保证可解
    final tiles = List<int>.generate(
        SlidingPuzzleConstants.totalCells, (i) => i);
    // tiles: [0, 1, 2, ..., 15], where 0 is empty at position 0

    int emptyPos = 0;
    int lastMove = -1;

    for (int i = 0; i < SlidingPuzzleConstants.shuffleMoves; i++) {
      final neighbors = _getNeighbors(emptyPos);
      // 避免来回移动同一个方块
      final validNeighbors =
          neighbors.where((n) => n != lastMove).toList();
      final pick =
          validNeighbors[random.nextInt(validNeighbors.length)];

      // 交换
      tiles[emptyPos] = tiles[pick];
      tiles[pick] = 0;
      lastMove = emptyPos;
      emptyPos = pick;
    }

    // 极低概率可能生成已解决状态，多做一步随机移动
    if (_isSolved(tiles)) {
      final neighbors = _getNeighbors(emptyPos);
      final pick = neighbors[random.nextInt(neighbors.length)];
      tiles[emptyPos] = tiles[pick];
      tiles[pick] = 0;
    }

    return tiles;
  }

  static List<int> _getNeighbors(int pos) {
    final size = SlidingPuzzleConstants.gridSize;
    final row = pos ~/ size;
    final col = pos % size;
    final result = <int>[];
    if (row > 0) result.add(pos - size); // up
    if (row < size - 1) result.add(pos + size); // down
    if (col > 0) result.add(pos - 1); // left
    if (col < size - 1) result.add(pos + 1); // right
    return result;
  }

  /// 判断是否已解决: tiles = [1, 2, 3, ..., 15, 0]
  static bool _isSolved(List<int> tiles) {
    for (int i = 0; i < SlidingPuzzleConstants.totalCells - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles[SlidingPuzzleConstants.totalCells - 1] == 0;
  }

  // ========== Public API ==========

  void startGame({
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    final tiles = generateTiles(seed);
    state = SlidingPuzzleState(
      status: SlidingPuzzleStatus.playing,
      tiles: tiles,
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
    );
  }

  void startGameWithTiles({
    required List<int> tiles,
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    state = SlidingPuzzleState(
      status: SlidingPuzzleStatus.playing,
      tiles: List.of(tiles),
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
    );
  }

  /// 尝试移动指定位置的方块，返回 true 表示移动成功
  bool moveTile(int position) {
    if (state.status != SlidingPuzzleStatus.playing) return false;
    if (position < 0 || position >= SlidingPuzzleConstants.totalCells) {
      return false;
    }

    final emptyPos = state.tiles.indexOf(0);
    final neighbors = _getNeighbors(emptyPos);

    if (!neighbors.contains(position)) return false;

    final newTiles = List<int>.of(state.tiles);
    newTiles[emptyPos] = newTiles[position];
    newTiles[position] = 0;

    final won = _isSolved(newTiles);

    state = SlidingPuzzleState(
      status: won ? SlidingPuzzleStatus.won : SlidingPuzzleStatus.playing,
      tiles: newTiles,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount + 1,
    );

    return true;
  }

  void opponentWon() {
    if (state.status != SlidingPuzzleStatus.playing) return;
    if (state.isSolo) return;
    state = SlidingPuzzleState(
      status: SlidingPuzzleStatus.lost,
      tiles: state.tiles,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  void timeout() {
    if (state.status != SlidingPuzzleStatus.playing) return;
    state = SlidingPuzzleState(
      status: SlidingPuzzleStatus.lost,
      tiles: state.tiles,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  void opponentTimeout() {
    if (state.status != SlidingPuzzleStatus.playing) return;
    state = SlidingPuzzleState(
      status: SlidingPuzzleStatus.won,
      tiles: state.tiles,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  void handleConnectionLost() {
    state = SlidingPuzzleState(
      status: SlidingPuzzleStatus.disconnected,
      tiles: state.tiles,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  void resetGame() {
    state = SlidingPuzzleState.initial();
  }

  void incrementRound() {
    state = SlidingPuzzleState(
      status: SlidingPuzzleStatus.loading,
      currentRound: state.currentRound + 1,
    );
  }

  void setLoading() {
    state = SlidingPuzzleState(
      status: SlidingPuzzleStatus.loading,
      currentRound: state.currentRound,
    );
  }

  static int generateSeed() {
    return DateTime.now().millisecondsSinceEpoch ^ (Random().nextInt(1 << 16));
  }
}

// ========== Providers ==========

final slidingPuzzleStateProvider =
    StateNotifierProvider<SlidingPuzzleStateNotifier, SlidingPuzzleState>(
        (ref) {
  return SlidingPuzzleStateNotifier();
});

enum SlidingPuzzleRematchStatus { none, waiting, received }

final slidingPuzzleRematchStatusProvider =
    StateProvider<SlidingPuzzleRematchStatus>(
        (ref) => SlidingPuzzleRematchStatus.none);

final slidingPuzzleAutoExitProvider = StateProvider<bool>((ref) => false);

final slidingPuzzleToastProvider = StateProvider<String?>((ref) => null);
