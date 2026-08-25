import 'package:cycle_ready/src/core/routing/app_router.dart';
import 'package:cycle_ready/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/coaching/application/coach_reminder_controller.dart';
import 'package:cycle_ready/src/features/sync/application/sync_coordinator.dart';

class CycleReadyApp extends ConsumerStatefulWidget {
  const CycleReadyApp({super.key});

  @override
  ConsumerState<CycleReadyApp> createState() => _CycleReadyAppState();
}

class _CycleReadyAppState extends ConsumerState<CycleReadyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = ref.read(coachReminderServiceProvider);
      await service.initialize(
        openRoute: (route) => ref.read(appRouterProvider).go(route),
      );
      await service.restoreSchedule();
      await ref.read(appSyncControllerProvider.future);
      await ref.read(appSyncControllerProvider.notifier).sync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appSyncControllerProvider.notifier).sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appSyncControllerProvider);
    return MaterialApp.router(
      title: 'CycleReady',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
