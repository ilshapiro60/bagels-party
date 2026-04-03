import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/paw_party_hero_banner.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _OnboardingHeroPage(
        title: 'Create Your Pet\'s Profile',
        subtitle:
            'Tell us about their personality, energy level, and play style — not just their breed.',
      ),
      const _OnboardingPage(
        icon: Icons.favorite,
        title: 'Find Compatible Matches',
        subtitle:
            'Our matching engine pairs pets by temperament, not just proximity. Better matches = better playdates.',
        color: PawPartyColors.secondary,
      ),
      const _OnboardingPage(
        icon: Icons.local_pizza,
        title: 'Host a party',
        subtitle:
            'Invite matched families over. Pizza and drinks provided by the host — that\'s our promise!',
        color: PawPartyColors.pizzaGold,
      ),
      const _OnboardingPage(
        icon: Icons.auto_stories,
        title: 'Build Their Passport',
        subtitle:
            'Track every meetup, watch your pet\'s social skills grow, and share their journey.',
        color: PawPartyColors.primaryLight,
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: PawPartyColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) => _pages[index],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? PawPartyColors.primary
                              : PawPartyColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          context.go('/home');
                        }
                      },
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'Next'
                            : 'Get Started!',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingHeroPage extends StatelessWidget {
  final String title;
  final String subtitle;

  const _OnboardingHeroPage({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PawPartyHeroBanner(
            height: 220,
            borderRadius: BorderRadius.circular(28),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
          const SizedBox(height: 28),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: PawPartyColors.textSecondary,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: color),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          const SizedBox(height: 48),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: PawPartyColors.textSecondary,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
        ],
      ),
    );
  }
}
