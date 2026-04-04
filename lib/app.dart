import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'providers/app_providers.dart';
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
    _restore();
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
