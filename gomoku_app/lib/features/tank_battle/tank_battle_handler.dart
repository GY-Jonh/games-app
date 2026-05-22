/// 坦克大战处理器，实现 GameHandler 接口。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';
import 'package:gomoku_app/features/tank_battle/models/tank_battle_state.dart';
import 'package:gomoku_app/features/tank_battle/tank_battle_providers.dart';
import 'package:gomoku_app/features/tank_battle/tank_battle_screen.dart';
import 'package:gomoku_app/models/network_message.dart';

class TankBattleHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;
  bool _isSolo = false;
  int _myPlayerIndex = 0;

  TankBattleHandler(this.ref, this._sendMessage);

  @override
  void initGame({
    required int myPlayerIndex,
    required String opponentName,
  }) {
    _isSolo = opponentName.isEmpty;
    _myPlayerIndex = myPlayerIndex;

    if (_isSolo) {
      _startSoloGame();
    } else {
      if (myPlayerIndex == 0) {
        _startPvPAsHost(opponentName);
      }
      // Guest 等待 tank_battle_level_start
    }
  }

  void _startSoloGame() {
    final seed = TankBattleStateNotifier.generateSeed();
    ref.read(tankBattleStateProvider.notifier).startLevel(
          level: 1,
          seed: seed,
          isSolo: true,
          selfName: deviceName,
        );
  }

  void _startPvPAsHost(String opponentName, {int level = 1}) {
    final seed = TankBattleStateNotifier.generateSeed();
    final notifier = ref.read(tankBattleStateProvider.notifier);

    // 设置同步回调
    notifier.onSyncNeeded = (snapshot) {
      final mapChanges = notifier.getMapChanges();
      _sendMessage(NetworkMessage(
        type: 'tank_battle_state_sync',
        senderId: deviceId,
        payload: {
          ...snapshot.toJson(),
          'map_changes': mapChanges,
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    };

    notifier.startLevel(
      level: level,
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
      playerCount: 2,
    );

    // 发送关卡开始消息给 Guest
    final mapData = TankBattleMaps.getMap(level);
    _sendMessage(NetworkMessage(
      type: 'tank_battle_level_start',
      senderId: deviceId,
      payload: {
        'level': level,
        'seed': seed,
        'map': mapData,
        'device_name': deviceName,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void handleMessage(NetworkMessage message) {
    switch (message.type) {
      case 'tank_battle_level_start':
        _handleLevelStart(message);
        break;
      case 'tank_battle_input':
        _handleRemoteInput(message);
        break;
      case 'tank_battle_state_sync':
        _handleStateSync(message);
        break;
      case 'tank_battle_game_over':
        _handleGameOver(message);
        break;
      case 'tank_battle_rematch_request':
        _handleRematchRequest(message);
        break;
      case 'tank_battle_rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  @override
  void handleConnectionLost() {
    ref.read(tankBattleRematchStatusProvider.notifier).state =
        TankBattleRematchStatus.none;

    final gameState = ref.read(tankBattleStateProvider);
    if (gameState.phase == TankBattlePhase.playing) {
      ref.read(tankBattleStateProvider.notifier).handleConnectionLost();
    } else {
      ref.read(tankBattleAutoExitProvider.notifier).state = true;
    }
  }

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return TankBattleScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
    );
  }

  @override
  void dispose() {
    ref.read(tankBattleStateProvider.notifier).resetGame();
    ref.read(tankBattleRematchStatusProvider.notifier).state =
        TankBattleRematchStatus.none;
    ref.read(tankBattleAutoExitProvider.notifier).state = false;
    ref.read(tankBattleToastProvider.notifier).state = null;
  }

  // ========== 消息处理 ==========

  void _handleLevelStart(NetworkMessage message) {
    // Guest 接收关卡开始
    final level = message.payload['level'] as int;
    final seed = message.payload['seed'] as int;
    final opponentName =
        message.payload['device_name'] as String? ?? '对手';

    ref.read(tankBattleStateProvider.notifier).startLevel(
          level: level,
          seed: seed,
          isSolo: false,
          selfName: deviceName,
          opponentName: opponentName,
          playerCount: 2,
        );
  }

  void _handleRemoteInput(NetworkMessage message) {
    // Host 接收 Guest 的输入
    final payload = message.payload;
    final dirIndex = payload['dir'] as int?;
    final firing = payload['fire'] as bool? ?? false;
    final dir = dirIndex != null ? Direction.fromIndex(dirIndex) : null;

    ref
        .read(tankBattleStateProvider.notifier)
        .setRemotePlayerInput(dir, firing);
  }

  void _handleStateSync(NetworkMessage message) {
    // Guest 接收 Host 的状态同步
    final currentMap = ref.read(tankBattleStateProvider).map;
    final remoteState = TankBattleState.fromSyncJson(
      message.payload,
      currentMap,
    );
    ref.read(tankBattleStateProvider.notifier).applyRemoteState(remoteState);

    // 应用地图增量
    final mapChanges = message.payload['map_changes'];
    if (mapChanges != null) {
      final changes = (mapChanges as List)
          .map((c) => (c as List).cast<int>())
          .toList();
      ref
          .read(tankBattleStateProvider.notifier)
          .applyMapDelta(changes);
    }
  }

  void _handleGameOver(NetworkMessage message) {
    final reason = message.payload['reason'] as String? ?? 'unknown';
    if (reason == 'quit' || reason == 'disconnect') {
      ref.read(tankBattleStateProvider.notifier).handleConnectionLost();
    }
  }

  // ========== 重赛逻辑 ==========

  void _handleRematchRequest(NetworkMessage message) {
    final gameState = ref.read(tankBattleStateProvider);
    if (gameState.phase == TankBattlePhase.playing) return;

    if (ref.read(tankBattleRematchStatusProvider) ==
        TankBattleRematchStatus.waiting) {
      // 双方同时请求，自动同意
      _sendMessage(NetworkMessage(
        type: 'tank_battle_rematch_response',
        senderId: deviceId,
        payload: {'accepted': true},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      _restartGame();
    } else {
      ref.read(tankBattleRematchStatusProvider.notifier).state =
          TankBattleRematchStatus.received;
      ref.read(tankBattleToastProvider.notifier).state = '对方请求了重赛';
    }
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted = message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      _restartGame();
    } else {
      ref.read(tankBattleRematchStatusProvider.notifier).state =
          TankBattleRematchStatus.none;
      ref.read(tankBattleToastProvider.notifier).state = '对方拒绝了重赛请求';
    }
  }

  void _restartGame() {
    ref.read(tankBattleRematchStatusProvider.notifier).state =
        TankBattleRematchStatus.none;

    final currentPhase = ref.read(tankBattleStateProvider).phase;

    if (_isSolo) {
      _startSoloGame();
    } else if (_myPlayerIndex == 0) {
      final opponentName = ref.read(tankBattleStateProvider).opponentName;
      // 过关 → 进入下一关；Game Over → 从第1关重新开始
      final level = currentPhase == TankBattlePhase.levelComplete
          ? ref.read(tankBattleStateProvider).currentLevel + 1
          : 1;
      _startPvPAsHost(opponentName, level: level);
    }
    // Guest 等待 Host 发送 tank_battle_level_start
  }
}
