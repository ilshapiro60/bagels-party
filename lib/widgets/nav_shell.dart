import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import 'paw_party_pizza_icon.dart';

class NavShell extends StatelessWidget {
  final Widget child;

  const NavShell({super.key, required this.child});

  /// Shell tab index for bottom ribbon highlight. Profile is not a tab (opens from Home header).
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/discover')) return 1;
    if (location.startsWith('/passport')) return 2;
    if (location.startsWith('/neighborhood-news')) return 3;
    if (location.startsWith('/profile')) return -99;
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
                _hostNavItem(context),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Host CTA: slightly larger than tab icons, inside a circle (pizza graphic).
  static const double _hostCircleDiameter = 58;

  Widget _hostNavItem(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push('/host'),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: const Offset(0, -5),
              child: Container(
                width: _hostCircleDiameter,
                height: _hostCircleDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PawPartyColors.warmOak,
                  border: Border.all(
                    color: PawPartyColors.primary.withValues(alpha: 0.2),
                    width: 1.25,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: PawPartyColors.secondary.withValues(alpha: 0.12),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: PawPartyPizzaIcon(size: 42),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Host',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color.lerp(
                  PawPartyColors.primary,
                  PawPartyColors.bloomPink,
                  0.35,
                )!,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
