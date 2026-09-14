export type AdaptiveSafetyInput = {
  illness: boolean;
  injury: boolean;
  athleteState: string;
  availableMinutes: number;
};

export type AdaptiveSafetyGate = {
  outcome: 'REST' | 'CONTINUE';
  reasonCode?: string;
};

/** Safety overrides shared by every server-side adaptive decision. */
export const evaluateAdaptiveSafety = (
  input: AdaptiveSafetyInput,
): AdaptiveSafetyGate => {
  if (input.illness || input.injury || input.athleteState === 'RED') {
    return {
      outcome: 'REST',
      reasonCode: input.illness
        ? 'ILLNESS_FLAG'
        : input.injury
        ? 'INJURY_OR_PAIN_FLAG'
        : 'ATHLETE_STATE_RED',
    };
  }
  if (input.availableMinutes <= 0) {
    return { outcome: 'REST', reasonCode: 'NO_TRAINING_AVAILABILITY' };
  }
  return { outcome: 'CONTINUE' };
};
