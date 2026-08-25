import 'package:cycle_ready/src/features/athlete/domain/athlete_profile.dart';

abstract interface class AthleteProfileRepository {
  Future<AthleteProfile> getProfile();
  Stream<AthleteProfile> watchProfile();
  Future<void> saveProfile(AthleteProfile profile);
}
