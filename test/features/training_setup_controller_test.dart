import 'package:adaptive_workout/features/setup/training_setup_controller.dart';
import 'package:adaptive_workout/domain/training/setup_variations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/training_setup_fixture.dart';
import '../support/setup_intake_fixture.dart';

void main() {
  late MemoryTrainingSetupRepository repo;
  late TrainingSetupController c;
  setUp(() {
    repo = MemoryTrainingSetupRepository();
    var id = 0;
    c = TrainingSetupController(
      repo,
      profileId: 'fixture',
      now: () => DateTime.utc(2026),
      newId: () => 'action_${id++}',
    );
  });
  tearDown(() => c.dispose());
  test('intake retries safely and later preference edits preserve evidence without baselines', () async {
    await c.load();
    repo.failNextRead = true;
    expect(
      await c.saveIntake(
        reports: [syntheticReport()],
        rehearsals: [syntheticRehearsal()],
      ),
      isFalse,
    );
    expect(c.canRetry, isTrue);
    expect(await c.retry(), isTrue);
    expect(repo.actions, hasLength(1));
    expect(c.saved!.reportedWork, hasLength(1));
    expect(c.saved!.startingLoads, isEmpty);
    expect(c.saved!.equipment, isEmpty);
    expect(await c.savePreferences([2, 4], '50', []), isTrue);
    expect(c.saved!.reportedWork, hasLength(1));
    expect(c.saved!.rehearsalConfirmations, hasLength(1));
    expect(await c.saveIntake(reports: [syntheticReport()]), isFalse);
    expect(c.saved!.reportedWork, hasLength(1));
    expect(await c.saveIntake(), isFalse);
  });
  test('preferences remain unknown until explicitly saved', () async {
    await c.load();
    expect(c.saved, isNull);
    expect(await c.savePreferences([2, 4], '50', []), isTrue);
    expect(c.saved!.trainingDays, [2, 4]);
    expect(c.saved!.preferredMinutes, 50);
    expect(c.saved!.limitations, isNull);
  });
  test(
    'failed writes preserve retry identity and reject new actions',
    () async {
      await c.load();
      repo.failWrite = true;
      expect(await c.savePreferences([2], '50', []), isFalse);
      expect(c.saved, isNull);
      expect(c.canRetry, isTrue);
      expect(await c.savePreferences([3], '90', []), isFalse);
      repo.failWrite = false;
      expect(await c.retry(), isTrue);
      expect(repo.actions.length, 1);
      expect(c.saved!.trainingDays, [2]);
    },
  );
  test(
    'lost read acknowledgement retries receipt without double write',
    () async {
      await c.load();
      repo.failNextRead = true;
      expect(await c.savePreferences([2], '50', []), isFalse);
      expect(repo.profiles['fixture']!.revision, 0);
      expect(await c.retry(), isTrue);
      expect(repo.actions.length, 1);
      expect(c.saved!.revision, 0);
    },
  );
  test('invalid and approximate values never save', () async {
    await c.load();
    expect(await c.savePreferences([2], '0', []), isFalse);
    expect(
      await c.saveMachine(
        label: 'fixture',
        sessionId: 'monday',
        slotId: 'incline_dumbbell_press',
        variation: 'incline_dumbbell_press',
        convention: SetupLoadConvention.perDumbbell,
        workingSettings: '20,25',
        rehearsalSettings: '10',
        startingWeight: 'about 20',
        confirmed: true,
      ),
      isFalse,
    );
    expect(repo.actions, isEmpty);
  });
  test('gradual draft then confirmation creates exact baseline and retains profile', () async {
    await c.load();
    await c.savePreferences([2], '50', []);
    expect(
      await c.saveMachine(
        label: 'fixture',
        sessionId: 'monday',
        slotId: 'incline_dumbbell_press',
        variation: 'incline_dumbbell_press',
        convention: SetupLoadConvention.perDumbbell,
        workingSettings: '',
        rehearsalSettings: '',
        startingWeight: '',
        confirmed: false,
      ),
      isTrue,
    );
    final id = c.saved!.equipment.single.id;
    expect(c.saved!.startingLoads, isEmpty);
    expect(
      await c.saveMachine(
        existingId: id,
        label: 'fixture',
        sessionId: 'monday',
        slotId: 'incline_dumbbell_press',
        variation: 'incline_dumbbell_press',
        convention: SetupLoadConvention.perDumbbell,
        workingSettings: '20,25',
        rehearsalSettings: '10',
        startingWeight: '20',
        confirmed: true,
      ),
      isTrue,
    );
    expect(c.saved!.startingLoads.single.microPounds, 20000000);
    expect(c.saved!.baselineIsCurrent(c.saved!.startingLoads.single), isTrue);
    expect(c.saved!.preferredMinutes, 50);
  });
}
