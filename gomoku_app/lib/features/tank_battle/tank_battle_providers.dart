/// 坦克大战状态管理与游戏循环。
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';
import 'package:gomoku_app/features/tank_battle/models/tank_battle_input.dart';
import 'package:gomoku_app/features/tank_battle/models/tank_battle_state.dart';
import 'package:gomoku_app/features/tank_battle/tank_battle_engine.dart';

// ========== 重赛状态 ==========

enum TankBattleRematchStatus { none, waiting, received }

// ========== 主 StateNotifier ==========

class TankBattleStateNotifier extends StateNotifier<TankBattleState> {
  TankBattleEngine? _engine;
  Timer? _gameLoopTimer;
  Timer? _phaseTimer;

  // 输入缓冲 (可变，不属于不可变状态)
  Direction? _playerDirection;
  bool _playerFiring = false;
  Direction? _remoteDirection;
  bool _remoteFiring = false;

  // PvP 同步回调 (由 handler 设置)
  void Function(TankBattleState snapshot)? onSyncNeeded;

  // 初始地图副本 (用于增量同步)
  List<List<TileType>>? _originalMap;

  TankBattleStateNotifier() : super(TankBattleState.initial());

  // ========== 种子生成 ==========

  static int generateSeed() => Random().nextInt(1 << 31);

  // ========== 关卡启动 ==========

  void startLevel({
    required int level,
    required int seed,
    required bool isSolo,
    required String selfName,
    String opponentName = '',
    int playerCount = 1,
  }) {
    _stopTimers();

    _engine = TankBattleEngine(
      level: level,
      seed: seed,
      playerCount: playerCount,
    );
    _originalMap = _engine!.toSnapshot(
      phase: TankBattlePhase.loading,
    ).map.map((row) => List<TileType>.from(row)).toList();

    // 关卡介绍阶段
    state = _engine!.toSnapshot(
      phase: TankBattlePhase.levelIntro,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
    );

    // 2 秒后开始游戏
    _phaseTimer = Timer(
      Duration(
          milliseconds:
              (TankBattleConstants.levelIntroDelayTicks *
                      TankBattleConstants.tickDuration *
                      1000)
                  .toInt()),
      () {
        if (!mounted) return;
        _startGameLoop(isSolo, selfName, opponentName);
      },
    );
  }

  void _startGameLoop(bool isSolo, String selfName, String opponentName) {
    if (_engine == null) return;

    state = _engine!.toSnapshot(
      phase: TankBattlePhase.playing,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
    );

    // Guest 在 PvP 中也运行游戏循环，用本地引擎提供 60fps 流畅画面，
    // 同时通过 applyRemoteState 接收 Host 权威状态修正偏差。
    _gameLoopTimer = Timer.periodic(
      Duration(milliseconds: (TankBattleConstants.tickDuration * 1000).toInt()),
      (_) => _gameLoopTick(),
    );
  }

  void _gameLoopTick() {
    if (_engine == null) return;
    if (state.phase != TankBattlePhase.playing) return;

    final isHost = onSyncNeeded != null;

    // 应用玩家输入 (Host/Guest 输入映射不同)
    if (state.isSolo) {
      // Solo: 只有 1 辆玩家坦克
      _engine!.setPlayerInput(0, _playerDirection, _playerFiring);
    } else if (isHost) {
      // Host: Player 0 = 自己, Player 1 = 对手(Guest)
      _engine!.setPlayerInput(0, _playerDirection, _playerFiring);
      _engine!.setPlayerInput(1, _remoteDirection, _remoteFiring);
    } else {
      // Guest: Player 0 = 对手(Host), Player 1 = 自己
      _engine!.setPlayerInput(0, _remoteDirection, _remoteFiring);
      _engine!.setPlayerInput(1, _playerDirection, _playerFiring);
    }
    _engine!.tick(TankBattleConstants.tickDuration);

    // 检查所有玩家死亡并重生（Solo: 1玩家，PvP: 2玩家）
    if (state.livesRemaining > 0) {
      final engineSnapshot =
          _engine!.toSnapshot(phase: TankBattlePhase.playing);
      for (int i = 0; i < _engine!.playerCount; i++) {
        final playerAlive = engineSnapshot.tanks
            .any((t) => t.type.isPlayer && t.ownerPlayerIndex == i);
        if (!playerAlive && _engine!.livesRemaining > 0) {
          _engine!.respawnPlayer(i);
        }
      }
    }

    // 发布状态
    final newPhase = _derivePhase();
    state = _engine!.toSnapshot(
      phase: newPhase,
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
    );

    // PvP 同步 (仅 Host)
    if (isHost && _engine!.tickCount % TankBattleConstants.syncIntervalTicks == 0) {
      onSyncNeeded?.call(state);
    }

    // 关卡完成时停止游戏循环
    if (newPhase == TankBattlePhase.levelComplete) {
      _gameLoopTimer?.cancel();
      _gameLoopTimer = null;
    }

    // 游戏结束
    if (newPhase == TankBattlePhase.lost) {
      _gameLoopTimer?.cancel();
      _gameLoopTimer = null;
    }
  }

  TankBattlePhase _derivePhase() {
    if (_engine == null) return TankBattlePhase.loading;
    if (_engine!.isGameOver) return TankBattlePhase.lost;
    if (_engine!.isLevelComplete) return TankBattlePhase.levelComplete;
    return TankBattlePhase.playing;
  }

  // ========== 输入控制 ==========

  void setPlayerInput(Direction? direction, bool firing) {
    _playerDirection = direction;
    _playerFiring = firing;
    final isHost = onSyncNeeded != null;
    if (isHost) {
      // Host: 自己的坦克是 Player 0
      _engine?.setPlayerInput(0, direction, firing);
    } else {
      // Guest: 自己的坦克是 Player 1
      _engine?.setPlayerInput(1, direction, firing);
    }
  }

  /// 设置远程玩家输入 (Host: Guest 的输入, Guest: Host 的输入)。
  void setRemotePlayerInput(Direction? direction, bool firing) {
    _remoteDirection = direction;
    _remoteFiring = firing;
    final isHost = onSyncNeeded != null;
    if (isHost) {
      // Host: 远程玩家(Guest) 是 Player 1
      _engine?.setPlayerInput(1, direction, firing);
    } else {
      // Guest: 远程玩家(Host) 是 Player 0
      _engine?.setPlayerInput(0, direction, firing);
    }
  }

  /// 获取当前输入状态 (用于 PvP 发送)。
  TankBattleInput getCurrentInput() =>
      TankBattleInput(direction: _playerDirection, firing: _playerFiring);

  // ========== PvP 相关 ==========

  /// Guest: 应用 Host 发来的状态。
  void applyRemoteState(TankBattleState remoteState) {
    state = remoteState.copyWith(
      isSolo: state.isSolo,
      selfName: state.selfName,
      opponentName: state.opponentName,
    );
  }

  /// Guest: 同步引擎内部状态（防止状态发散导致的闪烁）。
  void syncEngineFromState(TankBattleState syncedState) {
    _engine?.applyRemoteSnapshot(syncedState);
  }

  /// Guest: 应用地图增量 (同时同步到引擎)。
  void applyMapDelta(List<List<int>> changes) {
    final map = state.map.map((row) => List<TileType>.from(row)).toList();
    for (final change in changes) {
      if (change.length >= 3) {
        final r = change[0];
        final c = change[1];
        final type = TileType.values[change[2]];
        if (r >= 0 &&
            r < TankBattleConstants.gridSize &&
            c >= 0 &&
            c < TankBattleConstants.gridSize) {
          map[r][c] = type;
        }
      }
    }
    state = state.copyWith(map: map);
    // 同步到引擎，确保本地引擎的地图与 Host 保持一致
    _engine?.applyTileChanges(changes);
  }

  /// Host: 获取地图增量。
  List<List<int>> getMapChanges() {
    if (_engine == null || _originalMap == null) return [];
    return _engine!.getMapChanges(_originalMap!);
  }

  /// 进入下一关。
  void advanceToNextLevel({
    required int seed,
    required bool isSolo,
    required String selfName,
    String opponentName = '',
    int playerCount = 1,
  }) {
    final nextLevel = state.currentLevel + 1;
    startLevel(
      level: nextLevel,
      seed: seed,
      isSolo: isSolo,
      selfName: selfName,
      opponentName: opponentName,
      playerCount: playerCount,
    );
  }

  // ========== 断线处理 ==========

  void handleConnectionLost() {
    _stopTimers();
    state = state.copyWith(phase: TankBattlePhase.disconnected);
  }

  // ========== 清理 ==========

  void _stopTimers() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = null;
    _phaseTimer?.cancel();
    _phaseTimer = null;
  }

  void resetGame() {
    _stopTimers();
    _engine = null;
    _originalMap = null;
    _playerDirection = null;
    _playerFiring = false;
    _remoteDirection = null;
    _remoteFiring = false;
    onSyncNeeded = null;
    state = TankBattleState.initial();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}

// ========== Provider 定义 ==========

final tankBattleStateProvider =
    StateNotifierProvider<TankBattleStateNotifier, TankBattleState>((ref) {
  return TankBattleStateNotifier();
});

final tankBattleRematchStatusProvider =
    StateProvider<TankBattleRematchStatus>(
        (ref) => TankBattleRematchStatus.none);

final tankBattleAutoExitProvider = StateProvider<bool>((ref) => false);

final tankBattleToastProvider = StateProvider<String?>((ref) => null);
