import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/firestore_service.dart';
import 'package:go_glyder/services/messages_fs.dart';

/// Live community dashboard. Every number is computed from real Firestore
/// data, so a brand-new account starts at zero and the figures grow with use.
/// Carbon/trip metrics wait on the carpool-trip logging feature (Phase 4).
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('Community at a glance'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.35,
              children: [
                _CountTile(
                  icon: Icons.groups_rounded,
                  label: 'My Groups',
                  color: AppColors.brandGreen,
                  stream: firestore.streamMyGroups(),
                ),
                _CountTile(
                  icon: Icons.forum_rounded,
                  label: 'Community Posts',
                  color: const Color(0xFF0E7490),
                  stream: firestore.streamCommunityPosts(),
                ),
                const _ConvCountTile(),
                _CountTile(
                  icon: Icons.event_available_rounded,
                  label: 'Upcoming Events',
                  color: const Color(0xFFB45309),
                  stream: firestore.streamCalendarEvents(),
                  counter: _upcomingCount,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionHeader('Carbon impact'),
            const SizedBox(height: 12),
            _buildCarbonComingSoon(),
          ],
        ),
      ),
    );
  }

  static int _upcomingCount(QuerySnapshot<Map<String, dynamic>> snap) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return snap.docs.where((d) {
      final ts = d.data()['date'] as Timestamp?;
      return ts != null && !ts.toDate().isBefore(today);
    }).length;
  }

  Widget _buildCarbonComingSoon() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.brandTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: AppColors.brandDark,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'CO₂ savings coming soon',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Once families start logging carpool trips, this shows the miles '
            'shared and CO₂ kept out of the air by your school community.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// A stat card whose number is the count of docs in [stream] (optionally via a
/// custom [counter] for filtered totals).
class _CountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final int Function(QuerySnapshot<Map<String, dynamic>>)? counter;

  const _CountTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.stream,
    this.counter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              final value = !snapshot.hasData
                  ? '—'
                  : (counter?.call(snapshot.data!) ?? snapshot.data!.docs.length)
                        .toString();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Stat card that shows the number of the current user's conversations.
/// Uses the typed [MessagingService] stream instead of a raw QuerySnapshot.
class _ConvCountTile extends StatelessWidget {
  const _ConvCountTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Color(0xFF7C3AED),
              size: 22,
            ),
          ),
          StreamBuilder<List<dynamic>>(
            stream: MessagingService.instance.streamMyConversations(),
            builder: (context, snapshot) {
              final count =
                  snapshot.hasData ? snapshot.data!.length.toString() : '—';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Conversations',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
