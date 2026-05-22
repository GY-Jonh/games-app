import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/sliding_puzzle/sliding_puzzle_providers.dart';
import 'package:gomoku_app/features/sliding_puzzle/sliding_puzzle_timer.dart';
import 'package:gomoku_app/features/sliding_puzzle/widgets/sliding_puzzle_grid.dart';
import 'package:gomoku_app/models/network_message.dart';

class SlidingPuzzleScreen extends ConsumerStatefulWidget {
  final String opponentName;
  final void Function(NetworkMessage) onSendMessage;

  const SlidingPuzzleScreen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
  });

  @override
  ConsumerState<SlidingPuzzleScreen> createState() =>
      _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends ConsumerState<SlidingPuzzleScreen> {
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(slidingPuzzleStateProvider);
    final rematchStatus = ref.watch(slidingPuzzleRematchStatusProvider);
    final timerValue = ref.watch(slidingPuzzleTimerProvider);

    ref.listen<int>(slidingPuzzleTimerProvider, (prev, next) {
      if (prev != null && prev > 0 && next == 0) {
        final gs = ref.read(slidingPuzzleStateProvider);
        if (gs.status == SlidingPuzzleStatus.playing) {
          ref.read(slidingPuzzleStateProvider.notifier).timeout();
          if (!gs.isSolo) {
            widget.onSendMessage(NetworkMessage(
              type: 'sliding_puzzle_game_over',
              senderId: deviceId,
              payload: {'reason': 'timeout'},
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
      }
    });

    ref.listen<SlidingPuzzleState>(slidingPuzzleStateProvider, (prev, next) {
      if (prev?.status == SlidingPuzzleStatus.playing &&
          next.status != SlidingPuzzleStatus.playing) {
        ref.read(slidingPuzzleTimerProvider.notifier).stop();
      }
    });

    ref.listen<bool>(slidingPuzzleAutoExitProvider, (prev, next) {
      if (next == true) {
        ref.read(slidingPuzzleAutoExitProvider.notifier).state = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) navigator.pop();
          }
        });
      }
    });

    ref.listen<String?>(slidingPuzzleToastProvider, (prev, next) {
      if (next != null) {
        ref.read(slidingPuzzleToastProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), duration: const Duration(seconds: 2)),
        );
      }
    });

    if (gameState.status == SlidingPuzzleStatus.playing) {
      ref.read(slidingPuzzleTimerProvider.notifier).startIfNotRunning();
    }

    final isSolo = gameState.isSolo;
    final displayName = isSolo ? '数字华容道' : widget.opponentName;

    return PopScope(
      canPop: gameState.status != SlidingPuzzleStatus.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && gameState.status == SlidingPuzzleStatus.playing) {
          _showExitConfirm(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          title: Text(displayName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (gameState.status == SlidingPuzzleStatus.playing) {
                _showExitConfirm(context);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: _buildBody(gameState, rematchStatus, timerValue),
        ),
      ),
    );
  }

  Widget _buildBody(
    SlidingPuzzleState gameState,
    SlidingPuzzleRematchStatus rematchStatus,
    int timerValue,
  ) {
    if (gameState.status == SlidingPuzzleStatus.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (!gameState.isSolo) ...[
              const SizedBox(height: 16),
              const Text('等待对方准备...'),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildInfoBar(gameState, timerValue),
        Expanded(
          child: SlidingPuzzleGrid(
            tiles: gameState.tiles,
            canTap: gameState.status == SlidingPuzzleStatus.playing,
            onTap: (position) {
              final moved = ref
                  .read(slidingPuzzleStateProvider.notifier)
                  .moveTile(position);
              if (moved) {
                final newState = ref.read(slidingPuzzleStateProvider);
                if (newState.status == SlidingPuzzleStatus.won &&
                    !gameState.isSolo) {
                  widget.onSendMessage(NetworkMessage(
                    type: 'sliding_puzzle_won',
                    senderId: deviceId,
                    payload: {'move_count': newState.moveCount},
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  ));
                }
              }
            },
          ),
        ),
        if (gameState.status == SlidingPuzzleStatus.playing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '点击空格旁的方块，将其滑入空格\n按 1-15 顺序排列即可获胜',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
        if (gameState.status == SlidingPuzzleStatus.won ||
            gameState.status == SlidingPuzzleStatus.lost ||
            gameState.status == SlidingPuzzleStatus.draw ||
            gameState.status == SlidingPuzzleStatus.disconnected)
          _buildGameOverPanel(gameState, rematchStatus),
      ],
    );
  }

  Widget _buildInfoBar(SlidingPuzzleState state, int timerValue) {
    final minutes = timerValue ~/ 60;
    final seconds = timerValue % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            state.selfName.isNotEmpty ? state.selfName : '己方',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Column(
            children: [
              Text(
                '步数: ${state.moveCount}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: timerValue <= 30 ? Colors.red : Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            state.isSolo
                ? ''
                : (state.opponentName.isNotEmpty
                    ? state.opponentName
                    : '对手'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverPanel(
    SlidingPuzzleState state,
    SlidingPuzzleRematchStatus rematchStatus,
  ) {
    String title;
    Color titleColor;

    if (state.status == SlidingPuzzleStatus.won) {
      title = '你赢了！';
      titleColor = Colors.green;
    } else if (state.status == SlidingPuzzleStatus.lost) {
      title = '你输了';
      titleColor = Colors.red;
    } else if (state.status == SlidingPuzzleStatus.draw) {
      title = '平局';
      titleColor = Colors.orange;
    } else {
      title = '连接断开';
      titleColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '步数: ${state.moveCount}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!state.isSolo &&
                  rematchStatus ==
                      SlidingPuzzleRematchStatus.received) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('接受重赛'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(slidingPuzzleRematchStatusProvider.notifier)
                        .state = SlidingPuzzleRematchStatus.waiting;
                    widget.onSendMessage(NetworkMessage(
                      type: 'sliding_puzzle_rematch_request',
                      senderId: deviceId,
                      payload: {'device_name': deviceName},
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                    ));
                  },
                ),
                const SizedBox(width: 12),
              ] else ...[
                ElevatedButton.icon(
                  icon: Icon(
                    state.isSolo ? Icons.replay : Icons.refresh,
                    size: 18,
                  ),
                  label: Text(state.isSolo ? '再来一局' : '重赛'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () =>
                      _handleRematchAction(state, rematchStatus),
                ),
              ],
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, size: 18),
                label: const Text('退出'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
          if (!state.isSolo &&
              rematchStatus == SlidingPuzzleRematchStatus.waiting)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '等待对方回应...',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  void _handleRematchAction(
    SlidingPuzzleState state,
    SlidingPuzzleRematchStatus rematchStatus,
  ) {
    if (state.isSolo) {
      _restartSoloGame();
    } else if (rematchStatus != SlidingPuzzleRematchStatus.waiting) {
      widget.onSendMessage(NetworkMessage(
        type: 'sliding_puzzle_rematch_request',
        senderId: deviceId,
        payload: {'device_name': deviceName},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      ref.read(slidingPuzzleRematchStatusProvider.notifier).state =
          SlidingPuzzleRematchStatus.waiting;
    }
  }

  Future<void> _restartSoloGame() async {
    ref.read(slidingPuzzleStateProvider.notifier).setLoading();
    ref.read(slidingPuzzleTimerProvider.notifier).reset();

    final seed = SlidingPuzzleStateNotifier.generateSeed();
    ref.read(slidingPuzzleStateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(slidingPuzzleTimerProvider.notifier).start();
  }

  void _showExitConfirm(BuildContext context) {
    final isSolo = ref.read(slidingPuzzleStateProvider).isSolo;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出游戏？'),
        content: Text(isSolo ? '当前进度将丢失。' : '当前游戏将判负。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (!isSolo) {
                widget.onSendMessage(NetworkMessage(
                  type: 'sliding_puzzle_game_over',
                  senderId: deviceId,
                  payload: {'reason': 'quit'},
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));
              }
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
