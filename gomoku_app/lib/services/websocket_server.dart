import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:gomoku_app/models/network_message.dart';

typedef MessageHandler = void Function(NetworkMessage message);

class WebSocketServer {
  HttpServer? _httpServer;
  WebSocket? _webSocket;
  final StreamController<NetworkMessage> _messageController =
      StreamController<NetworkMessage>.broadcast();
  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  Stream<NetworkMessage> get onMessage => _messageController.stream;
  Stream<void> get onDisconnected => _disconnectController.stream;
  int? get port => _httpServer?.port;

  Future<int> start({int? preferredPort}) async {
    if (_isRunning) {
      return _httpServer?.port ?? 0;
    }

    _httpServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      preferredPort ?? 0,
    );

    _httpServer!.transform(WebSocketTransformer()).listen(
      (ws) {
        if (_webSocket != null) {
          // 已有活跃连接（游戏中），拒绝第三方连接
          ws.close(3000, 'Busy');
          return;
        }
        _webSocket = ws;
        ws.listen(
          (data) {
            try {
              final json = jsonDecode(data as String) as Map<String, dynamic>;
              final message = NetworkMessage.fromJson(json);
              _messageController.add(message);
            } catch (_) {}
          },
          onDone: () {
            _webSocket = null;
            _disconnectController.add(null);
          },
          onError: (_) {
            _webSocket = null;
            _disconnectController.add(null);
          },
        );
      },
    );

    _isRunning = true;
    return _httpServer!.port;
  }

  void send(NetworkMessage message) {
    if (_webSocket == null) return;
    try {
      _webSocket!.add(jsonEncode(message.toJson()));
    } catch (_) {
      _webSocket = null;
      _disconnectController.add(null);
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    try {
      await _webSocket?.close();
    } catch (_) {}
    try {
      await _httpServer?.close(force: true);
    } catch (_) {}
    _webSocket = null;
    _httpServer = null;
  }

  /// 清除当前连接引用，用于游戏结束后重置服务端状态
  void clearConnection() {
    _webSocket = null;
  }

  void dispose() {
    stop();
    _messageController.close();
    _disconnectController.close();
  }
}
