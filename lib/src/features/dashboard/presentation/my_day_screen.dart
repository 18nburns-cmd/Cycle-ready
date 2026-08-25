import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/core/formatting/units.dart';
import 'package:cycle_ready/src/features/activities/data/activity_repository.dart';
import 'package:cycle_ready/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:cycle_ready/src/features/readiness/application/readiness_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyDayScreen extends ConsumerWidget {
  const MyDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides =
        ref.watch(activitiesProvider).valueOrNull ?? const <Activity>[];
    final fitness = ref.watch(fitnessMetricsProvider);
    final readiness = ref.watch(todayReadinessProvider);
    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    final weeklyRides =
        rides.where((ride) => ride.startedAt.isAfter(weekStart)).toList();
    final weeklyDistance = weeklyRides.fold<double>(
      0,
      (total, ride) => total + ride.distanceMetres,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'This Week',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const DashboardSectionTitle('Rolling seven days'),
          RollingHistoryCard(rides: rides, history: fitness.history),
          const SizedBox(height: 20),
          const DashboardSectionTitle('This week'),
          Row(
            children: [
              Expanded(
                child: DashboardMetricCard(
                  label: 'Distance',
                  value: Units.distance(weeklyDistance, decimals: 0),
                  detail: '${weeklyRides.length} rides',
                  icon: Icons.route_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardMetricCard(
                  label: 'Load',
                  value: fitness.weeklyLoad.toStringAsFixed(0),
                  detail: 'Last 7 days',
                  icon: Icons.monitor_heart_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const DashboardSectionTitle('Readiness factors'),
          ...readiness.factors.map(ReadinessFactorTile.new),
          const SizedBox(height: 12),
          Text(
            'Readiness factors reflect today while the charts above use the latest rolling seven days.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
