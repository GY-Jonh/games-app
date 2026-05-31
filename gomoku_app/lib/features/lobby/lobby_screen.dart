import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/constants/app_constants.dart';
import 'package:gomoku_app/core/constants/game_constants.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/invitation/widgets/incoming_invitation_sheet.dart';
import 'package:gomoku_app/features/invitation/widgets/outgoing_invitation_overlay.dart';
import 'package:gomoku_app/features/lobby/widgets/empty_state_widget.dart';
import 'package:gomoku_app/features/lobby/widgets/local_device_card.dart';
import 'package:gomoku_app/features/lobby/widgets/peer_list_tile.dart';
import 'package:gomoku_app/models/network_message.dart';
import 'package:gomoku_app/models/peer_device.dart';
import 'package:gomoku_app/providers/connection_providers.dart';
import 'package:gomoku_app/providers/invitation_providers.dart';
import 'package:gomoku_app/providers/mdns_providers.dart';
import 'package:gomoku_app/providers/player_providers.dart';
import 'package:gomoku_app/services/connection_manager.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with SingleTickerProviderStateMixin {
  late final ConnectionManager _connectionManager;
  Timer? _cleanupTimer;
  Timer? _inviteTimer;
  bool _isInitialized = false;
  bool _isAccepting = false;
  GameHandler? _activeHandler;

  // 单人游戏面板
  bool _showSoloPanel = false;
  late final AnimationController _soloPanelController;

  @override
  void initState() {
    super.initState();
    _connectionManager = ConnectionManager();
    _soloPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initServices();
  }

  Future<void> _initServices() async {
    final mdns = ref.read(mDnsServiceProvider);

    // Start WebSocket server
    final port = await _connectionManager.startServer();
    mdns.setServerPort(port);

    // Refresh device name for the port update
    await mdns.start();

    ref.read(serverPortProvider.notifier).state = port;
    ref.read(mDnsStatusProvider.notifier).state = MDnsStatus.running;

    // Listen for incoming connections
    _connectionManager.onMessage.listen((message) {
      _handleMessage(message);
    });

    // Listen for peer discovery
    mdns.onPeerFound.listen((peer) {
      ref.read(discoveredPeersProvider.notifier).addOrUpdatePeer(peer);
    });

    // Cleanup expired peers
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(discoveredPeersProvider.notifier).cleanupExpiredPeers();
    });

    setState(() => _isInitialized = true);
  }

  void _handleMessage(NetworkMessage message) {
    switch (message.type) {
      // --- 通用邀请消息（在大厅处理）---
      case 'game_invite':
        final gameType = message.payload['game_type'] as String? ?? 'gomoku';
        final name = message.payload['device_name'] as String? ?? 'Unknown';
        ref.read(invitationStateProvider.notifier)
            .receiveInvite(message.senderId, name, gameType: gameType);
        break;

      case 'invite_accepted':
        _inviteTimer?.cancel();
        ref.read(invitationStateProvider.notifier).accept();
        final gameType = ref.read(invitationStateProvider.notifier).gameType ?? 'gomoku';
        // 兼容旧协议：yourPlayer (新) 或 yourColor (旧)
        final myPlayerIndex = message.payload['your_player'] as int?;
        final opponentName = ref.read(invitationStateProvider.notifier).toPeerName ?? '对手';

        _activeHandler = GameRegistry.createHandler(
          gameType,
          ref,
          (msg) => _connectionManager.send(msg),
        );
        if (myPlayerIndex != null) {
          _activeHandler!.initGame(
            myPlayerIndex: myPlayerIndex,
            opponentName: opponentName,
          );
        } else {
          // 旧协议向后兼容
          _initHandlerWithLegacyColor(message, opponentName);
        }
        _navigateToGame();
        break;

      case 'invite_declined':
        _inviteTimer?.cancel();
        ref.read(invitationStateProvider.notifier).decline();
        _showSnackBar('对方拒绝了邀请');
        break;

      case 'invite_cancelled':
        _inviteTimer?.cancel();
        ref.read(invitationStateProvider.notifier).reset();
        _showSnackBar('对方取消了邀请');
        break;

      // --- 游戏专用消息（委托给活跃 handler）---
      case 'game_move':
      case 'game_over':
      case 'rematch_request':
      case 'rematch_response':
        _activeHandler?.handleMessage(message);
        break;

      case 'connection_lost':
        // 重置通用邀请状态
        ref.read(invitationStateProvider.notifier).reset();
        // 委托给游戏 handler
        _activeHandler?.handleConnectionLost();
        break;

      default:
        // 游戏专用消息（spot_diff_* 等）路由给 handler
        _activeHandler?.handleMessage(message);
        break;
    }
  }

  /// 旧协议兼容：从 yourColor 字段推断 myPlayerIndex
  void _initHandlerWithLegacyColor(
      NetworkMessage message, String opponentName) {
    final legacyColor = message.payload['yourColor'] as String? ?? 'black';
    // 旧协议中邀请方执黑先手，被邀请方收到 yourColor 为己方颜色
    final myStoneIsBlack = legacyColor == 'black';
    _activeHandler!.initGame(
      myPlayerIndex: myStoneIsBlack ? 0 : 1,
      opponentName: opponentName,
    );
  }

  void _navigateToGame() {
    final opponentName =
        ref.read(invitationStateProvider.notifier).fromPeerName ??
        ref.read(invitationStateProvider.notifier).toPeerName ??
        '对手';

    // 更新 mDNS 广播为游戏中
    ref.read(mDnsServiceProvider).setGameStatus('playing');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _activeHandler!.buildScreen(
          opponentName: opponentName,
          onSendMessage: (message) => _connectionManager.send(message),
        ),
      ),
    ).then((_) {
      // 恢复 mDNS 为空闲状态
      ref.read(mDnsServiceProvider).setGameStatus('idle');
      _activeHandler?.dispose();
      _activeHandler = null;
      ref.read(invitationStateProvider.notifier).reset();
      ref.read(connectionStatusProvider.notifier).state =
          ConnectionStatus.idle;
      _connectionManager.disconnect();
      _isAccepting = false;
      _inviteTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _inviteTimer?.cancel();
    _soloPanelController.dispose();
    ref.read(mDnsServiceProvider).stop();
    _connectionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(discoveredPeersProvider);
    final serverPort = ref.watch(serverPortProvider);
    final invitationState = ref.watch(invitationStateProvider);
    final playerName = ref.watch(playerNameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_isInitialized) {
                ref.read(mDnsServiceProvider).stop();
                ref.read(mDnsServiceProvider).start();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              LocalDeviceCard(
                deviceName: playerName,
                serverPort: serverPort,
                isServerRunning: true,
                onEditName: () => _showEditNameDialog(),
              ),
              // 单人游戏入口
              _buildSoloEntry(),
              // 在线玩家区域
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '在线玩家',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.onlineGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${peers.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onlineGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: peers.isEmpty
                    ? const EmptyStateWidget(isSearching: true)
                    : ListView.builder(
                        itemCount: peers.length,
                        itemBuilder: (context, index) {
                          final peer = peers[index];
                          return PeerListTile(
                            peer: peer,
                            isInviting: invitationState ==
                                    InvitationState.outgoing &&
                                ref
                                        .read(invitationStateProvider
                                            .notifier)
                                        .toPeerId ==
                                    peer.id,
                            onInvite: () {
                              _invitePeer(peer);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          // 单人游戏右侧弹出面板
          if (_showSoloPanel) _buildSoloOverlay(),
        ],
      ),
      bottomSheet: invitationState == InvitationState.incoming
          ? IncomingInvitationSheet(
              peerName:
                  ref.read(invitationStateProvider.notifier).fromPeerName ?? '对方',
              gameType:
                  ref.read(invitationStateProvider.notifier).gameType ?? 'gomoku',
              onAccept: () {
                if (_isAccepting) return;
                _isAccepting = true;

                final gameType =
                    ref.read(invitationStateProvider.notifier).gameType ?? 'gomoku';
                // 通知邀请方：接受
                _connectionManager.send(NetworkMessage(
                  type: 'invite_accepted',
                  senderId: deviceId,
                  payload: {
                    'device_name': deviceName,
                    'your_player': 0,
                  },
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));

                ref.read(invitationStateProvider.notifier).accept();
                _activeHandler = GameRegistry.createHandler(
                  gameType,
                  ref,
                  (msg) => _connectionManager.send(msg),
                );
                _activeHandler!.initGame(
                  myPlayerIndex: 1, // 被邀请方后手（执白）
                  opponentName:
                      ref.read(invitationStateProvider.notifier).fromPeerName ?? '对手',
                );
                _navigateToGame();
              },
              onDecline: () {
                _inviteTimer?.cancel();
                // 通知邀请方：拒绝
                _connectionManager.send(NetworkMessage(
                  type: 'invite_declined',
                  senderId: deviceId,
                  payload: {'device_name': deviceName},
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));

                ref.read(invitationStateProvider.notifier).decline();
                _showSnackBar('已拒绝邀请');
              },
            )
          : invitationState == InvitationState.outgoing
              ? OutgoingInvitationOverlay(
                  peerName: ref
                          .read(invitationStateProvider.notifier)
                          .toPeerName ??
                      '对方',
                  onCancel: () {
                    _inviteTimer?.cancel();
                    // 通知对方取消邀请
                    _connectionManager.send(NetworkMessage(
                      type: 'invite_cancelled',
                      senderId: deviceId,
                      payload: {'device_name': deviceName},
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                    ));
                    ref.read(invitationStateProvider.notifier).cancel();
                    _connectionManager.disconnect();
                  },
                )
              : null,
    );
  }

  void _invitePeer(PeerDevice peer) {
    // 弹出游戏选择面板
    _showGamePicker(
      context,
      onSelect: (gameId) {
        ref.read(invitationStateProvider.notifier)
            .sendInvite(peer.id, peer.name, gameType: gameId);

        // 设置邀请超时（30秒）
        _inviteTimer?.cancel();
        _inviteTimer = Timer(const Duration(seconds: 30), () {
          if (ref.read(invitationStateProvider) == InvitationState.outgoing) {
            ref.read(invitationStateProvider.notifier).reset();
            _connectionManager.disconnect();
            _showSnackBar('邀请超时：${peer.name} 未响应');
          }
        });

        _connectionManager.connectToPeer(peer.ip, peer.port).then((success) {
          if (success) {
            _connectionManager.send(NetworkMessage(
              type: 'game_invite',
              senderId: deviceId,
              payload: {
                'device_name': deviceName,
                'game_type': gameId,
              },
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          } else {
            _inviteTimer?.cancel();
            _showSnackBar('无法连接到 ${peer.name}');
            ref.read(invitationStateProvider.notifier).reset();
          }
        });
      },
    );
  }

  void _showGamePicker(BuildContext context, {required void Function(String) onSelect}) {
    final games = GameRegistry.getAll();
    if (games.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  '选择游戏',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 游戏列表 (可滚动, 防止条目过多时被裁剪)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: games.map((game) => ListTile(
                        leading: Icon(game.icon, color: AppTheme.primaryColor),
                        title: Text(
                          game.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: game.subtitle.isNotEmpty
                            ? Text(game.subtitle,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                            : null,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onSelect(game.id);
                        },
                      )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单人游戏入口按钮
  Widget _buildSoloEntry() {
    final soloGames = _getSoloGames();
    if (soloGames.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openSoloPanel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.videogame_asset,
                  color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 10),
              Text(
                '单人游戏',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${soloGames.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  /// 右侧滑入的单人游戏面板
  Widget _buildSoloOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _soloPanelController,
        builder: (context, child) {
          // 背景遮罩
          final scrimOpacity = _soloPanelController.value * 0.4;
          return Stack(
            children: [
              // 遮罩
              if (scrimOpacity > 0)
                GestureDetector(
                  onTap: _closeSoloPanel,
                  child: Container(
                    color: Colors.black.withValues(alpha: scrimOpacity),
                  ),
                ),
              // 面板 (右侧滑入)
              Align(
                alignment: Alignment.centerRight,
                child: FractionalTranslation(
                  translation: Offset(
                      1.0 - _soloPanelController.value, 0.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: double.infinity,
                    child: Material(
                      color: Colors.white,
                      elevation: 8,
                      child: _buildSoloPanelContent(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 面板内容
  Widget _buildSoloPanelContent() {
    final soloGames = _getSoloGames();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部栏
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: _closeSoloPanel,
                ),
                const Expanded(
                  child: Text(
                    '单人游戏',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 游戏列表
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: soloGames.map((game) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(game.icon,
                        color: AppTheme.primaryColor, size: 22),
                  ),
                  title: Text(
                    game.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: game.subtitle.isNotEmpty
                      ? Text(game.subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600))
                      : null,
                  trailing: const Icon(Icons.play_arrow_rounded,
                      color: AppTheme.primaryColor, size: 28),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  onTap: () {
                    _closeSoloPanel();
                    // 等面板关闭动画完成后再跳转
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) _startSoloGame(game.id);
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _openSoloPanel() {
    setState(() => _showSoloPanel = true);
    _soloPanelController.forward();
  }

  void _closeSoloPanel() {
    _soloPanelController.reverse().then((_) {
      if (mounted) setState(() => _showSoloPanel = false);
    });
  }

  /// 返回支持单人模式的游戏
  List<GameDefinition> _getSoloGames() {
    const soloGameIds = {'spot_diff', 'lights_out', 'memory_match', 'game_2048', 'sliding_puzzle', 'minesweeper', 'tank_battle', 'zha_jinhua'};
    return GameRegistry.getAll().where((g) => soloGameIds.contains(g.id)).toList();
  }

  /// 启动单人游戏
  void _startSoloGame(String gameId) {
    final handler = GameRegistry.createHandler(
      gameId,
      ref,
      (_) {}, // 单人模式：发送消息为空操作
    );
    _activeHandler = handler;
    handler.initGame(
      myPlayerIndex: 0,
      opponentName: '', // 空 = 单人模式
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => handler.buildScreen(
          opponentName: '',
          onSendMessage: (_) {},
        ),
      ),
    ).then((_) {
      _activeHandler?.dispose();
      _activeHandler = null;
    });
  }

  void _showEditNameDialog() {
    final controller =
        TextEditingController(text: ref.read(playerNameProvider));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入你的昵称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(playerNameProvider.notifier).state = name;
                setCustomDeviceName(name);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
