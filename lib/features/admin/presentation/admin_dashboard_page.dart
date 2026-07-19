import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/features/admin/presentation/admin_calendar_page.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// School admin overview. Access is gated on verified membership of the
/// school's `admins` roster — a self-set role is not enough to get here.
class AdminDashboardPage extends StatelessWidget {
  final String schoolId;
  const AdminDashboardPage({super.key, required this.schoolId});

  FirestoreService get _fs => FirestoreService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: StreamBuilder<bool>(
        stream: _fs.streamIsSchoolAdmin(schoolId),
        builder: (context, adminSnap) {
          if (!adminSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (adminSnap.data != true) {
            return _locked();
          }
          return FutureBuilder<Map<String, dynamic>?>(
            future: _fs.getSchool(schoolId),
            builder: (context, schoolSnap) {
              final school = schoolSnap.data;
              final name = (school?['name'] ?? 'Your school') as String;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _header(name),
                  const SizedBox(height: 18),
                  _calendarCard(context, name),
                  const SizedBox(height: 22),
                  _joinCodeCard(context, schoolId),
                  const SizedBox(height: 22),
                  const _SectionLabel('Usage at a glance'),
                  const SizedBox(height: 12),
                  _statsGrid(),
                  const SizedBox(height: 26),
                  const _SectionLabel('Carpool groups'),
                  const SizedBox(height: 12),
                  _groupsList(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _locked() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.textTertiary),
            SizedBox(height: 14),
            Text('Admin access not verified',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('You need your school\'s admin code to view this.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _header(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text('VERIFIED ADMIN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Text(name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              )),
          const SizedBox(height: 4),
          Text('Managing your school community on GoGlyder',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 13.5)),
        ],
      ),
    );
  }

  Widget _calendarCard(BuildContext context, String schoolName) {
    return Material(
      color: AppColors.brandGreen,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AdminCalendarPage(schoolId: schoolId, schoolName: schoolName),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Colors.white),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('School calendar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    Text('Upload your calendar (.ics) for the whole community',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _joinCodeCard(BuildContext context, String schoolId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _fs.streamSchoolPrivateConfig(schoolId),
      builder: (context, snap) {
        final data = snap.data?.data();
        final joinCode = data?['joinCode'] as String?;

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
              Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, color: AppColors.brandGreen, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'School join code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (joinCode != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: joinCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Join code copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (joinCode == null) ...[
                const Text(
                  'No join code has been generated for this school yet. Parents and staff need a code to join this school.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _fs.refreshSchoolJoinCode(schoolId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Generate Join Code'),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      joinCode.split('').join(' '),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.brandDark,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh code',
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.textTertiary),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Refresh join code?'),
                            content: const Text(
                              'This will deactivate the current join code immediately. '
                              'Any new users will need the new code to join. '
                              'Existing members will remain in the school.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                ),
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Refresh'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await _fs.refreshSchoolJoinCode(schoolId);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share this 6-digit code with parents and staff so they can join your school community. Refresh it if it gets leaked.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _statsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _StatTile(
          icon: Icons.groups_rounded,
          label: 'Groups',
          stream: _fs.streamGroupsInSchool(schoolId),
        ),
        _StatTile(
          icon: Icons.forum_rounded,
          label: 'Posts',
          stream: _fs.streamCommunityPosts(),
        ),
      ],
    );
  }

  Widget _groupsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.streamGroupsInSchool(schoolId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Text('No carpool groups yet.',
              style: TextStyle(color: AppColors.textSecondary));
        }
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgAll,
            boxShadow: kCardShadow,
          ),
          child: Column(
            children: [
              for (var i = 0; i < docs.length; i++)
                Container(
                  decoration: BoxDecoration(
                    border: i == docs.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.brandTint,
                      child: Icon(Icons.directions_car_rounded,
                          color: AppColors.brandDark, size: 20),
                    ),
                    title: Text((docs[i].data()['name'] ?? 'Group') as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${docs[i].data()['members'] ?? 0} members'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2));
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  const _StatTile(
      {required this.icon, required this.label, required this.stream});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.brandGreen, size: 22),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) => Text(
              snap.hasData ? '${snap.data!.docs.length}' : '—',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
