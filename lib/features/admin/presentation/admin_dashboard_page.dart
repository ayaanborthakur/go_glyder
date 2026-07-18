import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:go_glyder/core/theme.dart';
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

  Widget _statsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: [
        _StatTile(
          icon: Icons.groups_rounded,
          label: 'Groups',
          stream: _fs.streamCarpoolGroups(),
        ),
        _StatTile(
          icon: Icons.forum_rounded,
          label: 'Posts',
          stream: _fs.streamCommunityPosts(),
        ),
        _StatTile(
          icon: Icons.event_rounded,
          label: 'Events',
          stream: _fs.streamCalendarEvents(),
        ),
      ],
    );
  }

  Widget _groupsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _fs.streamCarpoolGroups(),
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
                        '${docs[i].data()['members'] ?? 0} members · '
                        '${docs[i].data()['schoolName'] ?? ''}'),
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
