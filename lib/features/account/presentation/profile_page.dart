import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:go_glyder/core/session.dart';
import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/features/account/scripts/auth.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// A user's public profile. Anyone can open it (e.g. from a group's member
/// list) to see their role and carbon miles. On your own profile you can
/// also sign out.
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
          final name = (data['displayName'] ?? fallbackName ?? 'Member') as String;
          final role = data['role'] as String?;
          final email = data['email'] as String?;
          final miles = ((data['carbonMiles'] ?? 0) as num).toDouble();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 8),
              Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.brandTint,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: _roleBadge(role)),
              const SizedBox(height: 24),
              _carbonCard(miles),
              if (email != null && _isMe) ...[
                const SizedBox(height: 20),
                _infoRow(Icons.mail_outline_rounded, email),
              ],
              if (_isMe) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => FirestoreService.instance.setUserRole(''),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Change role'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => AuthService().signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(50),
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _roleBadge(String? role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        roleLabel(role),
        style: const TextStyle(
          color: AppColors.brandDark,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _carbonCard(double miles) {
    // Rough: ~0.4 kg CO2 per mile of driving avoided.
    final co2 = (miles * 0.4).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandGreen, AppColors.brandDark],
        ),
        borderRadius: AppRadius.xlAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.eco_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 12),
          Text(
            _fmt(miles),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'carbon miles saved',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            miles <= 0
                ? 'Carpool someone to start banking miles.'
                : 'Roughly $co2 kg of CO₂ kept out of the air.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5))),
        ],
      ),
    );
  }

  String _fmt(double m) {
    if (m == m.roundToDouble()) return m.toStringAsFixed(0);
    return m.toStringAsFixed(1);
  }
}
