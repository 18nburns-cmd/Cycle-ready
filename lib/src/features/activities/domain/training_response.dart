import 'package:cycle_ready/src/features/activities/domain/performance_momentum.dart';
import 'package:cycle_ready/src/features/activities/domain/training_metrics.dart';

enum TrainingResponseStatus {
  productive,
  maintaining,
  fatigued,
  rebuilding,
  insufficientData,
}

class TrainingResponse {
  const TrainingResponse({
    required this.status,
    required this.label,
    required this.explanation,
  });

  final TrainingResponseStatus status;
  final String label;
  final String explanation;
}

TrainingResponse assessTrainingResponse({
  required TrainingMetrics training,
  required PerformanceMomentum? momentum,
}) {
  // Load safety takes precedence over a strong power curve.
  if (training.form < -20 || training.rampRate > 8) {
    return const TrainingResponse(
      status: TrainingResponseStatus.fatigued,
      label: 'Fatigued',
      explanation:
          'Training stress is currently outrunning recovery. Absorb the work before chasing another power result.',
    );
  }
  if (momentum == null) {
    return const TrainingResponse(
      status: TrainingResponseStatus.insufficientData,
      label: 'Building evidence',
      explanation:
          'CycleReady needs comparable power efforts in both four-week periods before judging your training response.',
    );
  }
  if (momentum.status == PerformanceMomentumStatus.improving) {
    return const TrainingResponse(
      status: TrainingResponseStatus.productive,
      label: 'Productive',
      explanation:
          'Your recent power is improving while training load remains manageable. Keep the current balance of work and recovery.',
    );
  }
  if (momentum.status == PerformanceMomentumStatus.stable) {
    return const TrainingResponse(
      status: TrainingResponseStatus.maintaining,
      label: 'Maintaining',
      explanation:
          'Power is stable and load is controlled. That is a useful response during endurance blocks and recovery weeks.',
    );
  }
  if (momentum.status == PerformanceMomentumStatus.declining &&
      (training.form < -8 || training.rampRate > 5)) {
    return const TrainingResponse(
      status: TrainingResponseStatus.fatigued,
      label: 'Fatigued',
      explanation:
          'Lower recent power alongside rising fatigue suggests you may need recovery, but first consider whether comparable hard efforts were attempted.',
    );
  }
  return const TrainingResponse(
    status: TrainingResponseStatus.rebuilding,
    label: 'Rebuilding',
    explanation:
        'Your power profile is mixed or below the previous block without excessive load. Keep training consistently and create comparable efforts before reassessing.',
  );
}
