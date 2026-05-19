import 'package:flutter/material.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';
import 'package:gomoku_app/models/peer_device.dart';

class PeerListTile extends StatelessWidget {
  final PeerDevice peer;
  final bool isInviting;
  final VoidCallback onInvite;

  const PeerListTile({
    super.key,
    required this.peer,
    this.isInviting = false,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              peer.platform == 'ios' ? Colors.black : AppTheme.onlineGreen,
          child: Icon(
            peer.platform == 'ios' ? Icons.phone_iphone : Icons.phone_android,
            color: Colors.white,
          ),
        ),
        title: Text(
          peer.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.onlineGreen,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '在线 · ${peer.platform == 'ios' ? 'iPhone' : 'Android'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: isInviting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : peer.isInGame
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '游戏中',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  )
                : ElevatedButton(
                    onPressed: onInvite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('邀请', style: TextStyle(fontSize: 13)),
                  ),
      ),
    );
  }
}
