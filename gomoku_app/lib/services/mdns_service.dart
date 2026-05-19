import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/models/peer_device.dart';

class MDnsService {
  RawDatagramSocket? _socket;
  InternetAddress? _multicastAddress;
  Timer? _announceTimer;
  final StreamController<PeerDevice> _peerFoundController =
      StreamController<PeerDevice>.broadcast();
  final StreamController<String> _peerLostController =
      StreamController<String>.broadcast();

  bool _isRunning = false;
  int _serverPort = 0;
  String _status = 'idle';

  static const int _multicastPort = 55555;
  static const String _multicastGroup = '239.255.0.1';
  static const Duration _announceInterval = Duration(seconds: 5);

  bool get isRunning => _isRunning;

  Stream<PeerDevice> get onPeerFound => _peerFoundController.stream;
  Stream<String> get onPeerLost => _peerLostController.stream;

  void setServerPort(int port) {
    _serverPort = port;
  }

  /// 更新游戏状态并立即广播
  void setGameStatus(String status) {
    if (_status == status) return;
    _status = status;
    _announcePresence();
  }

  Future<void> start() async {
    if (_isRunning) return;

    try {
      _multicastAddress = InternetAddress(_multicastGroup);

      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _multicastPort,
        reuseAddress: true,
        reusePort: true,
      );

      _socket!.multicastHops = 1;
      _socket!.broadcastEnabled = true;

      try {
        _socket!.joinMulticast(_multicastAddress!);
      } catch (_) {
        // Multicast join may fail on some networks
      }

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      _announceTimer = Timer.periodic(_announceInterval, (_) {
        _announcePresence();
      });

      _announcePresence();
      _isRunning = true;
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  void _announcePresence() {
    if (_socket == null || _serverPort <= 0) return;

    final message = jsonEncode({
      'type': 'announce',
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'port': _serverPort,
      'status': _status,
      'version': '1.0.0',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      _socket!.send(
        utf8.encode(message),
        _multicastAddress!,
        _multicastPort,
      );
    } catch (_) {}
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final data = utf8.decode(datagram.data);
      final json = jsonDecode(data) as Map<String, dynamic>;

      if (json['type'] != 'announce') return;

      final peerId = json['device_id'] as String;
      if (peerId == deviceId) return;

      final peer = PeerDevice(
        id: peerId,
        name: json['device_name'] as String? ?? 'Unknown',
        ip: datagram.address.address,
        port: json['port'] as int? ?? 0,
        platform: json['platform'] as String? ?? 'unknown',
        status: json['status'] as String? ?? 'idle',
        lastSeen: DateTime.now(),
      );

      _peerFoundController.add(peer);
    } catch (_) {}
  }

  void stop() {
    _isRunning = false;
    _announceTimer?.cancel();
    _announceTimer = null;

    try {
      if (_socket != null && _multicastAddress != null) {
        _socket!.leaveMulticast(_multicastAddress!);
      }
    } catch (_) {}

    try {
      _socket?.close();
    } catch (_) {}

    _socket = null;
  }

  void dispose() {
    stop();
    _peerFoundController.close();
    _peerLostController.close();
  }
}
