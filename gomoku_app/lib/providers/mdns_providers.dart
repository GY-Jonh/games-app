import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/models/peer_device.dart';
import 'package:gomoku_app/services/mdns_service.dart';

final mDnsServiceProvider = Provider<MDnsService>((ref) {
  final service = MDnsService();
  ref.onDispose(() => service.dispose());
  return service;
});

class DiscoveredPeersNotifier extends StateNotifier<List<PeerDevice>> {
  final MDnsService _mdns;

  DiscoveredPeersNotifier(this._mdns) : super([]) {
    _mdns.onPeerFound.listen(addOrUpdatePeer);
    _mdns.onPeerLost.listen(_removePeer);
  }

  void addOrUpdatePeer(PeerDevice peer) {
    final existingIndex = state.indexWhere((p) => p.id == peer.id);
    if (existingIndex >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) peer else state[i],
      ];
    } else {
      state = [...state, peer];
    }
  }

  void _removePeer(String peerId) {
    state = state.where((p) => p.id != peerId).toList();
  }

  void cleanupExpiredPeers() {
    state = state.where((p) => !p.isExpired).toList();
  }

  void removePeer(String peerId) {
    state = state.where((p) => p.id != peerId).toList();
  }
}

final discoveredPeersProvider =
    StateNotifierProvider<DiscoveredPeersNotifier, List<PeerDevice>>((ref) {
  final mdns = ref.watch(mDnsServiceProvider);
  return DiscoveredPeersNotifier(mdns);
});

enum MDnsStatus { stopped, running, error }

final mDnsStatusProvider = StateProvider<MDnsStatus>((ref) => MDnsStatus.stopped);
