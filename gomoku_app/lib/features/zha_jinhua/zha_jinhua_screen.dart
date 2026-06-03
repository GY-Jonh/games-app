/// 炸金花主界面。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/zha_jinhua/constants/zha_jinhua_constants.dart';
import 'package:gomoku_app/features/zha_jinhua/models/zha_jinhua_state.dart';
import 'package:gomoku_app/features/zha_jinhua/zha_jinhua_providers.dart';
import 'package:gomoku_app/features/zha_jinhua/widgets/zhajinhua_action_buttons.dart';
import 'package:gomoku_app/features/zha_jinhua/widgets/zhajinhua_opponent_area.dart';
import 'package:gomoku_app/features/zha_jinhua/widgets/zhajinhua_player_area.dart';
import 'package:gomoku_app/features/zha_jinhua/widgets/zhajinhua_result_overlay.dart';
import 'package:gomoku_app/models/network_message.dart';

class ZhaJinhuaScreen extends ConsumerStatefulWidget {
  final String opponentName;
  final void Function(NetworkMessage) onSendMessage;
  final int myPlayerIndex;

  const ZhaJinhuaScreen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
    required this.myPlayerIndex,
  });

  @override
  ConsumerState<ZhaJinhuaScreen> createState() => _ZhaJinhuaScreenState();
}

class _ZhaJinhuaScreenState extends ConsumerState<ZhaJinhuaScreen> {
  bool get isSolo => widget.opponentName.isEmpty;

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(zhaJinhuaStateProvider);

    // 监听自动退出
    ref.listen<bool>(zhaJinhuaAutoExitProvider, (prev, next) {
      if (next) {
        ref.read(zhaJinhuaAutoExitProvider.notifier).state = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
      }
    });

    // 监听 Toast
    ref.listen<String?>(zhaJinhuaToastProvider, (prev, next) {
      if (next != null) {
        ref.read(zhaJinhuaToastProvider.notifier).state = null;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next), duration: const Duration(seconds: 2)),
          );
        }
      }
    });

    // Loading
    if (gameState.status == ZhaJinhuaGameStatus.loading) {
      return _buildScaffold(
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('发牌中...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    final showOverlay =
        gameState.phase == ZhaJinhuaPhase.roundEnd ||
        gameState.phase == ZhaJinhuaPhase.gameOver ||
        gameState.status == ZhaJinhuaGameStatus.disconnected;

    return _buildScaffold(
      body: Stack(
        children: [
          // 主游戏布局
          Column(
            children: [
              // 对手区域
              ZhaJinhuaOpponentArea(
                cards: gameState.opponentCards,
                faceDown: !gameState.opponentCardsRevealed,
                hasPeeked: gameState.opponentPeeked,
                name: isSolo ? 'AI对手' : widget.opponentName,
                chips: gameState.opponentChips,
              ),

              // 中间区域：底池 + 状态
              Expanded(
                child: Container(
                  color: const Color(0xFF2E7D32), // 中绿色
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 底池
                        Text(
                          '底池',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${gameState.pot}',
                          style: TextStyle(
                            color: Colors.amber.shade300,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '筹码',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 回合信息
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _turnText(gameState),
                            style: TextStyle(
                              color: _turnColor(gameState),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 第 N 回合
                        Text(
                          '第 ${gameState.roundNumber} 回合',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),

                        // 当前注额
                        if (gameState.currentBet > 0 &&
                            gameState.status == ZhaJinhuaGameStatus.playing)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '当前注: ${gameState.currentBet}',
                              style: TextStyle(
                                color: Colors.orange.shade300,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 玩家区域
              ZhaJinhuaPlayerArea(
                cards: gameState.playerCards,
                faceDown: !gameState.playerCardsRevealed,
                hasPeeked: gameState.playerPeeked,
                name: isSolo ? '你' : deviceName,
                chips: gameState.playerChips,
                onPeek: () => _handleAction('peek'),
              ),

              // 操作按钮
              if (gameState.status == ZhaJinhuaGameStatus.playing)
                ZhaJinhuaActionButtons(
                  canCall: gameState.canCall,
                  canRaise: gameState.canRaise,
                  canCompare: gameState.canCompare,
                  isEnabled: _isMyTurn(gameState),
                  callAmount: gameState.currentBet,
                  raiseAmount: gameState.currentBet +
                      ZhaJinhuaConstants.raiseIncrement,
                  onPeek: () => _handleAction('peek'),
                  onCall: () => _handleAction('call'),
                  onRaise: () => _handleAction('raise'),
                  onFold: () => _handleAction('fold'),
                  onCompare: () => _handleAction('compare'),
                ),
            ],
          ),

          // 结果覆盖层
          if (showOverlay)
            ZhaJinhuaResultOverlay(
              status: gameState.status,
              playerCards: gameState.playerCards,
              opponentCards: gameState.opponentCards,
              playerCardsRevealed: gameState.playerCardsRevealed,
              opponentCardsRevealed: gameState.opponentCardsRevealed,
              resultMessage: gameState.resultMessage,
              canContinue: _canContinue(gameState),
              playerChips: gameState.playerChips,
              opponentChips: gameState.opponentChips,
              isSolo: isSolo,
              onNextRound: () => _handleNextRound(gameState),
              onQuit: () => _quitGame(gameState),
            ),
        ],
      ),
    );
  }

  Widget _buildScaffold({required Widget body}) {
    return PopScope(
      canPop: !(ref.read(zhaJinhuaStateProvider).status ==
          ZhaJinhuaGameStatus.playing),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirm(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1B5E20), // 赌桌绿
        appBar: AppBar(
          toolbarHeight: 36,
          backgroundColor: const Color(0xFF2E7D32), // 深绿色
          title: Text(
            isSolo ? '炸金花' : widget.opponentName,
            style: const TextStyle(fontSize: 15),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () {
              final status = ref.read(zhaJinhuaStateProvider).status;
              if (status == ZhaJinhuaGameStatus.playing) {
                _showExitConfirm(context);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: body,
      ),
    );
  }

  // ========== 动作处理 ==========

  bool _isMyTurn(ZhaJinhuaState state) {
    if (state.phase != ZhaJinhuaPhase.playerTurn) return false;
    if (state.status != ZhaJinhuaGameStatus.playing) return false;
    return state.turnPlayerIndex == 0;
  }

  void _handleAction(String action) {
    if (isSolo || widget.myPlayerIndex == 0) {
      // Solo 或 PvP Host: 直接执行
      _executeLocalAction(action);
    } else {
      // PvP Guest: 发送给 Host
      widget.onSendMessage(NetworkMessage(
        type: 'zha_jinhua_player_action',
        senderId: deviceId,
        payload: {'action': action},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      // 立即禁用按钮，防止重复点击
      ref.read(zhaJinhuaStateProvider.notifier)
          .setGuestPendingPhase(ZhaJinhuaPhase.opponentTurn);
    }
  }

  void _executeLocalAction(String action) {
    final notifier = ref.read(zhaJinhuaStateProvider.notifier);
    switch (action) {
      case 'peek':
        notifier.playerPeek();
        break;
      case 'call':
        notifier.playerCall();
        break;
      case 'raise':
        notifier.playerRaise();
        break;
      case 'fold':
        notifier.playerFold();
        break;
      case 'compare':
        notifier.playerCompare();
        break;
    }

    // Solo: 自动处理 AI 轮到
    // PvP Host: handler 的 onActionNeeded 回调会发送给 Guest
  }

  // ========== 回合/游戏操作 ==========

  bool _canContinue(ZhaJinhuaState state) {
    // PvP 中只有 Host 能发起新回合，Guest 等待 Host 发牌
    if (!isSolo && widget.myPlayerIndex != 0) return false;
    return state.phase == ZhaJinhuaPhase.roundEnd &&
        state.playerChips > ZhaJinhuaConstants.anteAmount &&
        state.opponentChips > ZhaJinhuaConstants.anteAmount &&
        state.status != ZhaJinhuaGameStatus.disconnected;
  }

  void _handleNextRound(ZhaJinhuaState state) {
    if (isSolo || widget.myPlayerIndex == 0) {
      ref.read(zhaJinhuaStateProvider.notifier).startNewRound();
    }
    // Guest: 等待 Host 发送回合开始
  }

  void _quitGame(ZhaJinhuaState gameState) {
    if (!isSolo && gameState.status == ZhaJinhuaGameStatus.playing) {
      widget.onSendMessage(NetworkMessage(
        type: 'zha_jinhua_game_over',
        senderId: deviceId,
        payload: {'reason': 'quit', 'winner': 1},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    Navigator.of(context).pop();
  }

  // ========== 状态文本 ==========

  String _turnText(ZhaJinhuaState state) {
    if (state.status != ZhaJinhuaGameStatus.playing) {
      return '';
    }
    if (state.phase == ZhaJinhuaPhase.opponentTurn) {
      return isSolo ? 'AI 思考中...' : '${widget.opponentName} 操作中...';
    }
    if (state.turnPlayerIndex == 0 && state.phase == ZhaJinhuaPhase.playerTurn) {
      return '轮到你了';
    }
    return '等待中...';
  }

  Color _turnColor(ZhaJinhuaState state) {
    if (state.status != ZhaJinhuaGameStatus.playing) return Colors.white70;
    if (state.turnPlayerIndex == 0 && state.phase == ZhaJinhuaPhase.playerTurn) {
      return Colors.green.shade300;
    }
    if (state.phase == ZhaJinhuaPhase.opponentTurn) {
      return Colors.orange.shade300;
    }
    return Colors.white70;
  }

  // ========== 退出确认 ==========

  void _showExitConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('退出游戏？', style: TextStyle(color: Colors.white)),
        content: Text(
          '当前游戏将判负。',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (!isSolo) {
                widget.onSendMessage(NetworkMessage(
                  type: 'zha_jinhua_game_over',
                  senderId: deviceId,
                  payload: {'reason': 'quit', 'winner': 1},
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
