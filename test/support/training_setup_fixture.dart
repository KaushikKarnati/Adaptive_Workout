import 'package:adaptive_workout/domain/training/setup_variations.dart';
import 'package:adaptive_workout/domain/training/training_setup.dart';

EquipmentSetup fixtureEquipment({
  int revision = 0,
  bool confirmed = true,
  List<int> settings = const [20000000, 25000000],
  String id = 'machine',
}) => EquipmentSetup(
  id: id,
  revision: revision,
  label: 'Synthetic fixture dumbbells',
  variation: 'incline_dumbbell_press',
  equipmentId: 'dumbbells',
  quantity: 2,
  capabilities: [],
  convention: SetupLoadConvention.perDumbbell,
  workingLoads: settings,
  rehearsalLoads: [10000000],
  confirmedAt: confirmed ? DateTime.utc(2026, 1, 1, 0, revision) : null,
);
StartingLoad fixtureBaseline({
  int setupRevision = 0,
  int value = 20000000,
  String id = 'baseline',
  String machine = 'machine',
}) => StartingLoad(
  id: id,
  sessionId: 'monday',
  slotId: 'incline_dumbbell_press',
  variation: 'incline_dumbbell_press',
  setupId: machine,
  setupRevision: setupRevision,
  convention: SetupLoadConvention.perDumbbell,
  microPounds: value,
  confirmedAt: DateTime.utc(2026, 1, 1, 0, setupRevision),
);
TrainingSetup fixtureProfile({
  String profile = 'fixture_a',
  int revision = 0,
  List<int> days = const [2, 4],
  int? minutes = 50,
  List<EquipmentSetup> equipment = const [],
  List<StartingLoad> baselines = const [],
}) => TrainingSetup(
  profileId: profile,
  revision: revision,
  updatedAt: DateTime.utc(2026, 1, 1, 0, revision),
  trainingDays: days,
  preferredMinutes: minutes,
  supportedCapabilities: null,
  unsupportedCapabilities: null,
  limitations: null,
  excludedVariations: [],
  equipment: equipment,
  startingLoads: baselines,
);

class MemoryTrainingSetupRepository implements TrainingSetupRepository {
  final profiles = <String, TrainingSetup>{};
  final actions = <String, String>{};
  bool failWrite = false, failNextRead = false;
  int writes = 0;
  @override
  Future<TrainingSetup?> load(String profileId) async {
    if (failNextRead) {
      failNextRead = false;
      throw StateError('fixture read failure');
    }
    return profiles[profileId];
  }

  @override
  Future<void> save(
    TrainingSetup setup, {
    required int expectedRevision,
    required String actionId,
  }) async {
    writes++;
    if (failWrite) throw StateError('fixture write failure');
    final key = '${setup.profileId}/$actionId';
    if (actions.containsKey(key)) {
      requireSetup(actions[key] == setup.encode(), 'action_conflict');
      return;
    }
    requireSetup(
      (profiles[setup.profileId]?.revision ?? -1) == expectedRevision,
      'stale_revision',
    );
    validateSetupTransition(profiles[setup.profileId], setup);
    profiles[setup.profileId] = setup;
    actions[key] = setup.encode();
  }

  @override
  Future<void> close() async {}
}
