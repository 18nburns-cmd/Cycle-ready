import 'package:cycle_ready/src/features/athlete/application/athlete_profile_controller.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';
import 'package:cycle_ready/src/features/athlete/domain/athlete_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FTP change refreshes future adaptive workouts once', () async {
    final repository = _MemoryAthleteProfileRepository(_profile(ftp: 240));
    var refreshes = 0;
    final controller = AthleteProfileController(
      repository,
      onFtpChanged: () async {
        refreshes++;
        return true;
      },
    );

    final refreshed = await controller.save(_profile(ftp: 255));

    expect(refreshed, isTrue);
    expect(refreshes, 1);
    expect((await repository.getProfile()).ftp, 255);
  });

  test('non-FTP profile edit does not regenerate the plan', () async {
    final repository = _MemoryAthleteProfileRepository(_profile(ftp: 240));
    var refreshes = 0;
    final controller = AthleteProfileController(
      repository,
      onFtpChanged: () async {
        refreshes++;
        return true;
      },
    );

    final refreshed = await controller.save(
      AthleteProfile(
        name: 'Neil Updated',
        experienceLevel: 'intermediate',
        ftp: 240,
        maximumHeartRate: 190,
        restingHeartRate: 50,
        weightKg: 72,
        weeklyLoadTarget: 400,
      ),
    );

    expect(refreshed, isFalse);
    expect(refreshes, 0);
  });
}

AthleteProfile _profile({required int ftp}) => AthleteProfile(
      name: 'Neil',
      experienceLevel: 'intermediate',
      ftp: ftp,
      maximumHeartRate: 190,
      restingHeartRate: 50,
      weightKg: 72,
      weeklyLoadTarget: 400,
    );

class _MemoryAthleteProfileRepository implements AthleteProfileRepository {
  _MemoryAthleteProfileRepository(this.profile);

  AthleteProfile profile;

  @override
  Future<AthleteProfile> getProfile() async => profile;

  @override
  Future<void> saveProfile(AthleteProfile value) async => profile = value;

  @override
  Stream<AthleteProfile> watchProfile() => Stream.value(profile);
}
