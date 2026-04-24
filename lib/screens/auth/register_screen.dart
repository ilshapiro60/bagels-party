import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/assets.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/app_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _eulaAccepted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authStateProvider.notifier).signUp(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) context.go('/onboarding');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create account: $e')),
      );
    }
  }

  /// Same brand treatment as [LoginScreen] — one asset, no duplicate hero strip.
  Widget _buildLogoHeader(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          PawPartyAssets.homeHeroPets,
          height: 96,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
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
            ),
            child: const Icon(
              Icons.pets,
              size: 38,
              color: PawPartyColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: PawPartyColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Good vibes & playdates',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PawPartyColors.bloomPink,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.06, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: _buildLogoHeader(context)),
                      const SizedBox(height: 20),
                      Text(
                        'Join the Party!',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: PawPartyColors.primary,
                            ),
                      ).animate().fadeIn(duration: 500.ms),
                      const SizedBox(height: 8),
                      Text(
                        'Create your account and find your pet\'s pack',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                      ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                      const SizedBox(height: 8),
                      Text(
                        'Warm, bright, and pet-first — just like home.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: PawPartyColors.bloomPink,
                              fontWeight: FontWeight.w600,
                            ),
                      ).animate().fadeIn(delay: 150.ms, duration: 500.ms),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Your Name',
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Enter your name' : null,
                      ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter your email';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter a password';
                          if (v.length < 6) return 'At least 6 characters';
                          return null;
                        },
                      ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outlined),
                        ),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Passwords don\'t match';
                          }
                          return null;
                        },
                      ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _eulaAccepted,
                            onChanged: (v) =>
                                setState(() => _eulaAccepted = v ?? false),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'I agree to the Terms of Service and Community Guidelines. '
                                'I understand that objectionable content and abusive behavior '
                                'are not tolerated and may result in account removal.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 550.ms, duration: 500.ms),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              authState.isLoading || !_eulaAccepted ? null : _handleSignUp,
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Create Account'),
                        ),
                      ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  color: PawPartyColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
