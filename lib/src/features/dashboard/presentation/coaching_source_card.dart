import 'package:flutter/material.dart';

enum CoachingSourceState { checking, authoritative, offlineFallback }

class CoachingSourceCard extends StatelessWidget {
  const CoachingSourceCard({required this.state, super.key});

  final CoachingSourceState state;

  @override
  Widget build(BuildContext context) {
    // A successful server read is the normal state, so it does not need to
    // compete with the day's coaching. Checking and fallback states remain
    // visible because they require the athlete's attention.
    if (state == CoachingSourceState.authoritative) {
      return const SizedBox.shrink();
    }
    final (icon, title, message) = switch (state) {
      CoachingSourceState.checking => (
          Icons.sync,
          'Checking today\'s coaching',
          'CycleReady is looking for the latest server recommendation.',
        ),
      CoachingSourceState.authoritative => throw StateError('Handled above'),
      CoachingSourceState.offlineFallback => (
          Icons.phone_android,
          'Using on-phone coaching',
          'The server recommendation is unavailable, so CycleReady is using '
              'its safe offline calculation.',
        ),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}
