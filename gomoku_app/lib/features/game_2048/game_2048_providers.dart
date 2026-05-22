import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/game_2048/constants/game_2048_constants.dart';

// ========== Status Enum ==========

enum Game2048Status {
  loading,
  playing,
  won,
  lost,
  draw,
  disconnected,
}

// ========== Direction ==========

enum MoveDirection { up, down, left, right }

// ========== Game State ==========

class Game2048State {
  final Game2048Status status;
  final List<int> grid; // 16 values, 0 = empty, otherwise power of 2
  final int score;
  final int seed;
  final bool isSolo;
  final String selfName;
  final String opponentName;
  final int currentRound;
  final int moveCount;

  const Game2048State({
    required this.status,
    this.grid = const [],
    this.score = 0,
    this.seed = 0,
    this.isSolo = true,
    this.selfName = '',
    this.opponentName = '',
    this.currentRound = 1,
    this.moveCount = 0,
  });

  int cellAt(int row, int col) {
    if (row < 0 || row >= Game2048Constants.gridSize) return 0;
    if (col < 0 || col >= Game2048Constants.gridSize) return 0;
    return grid[row * Game2048Constants.gridSize + col];
  }

  factory Game2048State.initial() {
    return const Game2048State(status: Game2048Status.loading);
  }
}

// ========== State Notifier ==========

class Game2048StateNotifier extends StateNotifier<Game2048State> {
  Game2048StateNotifier() : super(Game2048State.initial());

  // ========== Seed-based Random ==========

  /// 根据 seed 初始化棋盘（2 个随机方块）
  static List<int> generateInitialGrid(int seed) {
    final random = Random(seed);
    final grid = List.filled(Game2048Constants.totalCells, 0);
    _spawnTile(grid, random);
    _spawnTile(grid, random);
    return grid;
  }

  static void _spawnTile(List<int> grid, Random random) {
    final emptyCells = <int>[];
    for (int i = 0; i < grid.length; i++) {
      if (grid[i] == 0) emptyCells.add(i);
    }
    if (emptyCells.isEmpty) return;
    final pos = emptyCells[random.nextInt(emptyCells.length)];
    final value = random.nextDouble() < Game2048Constants.spawnFourProbability
        ? 4
        : 2;
    grid[pos] = value;
  }

  // ========== Core Move Logic ==========

  /// 执行一次移动，返回 (是否有方块移动, 合并得分)
  ({bool moved, int mergeScore}) move(MoveDirection direction) {
    if (state.status != Game2048Status.playing) {
      return (moved: false, mergeScore: 0);
    }

    final newGrid = List<int>.of(state.grid);
    final (:moved, :mergeScore) = _applyMove(newGrid, direction);

    if (!moved) return (moved: false, mergeScore: 0);

    // 添加新随机方块
    final rng = Random(state.seed ^ (state.moveCount + 1));
    _spawnTile(newGrid, rng);

    // 检查是否获胜
    final hasWon = _hasValue(newGrid, Game2048Constants.winValue);
    // 检查是否 game over
    final isOver = !hasWon && _isGameOver(newGrid);

    final newScore = state.score + mergeScore;

    state = Game2048State(
      status: hasWon
          ? Game2048Status.won
          : isOver
              ? Game2048Status.lost
              : Game2048Status.playing,
      grid: newGrid,
      score: newScore,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount + 1,
    );

    return (moved: true, mergeScore: mergeScore);
  }

  ({bool moved, int mergeScore}) _applyMove(
      List<int> grid, MoveDirection direction) {
    bool moved = false;
    int mergeScore = 0;
    final size = Game2048Constants.gridSize;

    for (int i = 0; i < size; i++) {
      List<int> line;
      switch (direction) {
        case MoveDirection.left:
          line = List.generate(size, (j) => grid[i * size + j]);
          break;
        case MoveDirection.right:
          line = List.generate(size, (j) => grid[i * size + (size - 1 - j)]);
          break;
        case MoveDirection.up:
          line = List.generate(size, (j) => grid[j * size + i]);
          break;
        case MoveDirection.down:
          line = List.generate(size, (j) => grid[(size - 1 - j) * size + i]);
          break;
      }

      final mergeResult = _mergeLine(line);
      final merged = mergeResult.line;
      mergeScore += mergeResult.score;

      switch (direction) {
        case MoveDirection.left:
          for (int j = 0; j < size; j++) {
            if (grid[i * size + j] != merged[j]) moved = true;
            grid[i * size + j] = merged[j];
          }
          break;
        case MoveDirection.right:
          for (int j = 0; j < size; j++) {
            if (grid[i * size + (size - 1 - j)] != merged[j]) moved = true;
            grid[i * size + (size - 1 - j)] = merged[j];
          }
          break;
        case MoveDirection.up:
          for (int j = 0; j < size; j++) {
            if (grid[j * size + i] != merged[j]) moved = true;
            grid[j * size + i] = merged[j];
          }
          break;
        case MoveDirection.down:
          for (int j = 0; j < size; j++) {
            if (grid[(size - 1 - j) * size + i] != merged[j]) moved = true;
            grid[(size - 1 - j) * size + i] = merged[j];
          }
          break;
      }
    }

    return (moved: moved, mergeScore: mergeScore);
  }

  /// 合并一行/列：先去掉0，再合并相邻相同值，再补0
  /// 返回合并后的行和本次合并获得的分数
  ({List<int> line, int score}) _mergeLine(List<int> line) {
    int score = 0;
    // 去掉0
    final nonZero = line.where((v) => v != 0).toList();
    // 合并
    for (int i = 0; i < nonZero.length - 1; i++) {
      if (nonZero[i] == nonZero[i + 1]) {
        nonZero[i] *= 2;
        score += nonZero[i]; // 合并得分 = 合并后的值
        nonZero[i + 1] = 0;
        i++; // 跳过已合并的
      }
    }
    // 再去掉0并补0
    final result = nonZero.where((v) => v != 0).toList();
    while (result.length < Game2048Constants.gridSize) {
      result.add(0);
    }
    return (line: result, score: score);
  }

  bool _hasValue(List<int> grid, int value) {
    return grid.any((v) => v >= value);
  }

  bool _isGameOver(List<int> grid) {
    final size = Game2048Constants.gridSize;
    // 有空格则未结束
    if (grid.any((v) => v == 0)) return false;
    // 检查水平相邻
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size - 1; c++) {
        if (grid[r * size + c] == grid[r * size + c + 1]) return false;
      }
    }
    // 检查垂直相邻
    for (int c = 0; c < size; c++) {
      for (int r = 0; r < size - 1; r++) {
        if (grid[r * size + c] == grid[(r + 1) * size + c]) return false;
      }
    }
    return true;
  }

  // ========== Public API ==========

  void startGame({
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    final grid = generateInitialGrid(seed);
    state = Game2048State(
      status: Game2048Status.playing,
      grid: grid,
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
    );
  }

  void startGameWithGrid({
    required List<int> grid,
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    state = Game2048State(
      status: Game2048Status.playing,
      grid: List.of(grid),
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
    );
  }

  void opponentWon() {
    if (state.status != Game2048Status.playing) return;
    if (state.isSolo) return;
    state = Game2048State(
      status: Game2048Status.lost,
      grid: state.grid,
      score: state.score,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  void timeout() {
    if (state.status != Game2048Status.playing) return;
    state = Game2048State(
      status: Game2048Status.lost,
      grid: state.grid,
      score: state.score,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  void opponentTimeout() {
    if (state.status != Game2048Status.playing) return;
    state = Game2048State(
      status: Game2048Status.won,
      grid: state.grid,
      score: state.score,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  void handleConnectionLost() {
    state = Game2048State(
      status: Game2048Status.disconnected,
      grid: state.grid,
      score: state.score,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      moveCount: state.moveCount,
    );
  }

  void resetGame() {
    state = Game2048State.initial();
  }

  void incrementRound() {
    state = Game2048State(
      status: Game2048Status.loading,
      currentRound: state.currentRound + 1,
    );
  }

  void setLoading() {
    state = Game2048State(
      status: Game2048Status.loading,
      currentRound: state.currentRound,
    );
  }

  static int generateSeed() {
    return DateTime.now().millisecondsSinceEpoch ^ (Random().nextInt(1 << 16));
  }
}

// ========== Providers ==========

final game2048StateProvider =
    StateNotifierProvider<Game2048StateNotifier, Game2048State>((ref) {
  return Game2048StateNotifier();
});

enum Game2048RematchStatus { none, waiting, received }

final game2048RematchStatusProvider =
    StateProvider<Game2048RematchStatus>((ref) => Game2048RematchStatus.none);

final game2048AutoExitProvider = StateProvider<bool>((ref) => false);

final game2048ToastProvider = StateProvider<String?>((ref) => null);
