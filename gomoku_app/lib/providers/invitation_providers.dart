import 'package:flutter_riverpod/flutter_riverpod.dart';

enum InvitationState {
  none,
  outgoing,
  incoming,
  accepted,
  declined,
  cancelled,
}

final invitationStateProvider =
    StateNotifierProvider<InvitationNotifier, InvitationState>((ref) {
  return InvitationNotifier();
});

class InvitationNotifier extends StateNotifier<InvitationState> {
  InvitationNotifier() : super(InvitationState.none);

  String? _fromPeerId;
  String? _fromPeerName;
  String? _toPeerId;
  String? _toPeerName;
  String? _gameType;

  String? get fromPeerId => _fromPeerId;
  String? get fromPeerName => _fromPeerName;
  String? get toPeerId => _toPeerId;
  String? get toPeerName => _toPeerName;
  String? get gameType => _gameType;

  void sendInvite(String peerId, String peerName, {String? gameType}) {
    _toPeerId = peerId;
    _toPeerName = peerName;
    _gameType = gameType;
    state = InvitationState.outgoing;
  }

  void receiveInvite(String peerId, String peerName, {String? gameType}) {
    _fromPeerId = peerId;
    _fromPeerName = peerName;
    _gameType = gameType;
    state = InvitationState.incoming;
  }

  void accept() {
    state = InvitationState.accepted;
  }

  void decline() {
    state = InvitationState.declined;
  }

  void cancel() {
    state = InvitationState.cancelled;
  }

  void reset() {
    _fromPeerId = null;
    _fromPeerName = null;
    _toPeerId = null;
    _toPeerName = null;
    _gameType = null;
    state = InvitationState.none;
  }
}
