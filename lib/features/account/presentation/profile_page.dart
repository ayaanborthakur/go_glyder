import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:go_glyder/core/session.dart';
import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/features/account/scripts/auth.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// Compact profile: identity card, a carbon-miles strip, and (on your own
/// profile) a tidy settings list. Anyone can open a member's profile.
class ProfilePage extends StatelessWidget {
  final String uid;
  final String? fallbackName;

  const ProfilePage({super.key, required this.uid, this.fallbackName});

  bool get _isMe => session.user?.uid == uid;

  static String roleLabel(String? role) {
    switch (role) {
      case 'parent':
        return 'Parent';
      case 'staff':
        return 'Staff / Teacher';
      case 'admin':
        return 'School Admin';
      default:
        return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.instance.streamUserProfile(uid),
        builder: (context, snap) {
          final data = snap.data?.data() ?? const {};
          final name =
              (data['displayName'] ?? fallbackName ?? 'Member') as String;
          final role = data['role'] as String?;
          final email = data['email'] as String?;
          final bio = (data['bio'] ?? '') as String;
          final miles = ((data['carbonMiles'] ?? 0) as num).toDouble();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _identityCard(context, name, role, bio),
              const SizedBox(height: 12),
              _carbonStrip(miles),
              if (_isMe) ...[
                const SizedBox(height: 12),
                _settings(context, email),
              ],
            ],
          );
        },
      ),
    );
  }

  // ---- Identity card (avatar + name + role + bio) ----
  Widget _identityCard(
      BuildContext context, String name, String? role, String bio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.brandTint,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _roleBadge(role),
                  ],
                ),
              ),
              if (_isMe)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () => _editSheet(context, name, bio),
                ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bio,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ] else if (_isMe) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _editSheet(context, name, bio),
              child: Text(
                '+ Add a bio',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandGreen,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _roleBadge(String? role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        roleLabel(role),
        style: const TextStyle(
          color: AppColors.brandDark,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // ---- Compact carbon-miles strip ----
  Widget _carbonStrip(double miles) {
    final co2 = (miles * 0.4).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandGreen, AppColors.brandDark],
        ),
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_rounded, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fmt(miles),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'carbon miles saved',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            miles <= 0 ? 'Start carpooling' : '≈ $co2 kg CO₂',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Settings list (own profile) ----
  Widget _settings(BuildContext context, String? email) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          if (email != null)
            _row(Icons.mail_outline_rounded, email, subtitle: true),
          _row(
            Icons.swap_horiz_rounded,
            'Change role',
            onTap: () => FirestoreService.instance.setUserRole(''),
          ),
          _row(
            Icons.logout_rounded,
            'Sign out',
            danger: true,
            last: true,
            onTap: () => AuthService().signOut(),
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool danger = false,
    bool last = false,
    bool subtitle = false,
  }) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Icon(icon,
            size: 20,
            color: danger
                ? AppColors.danger
                : subtitle
                    ? AppColors.textTertiary
                    : AppColors.brandGreen),
        title: Text(
          label,
          style: TextStyle(
            color: subtitle ? AppColors.textSecondary : color,
            fontWeight: subtitle ? FontWeight.w500 : FontWeight.w600,
            fontSize: subtitle ? 14 : 15,
          ),
        ),
        trailing: (onTap != null && !danger)
            ? const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary)
            : null,
      ),
    );
  }

  void _editSheet(BuildContext context, String name, String bio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(initialName: name, initialBio: bio),
    );
  }

  String _fmt(double m) =>
      m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1);
}

class _EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialBio;
  const _EditProfileSheet({required this.initialName, required this.initialBio});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameC =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _bioC =
      TextEditingController(text: widget.initialBio);
  bool _saving = false;

  @override
  void dispose() {
    _nameC.dispose();
    _bioC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await FirestoreService.instance.updateUserProfile(
      displayName: _nameC.text.trim().isEmpty ? null : _nameC.text.trim(),
      bio: _bioC.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Edit profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const Text('Name',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 13)),
          const SizedBox(height: 6),
          TextField(controller: _nameC, textCapitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          const Text('Bio',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _bioC,
            maxLines: 3,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'A line about you — kids\' grades, neighborhood, etc.',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
