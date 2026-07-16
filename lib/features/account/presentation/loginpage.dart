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

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLogin = true; // true = Sign In, false = Sign Up
  bool _obscurePassword = true;
  bool _isLoading = false;

  static const Color _fieldFill = Color(0xFFF1F4F3);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _setMode(bool login) {
    if (_isLogin == login || _isLoading) return;
    setState(() {
      _isLogin = login;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isLogin) {
        await _authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await _authService.signUpWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      // On success the router's auth listener redirects into the app.
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 52,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBranding(),
                        const SizedBox(height: 30),
                        _buildCard(),
                        const SizedBox(height: 18),
                        _buildFooter(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        // Solid white squircle so the dark-green logo reads crisply.
        Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandAccent.withValues(alpha: 0.35),
                    blurRadius: 34,
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
                  size: 46,
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
        const SizedBox(height: 24),
        Text(
          _isLogin ? 'Welcome back' : 'Create account',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ).animate(delay: 200.ms).fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? 'Sign in to keep your school moving greener'
              : 'Join your school\'s carpooling community',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14.5,
            height: 1.4,
          ),
        ).animate(delay: 320.ms).fadeIn(duration: 500.ms).slideY(begin: 0.3, end: 0),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 46,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSegmentedToggle(),
                const SizedBox(height: 22),
                _field(
                  controller: _emailController,
                  hint: 'Email address',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Please enter your email';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  textInputAction:
                      _isLogin ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: _isLogin ? (_) => _submit() : null,
                  suffix: IconButton(
                    splashRadius: 20,
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 14),
                  _field(
                    controller: _confirmController,
                    hint: 'Confirm password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords don\'t match';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 22),
                _buildSubmitButton(),
              ],
            ),
          ),
        )
        .animate(delay: 420.ms)
        .fadeIn(duration: 550.ms)
        .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    String? Function(String?)? validator,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: !_isLoading,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: AppColors.brandGreen,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: _fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(AppColors.brandGreen, 1.6),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger, 1.6),
      ),
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segment('Sign In', _isLogin, () => _setMode(true)),
          _segment('Sign Up', !_isLogin, () => _setMode(false)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandDark : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.brandDark.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final button = GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brandAccent, AppColors.brandDark],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandDark.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                _isLogin ? 'Sign In' : 'Create Account',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );

    // A slow, subtle light sweep keeps the primary action feeling alive.
    if (_isLoading) return button;
    return button
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          delay: 1600.ms,
          duration: 1600.ms,
          color: Colors.white.withValues(alpha: 0.25),
        );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? 'New to GoGlyder?' : 'Already have an account?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        TextButton(
          onPressed: _isLoading ? null : () => _setMode(!_isLogin),
          child: Text(
            _isLogin ? 'Create one' : 'Sign in',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ).animate(delay: 600.ms).fadeIn(duration: 500.ms);
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
