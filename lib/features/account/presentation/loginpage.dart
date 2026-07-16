// lib/features/account/presentation/loginpage.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:go_glyder/core/theme.dart';
import 'package:go_glyder/features/account/scripts/auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() => _runSignIn(_authService.signInWithGoogle);

  Future<void> _signInWithMicrosoft() =>
      _runSignIn(_authService.signInWithMicrosoft);

  Future<void> _runSignIn(Future<Object?> Function() action) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // On success the router's auth listener redirects into the app.
      // A null result means the user dismissed the picker — do nothing.
      await action();
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.danger,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AuroraBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _buildBranding(),
                  const Spacer(flex: 4),
                  _buildSignInSection(),
                  const SizedBox(height: 28),
                  _buildFooter(),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandAccent.withValues(alpha: 0.35),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Image.asset(
                'lib/assets/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.directions_bus_rounded,
                  color: AppColors.brandDark,
                  size: 48,
                ),
              ),
            )
            .animate()
            .scale(
              duration: 550.ms,
              begin: const Offset(0.7, 0.7),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 400.ms),
        const SizedBox(height: 28),
        const Text(
          'GoGlyder',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
        const SizedBox(height: 10),
        Text(
          'Smarter, greener school carpooling',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 15.5,
            height: 1.4,
          ),
        ).animate(delay: 340.ms).fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
      ],
    );
  }

  Widget _buildSignInSection() {
    final Widget content = _isLoading
        ? const SizedBox(
            height: 58,
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          )
        : Column(
            children: [
              _providerButton(
                label: 'Continue with Google',
                logo: Image.asset(
                  'lib/assets/google_logo.png',
                  height: 22,
                  width: 22,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.g_mobiledata_rounded, size: 24),
                ),
                onTap: _signInWithGoogle,
              ),
              const SizedBox(height: 14),
              _providerButton(
                label: 'Continue with Microsoft',
                logo: const _MicrosoftLogo(size: 20),
                onTap: _signInWithMicrosoft,
              ),
            ],
          );

    return content
        .animate(delay: 480.ms)
        .fadeIn(duration: 550.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _providerButton({
    required String label,
    required Widget logo,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            logo,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'By continuing you agree to GoGlyder\'s Terms & Privacy Policy',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 12.5,
        height: 1.4,
      ),
    ).animate(delay: 620.ms).fadeIn(duration: 500.ms);
  }
}

/// Microsoft's four-square brand mark, drawn directly (no asset needed).
class _MicrosoftLogo extends StatelessWidget {
  final double size;
  const _MicrosoftLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    final tile = size / 2 - 1;
    Widget square(Color c) =>
        Container(width: tile, height: tile, color: c);
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              square(const Color(0xFFF25022)), // red
              square(const Color(0xFF7FBA00)), // green
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              square(const Color(0xFF00A4EF)), // blue
              square(const Color(0xFFFFB900)), // yellow
            ],
          ),
        ],
      ),
    );
  }
}

/// Rich multi-stop gradient plus two soft accent orbs for depth.
class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A4A2E), AppColors.brandDark, Color(0xFF021C12)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _orb(240, AppColors.brandAccent.withValues(alpha: 0.45))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: 0,
                    end: 30,
                    duration: 4000.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
            Positioned(
              bottom: -120,
              left: -90,
              child: _orb(320, const Color(0xFF14B8A6).withValues(alpha: 0.30))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: 0,
                    end: -30,
                    duration: 5000.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
