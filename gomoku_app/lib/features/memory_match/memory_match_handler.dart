import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/memory_match/memory_match_providers.dart';
import 'package:gomoku_app/features/memory_match/memory_match_screen.dart';
import 'package:gomoku_app/features/memory_match/memory_match_timer.dart';
import 'package:gomoku_app/models/network_message.dart';

/// 记忆翻牌游戏处理器，实现 GameHandler 接口。
class MemoryMatchHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;
  bool _isSolo = false;
  int _myPlayerIndex = 0;

  MemoryMatchHandler(this.ref, this._sendMessage);

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
      // PvP 模式：Host (myPlayerIndex==0) 生成卡片排列并发给对手
      // Guest (myPlayerIndex==1) 等待接收 memory_match_board
      if (myPlayerIndex == 0) {
        _startPvPAsHost(opponentName);
      }
    }
  }

  Future<void> _startSoloGame() async {
    ref.read(memoryMatchStateProvider.notifier).setLoading();
    final seed = MemoryMatchStateNotifier.generateSeed();
    ref.read(memoryMatchStateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(memoryMatchTimerProvider.notifier).start();
  }

  void _startPvPAsHost(String opponentName) {
    ref.read(memoryMatchStateProvider.notifier).setLoading();
    final seed = MemoryMatchStateNotifier.generateSeed();
    ref.read(memoryMatchStateProvider.notifier).startGame(
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
    );
    ref.read(memoryMatchTimerProvider.notifier).start();

    // 发送 seed 给对手
    _sendMessage(NetworkMessage(
      type: 'memory_match_board',
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
      case 'memory_match_board':
        _handleBoardMessage(message);
        break;
      case 'memory_match_won':
        _handleOpponentWon(message);
        break;
      case 'memory_match_game_over':
        _handleGameOver(message);
        break;
      case 'memory_match_rematch_request':
        _handleRematchRequest(message);
        break;
      case 'memory_match_rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  @override
  void handleConnectionLost() {
    ref.read(memoryMatchTimerProvider.notifier).stop();
    ref.read(memoryMatchRematchStatusProvider.notifier).state =
        MemoryMatchRematchStatus.none;

    final gameState = ref.read(memoryMatchStateProvider);
    if (gameState.status == MemoryMatchGameStatus.playing) {
      ref.read(memoryMatchStateProvider.notifier).handleConnectionLost();
    } else {
      ref.read(memoryMatchAutoExitProvider.notifier).state = true;
    }
  }

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return MemoryMatchScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
    );
  }

  @override
  void dispose() {
    ref.read(memoryMatchTimerProvider.notifier).stop();
    ref.read(memoryMatchStateProvider.notifier).resetGame();
    ref.read(memoryMatchRematchStatusProvider.notifier).state =
        MemoryMatchRematchStatus.none;
    ref.read(memoryMatchAutoExitProvider.notifier).state = false;
    ref.read(memoryMatchToastProvider.notifier).state = null;
  }

  // ========== Message Handlers ==========

  void _handleBoardMessage(NetworkMessage message) {
    // 游戏中忽略棋盘消息，防止超时/延迟消息打断当前对局
    if (ref.read(memoryMatchStateProvider).status ==
        MemoryMatchGameStatus.playing) {
      return;
    }

    final seed = message.payload['seed'] as int;
    final opponentName =
        message.payload['device_name'] as String? ?? '对手';

    final cards = MemoryMatchStateNotifier.generateCards(seed);
    ref.read(memoryMatchStateProvider.notifier).startGameWithCards(
      cards: cards,
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
    );
    ref.read(memoryMatchTimerProvider.notifier).start();
  }

  void _handleOpponentWon(NetworkMessage message) {
    ref.read(memoryMatchStateProvider.notifier).opponentWon();
    ref.read(memoryMatchTimerProvider.notifier).stop();
  }

  void _handleGameOver(NetworkMessage message) {
    final reason = message.payload['reason'] as String? ?? 'unknown';
    if (reason == 'quit' || reason == 'disconnect') {
      ref.read(memoryMatchStateProvider.notifier).handleConnectionLost();
    } else if (reason == 'timeout') {
      ref.read(memoryMatchStateProvider.notifier).opponentTimeout();
    }
    ref.read(memoryMatchTimerProvider.notifier).stop();
  }

  // ========== Rematch Logic ==========

  void _handleRematchRequest(NetworkMessage message) {
    // 游戏中不处理重赛请求
    if (ref.read(memoryMatchStateProvider).status ==
        MemoryMatchGameStatus.playing) {
      return;
    }

    if (ref.read(memoryMatchRematchStatusProvider) ==
        MemoryMatchRematchStatus.waiting) {
      // 双方同时请求重开，自动同意
      _sendMessage(NetworkMessage(
        type: 'memory_match_rematch_response',
        senderId: deviceId,
        payload: {'accepted': true},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      _restartGame();
    } else {
      ref.read(memoryMatchRematchStatusProvider.notifier).state =
          MemoryMatchRematchStatus.received;
      ref.read(memoryMatchToastProvider.notifier).state = '对方请求了重赛';
    }
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted = message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      _restartGame();
    } else {
      ref.read(memoryMatchRematchStatusProvider.notifier).state =
          MemoryMatchRematchStatus.none;
      ref.read(memoryMatchToastProvider.notifier).state = '对方拒绝了重开请求';
    }
  }

  void _restartGame() {
    ref.read(memoryMatchStateProvider.notifier).incrementRound();
    ref.read(memoryMatchRematchStatusProvider.notifier).state =
        MemoryMatchRematchStatus.none;
    ref.read(memoryMatchTimerProvider.notifier).reset();

    if (_isSolo) {
      _startSoloGame();
    } else if (_myPlayerIndex == 0) {
      // Host 生成新卡片排列并发给对手
      final seed = MemoryMatchStateNotifier.generateSeed();
      final opponentName =
          ref.read(memoryMatchStateProvider).opponentName;
      ref.read(memoryMatchStateProvider.notifier).startGame(
        seed: seed,
        isSolo: false,
        selfName: deviceName,
        opponentName: opponentName,
      );
      ref.read(memoryMatchTimerProvider.notifier).start();

      _sendMessage(NetworkMessage(
        type: 'memory_match_board',
        senderId: deviceId,
        payload: {
          'seed': seed,
          'device_name': deviceName,
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    // Guest 不生成卡片排列，等待 Host 发送 memory_match_board
  }
}
