import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:go_glyder/core/session.dart';
import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/features/account/presentation/profile_page.dart';
import 'package:go_glyder/features/admin/presentation/admin_dashboard_page.dart';
import 'package:go_glyder/services/firestore_service.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  void _openProfile() {
    final uid = session.user?.uid;
    if (uid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilePage(uid: uid)),
    );
  }

  Widget _buildAdminCard() {
    return Padding(
      padding: AppSpacing.page,
      child: Material(
        color: AppColors.brandDark,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AdminDashboardPage(schoolId: session.adminSchoolId!),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin dashboard',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      Text('Manage your school community',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader().animate().fadeIn(duration: 400.ms).slideY(
              begin: -0.15,
              end: 0,
              curve: Curves.easeOut,
            ),
            if (session.role == 'admin' && session.adminSchoolId != null) ...[
              const SizedBox(height: AppSpacing.xl),
              _buildAdminCard()
                  .animate(delay: 80.ms)
                  .fadeIn(duration: 450.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            ],
            const SizedBox(height: AppSpacing.xl),
            _buildQuickActions()
                .animate(delay: 120.ms)
                .fadeIn(duration: 450.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: AppSpacing.xl),
            _buildUpcomingSection()
                .animate(delay: 240.ms)
                .fadeIn(duration: 450.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: AppSpacing.xl),
            _buildFeaturesGrid()
                .animate(delay: 360.ms)
                .fadeIn(duration: 450.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 24,
        24,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandDark, AppColors.brandGreen],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GoGlyder',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              _HeaderIconButton(
                icon: Icons.person_rounded,
                onTap: _openProfile,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.eco_rounded,
                  color: AppColors.brandAccent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your school carpooling solution',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: AppSpacing.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Quick Actions'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.search_rounded,
                  label: 'Find a Ride',
                  onTap: () => context.go('/search'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.group_rounded,
                  label: 'Community',
                  onTap: () => context.go('/community'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Messages',
                  onTap: () => context.go('/messages'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Padding(
      padding: AppSpacing.page,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.instance.streamCalendarEvents(),
        builder: (context, snapshot) {
          // Events stream is ordered by date ascending, so the first one that
          // isn't in the past is the next upcoming event.
          Map<String, dynamic>? next;
          if (snapshot.hasData) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            for (final doc in snapshot.data!.docs) {
              final ts = doc.data()['date'] as Timestamp?;
              if (ts == null) continue;
              if (!ts.toDate().isBefore(today)) {
                next = doc.data();
                break;
              }
            }
          }

          final hasEvent = next != null;
          final title = hasEvent ? (next['title'] ?? 'Untitled') as String : 'No upcoming events';
          String subtitle = 'Add one from the calendar';
          if (hasEvent) {
            final ts = next['date'] as Timestamp?;
            final dateStr = ts != null
                ? DateFormat('MMM d, yyyy').format(ts.toDate())
                : '';
            final time = (next['time'] ?? '') as String;
            subtitle = [dateStr, if (time.isNotEmpty) time].join(' · ');
          }

          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: AppColors.brandAccent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.brandDark,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(
                    hasEvent
                        ? Icons.event_available_rounded
                        : Icons.event_busy_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXT SCHOOL EVENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.brandDark,
                    size: 18,
                  ),
                  onPressed: () => context.go('/calendar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    final features = [
      (
        Icons.calendar_month_rounded,
        'Calendar',
        'School events & trips',
        '/calendar',
      ),
      (
        Icons.insights_rounded,
        'Analytics',
        'Impact & savings',
        '/analytics',
      ),
      (
        Icons.map_rounded,
        'Live Map',
        'Routes near you',
        '/search',
      ),
      (
        Icons.forum_rounded,
        'Community',
        'Connect with parents',
        '/community',
      ),
    ];

    return Padding(
      padding: AppSpacing.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Explore'),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: features
                .map(
                  (f) => _FeatureCard(
                    icon: f.$1,
                    title: f.$2,
                    description: f.$3,
                    onTap: () => context.go(f.$4),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: AppRadius.mdAll,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            boxShadow: kCardShadow,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(icon, color: AppColors.brandDark, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            boxShadow: kCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, color: AppColors.brandDark, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
