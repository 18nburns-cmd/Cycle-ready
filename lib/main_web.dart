import 'package:cycle_ready/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/cloud_config.dart';
import 'package:cycle_ready/src/features/cloud_sync/presentation/cloud_account_button.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_snapshot_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_dashboard_summary.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_portal_data.dart';
import 'package:cycle_ready/src/features/cloud_sync/presentation/web_ride_detail_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeCloudIfConfigured();
  runApp(const ProviderScope(child: CycleReadyWebApp()));
}

class CycleReadyWebApp extends StatelessWidget {
  const CycleReadyWebApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CycleReady Web',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const WebDashboardShell(),
      );
}

class WebDashboardShell extends StatefulWidget {
  const WebDashboardShell({super.key});

  @override
  State<WebDashboardShell> createState() => _WebDashboardShellState();
}

class _WebDashboardShellState extends State<WebDashboardShell> {
  int selectedIndex = 0;

  static const destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today),
      label: Text('Today'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: Text('Performance'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: Text('Calendar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.favorite_outline),
      selectedIcon: Icon(Icons.favorite),
      label: Text('Wellness'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.restaurant_outlined),
      selectedIcon: Icon(Icons.restaurant),
      label: Text('Nutrition'),
    ),
  ];

  static const pages = <Widget>[
    _WebOverview(),
    _PerformancePage(),
    _CalendarPage(),
    _WellnessPage(),
    _NutritionPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = Column(
      children: [
        _WebHeader(section: destinations[selectedIndex].label),
        Expanded(child: pages[selectedIndex]),
      ],
    );
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              selectedIndex: selectedIndex,
              onDestinationSelected: _select,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: _CycleReadyMark(),
              ),
              destinations: destinations,
            ),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: _select,
              destinations: destinations
                  .map(
                    (item) => NavigationDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: (item.label as Text).data!,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  void _select(int value) => setState(() => selectedIndex = value);
}

class _WebHeader extends StatelessWidget {
  const _WebHeader({required this.section});

  final Widget section;

  @override
  Widget build(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            if (MediaQuery.sizeOf(context).width < 900) ...[
              const _CycleReadyMark(),
              const SizedBox(width: 16),
            ],
            DefaultTextStyle(
              style: Theme.of(context).textTheme.titleLarge!,
              child: section,
            ),
            const Spacer(),
            const CloudAccountButton(),
          ],
        ),
      );
}

class _CycleReadyMark extends StatelessWidget {
  const _CycleReadyMark();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'CycleReady',
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: const Icon(Icons.directions_bike),
        ),
      );
}

class _WebOverview extends ConsumerWidget {
  const _WebOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your cycling wellness, on a bigger screen',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A live view of your latest training, recovery and body metrics from CycleReady.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ref.watch(webDashboardSummaryProvider).when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stack) => _CloudError(error: error),
                      data: (summary) => summary == null
                          ? const _CloudFoundationCard()
                          : _SyncedMetrics(summary: summary),
                    ),
                const SizedBox(height: 18),
                const _TodayDetails(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900 ? 3 : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 16) / columns;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _PreviewCard(
                          width: width,
                          icon: Icons.bolt,
                          title: 'Readiness and recovery',
                          body:
                              'Today’s readiness, sleep, recovery time and coaching rationale.',
                        ),
                        _PreviewCard(
                          width: width,
                          icon: Icons.query_stats,
                          title: 'Training performance',
                          body:
                              'Long-range fitness, fatigue, form, FTP and power trends.',
                        ),
                        _PreviewCard(
                          width: width,
                          icon: Icons.map_outlined,
                          title: 'Detailed ride analysis',
                          body:
                              'Routes, power, heart rate, cadence and post-ride coaching.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
}

class _SyncedMetrics extends StatelessWidget {
  const _SyncedMetrics({required this.summary});

  final WebDashboardSummary summary;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricChip(label: 'Rides', value: '${summary.rideCount}'),
          _MetricChip(
            label: 'Distance',
            value:
                '${(summary.totalDistanceMetres / 1609.344).toStringAsFixed(0)} mi',
          ),
          _MetricChip(
            label: 'Time',
            value:
                '${(summary.totalDurationSeconds / 3600).toStringAsFixed(1)} h',
          ),
          _MetricChip(
            label: 'Load',
            value: summary.totalTrainingLoad.toStringAsFixed(0),
          ),
          _MetricChip(label: 'FTP', value: _optional(summary.ftp, ' W')),
          _MetricChip(
            label: 'Weight',
            value: summary.weightKg == null
                ? 'Not available'
                : '${summary.weightKg!.toStringAsFixed(1)} kg',
          ),
          _MetricChip(
            label: 'HRV',
            value: summary.latestHrv == null
                ? 'Not available'
                : '${summary.latestHrv!.toStringAsFixed(0)} ms',
          ),
        ],
      );

  String _optional(Object? value, String suffix) =>
      value == null ? 'Not available' : '$value$suffix';
}

class _TodayDetails extends ConsumerWidget {
  const _TodayDetails();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(webPortalDataProvider)
      .when(
        loading: () => const SizedBox.shrink(),
        error: (error, stack) => const SizedBox.shrink(),
        data: (data) {
          if (data == null) return const SizedBox.shrink();
          final latest = data.recovery.isEmpty ? null : data.recovery.first;
          final week = data.activitiesSince(const Duration(days: 7));
          final todayNutrition = data.nutritionFor(DateTime.now());
          final upcoming = data.planned
              .where((session) => !session.day.isBefore(DateTime.now()))
              .toList();
          return Column(
            children: [
              _MetricWrap(metrics: [
                (
                  'Latest sleep',
                  latest?.sleepMinutes == null
                      ? '—'
                      : '${(latest!.sleepMinutes! / 60).toStringAsFixed(1)} h'
                ),
                (
                  'Resting HR',
                  latest?.restingHeartRate == null
                      ? '—'
                      : '${latest!.restingHeartRate!.toStringAsFixed(0)} bpm'
                ),
                (
                  '7-day load',
                  week
                      .fold<double>(0, (sum, ride) => sum + ride.trainingLoad)
                      .toStringAsFixed(0)
                ),
                ('Today’s calories', '${todayNutrition.calories} kcal'),
                ('Today’s water', '${todayNutrition.waterMillilitres} ml'),
              ]),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Next planned session',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const CircleAvatar(child: Icon(Icons.directions_bike)),
                    title: Text(upcoming.first.title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        '${_longDate(upcoming.first.day)} • ${upcoming.first.durationMinutes} min • ${upcoming.first.targetLoad} load'),
                  ),
                ),
              ],
            ],
          );
        },
      );
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Text(value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        )),
              ],
            ),
          ),
        ),
      );
}

class _CloudError extends StatelessWidget {
  const _CloudError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Cloud data could not be loaded'),
          subtitle: Text('$error'),
        ),
      );
}

class _CloudFoundationCard extends StatelessWidget {
  const _CloudFoundationCard();

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_outlined, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secure sync required',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your Android data remains private and unchanged. A cloud account must be configured before this webpage can receive it.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.body,
  });

  final double width;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 28),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(body),
              ],
            ),
          ),
        ),
      );
}

class _PerformancePage extends ConsumerWidget {
  const _PerformancePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _PortalPage(
        data: ref.watch(webPortalDataProvider),
        builder: (data) {
          final week = data.activitiesSince(const Duration(days: 7));
          final month = data.activitiesSince(const Duration(days: 28));
          final weekLoad =
              week.fold<double>(0, (sum, ride) => sum + ride.trainingLoad);
          final monthLoad =
              month.fold<double>(0, (sum, ride) => sum + ride.trainingLoad);
          final recent = data.activities.take(10).toList();
          return _WebPageBody(
            title: 'Training performance',
            subtitle:
                'Current fitness signals and the rides that created them.',
            children: [
              _MetricWrap(metrics: [
                ('FTP', _value(data.ftp, ' W')),
                (
                  'Power / weight',
                  data.powerToWeight == null
                      ? '—'
                      : '${data.powerToWeight!.toStringAsFixed(2)} W/kg'
                ),
                ('7-day load', weekLoad.toStringAsFixed(0)),
                ('28-day load', monthLoad.toStringAsFixed(0)),
                ('7-day rides', '${week.length}'),
                (
                  '28-day hours',
                  '${(month.fold<int>(0, (sum, ride) => sum + ride.durationSeconds) / 3600).toStringAsFixed(1)} h'
                ),
              ]),
              _SectionCard(
                title: 'Training load — last rides',
                child: _BarTrend(
                  values:
                      recent.reversed.map((ride) => ride.trainingLoad).toList(),
                  colour: Colors.purpleAccent,
                ),
              ),
              _SectionCard(
                title: 'Recent activities',
                child: _ActivityTable(activities: recent),
              ),
              if (data.ftpHistory.isNotEmpty)
                _SectionCard(
                  title: 'FTP history',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: data.ftpHistory
                        .take(8)
                        .map((estimate) => Chip(
                              label: Text(
                                  '${_shortDate(estimate.estimatedAt)}  •  ${estimate.watts} W  •  ${estimate.confidence}'),
                            ))
                        .toList(),
                  ),
                ),
            ],
          );
        },
      );
}

class _CalendarPage extends ConsumerWidget {
  const _CalendarPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _PortalPage(
        data: ref.watch(webPortalDataProvider),
        builder: (data) {
          final now = DateTime.now();
          final windowStart = now.subtract(const Duration(days: 14));
          final windowEnd = now.add(const Duration(days: 42));
          final entries = <_CalendarEntry>[
            ...data.activities
                .where((item) =>
                    item.startedAt.isAfter(windowStart) &&
                    item.startedAt.isBefore(windowEnd))
                .map((item) => _CalendarEntry(
                    item.startedAt,
                    item.title,
                    '${(item.durationSeconds / 60).round()} min • ${item.trainingLoad.toStringAsFixed(0)} load',
                    true)),
            ...data.planned
                .where((item) =>
                    item.day.isAfter(windowStart) &&
                    item.day.isBefore(windowEnd))
                .map((item) => _CalendarEntry(
                    item.day,
                    item.title,
                    '${item.durationMinutes} min • ${item.targetLoad} target load',
                    false)),
          ]..sort((a, b) => a.day.compareTo(b.day));
          return _WebPageBody(
            title: 'Training calendar',
            subtitle:
                'Completed activities and upcoming CycleReady sessions in one timeline.',
            children: [
              _MetricWrap(metrics: [
                (
                  'Completed (14 days)',
                  '${entries.where((item) => item.completed).length}'
                ),
                (
                  'Planned (6 weeks)',
                  '${entries.where((item) => !item.completed).length}'
                ),
                (
                  'Next session',
                  data.planned.where((item) => !item.day.isBefore(now)).isEmpty
                      ? 'None'
                      : data.planned
                          .firstWhere((item) => !item.day.isBefore(now))
                          .title
                ),
              ]),
              _SectionCard(
                title: 'Schedule',
                child: entries.isEmpty
                    ? const Text(
                        'No completed or planned sessions are available in this period.')
                    : Column(
                        children: entries
                            .map((entry) => ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: entry.completed
                                        ? Colors.green.withValues(alpha: .18)
                                        : Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                    child: Icon(entry.completed
                                        ? Icons.check
                                        : Icons.schedule),
                                  ),
                                  title: Text(entry.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      '${_longDate(entry.day)} • ${entry.detail}'),
                                  trailing: Text(entry.completed
                                      ? 'Completed'
                                      : 'Planned'),
                                ))
                            .toList()),
              ),
            ],
          );
        },
      );
}

class _WellnessPage extends ConsumerWidget {
  const _WellnessPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _PortalPage(
        data: ref.watch(webPortalDataProvider),
        builder: (data) {
          final latest = data.recovery.isEmpty ? null : data.recovery.first;
          final recent = data.recovery.take(14).toList().reversed.toList();
          final body = data.body.take(12).toList().reversed.toList();
          return _WebPageBody(
            title: 'Wellness and recovery',
            subtitle:
                'Sleep, autonomic recovery, check-in signals and body trends.',
            children: [
              _MetricWrap(metrics: [
                (
                  'Sleep',
                  latest?.sleepMinutes == null
                      ? '—'
                      : '${(latest!.sleepMinutes! / 60).toStringAsFixed(1)} h'
                ),
                (
                  'HRV',
                  latest?.hrvMilliseconds == null
                      ? '—'
                      : '${latest!.hrvMilliseconds!.toStringAsFixed(0)} ms'
                ),
                (
                  'Resting HR',
                  latest?.restingHeartRate == null
                      ? '—'
                      : '${latest!.restingHeartRate!.toStringAsFixed(0)} bpm'
                ),
                (
                  'Weight',
                  data.currentWeight == null
                      ? '—'
                      : '${data.currentWeight!.toStringAsFixed(1)} kg'
                ),
                ('Fatigue check-in', _value(latest?.fatigue, '/10')),
                ('Stress check-in', _value(latest?.stress, '/10')),
                ('Motivation', _value(latest?.motivation, '/10')),
              ]),
              _SectionCard(
                title: 'HRV — recent records',
                child: _BarTrend(
                    values: recent
                        .map((item) => item.hrvMilliseconds ?? 0)
                        .toList(),
                    colour: Colors.tealAccent),
              ),
              _SectionCard(
                title: 'Sleep — recent records',
                child: _BarTrend(
                    values: recent
                        .map((item) => (item.sleepMinutes ?? 0) / 60)
                        .toList(),
                    colour: Colors.lightBlueAccent),
              ),
              if (body.isNotEmpty)
                _SectionCard(
                  title: 'Body weight',
                  child: _BarTrend(
                      values: body.map((item) => item.weightKg).toList(),
                      colour: Colors.orangeAccent),
                ),
            ],
          );
        },
      );
}

class _NutritionPage extends ConsumerWidget {
  const _NutritionPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _PortalPage(
        data: ref.watch(webPortalDataProvider),
        builder: (data) {
          final today = DateTime.now();
          final progress = data.nutritionFor(today);
          final entries = data.nutrition
              .where((item) => _isSameDay(item.recordedAt, today))
              .toList();
          return _WebPageBody(
            title: 'Nutrition and hydration',
            subtitle:
                'Today’s intake compared with the adaptive targets stored by CycleReady.',
            children: [
              _NutritionProgressGrid(progress: progress),
              _SectionCard(
                title: 'Today’s entries',
                child: entries.isEmpty
                    ? const Text(
                        'No nutrition or hydration entries have been recorded today.')
                    : Column(
                        children: entries
                            .map((entry) => ListTile(
                                  leading: CircleAvatar(
                                      child: Icon(entry.waterMillilitres > 0 &&
                                              entry.calories == 0
                                          ? Icons.water_drop
                                          : Icons.restaurant)),
                                  title: Text(entry.label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      '${entry.calories} kcal • ${entry.carbohydrateGrams.toStringAsFixed(0)} g carbs • ${entry.proteinGrams.toStringAsFixed(0)} g protein • ${entry.fatGrams.toStringAsFixed(0)} g fat'),
                                  trailing: entry.waterMillilitres == 0
                                      ? null
                                      : Text('${entry.waterMillilitres} ml'),
                                ))
                            .toList()),
              ),
            ],
          );
        },
      );
}

class _PortalPage extends StatelessWidget {
  const _PortalPage({required this.data, required this.builder});
  final AsyncValue<WebPortalData?> data;
  final Widget Function(WebPortalData data) builder;
  @override
  Widget build(BuildContext context) => data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: _CloudError(error: error)),
        data: (value) => value == null
            ? const Center(child: Text('Sign in to view your CycleReady data.'))
            : builder(value),
      );
}

class _WebPageBody extends StatelessWidget {
  const _WebPageBody(
      {required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              for (final child in children) ...[
                child,
                const SizedBox(height: 18)
              ],
            ]),
          ),
        ),
      );
}

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.metrics});
  final List<(String, String)> metrics;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: metrics
            .map((item) => _MetricChip(label: item.$1, value: item.$2))
            .toList(),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            child,
          ]),
        ),
      );
}

class _ActivityTable extends StatelessWidget {
  const _ActivityTable({required this.activities});
  final List<WebActivity> activities;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
            columns: const [
              DataColumn(label: Text('Ride')),
              DataColumn(label: Text('Distance')),
              DataColumn(label: Text('Time')),
              DataColumn(label: Text('Power')),
              DataColumn(label: Text('Heart rate')),
              DataColumn(label: Text('Load')),
            ],
            rows: activities
                .map((ride) => DataRow(
                      onSelectChanged: (_) => showDialog<void>(
                        context: context,
                        builder: (_) => WebRideDetailDialog(activity: ride),
                      ),
                      cells: [
                        DataCell(SizedBox(
                            width: 210,
                            child: Text(
                                '${ride.title}\n${_shortDate(ride.startedAt)}'))),
                        DataCell(Text(
                            '${(ride.distanceMetres / 1609.344).toStringAsFixed(1)} mi')),
                        DataCell(Text(
                            '${(ride.durationSeconds / 3600).toStringAsFixed(1)} h')),
                        DataCell(Text(ride.averagePower == null
                            ? '—'
                            : '${ride.averagePower} W')),
                        DataCell(Text(ride.averageHeartRate == null
                            ? '—'
                            : '${ride.averageHeartRate} bpm')),
                        DataCell(Text(ride.trainingLoad.toStringAsFixed(0))),
                      ],
                    ))
                .toList()),
      );
}

class _BarTrend extends StatelessWidget {
  const _BarTrend({required this.values, required this.colour});
  final List<double> values;
  final Color colour;
  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(
        0, (current, value) => value > current ? value : current);
    return SizedBox(
      height: 150,
      child: values.isEmpty || max <= 0
          ? const Center(child: Text('Not enough data yet.'))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: values
                  .map((value) => Expanded(
                        child: Tooltip(
                          message: value.toStringAsFixed(1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: 12 + 128 * value / max,
                              decoration: BoxDecoration(
                                  color: colour,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6))),
                            ),
                          ),
                        ),
                      ))
                  .toList()),
    );
  }
}

class _NutritionProgressGrid extends StatelessWidget {
  const _NutritionProgressGrid({required this.progress});
  final WebNutritionProgress progress;
  @override
  Widget build(BuildContext context) {
    final target = progress.target;
    return _MetricWrap(metrics: [
      ('Calories', _progress(progress.calories, target?.calories, 'kcal')),
      (
        'Carbohydrate',
        _progress(progress.carbohydrateGrams, target?.carbohydrateGrams, 'g')
      ),
      ('Protein', _progress(progress.proteinGrams, target?.proteinGrams, 'g')),
      ('Fat', _progress(progress.fatGrams, target?.fatGrams, 'g')),
      (
        'Water',
        _progress(progress.waterMillilitres, target?.waterMillilitres, 'ml')
      ),
    ]);
  }

  String _progress(num value, num? target, String unit) => target == null
      ? '${value.toStringAsFixed(0)} $unit'
      : '${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit';
}

class _CalendarEntry {
  const _CalendarEntry(this.day, this.title, this.detail, this.completed);
  final DateTime day;
  final String title;
  final String detail;
  final bool completed;
}

String _value(Object? value, String suffix) =>
    value == null ? '—' : '$value$suffix';
String _shortDate(DateTime day) => '${day.day}/${day.month}/${day.year}';
String _longDate(DateTime day) =>
    '${_weekday(day.weekday)} ${day.day}/${day.month}/${day.year}';
String _weekday(int day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
