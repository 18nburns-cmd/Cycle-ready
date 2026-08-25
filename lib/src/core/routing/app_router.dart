import 'package:cycle_ready/src/core/presentation/main_tabs_screen.dart';
import 'package:cycle_ready/src/features/check_in/presentation/check_in_screen.dart';
import 'package:cycle_ready/src/features/activities/presentation/activity_detail_screen.dart';
import 'package:cycle_ready/src/features/activities/presentation/athlete_settings_screen.dart';
import 'package:cycle_ready/src/features/activities/presentation/ftp_estimate_screen.dart';
import 'package:cycle_ready/src/features/activities/presentation/post_ride_debrief_screen.dart';
import 'package:cycle_ready/src/features/coaching/presentation/offline_coach_screen.dart';
import 'package:cycle_ready/src/features/coaching/presentation/local_ai_coach_screen.dart';
import 'package:cycle_ready/src/features/coaching/presentation/event_goal_screen.dart';
import 'package:cycle_ready/src/features/coaching/presentation/planned_workout_detail_screen.dart';
import 'package:cycle_ready/src/core/database/app_database.dart';
import 'package:cycle_ready/src/features/nutrition/presentation/nutrition_screen.dart';
import 'package:cycle_ready/src/features/nutrition/presentation/nutrition_label_scanner_screen.dart';
import 'package:cycle_ready/src/features/nutrition/presentation/saved_foods_screen.dart';
import 'package:cycle_ready/src/features/body/presentation/body_metrics_screen.dart';
import 'package:cycle_ready/src/features/splash/presentation/splash_screen.dart';
import 'package:cycle_ready/src/features/privacy/presentation/data_privacy_screen.dart';
import 'package:cycle_ready/src/features/insights/presentation/personal_insights_screen.dart';
import 'package:cycle_ready/src/features/strength/presentation/strength_screen.dart';
import 'package:cycle_ready/src/features/strength/presentation/strength_workout_screen.dart';
import 'package:cycle_ready/src/features/strength/presentation/mobility_screen.dart';
import 'package:cycle_ready/src/features/strength/presentation/mobility_workout_screen.dart';
import 'package:cycle_ready/src/features/strength/presentation/custom_strength_screen.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_program.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const DataPrivacyScreen(),
      ),
      GoRoute(
        path: '/activities',
        name: 'activities',
        builder: (context, state) => const MainTabsScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/activities/:id/debrief',
        name: 'post-ride-debrief',
        builder: (context, state) =>
            PostRideDebriefScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/activities/:id',
        name: 'activity-detail',
        builder: (context, state) =>
            ActivityDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ftp-estimate',
        name: 'ftp-estimate',
        builder: (context, state) => const FtpEstimateScreen(),
      ),
      GoRoute(
        path: '/athlete',
        name: 'athlete',
        builder: (context, state) => const AthleteSettingsScreen(),
      ),
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const MainTabsScreen(),
      ),
      GoRoute(
        path: '/performance',
        name: 'performance',
        builder: (context, state) => const MainTabsScreen(initialIndex: 2),
      ),
      GoRoute(
        path: '/my-day',
        name: 'my-day',
        builder: (context, state) => const MainTabsScreen(initialIndex: 3),
      ),
      GoRoute(
        path: '/plan',
        name: 'plan',
        builder: (context, state) => const MainTabsScreen(initialIndex: 3),
      ),
      GoRoute(
        path: '/coach',
        name: 'coach',
        builder: (context, state) => const OfflineCoachScreen(),
      ),
      GoRoute(
        path: '/coach/ai',
        name: 'local-ai-coach',
        builder: (context, state) => const LocalAiCoachScreen(),
      ),
      GoRoute(
        path: '/planned-workout',
        name: 'planned-workout',
        builder: (context, state) => PlannedWorkoutDetailScreen(
          session: state.extra! as PlannedSession,
        ),
      ),
      GoRoute(
        path: '/event-goal',
        name: 'event-goal',
        builder: (context, state) => const EventGoalScreen(),
      ),
      GoRoute(
        path: '/insights',
        name: 'insights',
        builder: (context, state) => const PersonalInsightsScreen(),
      ),
      GoRoute(
        path: '/check-in',
        name: 'check-in',
        builder: (context, state) => const CheckInScreen(),
      ),
      GoRoute(
        path: '/connections',
        name: 'connections',
        builder: (context, state) => const MainTabsScreen(initialIndex: 4),
      ),
      GoRoute(
        path: '/nutrition',
        name: 'nutrition',
        builder: (context, state) => const NutritionScreen(),
      ),
      GoRoute(
        path: '/nutrition/scan',
        name: 'nutrition-label-scanner',
        builder: (context, state) => const NutritionLabelScannerScreen(),
      ),
      GoRoute(
        path: '/nutrition/library',
        name: 'saved-foods',
        builder: (context, state) => const SavedFoodsScreen(),
      ),
      GoRoute(
        path: '/strength',
        name: 'strength',
        builder: (context, state) => const StrengthScreen(),
      ),
      GoRoute(
        path: '/strength/mobility',
        name: 'mobility',
        builder: (context, state) => const MobilityScreen(),
      ),
      GoRoute(
        path: '/strength/mobility/:index',
        name: 'mobility-workout',
        builder: (context, state) => MobilityWorkoutScreen(
          routineIndex: int.tryParse(state.pathParameters['index']!) ?? 0,
        ),
      ),
      GoRoute(
        path: '/strength/custom',
        name: 'custom-strength',
        builder: (context, state) => const CustomStrengthScreen(),
      ),
      GoRoute(
        path: '/strength/custom/workout',
        name: 'custom-strength-workout',
        builder: (context, state) => StrengthWorkoutScreen(
          customRoutine: state.extra as StrengthRoutine?,
        ),
      ),
      GoRoute(
        path: '/strength/workout/:index',
        name: 'strength-workout',
        builder: (context, state) => StrengthWorkoutScreen(
          routineIndex: int.tryParse(state.pathParameters['index']!) ?? 0,
        ),
      ),
      GoRoute(
        path: '/body',
        name: 'body',
        builder: (context, state) => const BodyMetricsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
