import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/paw_party_hero_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PawPartyHeroBanner(height: 200),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 28),
                      _buildWelcomeText(),
                      const SizedBox(height: 32),
                      _buildEmailField(),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 8),
                      _buildForgotPassword(),
                      const SizedBox(height: 32),
                      _buildSignInButton(authState.isLoading),
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildSocialButtons(),
                      const SizedBox(height: 32),
                      _buildSignUpLink(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PawPartyColors.primary.withValues(alpha: 0.2),
                PawPartyColors.bloomPinkSoft,
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: PawPartyColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.pets,
            size: 52,
            color: PawPartyColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: PawPartyColors.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Good vibes & playdates',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PawPartyColors.bloomPink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome Back!',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to find your pet\'s next playdate',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.45,
              ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter your email';
        if (!value.contains('@')) return 'Enter a valid email';
        return null;
      },
    ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideX(begin: -0.1);
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter your password';
        if (value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    ).animate().fadeIn(delay: 400.ms, duration: 500.ms).slideX(begin: -0.1);
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        child: Text(
          'Forgot Password?',
          style: TextStyle(
            color: PawPartyColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleSignIn,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text('Sign In'),
      ),
    ).animate().fadeIn(delay: 500.ms, duration: 500.ms);
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: PawPartyColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PawPartyColors.textHint,
                ),
          ),
        ),
        Expanded(child: Divider(color: PawPartyColors.divider)),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialButton(
          Icons.g_mobiledata_rounded,
          'Google',
          () => _handleSocial('google'),
        ),
        const SizedBox(width: 16),
        _socialButton(
          Icons.apple,
          'Apple',
          () => _handleSocial('apple'),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms, duration: 500.ms);
  }

  Future<void> _handleSocial(String method) async {
    await ref.read(authStateProvider.notifier).signInWithSocial(method);
    if (mounted) context.go('/home');
  }

  Widget _socialButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: BorderSide(color: PawPartyColors.divider),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New to ${AppConstants.appName}? ',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        GestureDetector(
          onTap: () => context.go('/register'),
          child: Text(
            'Create Account',
            style: TextStyle(
              color: PawPartyColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
