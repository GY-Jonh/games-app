import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/minesweeper/constants/minesweeper_constants.dart';

// ========== Status Enum ==========

enum MinesweeperStatus {
  loading,
  playing,
  won,
  lost,
  draw,
  disconnected,
}

// ========== Game State ==========

class MinesweeperState {
  final MinesweeperStatus status;
  final List<int> mines; // -1 = mine, 0-8 = adjacent mine count
  final Set<int> revealed; // 已翻开的格子
  final Set<int> flagged; // 已插旗的格子
  final int seed;
  final bool isSolo;
  final String selfName;
  final String opponentName;
  final int currentRound;
  final int revealCount; // 已翻开的非地雷格数
  final bool firstClick; // 是否是第一次点击（保护不踩雷）

  const MinesweeperState({
    required this.status,
    this.mines = const [],
    this.revealed = const {},
    this.flagged = const {},
    this.seed = 0,
    this.isSolo = true,
    this.selfName = '',
    this.opponentName = '',
    this.currentRound = 1,
    this.revealCount = 0,
    this.firstClick = true,
  });

  int mineAt(int row, int col) {
    if (row < 0 || row >= MinesweeperConstants.rows) return -1;
    if (col < 0 || col >= MinesweeperConstants.cols) return -1;
    return mines[row * MinesweeperConstants.cols + col];
  }

  bool isRevealed(int pos) => revealed.contains(pos);
  bool isFlagged(int pos) => flagged.contains(pos);

  int get totalNonMines =>
      MinesweeperConstants.totalCells - MinesweeperConstants.mineCount;

  factory MinesweeperState.initial() {
    return const MinesweeperState(status: MinesweeperStatus.loading);
  }
}

// ========== State Notifier ==========

class MinesweeperStateNotifier extends StateNotifier<MinesweeperState> {
  MinesweeperStateNotifier() : super(MinesweeperState.initial());

  // ========== Mine Generation ==========

  /// 生成地雷布局（不包含第一次点击位置）
  static List<int> generateMines(int seed, {int? safePos}) {
    final random = Random(seed);
    final cells = List<int>.generate(MinesweeperConstants.totalCells, (i) => i);

    // 移除安全位置（第一次点击保证不踩雷）
    if (safePos != null && safePos >= 0 &&
        safePos < MinesweeperConstants.totalCells) {
      cells.remove(safePos);
    }

    cells.shuffle(random);

    final minePositions =
        cells.take(MinesweeperConstants.mineCount).toSet();

    // 构建数值网格
    final grid = List<int>.filled(MinesweeperConstants.totalCells, 0);
    for (final pos in minePositions) {
      grid[pos] = -1;
    }

    // 计算每格周围地雷数
    for (int r = 0; r < MinesweeperConstants.rows; r++) {
      for (int c = 0; c < MinesweeperConstants.cols; c++) {
        final pos = r * MinesweeperConstants.cols + c;
        if (grid[pos] == -1) continue;
        int count = 0;
        for (final n in _getNeighbors(pos)) {
          if (grid[n] == -1) count++;
        }
        grid[pos] = count;
      }
    }

    return grid;
  }

  static List<int> _getNeighbors(int pos) {
    final cols = MinesweeperConstants.cols;
    final rows = MinesweeperConstants.rows;
    final r = pos ~/ cols;
    final c = pos % cols;
    final result = <int>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          result.add(nr * cols + nc);
        }
      }
    }
    return result;
  }

  // ========== Public API ==========

  void startGame({
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    // 地雷在第一次点击时再生成（保证安全）
    state = MinesweeperState(
      status: MinesweeperStatus.playing,
      mines: List.filled(MinesweeperConstants.totalCells, 0),
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
      firstClick: true,
    );
  }

  void startGameWithMines({
    required List<int> mines,
    required int seed,
    bool isSolo = false,
    String selfName = '',
    String opponentName = '',
  }) {
    state = MinesweeperState(
      status: MinesweeperStatus.playing,
      mines: List.of(mines),
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      currentRound: state.currentRound,
      firstClick: false,
    );
  }

  /// 翻开一个格子，返回 true 表示踩到地雷
  bool reveal(int position) {
    if (state.status != MinesweeperStatus.playing) return false;
    if (state.revealed.contains(position)) return false;
    if (state.flagged.contains(position)) return false;

    List<int> mines = state.mines;

    // 第一次点击：生成地雷（保证安全）
    if (state.firstClick) {
      mines = generateMines(state.seed, safePos: position);
    }

    final newRevealed = {...state.revealed};
    final hitMine = mines[position] == -1;

    if (hitMine) {
      // 踩雷：揭开所有地雷
      for (int i = 0; i < mines.length; i++) {
        if (mines[i] == -1) newRevealed.add(i);
      }
      state = MinesweeperState(
        status: MinesweeperStatus.lost,
        mines: mines,
        revealed: newRevealed,
        flagged: state.flagged,
        seed: state.seed,
        isSolo: state.isSolo,
        selfName: state.selfName,
        opponentName: state.opponentName,
        currentRound: state.currentRound,
        revealCount: state.revealCount,
        firstClick: false,
      );
      return true;
    }

    // 级联翻开（如果值为 0）
    _cascadeReveal(mines, newRevealed, position);

    final won = newRevealed.length >=
        MinesweeperConstants.totalCells - MinesweeperConstants.mineCount;

    state = MinesweeperState(
      status: won ? MinesweeperStatus.won : MinesweeperStatus.playing,
      mines: mines,
      revealed: newRevealed,
      flagged: state.flagged,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      revealCount: newRevealed.length,
      firstClick: false,
    );

    return false;
  }

  void _cascadeReveal(
      List<int> mines, Set<int> revealed, int position) {
    if (revealed.contains(position)) return;
    revealed.add(position);

    if (mines[position] != 0) return;

    for (final n in _getNeighbors(position)) {
      if (!revealed.contains(n) && mines[n] != -1) {
        _cascadeReveal(mines, revealed, n);
      }
    }
  }

  /// 插旗/取消旗
  void toggleFlag(int position) {
    if (state.status != MinesweeperStatus.playing) return;
    if (state.revealed.contains(position)) return;

    final newFlagged = {...state.flagged};
    if (newFlagged.contains(position)) {
      newFlagged.remove(position);
    } else {
      newFlagged.add(position);
    }

    state = MinesweeperState(
      status: state.status,
      mines: state.mines,
      revealed: state.revealed,
      flagged: newFlagged,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      revealCount: state.revealCount,
      firstClick: state.firstClick,
    );
  }

  void opponentWon() {
    if (state.status != MinesweeperStatus.playing) return;
    if (state.isSolo) return;
    state = MinesweeperState(
      status: MinesweeperStatus.lost,
      mines: state.mines,
      revealed: state.revealed,
      flagged: state.flagged,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      revealCount: state.revealCount,
      firstClick: state.firstClick,
    );
  }

  void timeout() {
    if (state.status != MinesweeperStatus.playing) return;
    state = MinesweeperState(
      status: MinesweeperStatus.lost,
      mines: state.mines,
      revealed: state.revealed,
      flagged: state.flagged,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      revealCount: state.revealCount,
      firstClick: state.firstClick,
    );
  }

  void opponentTimeout() {
    if (state.status != MinesweeperStatus.playing) return;
    state = MinesweeperState(
      status: MinesweeperStatus.won,
      mines: state.mines,
      revealed: state.revealed,
      flagged: state.flagged,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      revealCount: state.revealCount,
      firstClick: state.firstClick,
    );
  }

  void handleConnectionLost() {
    state = MinesweeperState(
      status: MinesweeperStatus.disconnected,
      mines: state.mines,
      revealed: state.revealed,
      flagged: state.flagged,
      seed: state.seed,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
      currentRound: state.currentRound,
      revealCount: state.revealCount,
      firstClick: state.firstClick,
    );
  }

  void resetGame() {
    state = MinesweeperState.initial();
  }

  void incrementRound() {
    state = MinesweeperState(
      status: MinesweeperStatus.loading,
      currentRound: state.currentRound + 1,
    );
  }

  void setLoading() {
    state = MinesweeperState(
      status: MinesweeperStatus.loading,
      currentRound: state.currentRound,
    );
  }

  static int generateSeed() {
    return DateTime.now().millisecondsSinceEpoch ^ (Random().nextInt(1 << 16));
  }
}

// ========== Providers ==========

final minesweeperStateProvider =
    StateNotifierProvider<MinesweeperStateNotifier, MinesweeperState>((ref) {
  return MinesweeperStateNotifier();
});

enum MinesweeperRematchStatus { none, waiting, received }

final minesweeperRematchStatusProvider =
    StateProvider<MinesweeperRematchStatus>(
        (ref) => MinesweeperRematchStatus.none);

final minesweeperAutoExitProvider = StateProvider<bool>((ref) => false);

final minesweeperToastProvider = StateProvider<String?>((ref) => null);
