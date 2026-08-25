import 'package:cycle_ready/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cycle_ready/src/features/cloud_sync/data/cloud_config.dart';
import 'package:cycle_ready/src/features/cloud_sync/presentation/cloud_account_button.dart';
import 'package:cycle_ready/src/features/cloud_sync/application/cloud_snapshot_provider.dart';
import 'package:cycle_ready/src/features/cloud_sync/domain/web_dashboard_summary.dart';
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
    _EmptyFeature(
      icon: Icons.show_chart,
      title: 'Performance',
      description:
          'Fitness, fatigue, form, power curve and ride analysis will appear here once cloud sync is connected.',
    ),
    _EmptyFeature(
      icon: Icons.calendar_month,
      title: 'Training calendar',
      description:
          'Planned and completed rides, strength sessions and mobility work will share one calendar.',
    ),
    _EmptyFeature(
      icon: Icons.favorite,
      title: 'Wellness',
      description:
          'Sleep, HRV, resting heart rate, recovery and body-composition trends will be available across longer periods.',
    ),
    _EmptyFeature(
      icon: Icons.restaurant,
      title: 'Nutrition',
      description:
          'Daily calories, macros, hydration and saved foods will stay aligned with the phone app.',
    ),
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
                  'The responsive dashboard is ready. Secure cloud sync is the next milestone before personal health and training data can appear here.',
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

class _EmptyFeature extends StatelessWidget {
  const _EmptyFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(description, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}
