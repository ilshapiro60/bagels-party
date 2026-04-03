import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';

class NavShell extends StatelessWidget {
  final Widget child;

  const NavShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/discover')) return 1;
    if (location.startsWith('/passport')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: PawPartyColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(
                  context,
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  route: '/home',
                  currentIndex: index,
                ),
                _navItem(
                  context,
                  index: 1,
                  icon: Icons.search,
                  activeIcon: Icons.search,
                  label: 'Discover',
                  route: '/discover',
                  currentIndex: index,
                ),
                _hostButton(context),
                _navItem(
                  context,
                  index: 2,
                  icon: Icons.auto_stories_outlined,
                  activeIcon: Icons.auto_stories,
                  label: 'Passport',
                  route: '/passport',
                  currentIndex: index,
                ),
                _navItem(
                  context,
                  index: 3,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  route: '/profile',
                  currentIndex: index,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required int currentIndex,
  }) {
    final isActive = index == currentIndex;

    return GestureDetector(
      onTap: () => context.go(route),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive
                  ? PawPartyColors.primary
                  : PawPartyColors.textHint,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? PawPartyColors.primary
                    : PawPartyColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hostButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/host'),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PawPartyColors.primary, PawPartyColors.primaryDark],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: PawPartyColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.local_pizza,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
