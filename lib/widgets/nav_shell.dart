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
    if (location.startsWith('/neighborhood-news')) return 3;
    if (location.startsWith('/profile')) return 4;
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
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                _navItem(
                  context,
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  route: '/home',
                  currentIndex: index,
                  inactiveTint: PawPartyColors.primaryLight,
                ),
                _navItem(
                  context,
                  index: 1,
                  icon: Icons.search,
                  activeIcon: Icons.search,
                  label: 'Discover',
                  route: '/discover',
                  currentIndex: index,
                  inactiveTint: PawPartyColors.secondary,
                ),
                _navItem(
                  context,
                  index: -1,
                  icon: Icons.local_pizza_outlined,
                  activeIcon: Icons.local_pizza,
                  label: 'Host',
                  route: '/host',
                  currentIndex: index,
                  isPush: true,
                  inactiveTint: Color.lerp(
                    PawPartyColors.pizzaGold,
                    PawPartyColors.pawBrown,
                    0.35,
                  )!,
                ),
                _navItem(
                  context,
                  index: 2,
                  icon: Icons.auto_stories_outlined,
                  activeIcon: Icons.auto_stories,
                  label: 'Passport',
                  route: '/passport',
                  currentIndex: index,
                  inactiveTint: PawPartyColors.rugTeal,
                ),
                _navItem(
                  context,
                  index: 3,
                  icon: Icons.forum_outlined,
                  activeIcon: Icons.forum,
                  label: 'News',
                  route: '/neighborhood-news',
                  currentIndex: index,
                  inactiveTint: PawPartyColors.bloomPink,
                ),
                _navItem(
                  context,
                  index: 4,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  route: '/profile',
                  currentIndex: index,
                  inactiveTint: PawPartyColors.accent,
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
    required Color inactiveTint,
    bool isPush = false,
  }) {
    final isActive = index == currentIndex;
    final iconColor =
        isActive ? PawPartyColors.primary : inactiveTint;
    final labelColor = isActive
        ? PawPartyColors.primary
        : Color.lerp(inactiveTint, PawPartyColors.textSecondary, 0.45)!;

    return Expanded(
      child: GestureDetector(
        onTap: () => isPush ? context.push(route) : context.go(route),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: iconColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: labelColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

}
