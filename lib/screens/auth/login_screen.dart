import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/assets.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/app_providers.dart';

String _snackBarErrorText(Object e) {
  var s = e.toString();
  const prefix = 'Exception: ';
  if (s.startsWith(prefix)) {
    s = s.substring(prefix.length).trim();
  }
  return s;
}

/// Human-readable auth errors (avoids raw `[firebase_auth/invalid-credential]` in UI).
String _authUserMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'That email or password is not correct. Try again or tap Forgot password.';
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support if you need help.';
      case 'too-many-requests':
        return 'Too many sign-in attempts. Wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Network problem. Check your connection and try again.';
      case 'credential-already-in-use':
        return 'That sign-in is already linked to another account.';
      case 'operation-not-allowed':
        return 'This sign-in method is not available right now.';
      case 'internal-error':
        return 'Something went wrong. Please try again in a moment.';
      case 'missing-android-pkg-name':
      case 'missing-ios-bundle-id':
        return 'Password reset is not configured for this app build. Contact support.';
      default:
        break;
    }
  }
  final raw = _snackBarErrorText(e);
  if (raw.contains('firebase_auth') || raw.contains('FirebaseAuth')) {
    return 'Sign-in could not be completed. Please try again.';
  }
  return raw;
}

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
    try {
      await ref.read(authStateProvider.notifier).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authUserMessage(e))),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your email in the field above, then tap Forgot password again.',
          ),
        ),
      );
      return;
    }
    try {
      await ref.read(authStateProvider.notifier).sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'If $email is registered, you’ll get a reset link shortly. '
            'Check spam/junk if you don’t see it.',
          ),
        ),
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Check the email address and try again.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authUserMessage(e))),
      );
    }
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 6),
                      _buildWelcomeText(),
                      const SizedBox(height: 10),
                      ..._passwordFlow(authState.isLoading),
                      const SizedBox(height: 8),
                      _buildDivider(),
                      const SizedBox(height: 8),
                      _buildSocialButtons(),
                      const SizedBox(height: 8),
                      _buildSignUpLink(),
                      const SizedBox(height: 4),
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
        const SizedBox(height: 10),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: PawPartyColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Good vibes & playdates',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: PawPartyColors.bloomPink,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Sign in to find your pet\'s next playdate',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.25,
                color: PawPartyColors.textSecondary,
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
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        prefixIcon: Icon(Icons.email_outlined, size: 20),
        prefixIconConstraints: BoxConstraints(minWidth: 40, minHeight: 36),
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        prefixIcon: const Icon(Icons.lock_outlined, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 36),
        suffixIcon: IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
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
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: _handleForgotPassword,
        child: Text(
          'Forgot password?',
          style: TextStyle(
            color: PawPartyColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleSignIn,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
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

  List<Widget> _passwordFlow(bool isLoading) {
    return [
      _buildEmailField(),
      const SizedBox(height: 8),
      _buildPasswordField(),
      const SizedBox(height: 2),
      _buildForgotPassword(),
      const SizedBox(height: 10),
      _buildSignInButton(isLoading),
    ];
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: PawPartyColors.divider, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'or',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: PawPartyColors.textHint,
                  fontSize: 11,
                ),
          ),
        ),
        Expanded(child: Divider(color: PawPartyColors.divider, height: 1)),
      ],
    );
  }

  Widget _buildSocialButtons() {
    final showApple = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Row(
      children: [
        Expanded(
          child: _socialButton(
            Icons.g_mobiledata_rounded,
            'Google',
            () => _handleSocial('google'),
          ),
        ),
        if (showApple) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _socialButton(
              Icons.apple,
              'Apple',
              () => _handleSocial('apple'),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 600.ms, duration: 500.ms);
  }

  Future<void> _handleSocial(String method) async {
    try {
      final ok =
          await ref.read(authStateProvider.notifier).signInWithSocial(method);
      if (!mounted) return;
      if (ok) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authUserMessage(e))),
      );
    }
  }

  Widget _socialButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: PawPartyColors.divider),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          'New to ${AppConstants.appName}?',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        GestureDetector(
          onTap: () => context.go('/register'),
          child: Text(
            'Create account',
            style: TextStyle(
              color: PawPartyColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
