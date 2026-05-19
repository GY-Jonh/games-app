import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:gomoku_app/models/network_message.dart';

class WebSocketClient {
  WebSocket? _webSocket;
  final StreamController<NetworkMessage> _messageController =
      StreamController<NetworkMessage>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  bool _isConnected = false;
  Timer? _pingTimer;

  bool get isConnected => _isConnected;
  Stream<NetworkMessage> get onMessage => _messageController.stream;
  Stream<bool> get onConnectionState => _connectionStateController.stream;

  Future<bool> connect(String host, int port) async {
    try {
      _webSocket = await WebSocket.connect('ws://$host:$port')
          .timeout(const Duration(seconds: 10));
      _isConnected = true;
      _connectionStateController.add(true);

      _webSocket!.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final message = NetworkMessage.fromJson(json);
            _messageController.add(message);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _connectionStateController.add(false);
          _pingTimer?.cancel();
        },
        onError: (_) {
          _isConnected = false;
          _connectionStateController.add(false);
          _pingTimer?.cancel();
        },
      );

      // Start ping timer
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        send(NetworkMessage(
          type: 'ping',
          senderId: '',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      });

      return true;
    } catch (_) {
      _isConnected = false;
      _connectionStateController.add(false);
      return false;
    }
  }

  void send(NetworkMessage message) {
    if (_webSocket != null && _isConnected) {
      _webSocket!.add(jsonEncode(message.toJson()));
    }
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _isConnected = false;
    _connectionStateController.add(false);
    try {
      await _webSocket?.close();
    } catch (_) {}
    _webSocket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}
