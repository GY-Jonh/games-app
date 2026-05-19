class NetworkMessage {
  final String type;
  final String senderId;
  final String? gameId;
  final Map<String, dynamic> payload;
  final int timestamp;

  const NetworkMessage({
    required this.type,
    required this.senderId,
    this.gameId,
    this.payload = const {},
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'senderId': senderId,
        if (gameId != null) 'gameId': gameId,
        'payload': payload,
        'timestamp': timestamp,
      };

  factory NetworkMessage.fromJson(Map<String, dynamic> json) =>
      NetworkMessage(
        type: json['type'] as String,
        senderId: json['senderId'] as String,
        gameId: json['gameId'] as String?,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        timestamp: json['timestamp'] as int,
      );
}
