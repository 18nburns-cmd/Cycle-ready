import 'package:cycle_ready/src/core/database/database_provider.dart';
import 'package:cycle_ready/src/features/athlete/data/drift_athlete_profile_repository.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile_repository.dart';
import 'package:cycle_ready/src/features/coaching/application/planned_session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final athleteProfileRepositoryProvider = Provider<AthleteProfileRepository>(
  (ref) => DriftAthleteProfileRepository(ref.watch(databaseProvider)),
);

final athleteProfileProvider = StreamProvider<AthleteProfile>(
  (ref) => ref.watch(athleteProfileRepositoryProvider).watchProfile(),
);

final athleteProfileControllerProvider = Provider(
  (ref) => AthleteProfileController(
    ref.watch(athleteProfileRepositoryProvider),
    onFtpChanged: () => ref
        .read(plannedSessionControllerProvider)
        .refreshAdaptivePlanForFtpChange(),
  ),
);

typedef FtpChangedCallback = Future<bool> Function();

class AthleteProfileController {
  const AthleteProfileController(
    this.repository, {
    this.onFtpChanged,
  });

  final AthleteProfileRepository repository;
  final FtpChangedCallback? onFtpChanged;

  Future<AthleteProfile> load() => repository.getProfile();

  /// Saves the profile and returns whether future adaptive workouts were
  /// refreshed because FTP changed.
  Future<bool> save(AthleteProfile profile) async {
    final previous = await repository.getProfile();
    await repository.saveProfile(profile);
    if (previous.ftp == profile.ftp || onFtpChanged == null) return false;
    return onFtpChanged!();
  }
}
