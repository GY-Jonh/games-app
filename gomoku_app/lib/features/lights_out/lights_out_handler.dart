import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/lights_out/lights_out_providers.dart';
import 'package:gomoku_app/features/lights_out/lights_out_screen.dart';
import 'package:gomoku_app/features/lights_out/lights_out_timer.dart';
import 'package:gomoku_app/models/network_message.dart';

/// 点灯游戏处理器，实现 GameHandler 接口。
class LightsOutHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;
  bool _isSolo = false;
  int _myPlayerIndex = 0;

  LightsOutHandler(this.ref, this._sendMessage);

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
      // PvP 模式：Host (myPlayerIndex==0) 生成棋盘并发给对手
      // Guest (myPlayerIndex==1) 等待接收 lights_out_board
      if (myPlayerIndex == 0) {
        _startPvPAsHost(opponentName);
      }
    }
  }

  Future<void> _startSoloGame() async {
    ref.read(lightsOutStateProvider.notifier).setLoading();
    final seed = LightsOutStateNotifier.generateSeed();
    ref.read(lightsOutStateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(lightsOutTimerProvider.notifier).start();
  }

  void _startPvPAsHost(String opponentName) {
    ref.read(lightsOutStateProvider.notifier).setLoading();
    final seed = LightsOutStateNotifier.generateSeed();
    ref.read(lightsOutStateProvider.notifier).startGame(
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
    );
    ref.read(lightsOutTimerProvider.notifier).start();

    // 发送 seed 给对手
    _sendMessage(NetworkMessage(
      type: 'lights_out_board',
      senderId: deviceId,
      payload: {
        'seed': seed,
        'device_name': deviceName,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void handleMessage(NetworkMessage message) {
    switch (message.type) {
      case 'lights_out_board':
        _handleBoardMessage(message);
        break;
      case 'lights_out_won':
        _handleOpponentWon(message);
        break;
      case 'lights_out_game_over':
        _handleGameOver(message);
        break;
      case 'lights_out_rematch_request':
        _handleRematchRequest(message);
        break;
      case 'lights_out_rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  @override
  void handleConnectionLost() {
    ref.read(lightsOutTimerProvider.notifier).stop();
    ref.read(lightsOutRematchStatusProvider.notifier).state =
        LightsOutRematchStatus.none;

    final gameState = ref.read(lightsOutStateProvider);
    if (gameState.status == LightsOutGameStatus.playing) {
      ref.read(lightsOutStateProvider.notifier).handleConnectionLost();
    } else {
      ref.read(lightsOutAutoExitProvider.notifier).state = true;
    }
  }

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return LightsOutScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
    );
  }

  @override
  void dispose() {
    ref.read(lightsOutTimerProvider.notifier).stop();
    ref.read(lightsOutStateProvider.notifier).resetGame();
    ref.read(lightsOutRematchStatusProvider.notifier).state =
        LightsOutRematchStatus.none;
    ref.read(lightsOutAutoExitProvider.notifier).state = false;
    ref.read(lightsOutToastProvider.notifier).state = null;
  }

  // ========== Message Handlers ==========

  void _handleBoardMessage(NetworkMessage message) {
    // 游戏中忽略棋盘消息，防止超时/延迟消息打断当前对局
    if (ref.read(lightsOutStateProvider).status ==
        LightsOutGameStatus.playing) {
      return;
    }

    final seed = message.payload['seed'] as int;
    final opponentName =
        message.payload['device_name'] as String? ?? '对手';

    final bits = LightsOutStateNotifier.generateBoardBits(seed);
    ref.read(lightsOutStateProvider.notifier).startGameWithBits(
      bits: bits,
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
    );
    ref.read(lightsOutTimerProvider.notifier).start();
  }

  void _handleOpponentWon(NetworkMessage message) {
    ref.read(lightsOutStateProvider.notifier).opponentWon();
    ref.read(lightsOutTimerProvider.notifier).stop();
  }

  void _handleGameOver(NetworkMessage message) {
    final reason = message.payload['reason'] as String? ?? 'unknown';
    if (reason == 'quit' || reason == 'disconnect') {
      ref.read(lightsOutStateProvider.notifier).handleConnectionLost();
    } else if (reason == 'timeout') {
      ref.read(lightsOutStateProvider.notifier).opponentTimeout();
    }
    ref.read(lightsOutTimerProvider.notifier).stop();
  }

  // ========== Rematch Logic ==========

  void _handleRematchRequest(NetworkMessage message) {
    // 游戏中不处理重赛请求
    if (ref.read(lightsOutStateProvider).status ==
        LightsOutGameStatus.playing) {
      return;
    }

    if (ref.read(lightsOutRematchStatusProvider) ==
        LightsOutRematchStatus.waiting) {
      // 双方同时请求重开，自动同意
      _sendMessage(NetworkMessage(
        type: 'lights_out_rematch_response',
        senderId: deviceId,
        payload: {'accepted': true},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      _restartGame();
    } else {
      ref.read(lightsOutRematchStatusProvider.notifier).state =
          LightsOutRematchStatus.received;
      ref.read(lightsOutToastProvider.notifier).state = '对方请求了重赛';
    }
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted = message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      _restartGame();
    } else {
      ref.read(lightsOutRematchStatusProvider.notifier).state =
          LightsOutRematchStatus.none;
      ref.read(lightsOutToastProvider.notifier).state = '对方拒绝了重开请求';
    }
  }

  void _restartGame() {
    ref.read(lightsOutStateProvider.notifier).incrementRound();
    ref.read(lightsOutRematchStatusProvider.notifier).state =
        LightsOutRematchStatus.none;
    ref.read(lightsOutTimerProvider.notifier).reset();

    if (_isSolo) {
      _startSoloGame();
    } else if (_myPlayerIndex == 0) {
      // Host 生成新棋盘并发给对手
      final seed = LightsOutStateNotifier.generateSeed();
      final opponentName =
          ref.read(lightsOutStateProvider).opponentName;
      ref.read(lightsOutStateProvider.notifier).startGame(
        seed: seed,
        isSolo: false,
        selfName: deviceName,
        opponentName: opponentName,
      );
      ref.read(lightsOutTimerProvider.notifier).start();

      _sendMessage(NetworkMessage(
        type: 'lights_out_board',
        senderId: deviceId,
        payload: {
          'seed': seed,
          'device_name': deviceName,
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    // Guest 不生成棋盘，等待 Host 发送 lights_out_board
  }
}
