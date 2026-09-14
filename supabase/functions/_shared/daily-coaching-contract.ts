export const DAILY_COACHING_CONTRACT_VERSION = '1.0' as const;

export type DailyCoachingWorkout = {
  id: string;
  family: string;
  title: string;
  intensity: 'REST' | 'RECOVERY' | 'ENDURANCE' | 'MODERATE' | 'HIGH';
  duration_minutes: number;
  target_load: number;
};

export type DailyCoachingEvidence = {
  readiness: number;
  fatigue_risk: number;
  training_progress: number;
  goal_alignment: number;
  hrv_change_percent: number | null;
  resting_hr_delta: number | null;
  sleep_deficit_minutes: number | null;
  acute_chronic_load_ratio: number | null;
  fatigue: number;
  soreness: number;
  stress: number;
  illness_symptoms: boolean;
  injury_pain: boolean;
  recent_hard_session: boolean;
  available_minutes: number | null;
  evidence_updated_at: string;
};

export type DailyCoachingInputV1 = {
  contract_version: typeof DAILY_COACHING_CONTRACT_VERSION;
  athlete_id: string;
  coaching_date: string;
  timezone: string;
  requested_at: string;
  planned_workout: DailyCoachingWorkout | null;
  evidence: DailyCoachingEvidence;
};

export type DailyCoachingOutputV1 = {
  contract_version: typeof DAILY_COACHING_CONTRACT_VERSION;
  athlete_id: string;
  coaching_date: string;
  idempotency_key: string;
  status: 'COMPLETED' | 'FALLBACK';
  athlete_state: string;
  data_confidence: 'HIGH' | 'MEDIUM' | 'LOW';
  decision: string;
  selected_workout: DailyCoachingWorkout | null;
  readiness: number;
  reason_codes: string[];
  explanation: string;
  next_72h_effect: string;
  confidence: number;
  evidence_snapshot: DailyCoachingEvidence;
  model_version: string;
  generated_at: string;
};

const objectValue = (value: unknown): Record<string, unknown> => {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new TypeError('Daily coaching payload must be a JSON object.');
  }
  return value as Record<string, unknown>;
};

const requiredString = (source: Record<string, unknown>, key: string): string => {
  const value = source[key];
  if (typeof value !== 'string' || value.trim() === '') {
    throw new TypeError(`Daily coaching ${key} must be a non-empty string.`);
  }
  return value;
};

/** Strictly validates the routing envelope before relational context assembly. */
export const parseDailyCoachingRequest = (value: unknown): Pick<
  DailyCoachingInputV1,
  'contract_version' | 'athlete_id' | 'coaching_date' | 'timezone' | 'requested_at'
> => {
  const source = objectValue(value);
  const contractVersion = requiredString(source, 'contract_version');
  if (contractVersion !== DAILY_COACHING_CONTRACT_VERSION) {
    throw new RangeError(`Unsupported daily coaching contract: ${contractVersion}`);
  }
  const coachingDate = requiredString(source, 'coaching_date');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(coachingDate)) {
    throw new TypeError('Daily coaching coaching_date must use YYYY-MM-DD.');
  }
  return {
    contract_version: DAILY_COACHING_CONTRACT_VERSION,
    athlete_id: requiredString(source, 'athlete_id'),
    coaching_date: coachingDate,
    timezone: requiredString(source, 'timezone'),
    requested_at: requiredString(source, 'requested_at'),
  };
};
