import 'package:cycle_ready/src/features/coaching/application/coach_reminder_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coachReminderServiceProvider = Provider((ref) => CoachReminderService());

final coachReminderControllerProvider =
    AsyncNotifierProvider<CoachReminderController, CoachReminderSettings>(
  CoachReminderController.new,
);

class CoachReminderController extends AsyncNotifier<CoachReminderSettings> {
  CoachReminderService get _service => ref.read(coachReminderServiceProvider);

  @override
  Future<CoachReminderSettings> build() => _service.load();

  Future<bool> setEnabled(bool enabled) async {
    final current = state.valueOrNull ??
        const CoachReminderSettings(enabled: false, hour: 20, minute: 30);
    state = const AsyncLoading();
    if (!enabled) {
      await _service.disable();
      state = AsyncData(
        CoachReminderSettings(
          enabled: false,
          hour: current.hour,
          minute: current.minute,
        ),
      );
      return true;
    }
    final allowed =
        await _service.enable(hour: current.hour, minute: current.minute);
    state = AsyncData(
      CoachReminderSettings(
        enabled: allowed,
        hour: current.hour,
        minute: current.minute,
      ),
    );
    return allowed;
  }

  Future<void> setTime(int hour, int minute) async {
    final current = state.valueOrNull ??
        const CoachReminderSettings(enabled: false, hour: 20, minute: 30);
    await _service.updateTime(hour: hour, minute: minute);
    state = AsyncData(
      CoachReminderSettings(
        enabled: current.enabled,
        hour: hour,
        minute: minute,
      ),
    );
  }
}
