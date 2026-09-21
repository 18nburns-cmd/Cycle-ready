import 'dart:async';

import 'package:cycle_ready/src/core/routing/app_router.dart';
import 'package:cycle_ready/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cycle_ready/src/features/coaching/application/coach_reminder_controller.dart';
import 'package:cycle_ready/src/features/coaching/application/daily_coaching_status_provider.dart';
import 'package:cycle_ready/src/features/sync/application/sync_coordinator.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_auth_provider.dart';
import 'package:cycle_ready/src/features/notifications/application/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CycleReadyApp extends ConsumerStatefulWidget {
  const CycleReadyApp({super.key});

  @override
  ConsumerState<CycleReadyApp> createState() => _CycleReadyAppState();
}

class _CycleReadyAppState extends ConsumerState<CycleReadyApp>
    with WidgetsBindingObserver {
  PushNotificationService? _pushNotifications;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(cloudConfigProvider).isConfigured) {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen(
        (state) {
          ref.invalidate(todayDailyCoachingRecommendationProvider);
          if (state.event == AuthChangeEvent.passwordRecovery && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showPasswordReset();
            });
          }
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = ref.read(coachReminderServiceProvider);
      await service.initialize(
        openRoute: (route) => ref.read(appRouterProvider).go(route),
      );
      await service.restoreSchedule();
      if (ref.read(cloudConfigProvider).isConfigured &&
          PushNotificationService.isSupported) {
        try {
          _pushNotifications = ref.read(pushNotificationServiceProvider);
          await _pushNotifications!.start(
            openRoute: (route) => ref.read(appRouterProvider).go(route),
          );
        } catch (_) {
          // Push registration must never block health, training or cloud sync.
          // A later app start retries token registration automatically.
        }
      }
      await ref.read(appSyncControllerProvider.future);
      await ref.read(appSyncControllerProvider.notifier).sync();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _pushNotifications?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _showPasswordReset() async {
    final password = TextEditingController();
    String? validation;
    var busy = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose a new password'),
          content: TextField(
            controller: password,
            obscureText: true,
            enabled: !busy,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'New password',
              errorText: validation,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (password.text.length < 8) {
                        setDialogState(
                            () => validation = 'Use at least 8 characters.');
                        return;
                      }
                      setDialogState(() {
                        busy = true;
                        validation = null;
                      });
                      try {
                        await ref
                            .read(cloudAuthRepositoryProvider)
                            .updatePassword(password: password.text);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (error) {
                        setDialogState(() {
                          busy = false;
                          validation = error.toString();
                        });
                      }
                    },
              child: const Text('Update password'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayDailyCoachingRecommendationProvider);
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
