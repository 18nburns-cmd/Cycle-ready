import 'dart:math' as math;

import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_program.dart';
import 'package:cycle_ready/src/features/strength/domain/strength_progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StrengthWorkoutScreen extends ConsumerStatefulWidget {
  const StrengthWorkoutScreen({
    this.routineIndex = 0,
    this.customRoutine,
    super.key,
  });
  final int routineIndex;
  final StrengthRoutine? customRoutine;
  @override
  ConsumerState<StrengthWorkoutScreen> createState() =>
      _StrengthWorkoutScreenState();
}

class _StrengthWorkoutScreenState extends ConsumerState<StrengthWorkoutScreen> {
  final logs = <String, List<_SetLog>>{};
  final appliedProgressionIds = <String>{};
  final workoutStartedAt = DateTime.now();
  bool saving = false;

  @override
  void dispose() {
    for (final set in logs.values.expand((value) => value)) {
      set.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(strengthProfileProvider).valueOrNull;
    final progressions =
        ref.watch(strengthProgressionsProvider).valueOrNull ?? const {};
    if (profile == null) {
      return const Scaffold(
          body: Center(child: Text('Complete strength setup first.')));
    }
    final program = buildStrengthProgram(
        goal: StrengthGoal.values.byName(profile.goal),
        location: TrainingLocation.values.byName(profile.location),
        experience: StrengthExperience.values.byName(profile.experience),
        daysPerWeek: profile.daysPerWeek);
    final routine = widget.customRoutine ??
        program[widget.routineIndex.clamp(0, program.length - 1)];
    for (final exercise in routine.exercises) {
      final progression = progressions[exercise.id];
      logs.putIfAbsent(
          exercise.id,
          () => List.generate(
              exercise.defaultSets,
              (index) => _SetLog(
                    reps: progression?.suggestedReps ?? exercise.defaultReps,
                    weightKg: progression?.suggestedWeightKg,
                  )));
      if (progression != null && appliedProgressionIds.add(exercise.id)) {
        for (final set in logs[exercise.id]!) {
          set.reps.text = '${progression.suggestedReps}';
          set.weight.text = progression.suggestedWeightKg <= 0
              ? ''
              : progression.suggestedWeightKg.toStringAsFixed(1);
        }
      }
    }
    final completed = logs.values
        .expand((value) => value)
        .where((value) => value.completed)
        .length;
    final total = logs.values.fold<int>(0, (sum, value) => sum + value.length);
    return Scaffold(
      appBar: AppBar(
          title: Text(routine.name,
              style: const TextStyle(fontWeight: FontWeight.w800))),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                  onPressed:
                      saving || completed == 0 ? null : () => _finish(routine),
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.flag),
                  label: Text('Finish workout · $completed/$total sets')))),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(routine.focus,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          const Text(
                              'Use controlled technique. Stop any exercise that causes sharp pain. The final repetitions should feel challenging but repeatable.')
                        ]))),
            ...routine.exercises.asMap().entries.map((entry) => _ExerciseCard(
                number: entry.key + 1,
                exercise: entry.value,
                sets: logs[entry.value.id]!,
                progression: progressions[entry.value.id],
                onChanged: () => setState(() {}))),
          ]),
    );
  }

  Future<void> _finish(StrengthRoutine routine) async {
    setState(() => saving = true);
    final controller = ref.read(strengthControllerProvider);
    final sessionId = await controller.startSession(
      routine.name,
      startedAt: workoutStartedAt,
    );
    for (final exercise in routine.exercises) {
      final sets = logs[exercise.id]!;
      for (var index = 0; index < sets.length; index++) {
        final value = sets[index];
        if (!value.completed) continue;
        await controller.saveSet(
            sessionId: sessionId,
            exerciseId: exercise.id,
            setNumber: index + 1,
            targetReps: exercise.defaultReps,
            completedReps: int.tryParse(value.reps.text) ?? 0,
            weightKg: double.tryParse(value.weight.text) ?? 0);
      }
    }
    await controller.completeSession(sessionId);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Strength workout saved.')));
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard(
      {required this.number,
      required this.exercise,
      required this.sets,
      required this.progression,
      required this.onChanged});
  final int number;
  final StrengthExercise exercise;
  final List<_SetLog> sets;
  final StrengthProgression? progression;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Card(
          child: ExpansionTile(
        initiallyExpanded: number == 1,
        leading: CircleAvatar(child: Text('$number')),
        title: Text(exercise.name,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(exercise.muscles),
        children: [
          _ExerciseAnimation(exerciseId: exercise.id),
          if (progression != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.trending_up),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NEXT-SESSION TARGET',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800)),
                      Text(progression!.message),
                    ],
                  ),
                ),
              ]),
            ),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(exercise.instructions)),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                SizedBox(width: 44, child: Text('SET')),
                Expanded(child: Text('WEIGHT (KG)')),
                SizedBox(width: 12),
                Expanded(child: Text('REPS')),
                SizedBox(width: 48)
              ])),
          ...sets.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                SizedBox(
                    width: 44,
                    child:
                        Text('${entry.key + 1}', textAlign: TextAlign.center)),
                Expanded(
                    child: TextField(
                        controller: entry.value.weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            hintText: '0', isDense: true))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        controller: entry.value.reps,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true))),
                SizedBox(
                    width: 48,
                    child: Checkbox(
                        value: entry.value.completed,
                        onChanged: (value) {
                          entry.value.completed = value ?? false;
                          onChanged();
                        }))
              ]))),
          const SizedBox(height: 10),
        ],
      ));
}

class _ExerciseAnimation extends StatefulWidget {
  const _ExerciseAnimation({required this.exerciseId});
  final String exerciseId;
  @override
  State<_ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<_ExerciseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 232,
      child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final frame = (controller.value * 3.999).floor();
            return Column(children: [
              Text('3D TECHNIQUE GUIDE',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(letterSpacing: .8)),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: _ExerciseSpriteFrame(
                    exerciseId: widget.exerciseId,
                    frame: frame,
                    fallbackProgress:
                        Curves.easeInOut.transform(controller.value),
                  ),
                ),
              ),
            ]);
          }));
}

class _ExerciseSpriteFrame extends StatelessWidget {
  const _ExerciseSpriteFrame({
    required this.exerciseId,
    required this.frame,
    required this.fallbackProgress,
  });

  final String exerciseId;
  final int frame;
  final double fallbackProgress;

  @override
  Widget build(BuildContext context) {
    const frameWidth = 154.0;
    return SizedBox(
      width: frameWidth,
      height: 202,
      child: ClipRect(
        child: Stack(children: [
          Positioned(
            left: -frame * frameWidth,
            top: 0,
            width: frameWidth * 4,
            height: 202,
            child: Image.asset(
              'assets/strength/$exerciseId.png',
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => SizedBox(
                width: frameWidth,
                child: CustomPaint(
                  painter: _ExercisePainter(
                    exerciseId: exerciseId,
                    progress: fallbackProgress,
                    color: Theme.of(context).colorScheme.primary,
                    guideColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ExercisePainter extends CustomPainter {
  const _ExercisePainter({
    required this.exerciseId,
    required this.progress,
    required this.color,
    required this.guideColor,
  });

  final String exerciseId;
  final double progress;
  final Color color;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = color;
    final guide = Paint()
      ..color = guideColor.withValues(alpha: .22)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(size.width * .14, size.height - 8),
        Offset(size.width * .86, size.height - 8), guide);

    if (exerciseId == 'push_up' || exerciseId.contains('plank')) {
      _horizontal(canvas, size, body, joint, bridge: false);
    } else if (exerciseId == 'bridge') {
      _horizontal(canvas, size, body, joint, bridge: true);
    } else if (exerciseId == 'deadlift' || exerciseId == 'row') {
      _hinge(canvas, size, body, joint, row: exerciseId == 'row');
    } else if (exerciseId == 'lat_pull') {
      _latPull(canvas, size, body, joint);
    } else {
      _upright(canvas, size, body, joint);
    }
  }

  void _upright(Canvas canvas, Size size, Paint body, Paint joint) {
    final cx = size.width / 2;
    final squat = {'squat', 'leg_press', 'split_squat'}.contains(exerciseId);
    final lift = exerciseId == 'calf' ? progress * 8 : 0.0;
    final depth = squat ? progress * 25 : 0.0;
    final head = Offset(cx, 18 + depth * .55 - lift);
    final shoulder = Offset(cx, 34 + depth * .6 - lift);
    final hip = Offset(cx, 62 + depth - lift);
    final leftKnee = Offset(cx - 18 - depth * .25, 82 - lift);
    final rightKnee = Offset(cx + 18 + depth * .25, 82 - lift);
    final leftFoot = Offset(cx - 26, size.height - 9 - lift);
    final rightFoot = Offset(cx + 26, size.height - 9 - lift);
    _head(canvas, head, joint);
    _torso(canvas, shoulder, hip, body);
    _line(canvas, hip, leftKnee, body);
    _line(canvas, leftKnee, leftFoot, body);
    _line(canvas, hip, rightKnee, body);
    _line(canvas, rightKnee, rightFoot, body);
    final handY = exerciseId == 'mobility'
        ? 30 - progress * 18
        : exerciseId == 'calf'
            ? 52 - lift
            : 58 + depth * .65 - lift;
    final reach = exerciseId == 'mobility' ? 42.0 : 18.0;
    _line(canvas, shoulder, Offset(cx - reach, handY), body);
    _line(canvas, shoulder, Offset(cx + reach, handY), body);
    if (exerciseId == 'squat' || exerciseId == 'split_squat') {
      _weight(canvas, Offset(cx, handY), body);
    }
  }

  void _hinge(Canvas canvas, Size size, Paint body, Paint joint,
      {required bool row}) {
    final cx = size.width / 2;
    final hip = Offset(cx, 61);
    final shoulder = Offset(cx + 4 + 30 * progress, 35 + 24 * progress);
    final head = Offset(shoulder.dx + 8, shoulder.dy - 16);
    _head(canvas, head, joint);
    _torso(canvas, shoulder, hip, body);
    _line(canvas, hip, Offset(cx - 14, 86), body);
    _line(canvas, Offset(cx - 14, 86), Offset(cx - 19, size.height - 9), body);
    _line(canvas, hip, Offset(cx + 14, 86), body);
    _line(canvas, Offset(cx + 14, 86), Offset(cx + 20, size.height - 9), body);
    final hand = row
        ? Offset(shoulder.dx - 4 - 15 * progress, shoulder.dy + 20)
        : Offset(shoulder.dx + 8, shoulder.dy + 30);
    _line(canvas, shoulder, hand, body);
    _weight(canvas, hand, body);
  }

  void _horizontal(Canvas canvas, Size size, Paint body, Paint joint,
      {required bool bridge}) {
    final ground = size.height - 13;
    if (bridge) {
      final shoulder = Offset(size.width * .30, ground - 8);
      final hip = Offset(size.width * .53, ground - 8 - 30 * progress);
      final knee = Offset(size.width * .68, ground - 35);
      final foot = Offset(size.width * .78, ground);
      _head(canvas, Offset(size.width * .20, ground - 9), joint);
      _torso(canvas, shoulder, hip, body);
      _line(canvas, hip, knee, body);
      _line(canvas, knee, foot, body);
      return;
    }
    final lower = exerciseId == 'push_up' ? progress * 12 : progress * 2;
    final shoulder = Offset(size.width * .32, ground - 35 + lower);
    final hip = Offset(size.width * .57, ground - 32 + lower);
    final heel = Offset(size.width * .78, ground - 24 + lower);
    _head(canvas, Offset(size.width * .22, ground - 39 + lower), joint);
    _torso(canvas, shoulder, hip, body);
    _line(canvas, hip, heel, body);
    _line(canvas, shoulder, Offset(size.width * .35, ground), body);
    _line(canvas, Offset(size.width * .35, ground),
        Offset(size.width * .28, ground), body);
  }

  void _latPull(Canvas canvas, Size size, Paint body, Paint joint) {
    final cx = size.width / 2;
    final head = const Offset(0, 0) + Offset(cx, 30);
    final shoulder = Offset(cx, 48);
    final hip = Offset(cx, 78);
    _head(canvas, head, joint);
    _torso(canvas, shoulder, hip, body);
    _line(canvas, hip, Offset(cx - 22, size.height - 10), body);
    _line(canvas, hip, Offset(cx + 22, size.height - 10), body);
    final handY = 8 + progress * 38;
    _line(canvas, shoulder, Offset(cx - 34, handY), body);
    _line(canvas, shoulder, Offset(cx + 34, handY), body);
    canvas.drawLine(Offset(cx - 42, handY), Offset(cx + 42, handY), body);
  }

  void _head(Canvas canvas, Offset center, Paint paint) {
    final outline = Paint()..color = const Color(0xFF111820);
    final skin = Paint()..color = const Color(0xFFE8A77C);
    final hair = Paint()
      ..color = const Color(0xFF33251F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
        Rect.fromCenter(center: center, width: 17, height: 20), outline);
    canvas.drawOval(
        Rect.fromCenter(center: center, width: 14, height: 17), skin);
    canvas.drawArc(
        Rect.fromCenter(center: center.translate(0, -1), width: 13, height: 14),
        math.pi,
        math.pi,
        false,
        hair);
  }

  void _torso(Canvas canvas, Offset shoulder, Offset hip, Paint paint) {
    final delta = hip - shoulder;
    final length = math.max(delta.distance, 1);
    final perpendicular = Offset(-delta.dy / length, delta.dx / length);
    final path = Path()
      ..moveTo(shoulder.dx + perpendicular.dx * 11,
          shoulder.dy + perpendicular.dy * 11)
      ..lineTo(shoulder.dx - perpendicular.dx * 11,
          shoulder.dy - perpendicular.dy * 11)
      ..lineTo(hip.dx - perpendicular.dx * 7, hip.dy - perpendicular.dy * 7)
      ..lineTo(hip.dx + perpendicular.dx * 7, hip.dy + perpendicular.dy * 7)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF111820));
    final inner = Path()
      ..moveTo(shoulder.dx + perpendicular.dx * 8,
          shoulder.dy + perpendicular.dy * 8)
      ..lineTo(shoulder.dx - perpendicular.dx * 8,
          shoulder.dy - perpendicular.dy * 8)
      ..lineTo(hip.dx - perpendicular.dx * 5, hip.dy - perpendicular.dy * 5)
      ..lineTo(hip.dx + perpendicular.dx * 5, hip.dy + perpendicular.dy * 5)
      ..close();
    canvas.drawPath(inner, Paint()..color = paint.color);
  }

  void _line(Canvas canvas, Offset a, Offset b, Paint paint) {
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFF111820)
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round);
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = paint.color.withValues(alpha: .82)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
  }

  void _weight(Canvas canvas, Offset center, Paint paint) {
    canvas.drawLine(Offset(center.dx - 10, center.dy),
        Offset(center.dx + 10, center.dy), paint);
    canvas.drawCircle(Offset(center.dx - 12, center.dy), 4, paint);
    canvas.drawCircle(Offset(center.dx + 12, center.dy), 4, paint);
  }

  @override
  bool shouldRepaint(covariant _ExercisePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.exerciseId != exerciseId ||
      oldDelegate.color != color;
}

class _SetLog {
  _SetLog({required int reps, double? weightKg})
      : weight = TextEditingController(
            text: weightKg == null || weightKg <= 0
                ? ''
                : weightKg.toStringAsFixed(1)),
        reps = TextEditingController(text: '$reps');
  final TextEditingController weight;
  final TextEditingController reps;
  bool completed = false;
  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}
