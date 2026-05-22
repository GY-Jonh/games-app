import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/memory_match/constants/memory_match_constants.dart';
import 'package:gomoku_app/features/memory_match/memory_match_providers.dart';
import 'package:gomoku_app/features/memory_match/memory_match_timer.dart';
import 'package:gomoku_app/features/memory_match/widgets/memory_match_card.dart';
import 'package:gomoku_app/models/network_message.dart';

class MemoryMatchScreen extends ConsumerStatefulWidget {
  final String opponentName;
  final void Function(NetworkMessage) onSendMessage;

  const MemoryMatchScreen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
  });

  @override
  ConsumerState<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends ConsumerState<MemoryMatchScreen> {
  /// 是否正在等待两张卡片的校验结果
  bool _isAwaitingResolution = false;

  /// 校验延迟计时器
  Timer? _resolveTimer;

  @override
  void dispose() {
    _resolveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(memoryMatchStateProvider);
    final rematchStatus = ref.watch(memoryMatchRematchStatusProvider);
    final timerValue = ref.watch(memoryMatchTimerProvider);

    // 计时归零 → timeout
    ref.listen<int>(memoryMatchTimerProvider, (prev, next) {
      if (prev != null && prev > 0 && next == 0) {
        final gs = ref.read(memoryMatchStateProvider);
        if (gs.status == MemoryMatchGameStatus.playing) {
          ref.read(memoryMatchStateProvider.notifier).timeout();
          if (!gs.isSolo) {
            widget.onSendMessage(NetworkMessage(
              type: 'memory_match_game_over',
              senderId: deviceId,
              payload: {'reason': 'timeout'},
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
      }
    });

    // 游戏结束时停定时器
    ref.listen<MemoryMatchState>(memoryMatchStateProvider, (prev, next) {
      if (prev?.status == MemoryMatchGameStatus.playing &&
          next.status != MemoryMatchGameStatus.playing) {
        ref.read(memoryMatchTimerProvider.notifier).stop();
        _resolveTimer?.cancel();
        _isAwaitingResolution = false;
      }
    });

    // 自动退出监听
    ref.listen<bool>(memoryMatchAutoExitProvider, (prev, next) {
      if (next == true) {
        ref.read(memoryMatchAutoExitProvider.notifier).state = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
          }
        });
      }
    });

    // Toast 监听
    ref.listen<String?>(memoryMatchToastProvider, (prev, next) {
      if (next != null) {
        ref.read(memoryMatchToastProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    // 进入 playing 状态时启动计时器
    if (gameState.status == MemoryMatchGameStatus.playing) {
      ref.read(memoryMatchTimerProvider.notifier).startIfNotRunning();
    }

    final isSolo = gameState.isSolo;
    final displayName = isSolo ? '记忆翻牌' : widget.opponentName;

    return PopScope(
      canPop: gameState.status != MemoryMatchGameStatus.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && gameState.status == MemoryMatchGameStatus.playing) {
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
              if (gameState.status == MemoryMatchGameStatus.playing) {
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
    MemoryMatchState gameState,
    MemoryMatchRematchStatus rematchStatus,
    int timerValue,
  ) {
    if (gameState.status == MemoryMatchGameStatus.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (!gameState.isSolo) ...[
              const SizedBox(height: 16),
              const Text('等待对方准备卡牌...'),
            ],
          ],
        ),
      );
    }

    final matchedCount = gameState.matchedPositions.length ~/ 2;
    final totalPairs = MemoryMatchConstants.pairCount;

    return Column(
      children: [
        // 信息栏
        _buildInfoBar(gameState, timerValue, matchedCount, totalPairs),
        // 卡片网格
        Expanded(
          child: _buildCardGrid(gameState),
        ),
        // 操作提示
        if (gameState.status == MemoryMatchGameStatus.playing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '翻开两张卡片，图案相同则配对成功\n将所有卡片配对即可获胜',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
        // 底部弹窗（游戏结束）
        if (gameState.status == MemoryMatchGameStatus.won ||
            gameState.status == MemoryMatchGameStatus.lost ||
            gameState.status == MemoryMatchGameStatus.draw ||
            gameState.status == MemoryMatchGameStatus.disconnected)
          _buildGameOverPanel(gameState, rematchStatus),
      ],
    );
  }

  Widget _buildInfoBar(
    MemoryMatchState state,
    int timerValue,
    int matchedCount,
    int totalPairs,
  ) {
    final minutes = timerValue ~/ 60;
    final seconds = timerValue % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 己方
          Text(
            state.selfName.isNotEmpty ? state.selfName : '己方',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          // 中间：配对数 + 时间 + 操作次数
          Column(
            children: [
              Text(
                '配对 $matchedCount / $totalPairs · ${state.moveCount} 步',
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
          // 对方
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

  Widget _buildCardGrid(MemoryMatchState state) {
    final totalCards = MemoryMatchConstants.totalCards;
    final columns = MemoryMatchConstants.gridColumns;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: totalCards,
          itemBuilder: (context, index) {
            final isFaceUp = state.isRevealed(index);
            final isMatched = state.isMatched(index);

            return MemoryMatchCard(
              symbol: state.getSymbol(index),
              isFaceUp: isFaceUp,
              isMatched: isMatched,
              canTap: state.status == MemoryMatchGameStatus.playing &&
                  !_isAwaitingResolution,
              onTap: () => _onCardTap(state, index),
            );
          },
        ),
      ),
    );
  }

  void _onCardTap(MemoryMatchState state, int position) {
    // 双击防连点
    if (_isAwaitingResolution) return;
    if (state.status != MemoryMatchGameStatus.playing) return;
    if (state.isMatched(position)) return;

    final isSecondSelection =
        ref.read(memoryMatchStateProvider.notifier).selectCard(position);

    if (isSecondSelection) {
      // 两张卡片已翻开，进入等待校验阶段
      setState(() => _isAwaitingResolution = true);

      _resolveTimer?.cancel();
      _resolveTimer = Timer(
        Duration(milliseconds: MemoryMatchConstants.revealDelayMs),
        () {
          if (!mounted) return;

          final currentState = ref.read(memoryMatchStateProvider);
          // 检查是否仍在 playing 状态（防止超时/断线干扰）
          if (currentState.status != MemoryMatchGameStatus.playing) {
            setState(() => _isAwaitingResolution = false);
            return;
          }

          final matched =
              ref.read(memoryMatchStateProvider.notifier).resolveSelection();

          if (matched && !currentState.isSolo) {
            // 检查是否全部配对完成 → 获胜
            final newState = ref.read(memoryMatchStateProvider);
            if (newState.status == MemoryMatchGameStatus.won) {
              widget.onSendMessage(NetworkMessage(
                type: 'memory_match_won',
                senderId: deviceId,
                payload: {
                  'move_count': newState.moveCount,
                },
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
            }
          }

          setState(() => _isAwaitingResolution = false);
        },
      );
    }
  }

  Widget _buildGameOverPanel(
    MemoryMatchState state,
    MemoryMatchRematchStatus rematchStatus,
  ) {
    String title;
    Color titleColor;

    if (state.status == MemoryMatchGameStatus.won) {
      title = '你赢了！';
      titleColor = Colors.green;
    } else if (state.status == MemoryMatchGameStatus.lost) {
      title = '你输了';
      titleColor = Colors.red;
    } else if (state.status == MemoryMatchGameStatus.draw) {
      title = '平局';
      titleColor = Colors.orange;
    } else {
      title = '连接断开';
      titleColor = Colors.grey;
    }

    final matchedCount = state.matchedPositions.length ~/ 2;
    final totalPairs = MemoryMatchConstants.pairCount;

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
            '配对 $matchedCount / $totalPairs · ${state.moveCount} 步',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!state.isSolo &&
                  rematchStatus == MemoryMatchRematchStatus.received) ...[
                // 收到对方重赛请求：接受 / 拒绝
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
                        .read(memoryMatchRematchStatusProvider.notifier)
                        .state = MemoryMatchRematchStatus.waiting;
                    widget.onSendMessage(NetworkMessage(
                      type: 'memory_match_rematch_request',
                      senderId: deviceId,
                      payload: {'device_name': deviceName},
                      timestamp:
                          DateTime.now().millisecondsSinceEpoch,
                    ));
                  },
                ),
                const SizedBox(width: 12),
              ] else ...[
                // 再来一局 / 重赛按钮
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
              // 退出
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, size: 18),
                label: const Text('退出'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          if (!state.isSolo &&
              rematchStatus == MemoryMatchRematchStatus.waiting)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '等待对方回应...',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  void _handleRematchAction(
    MemoryMatchState state,
    MemoryMatchRematchStatus rematchStatus,
  ) {
    if (state.isSolo) {
      _restartSoloGame();
    } else if (rematchStatus != MemoryMatchRematchStatus.waiting) {
      // 防止按钮连点发送重复请求
      widget.onSendMessage(NetworkMessage(
        type: 'memory_match_rematch_request',
        senderId: deviceId,
        payload: {'device_name': deviceName},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      ref.read(memoryMatchRematchStatusProvider.notifier).state =
          MemoryMatchRematchStatus.waiting;
    }
  }

  Future<void> _restartSoloGame() async {
    _resolveTimer?.cancel();
    _isAwaitingResolution = false;

    ref.read(memoryMatchStateProvider.notifier).setLoading();
    ref.read(memoryMatchTimerProvider.notifier).reset();

    final seed = MemoryMatchStateNotifier.generateSeed();
    ref.read(memoryMatchStateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(memoryMatchTimerProvider.notifier).start();
  }

  void _showExitConfirm(BuildContext context) {
    final isSolo = ref.read(memoryMatchStateProvider).isSolo;
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
                  type: 'memory_match_game_over',
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
