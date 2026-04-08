import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'providers/app_providers.dart';
import 'services/push_notification_service.dart';
import 'widgets/startup_splash.dart';

class PawPartyApp extends ConsumerStatefulWidget {
  const PawPartyApp({super.key});

  @override
  ConsumerState<PawPartyApp> createState() => _PawPartyAppState();
}

class _PawPartyAppState extends ConsumerState<PawPartyApp> {
  bool _sessionReady = false;

  @override
  void initState() {
    super.initState();
    _setupPushCallbacks();
    _restore();
  }

  void _setupPushCallbacks() {
    PushNotificationService.onForegroundMessage = _showForegroundBanner;
    PushNotificationService.onNotificationTap = _handleNotificationTap;
  }

  void _showForegroundBanner(RemoteMessage message) {
    final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;

    ScaffoldMessenger.of(ctx).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(Icons.pets, color: PawPartyTheme.lightTheme.colorScheme.primary),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty)
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner();
              _handleNotificationTap(message);
            },
            child: const Text('View'),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      final c = appRouter.routerDelegate.navigatorKey.currentContext;
      if (c == null || !c.mounted) return;
      ScaffoldMessenger.of(c).hideCurrentMaterialBanner();
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'buddy_request' || type == 'buddy_accepted') {
      appRouter.go('/friends');
    } else if (type == 'party_invite' || type == 'party_invite_accepted') {
      appRouter.go('/home');
    }
  }

  Future<void> _restore() async {
    try {
      await ref.read(authStateProvider.notifier).restoreSession();
    } catch (e, st) {
      debugPrint('Startup session restore error: $e\n$st');
    } finally {
      if (mounted) setState(() => _sessionReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionReady) {
      return MaterialApp(
        title: 'Bagel\'s Party',
        debugShowCheckedModeBanner: false,
        theme: PawPartyTheme.lightTheme,
        home: const StartupSplash(),
      );
    }
    return MaterialApp.router(
      title: 'Bagel\'s Party',
      debugShowCheckedModeBanner: false,
      theme: PawPartyTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
