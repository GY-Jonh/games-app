import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/sliding_puzzle/sliding_puzzle_providers.dart';
import 'package:gomoku_app/features/sliding_puzzle/sliding_puzzle_screen.dart';
import 'package:gomoku_app/features/sliding_puzzle/sliding_puzzle_timer.dart';
import 'package:gomoku_app/models/network_message.dart';

class SlidingPuzzleHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;
  bool _isSolo = false;
  int _myPlayerIndex = 0;

  SlidingPuzzleHandler(this.ref, this._sendMessage);

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
    }
  }

  Future<void> _startSoloGame() async {
    ref.read(slidingPuzzleStateProvider.notifier).setLoading();
    final seed = SlidingPuzzleStateNotifier.generateSeed();
    ref.read(slidingPuzzleStateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(slidingPuzzleTimerProvider.notifier).start();
  }

  void _startPvPAsHost(String opponentName) {
    ref.read(slidingPuzzleStateProvider.notifier).setLoading();
    final seed = SlidingPuzzleStateNotifier.generateSeed();
    ref.read(slidingPuzzleStateProvider.notifier).startGame(
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
    );
    ref.read(slidingPuzzleTimerProvider.notifier).start();

    _sendMessage(NetworkMessage(
      type: 'sliding_puzzle_board',
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
      case 'sliding_puzzle_board':
        _handleBoardMessage(message);
        break;
      case 'sliding_puzzle_won':
        _handleOpponentWon(message);
        break;
      case 'sliding_puzzle_game_over':
        _handleGameOver(message);
        break;
      case 'sliding_puzzle_rematch_request':
        _handleRematchRequest(message);
        break;
      case 'sliding_puzzle_rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  @override
  void handleConnectionLost() {
    ref.read(slidingPuzzleTimerProvider.notifier).stop();
    ref.read(slidingPuzzleRematchStatusProvider.notifier).state =
        SlidingPuzzleRematchStatus.none;

    final gameState = ref.read(slidingPuzzleStateProvider);
    if (gameState.status == SlidingPuzzleStatus.playing) {
      ref.read(slidingPuzzleStateProvider.notifier).handleConnectionLost();
    } else {
      ref.read(slidingPuzzleAutoExitProvider.notifier).state = true;
    }
  }

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return SlidingPuzzleScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
    );
  }

  @override
  void dispose() {
    ref.read(slidingPuzzleTimerProvider.notifier).stop();
    ref.read(slidingPuzzleStateProvider.notifier).resetGame();
    ref.read(slidingPuzzleRematchStatusProvider.notifier).state =
        SlidingPuzzleRematchStatus.none;
    ref.read(slidingPuzzleAutoExitProvider.notifier).state = false;
    ref.read(slidingPuzzleToastProvider.notifier).state = null;
  }

  void _handleBoardMessage(NetworkMessage message) {
    if (ref.read(slidingPuzzleStateProvider).status ==
        SlidingPuzzleStatus.playing) {
      return;
    }

    final seed = message.payload['seed'] as int;
    final opponentName =
        message.payload['device_name'] as String? ?? '对手';

    final tiles = SlidingPuzzleStateNotifier.generateTiles(seed);
    ref.read(slidingPuzzleStateProvider.notifier).startGameWithTiles(
      tiles: tiles,
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
    );
    ref.read(slidingPuzzleTimerProvider.notifier).start();
  }

  void _handleOpponentWon(NetworkMessage message) {
    ref.read(slidingPuzzleStateProvider.notifier).opponentWon();
    ref.read(slidingPuzzleTimerProvider.notifier).stop();
  }

  void _handleGameOver(NetworkMessage message) {
    final reason = message.payload['reason'] as String? ?? 'unknown';
    if (reason == 'quit' || reason == 'disconnect') {
      ref.read(slidingPuzzleStateProvider.notifier).handleConnectionLost();
    } else if (reason == 'timeout') {
      ref.read(slidingPuzzleStateProvider.notifier).opponentTimeout();
    }
    ref.read(slidingPuzzleTimerProvider.notifier).stop();
  }

  void _handleRematchRequest(NetworkMessage message) {
    if (ref.read(slidingPuzzleStateProvider).status ==
        SlidingPuzzleStatus.playing) {
      return;
    }

    if (ref.read(slidingPuzzleRematchStatusProvider) ==
        SlidingPuzzleRematchStatus.waiting) {
      _sendMessage(NetworkMessage(
        type: 'sliding_puzzle_rematch_response',
        senderId: deviceId,
        payload: {'accepted': true},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      _restartGame();
    } else {
      ref.read(slidingPuzzleRematchStatusProvider.notifier).state =
          SlidingPuzzleRematchStatus.received;
      ref.read(slidingPuzzleToastProvider.notifier).state = '对方请求了重赛';
    }
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted = message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      _restartGame();
    } else {
      ref.read(slidingPuzzleRematchStatusProvider.notifier).state =
          SlidingPuzzleRematchStatus.none;
      ref.read(slidingPuzzleToastProvider.notifier).state = '对方拒绝了重开请求';
    }
  }

  void _restartGame() {
    ref.read(slidingPuzzleStateProvider.notifier).incrementRound();
    ref.read(slidingPuzzleRematchStatusProvider.notifier).state =
        SlidingPuzzleRematchStatus.none;
    ref.read(slidingPuzzleTimerProvider.notifier).reset();

    if (_isSolo) {
      _startSoloGame();
    } else if (_myPlayerIndex == 0) {
      final seed = SlidingPuzzleStateNotifier.generateSeed();
      final opponentName =
          ref.read(slidingPuzzleStateProvider).opponentName;
      ref.read(slidingPuzzleStateProvider.notifier).startGame(
        seed: seed,
        isSolo: false,
        selfName: deviceName,
        opponentName: opponentName,
      );
      ref.read(slidingPuzzleTimerProvider.notifier).start();

      _sendMessage(NetworkMessage(
        type: 'sliding_puzzle_board',
        senderId: deviceId,
        payload: {
          'seed': seed,
          'device_name': deviceName,
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }
}
