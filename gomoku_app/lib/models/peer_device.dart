class PeerDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String platform;
  final String status; // 'idle' 或 'playing'
  final DateTime lastSeen;

  const PeerDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
    this.status = 'idle',
    required this.lastSeen,
  });

  bool get isExpired =>
      DateTime.now().difference(lastSeen).inSeconds > 10;

  bool get isInGame => status == 'playing';

  PeerDevice copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    String? platform,
    String? status,
    DateTime? lastSeen,
  }) {
    return PeerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerDevice && id == other.id && port == other.port;

  @override
  int get hashCode => id.hashCode ^ port.hashCode;
}
