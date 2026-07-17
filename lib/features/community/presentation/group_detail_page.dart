import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/firestore_service.dart';

class GroupDetailPage extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  FirestoreService get _fs => FirestoreService.instance;

  Future<void> _leave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        content: Text('You\'ll no longer see "$groupName" in your groups.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _fs.leaveGroup(groupId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(groupName)),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _fs.getGroup(groupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() ?? const {};
          final joinCode = (data['joinCode'] ?? '——') as String;
          final description = (data['description'] ?? '') as String;
          final schoolName = (data['schoolName'] ?? '') as String;
          final pickupArea = (data['pickupArea'] ?? '') as String;
          final members = (data['members'] ?? 0) as int;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _aboutCard(schoolName, pickupArea, members),
              const SizedBox(height: 20),
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _inviteCard(context, joinCode),
              const SizedBox(height: 24),
              _membersSection(),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _leave(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Leave group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(50),
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _aboutCard(String schoolName, String pickupArea, int members) {
    Widget row(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.brandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (schoolName.isNotEmpty) row(Icons.school_outlined, schoolName),
          if (pickupArea.isNotEmpty) row(Icons.place_outlined, pickupArea),
          row(
            Icons.groups_outlined,
            '$members member${members == 1 ? '' : 's'}',
          ),
        ],
      ),
    );
  }

  Widget _inviteCard(BuildContext context, String joinCode) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          const Text(
            'Invite parents to this group',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share the code or let them scan the QR',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.divider),
            ),
            child: QrImageView(
              data: joinCode,
              version: QrVersions.auto,
              size: 180,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.brandDark,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.brandDark,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Join code with copy button
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: joinCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Join code copied')),
              );
            },
            borderRadius: AppRadius.mdAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.brandTint,
                borderRadius: AppRadius.mdAll,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    joinCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: AppColors.brandDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.copy_rounded,
                    size: 20,
                    color: AppColors.brandDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _membersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Members',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _fs.streamGroupMembers(groupId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snap.data!.docs;
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgAll,
                boxShadow: kCardShadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < docs.length; i++)
                    _memberTile(
                      (docs[i].data()['displayName'] ?? 'Member') as String,
                      last: i == docs.length - 1,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _memberTile(String name, {required bool last}) {
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.brandTint,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.brandDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
