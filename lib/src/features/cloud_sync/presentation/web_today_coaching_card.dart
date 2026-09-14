import 'package:cycle_ready/src/features/coaching/domain/daily_coaching_status.dart';
import 'package:flutter/material.dart';

class WebTodayCoachingCard extends StatelessWidget {
  const WebTodayCoachingCard({required this.recommendation, super.key});

  final DailyCoachingRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final workout = recommendation.workout;
    final title = workout?.title ?? 'Rest day';
    final details = workout == null
        ? 'No riding prescribed'
        : '${workout.durationMinutes} min • ${workout.targetLoad} load';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_done_outlined),
                const SizedBox(width: 10),
                Text(
                  "Today's coaching",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(details),
            const SizedBox(height: 10),
            Text(recommendation.explanation),
            const SizedBox(height: 8),
            Text(
              'Confidence ${(recommendation.confidence * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
