import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/services/firestore_service.dart';

/// Brief splash shown while the signed-in user's profile/role loads.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.brandDark,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      ),
    );
  }
}

class _Role {
  final String key;
  final String title;
  final String blurb;
  final IconData icon;
  const _Role(this.key, this.title, this.blurb, this.icon);
}

const List<_Role> _roles = [
  _Role('parent', 'Parent',
      'Arrange carpools and share rides for your family.',
      Icons.escalator_warning_rounded),
  _Role('staff', 'Staff / Teacher',
      'Coordinate rides for classes, clubs, and events.',
      Icons.co_present_rounded),
  _Role('admin', 'School Admin',
      "Manage your school's groups, events, and families.",
      Icons.admin_panel_settings_rounded),
];

/// First-time role picker. Shown once, right after a new account signs in.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  String? _selected;
  bool _saving = false;

  Future<void> _continue() async {
    if (_selected == null || _saving) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.instance.setUserRole(_selected!);
      // The session's profile stream picks up the new role and the router
      // redirects into the app automatically.
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save your role. Please try again."),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome to GoGlyder',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      )),
                  const SizedBox(height: 6),
                  Text(
                    'How will you use GoGlyder? You can change this later.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                children: _roles.map(_roleCard).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (_selected == null || _saving) ? null : _continue,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(_Role r) {
    final selected = _selected == r.key;
    return GestureDetector(
      onTap: () => setState(() => _selected = r.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: selected ? AppColors.brandGreen : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? null : kCardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? AppColors.brandDark : AppColors.brandTint,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(r.icon,
                  color: selected ? Colors.white : AppColors.brandDark, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      style: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(r.blurb,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: selected ? AppColors.brandGreen : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
