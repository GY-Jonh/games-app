import 'dart:async';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/models/network_message.dart';
import 'package:gomoku_app/services/websocket_client.dart';
import 'package:gomoku_app/services/websocket_server.dart';

class ConnectionManager {
  final WebSocketServer _server;
  WebSocketClient? _client;
  final StreamController<NetworkMessage> _messageController =
      StreamController<NetworkMessage>.broadcast();
  bool _isConnected = false;
  bool _isInitiator = false;

  Stream<NetworkMessage> get onMessage => _messageController.stream;
  bool get isConnected => _isConnected;
  bool get hasActiveConnection => _client?.isConnected ?? false;
  WebSocketServer get server => _server;

  ConnectionManager() : _server = WebSocketServer();

  Future<int> startServer({int? preferredPort}) async {
    final port = await _server.start(preferredPort: preferredPort);
    _server.onMessage.listen((message) {
      _messageController.add(message);
    });
    _server.onDisconnected.listen((_) {
      if (_isConnected || _client?.isConnected == true) {
        _isConnected = false;
      }
      // only emit connection_lost if we are not the initiator (server-side drop)
      if (!_isInitiator) {
        _messageController.add(NetworkMessage(
          type: 'connection_lost',
          senderId: deviceId,
          payload: {},
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    });
    return port;
  }

  Future<bool> connectToPeer(String host, int port) async {
    // 断开已有连接，防止泄漏
    await _client?.disconnect();
    _client = WebSocketClient();
    final success = await _client!.connect(host, port);
    if (success) {
      _isConnected = true;
      _isInitiator = true;
      _client!.onMessage.listen((message) {
        _messageController.add(message);
      });

      // 监听连接断开
      _client!.onConnectionState.listen((isConnected) {
        if (!isConnected && _isConnected) {
          _isConnected = false;
          _messageController.add(NetworkMessage(
            type: 'connection_lost',
            senderId: deviceId,
            payload: {},
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      });

      send(NetworkMessage(
        type: 'peer_info',
        senderId: deviceId,
        payload: {
          'device_name': deviceName,
          'device_id': deviceId,
          'platform': platform,
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    return success;
  }

  void send(NetworkMessage message) {
    if (_client != null && _client!.isConnected) {
      try {
        _client!.send(message);
      } catch (_) {
        _onConnectionLost();
      }
    } else {
      _server.send(message);
    }
  }

  void _onConnectionLost() {
    _isConnected = false;
    _messageController.add(NetworkMessage(
      type: 'connection_lost',
      senderId: deviceId,
      payload: {},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  bool get isInitiator => _isInitiator;

  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
    _isConnected = false;
    _isInitiator = false;
    _server.clearConnection();
  }

  Future<void> stop() async {
    await disconnect();
    await _server.stop();
  }

  void dispose() {
    stop();
    _messageController.close();
  }
}
