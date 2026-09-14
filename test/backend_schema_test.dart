import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String v2Migration;
  late String metricsMigration;
  late String metricsFunction;
  late String readinessMigration;
  late String readinessFunction;
  late String planningMigration;
  late String planningFunction;
  late String sessionMigration;
  late String sessionFunction;
  late String decisionMigration;
  late String decisionFunction;
  late String nutritionMigration;
  late String capabilityFunction;
  late String intervalsFunction;
  late String snapshotPlanningBackfill;
  late String suppliedPlanningBackfill;
  late String planningBackfillValidation;
  late String snapshotTimezoneCorrection;
  late String intervalsOauthMigration;
  late String intervalsOauthStart;
  late String intervalsOauthCallback;
  late String intervalsSchedulerMigration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/202608310001_create_adaptive_coaching_platform.sql',
    ).readAsStringSync();
    v2Migration = File(
      'supabase/migrations/202608310005_complete_v2_cloud_contract.sql',
    ).readAsStringSync();
    metricsMigration = File(
      'supabase/migrations/202608310006_add_versioned_derived_metrics.sql',
    ).readAsStringSync();
    metricsFunction = File(
      'supabase/functions/process-derived-metrics/index.ts',
    ).readAsStringSync();
    readinessMigration = File(
      'supabase/migrations/202608310007_extend_daily_readiness.sql',
    ).readAsStringSync();
    readinessFunction = File(
      'supabase/functions/process-readiness/index.ts',
    ).readAsStringSync();
    planningMigration = File(
      'supabase/migrations/202608310008_version_goal_periodisation.sql',
    ).readAsStringSync();
    planningFunction = File(
      'supabase/functions/process-goal-plan/index.ts',
    ).readAsStringSync();
    sessionMigration = File(
      'supabase/migrations/202608310009_extend_session_analysis.sql',
    ).readAsStringSync();
    sessionFunction = File(
      'supabase/functions/process-session-analysis/index.ts',
    ).readAsStringSync();
    decisionMigration = File(
      'supabase/migrations/202608310010_seed_workouts_and_decision_rpc.sql',
    ).readAsStringSync();
    decisionFunction = File(
      'supabase/functions/process-adaptive-decision/index.ts',
    ).readAsStringSync();
    nutritionMigration = File(
      'supabase/migrations/202608310011_add_relational_nutrition.sql',
    ).readAsStringSync();
    capabilityFunction = File(
      'supabase/functions/process-athlete-capabilities/index.ts',
    ).readAsStringSync();
    intervalsFunction = File(
      'supabase/functions/intervals-sync/index.ts',
    ).readAsStringSync();
    snapshotPlanningBackfill = File(
      'supabase/migrations/202609020001_backfill_snapshot_planning_data.sql',
    ).readAsStringSync();
    suppliedPlanningBackfill = File(
      'supabase/migrations/202609020002_backfill_new_snapshot_planning_data.sql',
    ).readAsStringSync();
    planningBackfillValidation = File(
      'supabase/migrations/202609020005_validate_snapshot_planning_backfill.sql',
    ).readAsStringSync();
    snapshotTimezoneCorrection = File(
      'supabase/migrations/202609020006_correct_snapshot_calendar_timezone.sql',
    ).readAsStringSync();
    intervalsOauthMigration = File(
      'supabase/migrations/202609020008_add_intervals_oauth_credentials.sql',
    ).readAsStringSync();
    intervalsOauthStart = File(
      'supabase/functions/intervals-oauth-start/index.ts',
    ).readAsStringSync();
    intervalsOauthCallback = File(
      'supabase/functions/intervals-oauth-callback/index.ts',
    ).readAsStringSync();
    intervalsSchedulerMigration = File(
      'supabase/migrations/202609020010_schedule_intervals_sync_and_alerts.sql',
    ).readAsStringSync();
  });

  test('snapshot planning bridge is idempotent and preserves provenance', () {
    expect(snapshotPlanningBackfill, contains("payload -> 'eventGoals'"));
    expect(snapshotPlanningBackfill, contains("payload -> 'plannedSessions'"));
    expect(snapshotPlanningBackfill, contains('not exists ('));
    expect(snapshotPlanningBackfill, contains("'compatibility_snapshot'"));
    expect(snapshotPlanningBackfill, contains("'snapshot-bridge-v1'"));
    expect(snapshotPlanningBackfill, isNot(contains('delete from')));
    expect(snapshotPlanningBackfill, isNot(contains('drop table')));
    expect(suppliedPlanningBackfill, contains("'compatibility_snapshot'"));
    expect(suppliedPlanningBackfill, contains('not exists ('));
    expect(suppliedPlanningBackfill, isNot(contains('delete from')));
    expect(planningBackfillValidation, contains('from public.goals'));
    expect(
        planningBackfillValidation, contains('from public.planned_sessions'));
    expect(suppliedPlanningBackfill, contains("time zone 'Europe/London'"));
    expect(
        snapshotTimezoneCorrection, contains('update public.planned_sessions'));
  });

  test('v2 contract adds every authoritative coaching relation', () {
    const relations = <String>[
      'event_demand_profiles',
      'athlete_capabilities',
      'training_phases',
      'weekly_plans',
      'daily_wellness_resolved',
      'coaching_state_snapshots',
      'metric_calculation_runs',
      'integration_sync_runs',
      'athlete_feedback',
      'notifications',
    ];

    for (final relation in relations) {
      expect(v2Migration, contains('create table public.$relation'));
      expect(v2Migration, contains("'$relation'"));
    }
    expect(v2Migration, contains('create view public.wellness_observations'));
  });

  test('v2 derived and coaching records are attributable and versioned', () {
    expect(v2Migration, contains('source_references jsonb'));
    expect(v2Migration, contains('source_attribution jsonb'));
    expect(v2Migration, contains('algorithm_version text not null'));
    expect(v2Migration, contains('idempotency_key text not null'));
    expect(migration, contains('original_workout_id'));
  });

  test('server-derived metrics are versioned, attributable and idempotent', () {
    expect(metricsMigration,
        contains('create table public.daily_training_metrics'));
    expect(metricsMigration,
        contains('create table public.athlete_metric_baselines'));
    expect(metricsMigration, contains('source_activity_ids uuid[]'));
    expect(metricsMigration, contains('source_observation_ids uuid[]'));
    expect(metricsMigration, contains('metric_calculation_runs_idempotency'));
    expect(metricsFunction,
        contains("const ALGORITHM_VERSION = 'derived-metrics-v1'"));
    expect(metricsFunction, contains('1 - Math.exp(-1 / 42)'));
    expect(metricsFunction, contains('1 - Math.exp(-1 / 7)'));
    expect(metricsFunction,
        contains('onConflict: \'athlete_id,metric_date,algorithm_version\''));
  });

  test('readiness processing lowers confidence and lets symptoms override', () {
    expect(readinessMigration, contains('recovery_score'));
    expect(readinessMigration, contains('source_references jsonb'));
    expect(readinessFunction,
        contains("const ALGORITHM_VERSION = 'readiness-v2.0.0'"));
    expect(readinessFunction, contains("illness || injury ? 'RED'"));
    expect(
        readinessFunction, contains('data_confidence: round(availableWeight)'));
    expect(readinessFunction, contains('daily_wellness_resolved'));
    expect(readinessFunction, contains('coaching_state_snapshots'));
  });

  test('goal planning persists demands and a complete versioned hierarchy', () {
    expect(planningMigration, contains("add value if not exists 'PEAK'"));
    expect(planningFunction, contains('event_demand_profiles'));
    expect(planningFunction, contains('athlete_capabilities'));
    expect(planningFunction, contains('training_phases'));
    expect(planningFunction, contains('training_blocks'));
    expect(planningFunction, contains('weekly_plans'));
    expect(planningFunction, contains('adaptation_objectives'));
    expect(planningFunction, contains('recovery_week: false'));
    expect(planningFunction,
        contains('import {\n  analyseCapabilityGaps, calculateEventDemands'));
    expect(planningFunction,
        contains("const ALGORITHM_VERSION = 'goal-periodisation-v3.0.0'"));
  });

  test('session analysis separates immediate stimulus from recovery cost', () {
    expect(sessionMigration,
        contains("analysis_status text not null default 'provisional'"));
    expect(sessionFunction, contains("const mode = body.mode === 'recovery'"));
    expect(sessionFunction, contains('familyWeights'));
    expect(sessionFunction, contains('validPwHr'));
    expect(sessionFunction, contains('duration_seconds) ?? 0) < 5400'));
    expect(sessionFunction, contains('ACHIEVED_HIGH_COST'));
    expect(sessionFunction, contains('recovery_updated_at'));
    expect(sessionFunction, contains("analysis_status: 'complete'"));
  });

  test('adaptive decisions rank only after safety and mutate atomically', () {
    for (final family in <String>[
      'recovery',
      'endurance',
      'tempo',
      'sweet_spot',
      'threshold',
      'vo2_max',
      'anaerobic',
      'sprint',
      'neuromuscular',
      'cadence',
      'climbing',
      'race_simulation',
    ]) {
      expect(decisionMigration, contains("'$family'"));
    }
    expect(
        decisionMigration, contains('function public.apply_adaptive_decision'));
    expect(decisionMigration, contains('for update'));
    expect(decisionMigration, contains('original_workout_id = coalesce'));
    expect(decisionFunction,
        contains('// Hard constraints execute before candidate ranking.'));
    expect(decisionFunction, contains('const SWAP_MARGIN = 5'));
    expect(decisionFunction, contains('alignment * 0.15'));
    expect(decisionFunction, contains('phaseFit * 0.1'));
    expect(decisionFunction, contains('familyEligibility * 0.2'));
    expect(decisionFunction, contains('workoutFamilyEligibility'));
    expect(decisionFunction, contains('adaptationChangeTier'));
    expect(decisionFunction, contains('absorbedComparable >= 2'));
    expect(decisionFunction, contains('strategic_eligibility_before_ranking'));
    expect(decisionFunction, contains('availability * 0.1'));
    expect(decisionFunction, contains('goal * 0.05'));
    expect(decisionFunction, contains('RECOVERY_DAY_LIMIT'));
    expect(
        decisionFunction, contains("supabase.rpc('apply_adaptive_decision'"));
  });

  test('relational nutrition preserves web parity under athlete RLS', () {
    expect(
        nutritionMigration, contains('create table public.nutrition_entries'));
    expect(nutritionMigration,
        contains('create table public.daily_nutrition_targets'));
    expect(nutritionMigration, contains('public.owns_athlete(athlete_id)'));
    expect(nutritionMigration, contains('algorithm_version text not null'));
  });

  test('capability processing is evidence-backed and changes gradually', () {
    for (final dimension in <String>[
      'aerobic_endurance',
      'tempo',
      'threshold',
      'vo2_max',
      'anaerobic_capacity',
      'sprint_power',
      'climbing',
      'durability',
      'repeatability',
      'recovery_between_efforts',
      'heat_tolerance',
      'pacing',
      'fueling',
    ]) {
      expect(capabilityFunction, contains("'$dimension'"));
    }
    expect(capabilityFunction,
        contains('Math.max(-5, Math.min(5, observed - previous))'));
    expect(capabilityFunction, contains('dimension_source_ids'));
    expect(capabilityFunction,
        contains('dimensionsWithEvidence / dimensions.length'));
    expect(capabilityFunction,
        contains("const ALGORITHM_VERSION = 'athlete-capabilities-v2.0.0'"));
  });

  test('Intervals sync records runs and advances the coaching pipeline', () {
    expect(intervalsFunction, contains('integration_sync_runs'));
    expect(intervalsFunction, contains('idempotency_key: runKey'));
    for (final processor in <String>[
      'process-derived-metrics',
      'process-session-analysis',
      'process-athlete-capabilities',
      'process-readiness',
      'process-goal-plan',
      'process-adaptive-decision',
    ]) {
      expect(intervalsFunction, contains("'$processor'"));
    }
    expect(intervalsFunction, contains("mode: 'recovery'"));
    expect(
        intervalsFunction,
        contains(
            "status: processingFailed ? 'imported_processing_partial' : 'completed'"));
    expect(intervalsFunction, contains("from('provider_credentials')"));
    expect(intervalsFunction, contains("? '0' : providerAthleteId"));
    expect(intervalsFunction, contains(r'Basic ${btoa'));
  });

  test('Intervals OAuth keeps tokens server-only and protects callback state',
      () {
    expect(intervalsOauthMigration,
        contains('create table public.provider_credentials'));
    expect(intervalsOauthMigration,
        contains('create table public.oauth_authorization_states'));
    expect(intervalsOauthMigration, contains('enable row level security'));
    expect(
        intervalsOauthMigration,
        contains(
            'revoke all on public.provider_credentials from anon, authenticated'));
    expect(intervalsOauthStart, contains('crypto.subtle.digest'));
    expect(intervalsOauthStart,
        contains("'ACTIVITY:READ,WELLNESS:READ,CALENDAR:WRITE,SETTINGS:READ'"));
    expect(intervalsOauthStart, contains('userClient.auth.getUser()'));
    expect(intervalsOauthCallback,
        contains('https://intervals.icu/api/oauth/token'));
    expect(intervalsOauthCallback, contains(".is('consumed_at', null)"));
    expect(intervalsOauthCallback, contains("from('provider_credentials')"));
  });

  test('Intervals synchronization is scheduled and monitored securely', () {
    expect(intervalsSchedulerMigration, contains('cron.schedule('));
    expect(intervalsSchedulerMigration,
        contains("'cycle-ready-intervals-hourly'"));
    expect(intervalsSchedulerMigration,
        contains("'cycle-ready-integration-monitor'"));
    expect(intervalsSchedulerMigration, contains('vault.create_secret'));
    expect(intervalsSchedulerMigration,
        contains('integration_scheduler_authorization'));
    expect(intervalsSchedulerMigration, contains("'integration_sync_alert'"));
    expect(
        intervalsFunction,
        contains(
            "request.headers.get(\n      'x-cycle-ready-scheduler-secret'"));
    expect(
        intervalsFunction, contains('await sha256(suppliedSchedulerSecret)'));
  });

  test('canonical schema contains every required platform relation', () {
    const relations = <String>[
      'athletes',
      'athlete_availability',
      'integrations',
      'activities',
      'activity_intervals',
      'wellness',
      'ftp_history',
      'weight_history',
      'goals',
      'training_blocks',
      'workout_library',
      'planned_sessions',
      'session_analysis',
      'daily_readiness',
      'adaptive_decisions',
    ];

    for (final relation in relations) {
      expect(
        migration,
        contains('create table public.$relation'),
        reason: '$relation must be part of the canonical backend',
      );
    }
  });

  test('push tokens are athlete-owned and never available anonymously', () {
    final migration = File(
      'supabase/migrations/202609030001_add_push_notification_devices.sql',
    ).readAsStringSync();
    expect(migration, contains('create table public.device_push_tokens'));
    expect(migration, contains('auth.uid() = user_id'));
    expect(migration, contains('public.owns_athlete(athlete_id)'));
    expect(migration,
        contains('revoke all on public.device_push_tokens from anon'));
  });

  test('notification delivery uses authenticated FCM and removes stale tokens',
      () {
    final function = File('supabase/functions/deliver-notifications/index.ts')
        .readAsStringSync();
    final schedule = File(
      'supabase/migrations/202609030002_schedule_notification_delivery.sql',
    ).readAsStringSync();
    expect(function, contains('firebase.messaging'));
    expect(function, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(function, contains("body.includes('UNREGISTERED')"));
    expect(schedule, contains('cycle-ready-notification-delivery'));
    expect(schedule, contains('cycle_ready_scheduler_secret_v1'));
  });

  test('all athlete-owned relations are protected by RLS ownership', () {
    expect(migration,
        contains('alter table public.athletes enable row level security'));
    expect(migration, contains('user_id = (select auth.uid())'));
    expect(migration, contains('public.owns_athlete(athlete_id)'));
    expect(migration, contains("'adaptive_decisions'"));
    expect(migration,
        contains('revoke all on all tables in schema public from anon'));
  });

  test('provider identity and coaching history are immutable-safe', () {
    expect(migration, contains('activities_external_identity'));
    expect(migration, contains('where external_activity_id is not null'));
    expect(migration, contains('adaptive_decisions_append_only'));
    expect(migration,
        contains("raise exception 'adaptive decisions are append-only'"));
    expect(migration, isNot(contains('access_token')));
    expect(migration, isNot(contains('refresh_token')));
  });
}
