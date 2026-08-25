import 'dart:async';

import 'package:cycle_ready/src/features/strength/application/strength_provider.dart';
import 'package:cycle_ready/src/features/strength/domain/mobility_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MobilityWorkoutScreen extends ConsumerStatefulWidget {
  const MobilityWorkoutScreen({required this.routineIndex, super.key});
  final int routineIndex;

  @override
  ConsumerState<MobilityWorkoutScreen> createState() =>
      _MobilityWorkoutScreenState();
}

class _MobilityWorkoutScreenState extends ConsumerState<MobilityWorkoutScreen> {
  Timer? _timer;
  int _exerciseIndex = 0;
  int _remaining = 0;
  bool _running = false;
  bool _saving = false;
  late final DateTime _startedAt;

  MobilityRoutine get routine => mobilityRoutines[
      widget.routineIndex.clamp(0, mobilityRoutines.length - 1)];
  MobilityExercise get exercise => routine.exercises[_exerciseIndex];

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _remaining = routine.exercises.first.totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _timer?.cancel();
        _next();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _next() {
    _timer?.cancel();
    if (_exerciseIndex >= routine.exercises.length - 1) {
      setState(() {
        _remaining = 0;
        _running = false;
      });
      _finish();
      return;
    }
    setState(() {
      _exerciseIndex++;
      _remaining = exercise.totalSeconds;
      _running = false;
    });
  }

  void _previous() {
    if (_exerciseIndex == 0) return;
    _timer?.cancel();
    setState(() {
      _exerciseIndex--;
      _remaining = exercise.totalSeconds;
      _running = false;
    });
  }

  Future<void> _finish() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final controller = ref.read(strengthControllerProvider);
    final sessionId = await controller.startSession(
      'Mobility · ${routine.name}',
      startedAt: _startedAt,
    );
    for (var index = 0; index < routine.exercises.length; index++) {
      final item = routine.exercises[index];
      await controller.saveSet(
        sessionId: sessionId,
        exerciseId: 'mobility_${item.id}',
        setNumber: index + 1,
        targetReps: item.totalSeconds,
        completedReps: item.totalSeconds,
        weightKg: 0,
      );
    }
    await controller.completeSession(sessionId);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Mobility session completed and added to your calendar.'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_exerciseIndex +
            (exercise.totalSeconds == 0
                ? 0
                : 1 - _remaining / exercise.totalSeconds)) /
        routine.exercises.length;
    return Scaffold(
      appBar: AppBar(title: Text(routine.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              LinearProgressIndicator(value: progress.clamp(0, 1)),
              const SizedBox(height: 10),
              Text(
                'Movement ${_exerciseIndex + 1} of ${routine.exercises.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              _MobilityAnimation(exerciseId: exercise.id),
              const SizedBox(height: 18),
              Text(
                exercise.name,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(exercise.focus),
              const SizedBox(height: 20),
              Text(
                _formatSeconds(_remaining),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              if (exercise.sides == 2)
                Text('${exercise.seconds} seconds each side'),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    exercise.instructions,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _exerciseIndex == 0 ? null : _previous,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _toggleTimer,
                      icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                      label: Text(_running ? 'Pause' : 'Start timer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: _saving ? null : _next,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _saving ? null : _finish,
                child: Text(_saving ? 'Saving…' : 'Finish routine'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSeconds(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

class _MobilityAnimation extends StatefulWidget {
  const _MobilityAnimation({required this.exerciseId});
  final String exerciseId;

  @override
  State<_MobilityAnimation> createState() => _MobilityAnimationState();
}

class _MobilityAnimationState extends State<_MobilityAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 190,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final frame = (_controller.value * 3.999).floor();
            const frameWidth = 154.0;
            return Column(
              children: [
                Text(
                  'HUMAN MOVEMENT GUIDE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: .8,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: SizedBox(
                    width: frameWidth,
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Positioned(
                            left: -frame * frameWidth,
                            top: 0,
                            width: frameWidth * 4,
                            bottom: 0,
                            child: Image.asset(
                              'assets/mobility/${widget.exerciseId}.png',
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.self_improvement,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
