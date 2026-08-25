import 'package:cycle_ready/src/core/presentation/app_bottom_navigation.dart';
import 'package:cycle_ready/src/features/activities/presentation/activities_screen.dart';
import 'package:cycle_ready/src/features/activities/presentation/performance_screen.dart';
import 'package:cycle_ready/src/features/check_in/presentation/check_in_screen.dart';
import 'package:cycle_ready/src/features/coaching/presentation/training_plan_screen.dart';
import 'package:cycle_ready/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cycle_ready/src/features/health/presentation/connections_screen.dart';
import 'package:cycle_ready/src/features/readiness/application/recovery_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainTabsScreen extends ConsumerStatefulWidget {
  const MainTabsScreen({this.initialIndex = 0, super.key});
  final int initialIndex;

  @override
  ConsumerState<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends ConsumerState<MainTabsScreen> {
  late final PageController controller;
  late int index;
  bool checkedForDailyPrompt = false;

  static const pages = [
    DashboardScreen(),
    ActivitiesScreen(),
    PerformanceScreen(),
    TrainingPlanScreen(),
    ConnectionsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex.clamp(0, pages.length - 1);
    controller = PageController(initialPage: index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDailyCheckIn());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _showDailyCheckIn() async {
    if (checkedForDailyPrompt || !mounted) return;
    checkedForDailyPrompt = true;
    final completed = await ref.read(todayCheckInCompletedProvider.future);
    if (completed || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => const DailyCheckInPrompt(),
    );
  }

  void _select(int value) {
    if (value == index) return;
    setState(() => index = value);
    controller.animateToPage(
      value,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: PageView(
          controller: controller,
          onPageChanged: (value) => setState(() => index = value),
          children: pages,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: AppBottomNavigation(
            index: index,
            onDestinationSelected: _select,
          ),
        ),
      );
}
