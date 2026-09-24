import 'package:adaptive_workout/domain/gyms/gym_profile.dart';

class FakeGymProfileRepository implements GymProfileRepository {
  GymProfiles stored = GymProfiles(profiles: []);
  bool failRead = false, failWrite = false;
  @override
  Future<GymProfiles> load() async {
    if (failRead) {
      failRead = false;
      throw StateError('read failed');
    }
    return GymProfiles.decode(stored.encode());
  }

  @override
  Future<void> save(GymProfiles next, {required GymProfiles expected}) async {
    if (failWrite) throw StateError('write failed');
    if (stored.encode() == next.encode()) return;
    if (stored.encode() != expected.encode()) throw StateError('conflict');
    stored = GymProfiles.decode(next.encode());
  }

  @override
  Future<void> close() async {}
}
