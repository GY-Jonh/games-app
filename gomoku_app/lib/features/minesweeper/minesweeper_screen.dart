import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/minesweeper/constants/minesweeper_constants.dart';
import 'package:gomoku_app/features/minesweeper/minesweeper_providers.dart';
import 'package:gomoku_app/features/minesweeper/minesweeper_timer.dart';
import 'package:gomoku_app/features/minesweeper/widgets/minesweeper_grid.dart';
import 'package:gomoku_app/models/network_message.dart';

class MinesweeperScreen extends ConsumerStatefulWidget {
  final String opponentName;
  final void Function(NetworkMessage) onSendMessage;

  const MinesweeperScreen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
  });

  @override
  ConsumerState<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends ConsumerState<MinesweeperScreen> {
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(minesweeperStateProvider);
    final rematchStatus = ref.watch(minesweeperRematchStatusProvider);
    final timerValue = ref.watch(minesweeperTimerProvider);

    ref.listen<int>(minesweeperTimerProvider, (prev, next) {
      if (prev != null && prev > 0 && next == 0) {
        final gs = ref.read(minesweeperStateProvider);
        if (gs.status == MinesweeperStatus.playing) {
          ref.read(minesweeperStateProvider.notifier).timeout();
          if (!gs.isSolo) {
            widget.onSendMessage(NetworkMessage(
              type: 'minesweeper_game_over',
              senderId: deviceId,
              payload: {'reason': 'timeout'},
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
      }
    });

    ref.listen<MinesweeperState>(minesweeperStateProvider, (prev, next) {
      if (prev?.status == MinesweeperStatus.playing &&
          next.status != MinesweeperStatus.playing) {
        ref.read(minesweeperTimerProvider.notifier).stop();
      }
    });

    ref.listen<bool>(minesweeperAutoExitProvider, (prev, next) {
      if (next == true) {
        ref.read(minesweeperAutoExitProvider.notifier).state = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) navigator.pop();
          }
        });
      }
    });

    ref.listen<String?>(minesweeperToastProvider, (prev, next) {
      if (next != null) {
        ref.read(minesweeperToastProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), duration: const Duration(seconds: 2)),
        );
      }
    });

    if (gameState.status == MinesweeperStatus.playing) {
      ref.read(minesweeperTimerProvider.notifier).startIfNotRunning();
    }

    final isSolo = gameState.isSolo;
    final displayName = isSolo ? '扫雷' : widget.opponentName;

    return PopScope(
      canPop: gameState.status != MinesweeperStatus.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && gameState.status == MinesweeperStatus.playing) {
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
              if (gameState.status == MinesweeperStatus.playing) {
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
    MinesweeperState gameState,
    MinesweeperRematchStatus rematchStatus,
    int timerValue,
  ) {
    if (gameState.status == MinesweeperStatus.loading) {
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

    final flagsUsed = gameState.flagged.length;
    final minesLeft = MinesweeperConstants.mineCount - flagsUsed;

    return Column(
      children: [
        _buildInfoBar(gameState, timerValue, minesLeft),
        Expanded(
          child: MinesweeperGrid(
            mines: gameState.mines,
            revealed: gameState.revealed,
            flagged: gameState.flagged,
            canTap: gameState.status == MinesweeperStatus.playing,
            onTap: (position) {
              final hitMine = ref
                  .read(minesweeperStateProvider.notifier)
                  .reveal(position);

              final newState = ref.read(minesweeperStateProvider);

              if (hitMine && !gameState.isSolo) {
                // 踩雷通知对手
                widget.onSendMessage(NetworkMessage(
                  type: 'minesweeper_hit_mine',
                  senderId: deviceId,
                  payload: {},
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));
              }

              if (!hitMine &&
                  newState.status == MinesweeperStatus.won &&
                  !gameState.isSolo) {
                // 全部翻开通知对手
                widget.onSendMessage(NetworkMessage(
                  type: 'minesweeper_won',
                  senderId: deviceId,
                  payload: {'reveal_count': newState.revealCount},
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));
              }
            },
            onLongPress: (position) {
              ref
                  .read(minesweeperStateProvider.notifier)
                  .toggleFlag(position);
            },
          ),
        ),
        if (gameState.status == MinesweeperStatus.playing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '点击翻开格子，长按插旗标记地雷\n翻开所有安全格即可获胜',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
        if (gameState.status == MinesweeperStatus.won ||
            gameState.status == MinesweeperStatus.lost ||
            gameState.status == MinesweeperStatus.draw ||
            gameState.status == MinesweeperStatus.disconnected)
          _buildGameOverPanel(gameState, rematchStatus),
      ],
    );
  }

  Widget _buildInfoBar(
      MinesweeperState state, int timerValue, int minesLeft) {
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
                '剩余地雷: $minesLeft',
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
    MinesweeperState state,
    MinesweeperRematchStatus rematchStatus,
  ) {
    String title;
    Color titleColor;

    if (state.status == MinesweeperStatus.won) {
      title = '你赢了！';
      titleColor = Colors.green;
    } else if (state.status == MinesweeperStatus.lost) {
      title = '你输了';
      titleColor = Colors.red;
    } else if (state.status == MinesweeperStatus.draw) {
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
            '已翻开: ${state.revealCount} / ${state.totalNonMines}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!state.isSolo &&
                  rematchStatus ==
                      MinesweeperRematchStatus.received) ...[
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
                        .read(minesweeperRematchStatusProvider.notifier)
                        .state = MinesweeperRematchStatus.waiting;
                    widget.onSendMessage(NetworkMessage(
                      type: 'minesweeper_rematch_request',
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
              rematchStatus == MinesweeperRematchStatus.waiting)
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
    MinesweeperState state,
    MinesweeperRematchStatus rematchStatus,
  ) {
    if (state.isSolo) {
      _restartSoloGame();
    } else if (rematchStatus != MinesweeperRematchStatus.waiting) {
      widget.onSendMessage(NetworkMessage(
        type: 'minesweeper_rematch_request',
        senderId: deviceId,
        payload: {'device_name': deviceName},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      ref.read(minesweeperRematchStatusProvider.notifier).state =
          MinesweeperRematchStatus.waiting;
    }
  }

  Future<void> _restartSoloGame() async {
    ref.read(minesweeperStateProvider.notifier).setLoading();
    ref.read(minesweeperTimerProvider.notifier).reset();

    final seed = MinesweeperStateNotifier.generateSeed();
    ref.read(minesweeperStateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(minesweeperTimerProvider.notifier).start();
  }

  void _showExitConfirm(BuildContext context) {
    final isSolo = ref.read(minesweeperStateProvider).isSolo;
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
                  type: 'minesweeper_game_over',
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
