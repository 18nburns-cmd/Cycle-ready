import { createClient } from 'npm:@supabase/supabase-js@2';
import { evaluateAdaptiveSafety } from '../_shared/adaptive-safety.ts';
import { adaptationChangeTier, workoutFamilyEligibility } from '../_shared/strategic-planning.ts';

type Json = Record<string, unknown>;
const MODEL_VERSION = 'adaptive-decision-v2.0.0';
const SWAP_MARGIN = 5;
const requiredEnv = (name: string): string => {
  const result = Deno.env.get(name)?.trim();
  if (!result) throw new Error(`Missing server secret: ${name}`);
  return result;
};
const num = (input: unknown): number => {
  const parsed = Number(input);
  return Number.isFinite(parsed) ? parsed : 0;
};
const clamp = (input: number): number => Math.max(0, Math.min(100, input));
const errorMessage = (error: unknown): string => {
  if (error instanceof Error) return error.message;
  if (error && typeof error === 'object') {
    const value = error as Record<string, unknown>;
    const parts = [value.message, value.details, value.hint, value.code]
      .filter((part) => typeof part === 'string' && part.length > 0);
    if (parts.length > 0) return parts.join(' | ');
  }
  return String(error || 'Unknown decision error');
};
const dateKey = (input: Date): string => input.toISOString().slice(0, 10);
const daysBefore = (date: string, days: number): string => {
  const value = new Date(`${date}T00:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() - days);
  return dateKey(value);
};
const equipmentFor = (workout: Json): string[] => {
  const structure = workout.interval_structure as Json | undefined;
  return Array.isArray(structure?.equipment) ? structure.equipment.map(String) : [];
};
const workoutSnapshot = (workout: Json | null, planned: Json): Json => workout ?? {
  id: planned.current_workout_id ?? planned.workout_library_id,
  session_type: planned.session_type,
  primary_adaptation: planned.primary_adaptation,
  secondary_adaptation: planned.secondary_adaptation,
  duration_minutes: planned.planned_duration_minutes,
  planned_load: planned.planned_load,
  purpose: planned.purpose,
};

const suitability = (
  candidate: Json,
  context: {
    block: Json | null;
    readiness: Json;
    availableMinutes: number;
    recentAnalyses: Json[];
    limitingFactors: string[];
    familyWeights: Record<string, number>;
  },
) => {
  const primary = String(candidate.primary_adaptation ?? '');
  const blockPrimary = String(context.block?.primary_adaptation ?? '');
  const alignment = primary === blockPrimary ? 100
    : candidate.secondary_adaptation === blockPrimary ? 75
    : context.limitingFactors.includes(primary) ? 65 : 35;
  const difficulty = num(candidate.difficulty_level);
  const fatigueRisk = num(context.readiness.fatigue_score);
  const recoveryFit = clamp(100 - difficulty * fatigueRisk / 10);
  const readiness = num(context.readiness.readiness_score);
  const desiredDifficulty = readiness >= 75 ? 7 : readiness >= 60 ? 5 : readiness >= 45 ? 3 : 1;
  const loadFit = clamp(100 - Math.abs(difficulty - desiredDifficulty) * 15);
  const phases = Array.isArray(candidate.intended_phases) ? candidate.intended_phases.map(String) : [];
  const phaseFit = phases.includes(String(context.block?.phase ?? '')) ? 100 : 25;
  const comparable = context.recentAnalyses.filter((analysis) =>
    analysis.planned_sessions?.session_type === candidate.session_type
  );
  const success = comparable.length === 0 ? 50 : comparable.reduce((sum, analysis) =>
    sum + (analysis.absorbed === true ? 100 : analysis.adaptation_achieved === true ? 65 : 25), 0) / comparable.length;
  const duration = num(candidate.duration_minutes);
  const availability = duration <= context.availableMinutes ? 100 : 0;
  const goal = context.limitingFactors.includes(primary) ? 100 : 50;
  const familyEligibility = (context.familyWeights[String(candidate.session_type)] ?? 0) * 100;
  return Math.round((alignment * 0.15 + recoveryFit * 0.15 + loadFit * 0.15 +
    phaseFit * 0.1 + success * 0.1 + availability * 0.1 + goal * 0.05 +
    familyEligibility * 0.2) * 100) / 100;
};

Deno.serve(async (request) => {
  if (request.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });
  try {
    if (request.headers.get('x-cycle-ready-sync-secret') !== requiredEnv('CYCLEREADY_SYNC_JOB_SECRET')) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }
    const body = await request.json().catch(() => ({})) as Json;
    const decisionDate = typeof body.date === 'string' ? body.date : dateKey(new Date());
    const supabase = createClient(requiredEnv('SUPABASE_URL'), requiredEnv('SUPABASE_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
    let planQuery = supabase.from('planned_sessions').select('*').eq('scheduled_date', decisionDate).eq('completion_status', 'planned');
    if (typeof body.planned_session_id === 'string') planQuery = planQuery.eq('id', body.planned_session_id);
    if (typeof body.athlete_id === 'string') planQuery = planQuery.eq('athlete_id', body.athlete_id);
    const { data: sessions, error: sessionError } = await planQuery;
    if (sessionError) throw sessionError;
    const outputs: Json[] = [];

    for (const planned of sessions ?? []) {
      const dayOfWeek = new Date(`${decisionDate}T00:00:00.000Z`).getUTCDay() || 7;
      const [athleteResult, availabilityResult, readinessResult, blockResult, libraryResult, analysesResult, wellnessResult, readinessHistoryResult, priorPlansResult, demandResult, baselineResult] = await Promise.all([
        supabase.from('athletes').select('*').eq('id', planned.athlete_id).single(),
        supabase.from('athlete_availability').select('*').eq('athlete_id', planned.athlete_id).eq('day_of_week', dayOfWeek).maybeSingle(),
        supabase.from('daily_readiness').select('*').eq('athlete_id', planned.athlete_id).lte('readiness_date', decisionDate).order('readiness_date', { ascending: false }).limit(1).maybeSingle(),
        planned.training_block_id ? supabase.from('training_blocks').select('*').eq('id', planned.training_block_id).maybeSingle() : Promise.resolve({ data: null, error: null }),
        supabase.from('workout_library').select('*').eq('active', true),
        supabase.from('session_analysis').select('*,planned_sessions(session_type)').eq('athlete_id', planned.athlete_id).eq('analysis_status', 'complete').order('analysed_at', { ascending: false }).limit(12),
        supabase.from('daily_wellness_resolved').select('*').eq('athlete_id', planned.athlete_id).gte('recorded_date', daysBefore(decisionDate, 3)).lte('recorded_date', decisionDate).order('recorded_date', { ascending: false }),
        supabase.from('daily_readiness').select('readiness_date,readiness_score').eq('athlete_id', planned.athlete_id).gte('readiness_date', daysBefore(decisionDate, 2)).lte('readiness_date', decisionDate).order('readiness_date', { ascending: false }),
        supabase.from('planned_sessions').select('session_type,scheduled_date,weekly_plan_id').eq('athlete_id', planned.athlete_id).lt('scheduled_date', decisionDate).order('scheduled_date', { ascending: false }).limit(2),
        supabase.from('event_demand_profiles').select('*').eq('athlete_id', planned.athlete_id).order('calculated_at', { ascending: false }).limit(1).maybeSingle(),
        supabase.from('athlete_metric_baselines').select('*').eq('athlete_id', planned.athlete_id).lte('baseline_date', decisionDate).order('baseline_date', { ascending: false }).limit(1).maybeSingle(),
      ]);
      for (const result of [athleteResult, availabilityResult, readinessResult, blockResult, libraryResult, analysesResult, wellnessResult, readinessHistoryResult, priorPlansResult, demandResult, baselineResult]) {
        if (result.error) throw result.error;
      }
      const readiness = readinessResult.data ?? { readiness_score: 50, fatigue_score: 50, athlete_state: 'YELLOW', data_confidence: 0 };
      const wellness = wellnessResult.data ?? [];
      const todayWellness = wellness.find((item) => item.recorded_date === decisionDate);
      const illness = todayWellness?.illness_flag === true;
      const injury = todayWellness?.injury_or_pain_flag === true;
      const isTaper = ['TAPER', 'PEAK'].includes(String(blockResult.data?.phase ?? ''));
      const constraints = athleteResult.data.coaching_constraints as Json;
      const ownedEquipment = Array.isArray(constraints?.equipment) ? constraints.equipment.map(String) : ['outdoor_bike'];
      const availability = availabilityResult.data;
      const availableMinutes = availability?.available === false ? 0 : num(availability?.maximum_duration_minutes) || 1440;
      const library = (libraryResult.data ?? []) as Json[];
      const current = library.find((candidate) => candidate.id === (planned.current_workout_id ?? planned.workout_library_id)) ?? null;
      const original = workoutSnapshot(current, planned);
      const reasons: string[] = [];
      let decision = 'KEEP';
      let adaptationLevel = 0;
      let replacement: Json | null = current;
      let explanation = 'The planned workout remains the highest-value absorbable session for the current block purpose.';

      // Hard constraints execute before candidate ranking.
      const safetyGate = evaluateAdaptiveSafety({
        illness,
        injury,
        athleteState: String(readiness.athlete_state),
        availableMinutes,
      });
      if (safetyGate.outcome === 'REST') {
        decision = 'REST'; adaptationLevel = 1; replacement = null;
        reasons.push(safetyGate.reasonCode!);
        explanation = safetyGate.reasonCode === 'NO_TRAINING_AVAILABILITY'
          ? 'The athlete is unavailable today, so the session is not moved forward or replaced with hidden load.'
          : 'A health or safety constraint overrides the planned session, so rest is prescribed and no workout candidate is ranked.';
      } else {
        let candidates = library.filter((candidate) => {
          const equipment = equipmentFor(candidate);
          const equipmentFit = equipment.length === 0 || equipment.some((item) => ownedEquipment.includes(item));
          const durationFit = num(candidate.duration_minutes) <= availableMinutes;
          const taperFit = !isTaper || num(candidate.difficulty_level) <= 6;
          return equipmentFit && durationFit && taperFit;
        });

        // Strategic family eligibility is established before suitability
        // ranking. Readiness can change dose, but cannot invent a new block
        // objective or open the complete workout catalogue.
        const demandScores = demandResult.data?.demand_scores as Json ?? {};
        const maintenance = Array.isArray(blockResult.data?.maintenance_adaptations)
          ? blockResult.data.maintenance_adaptations.map(String) : [];
        const familyEvaluations = Object.fromEntries([...new Set(library.map((candidate) =>
          String(candidate.session_type)))].map((family) => [family, workoutFamilyEligibility({
            family, phase: String(blockResult.data?.phase ?? 'FOUNDATION'),
            primary: String(blockResult.data?.primary_adaptation ?? planned.primary_adaptation),
            secondary: blockResult.data?.secondary_adaptation == null ? null : String(blockResult.data.secondary_adaptation),
            maintenance, demands: demandScores,
          })]));
        const ineligibleFamilies = Object.entries(familyEvaluations)
          .filter(([, evaluation]) => !evaluation.eligible)
          .map(([family, evaluation]) => ({ family, reason_codes: evaluation.reason_codes }));
        candidates = candidates.filter((candidate) =>
          familyEvaluations[String(candidate.session_type)]?.eligible === true);
        console.log(JSON.stringify({ stage: 'workout_family_eligibility',
          planned_session_id: planned.id, family_evaluations: familyEvaluations,
          rejected_families: ineligibleFamilies }));

        const priorWasHard = ['threshold', 'vo2_max', 'anaerobic', 'sprint', 'race_simulation']
          .includes(String((priorPlansResult.data ?? [])[0]?.session_type ?? ''));
        if (priorWasHard) {
          candidates = candidates.filter((candidate) => num(candidate.difficulty_level) <= 6);
          reasons.push('HARD_SESSION_SPACING');
        }

        const priorRecoveryCount = (priorPlansResult.data ?? []).filter((item) => item.session_type === 'recovery').length;
        const baselineHrv = num(baselineResult.data?.hrv_baseline_ms);
        const baselineRhr = num(baselineResult.data?.resting_hr_baseline);
        const lowReadinessTwoDays = (readinessHistoryResult.data ?? []).filter((item) => num(item.readiness_score) < 45).length >= 2;
        const hrvLowThreeDays = baselineHrv > 0 && wellness.filter((item) => num(item.hrv_ms) > 0 && num(item.hrv_ms) < baselineHrv).length >= 3;
        const rhrHighThreeDays = baselineRhr > 0 && wellness.filter((item) => num(item.resting_hr) >= baselineRhr + 5).length >= 3;
        const previousHighCost = (analysesResult.data ?? [])[0]?.recovery_cost_score > 80;
        let plannedRecoveryWeek = false;
        if (planned.weekly_plan_id) {
          const recoveryWeek = await supabase.from('weekly_plans').select('recovery_week').eq('id', planned.weekly_plan_id).maybeSingle();
          if (recoveryWeek.error) throw recoveryWeek.error;
          plannedRecoveryWeek = recoveryWeek.data?.recovery_week === true;
        }
        const recoveryException = plannedRecoveryWeek || lowReadinessTwoDays || hrvLowThreeDays || rhrHighThreeDays || illness || injury || previousHighCost;
        if (priorRecoveryCount >= 2 && !recoveryException) {
          candidates = candidates.filter((candidate) => candidate.session_type !== 'recovery');
          reasons.push('RECOVERY_DAY_LIMIT');
        }

        const limitingFactors = Array.isArray(demandResult.data?.limiting_factors) ? demandResult.data.limiting_factors.map(String) : [];
        const familyWeights = Object.fromEntries(Object.entries(familyEvaluations)
          .map(([family, evaluation]) => [family, evaluation.weight]));
        const context = { block: blockResult.data, readiness, availableMinutes,
          recentAnalyses: analysesResult.data ?? [], limitingFactors, familyWeights };
        const absorbedComparable = (analysesResult.data ?? []).filter((analysis) =>
          analysis.absorbed === true &&
          analysis.adaptation_achieved === true &&
          analysis.planned_sessions?.session_type === current?.session_type).length;
        candidates = candidates.filter((candidate) => {
          const upwardSameFamily = candidate.session_type === current?.session_type &&
            (num(candidate.difficulty_level) > num(current?.difficulty_level) ||
              num(candidate.duration_minutes) > num(current?.duration_minutes));
          return !upwardSameFamily || absorbedComparable >= 2;
        });
        const intendedAdaptation = String(blockResult.data?.primary_adaptation ??
          planned.primary_adaptation ?? current?.primary_adaptation ?? 'aerobic_endurance');
        const ranked = candidates.map((candidate) => ({ candidate,
          score: suitability(candidate, context),
          changeTier: adaptationChangeTier({ candidate, current, intendedAdaptation }),
        })).sort((left, right) => left.changeTier - right.changeTier || right.score - left.score);
        const plannedScore = current ? suitability(current, context) : 50;
        const better = ranked.filter((item) => item.candidate.id !== current?.id &&
          item.score > plannedScore + SWAP_MARGIN);
        const best = better[0];
        console.log(JSON.stringify({ stage: 'candidate_ranking',
          planned_session_id: planned.id, intended_adaptation: intendedAdaptation,
          absorbed_comparable_sessions: absorbedComparable,
          candidates: ranked.map((item) => ({ id: item.candidate.id,
            family: item.candidate.session_type, score: item.score,
            change_tier: item.changeTier })) }));
        if (best) {
          replacement = best.candidate;
          decision = best.changeTier <= 2 ? 'REDUCE' : 'MODIFY';
          adaptationLevel = best.changeTier;
          reasons.push(best.changeTier <= 2 ? 'VOLUME_REDUCTION' :
            best.changeTier === 3 ? 'SAME_ADAPTATION_SUBSTITUTION' : 'HIGHER_SUITABILITY');
          explanation = `The minimum effective change is hierarchy level ${best.changeTier}. ` +
            `It scores ${best.score}, more than ${SWAP_MARGIN} points above the planned session's ${plannedScore}, while retaining the closest safe dose of ${intendedAdaptation}.`;
        } else {
          reasons.push(best && Math.abs(best.score - plannedScore) <= SWAP_MARGIN ? 'KEEP_NEAR_TIE' : 'PLANNED_SESSION_SUITABLE');
        }
        if (isTaper) reasons.push('TAPER_PROTECTION');
        if (availableMinutes < num(planned.planned_duration_minutes)) reasons.push('DURATION_CONSTRAINT');
      }

      const evidence = {
        readiness_id: readiness.id ?? null, readiness_score: readiness.readiness_score,
        data_confidence: readiness.data_confidence, block_id: blockResult.data?.id ?? null,
        block_purpose: blockResult.data?.purpose ?? null, available_minutes: availableMinutes,
        owned_equipment: ownedEquipment, event_demand_profile_id: demandResult.data?.id ?? null,
        safety_evaluated_before_ranking: true, strategic_eligibility_before_ranking: true,
        swap_margin: SWAP_MARGIN,
      };
      const confidence = Math.max(0.25, Math.min(1, num(readiness.data_confidence)));
      const payload = {
        athlete_id: planned.athlete_id, original_workout: original,
        replacement_workout: replacement, replacement_workout_id: replacement?.id ?? '',
        adaptation_level: adaptationLevel, decision, reason_codes: [...new Set(reasons)],
        evidence, explanation, confidence, coaching_model_version: MODEL_VERSION,
        decision_key: `${planned.id}:${decisionDate}:${readiness.id ?? 'missing'}:${MODEL_VERSION}`,
      };
      const rpc = await supabase.rpc('apply_adaptive_decision', { target_session_id: planned.id, decision_payload: payload });
      if (rpc.error) throw rpc.error;
      outputs.push({ planned_session_id: planned.id, decision_id: rpc.data, ...payload });
    }
    return Response.json({ coaching_model_version: MODEL_VERSION, decisions: outputs });
  } catch (error) {
    console.error(error);
    return Response.json({ error: errorMessage(error) }, { status: 500 });
  }
});
