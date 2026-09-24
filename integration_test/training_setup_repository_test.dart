import 'dart:convert';

import 'package:adaptive_workout/data/repositories/sqlite_training_setup_repository.dart';
import 'package:adaptive_workout/domain/training/training_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/training_setup_fixture.dart';
import '../test/support/setup_intake_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const path = 'training_setup_fixture.sqlite';
  late SqliteTrainingSetupRepository repo;
  setUp(() async {
    await deleteDatabase(path);
    repo = await SqliteTrainingSetupRepository.open(path: path);
  });
  tearDown(() async {
    await repo.close();
    await deleteDatabase(path);
  });
  testWidgets(
    'schema-two reports and rehearsal drafts survive reopen alongside unchanged v1 audit',
    (_) async {
      final old = fixtureProfile();
      await repo.save(old, expectedRevision: -1, actionId: 'old');
      final next = withIntake(
        old,
        revision: 1,
        reports: [syntheticReport()],
        rehearsals: [syntheticRehearsal()],
      );
      await repo.save(next, expectedRevision: 0, actionId: 'intake');
      await repo.save(next, expectedRevision: 0, actionId: 'intake');
      await repo.close();
      repo = await SqliteTrainingSetupRepository.open(path: path);
      final restored = (await repo.load(old.profileId))!;
      expect(restored.encode(), next.encode());
      expect(restored.startingLoads, isEmpty);
      expect(
        restored.rehearsalConfirmations.single.hasCompleteAttestation,
        isFalse,
      );
      final db = await openDatabase(path);
      expect((await db.query('revisions')).single['payload'], old.encode());
      expect((await db.query('receipts')).length, 2);
      expect(await repo.load('other'), isNull);
      await expectLater(
        repo.save(
          withIntake(old, revision: 2),
          expectedRevision: 1,
          actionId: 'delete_reports',
        ),
        throwsA(isA<SetupException>()),
      );
      expect((await repo.load(old.profileId))!.encode(), next.encode());
    },
  );
  testWidgets(
    'intake receipt failure rolls back the new payload and prior revision',
    (_) async {
      final old = fixtureProfile();
      await repo.save(old, expectedRevision: -1, actionId: 'old');
      final db = await openDatabase(path);
      await db.execute(
        "CREATE TRIGGER intake_failure BEFORE INSERT ON receipts BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      final next = withIntake(old, revision: 1, reports: [syntheticReport()]);
      await expectLater(
        repo.save(next, expectedRevision: 0, actionId: 'intake'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repo.load(old.profileId))!.encode(), old.encode());
      expect(await db.query('revisions'), isEmpty);
      await db.execute('DROP TRIGGER intake_failure');
      await repo.save(next, expectedRevision: 0, actionId: 'intake');
      expect((await repo.load(old.profileId))!.encode(), next.encode());
    },
  );
  testWidgets(
    'native setup confirmation, revision history, receipts, isolation and reopen',
    (_) async {
      final a = fixtureProfile();
      await repo.save(a, expectedRevision: -1, actionId: 'create');
      await repo.save(
        fixtureProfile(profile: 'fixture_b'),
        expectedRevision: -1,
        actionId: 'create',
      );
      final confirmed = fixtureProfile(
        revision: 1,
        equipment: [fixtureEquipment()],
        baselines: [fixtureBaseline()],
      );
      await repo.save(confirmed, expectedRevision: 0, actionId: 'verify');
      await repo.save(confirmed, expectedRevision: 0, actionId: 'verify');
      await expectLater(
        repo.save(confirmed, expectedRevision: 0, actionId: 'stale'),
        throwsA(isA<SetupException>()),
      );
      await expectLater(
        repo.save(
          fixtureProfile(revision: 1, minutes: 90),
          expectedRevision: 0,
          actionId: 'verify',
        ),
        throwsA(isA<SetupException>()),
      );
      await repo.close();
      repo = await SqliteTrainingSetupRepository.open(path: path);
      final restored = await repo.load('fixture_a');
      expect(restored!.encode(), confirmed.encode());
      expect((await repo.load('fixture_b'))!.equipment, isEmpty);
      final db = await openDatabase(path);
      expect((await db.query('revisions')).length, 1);
      expect((await db.query('receipts')).length, 3);
      expect(
        (await db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
    },
  );
  testWidgets('receipt failure rolls back whole aggregate and can retry', (
    _,
  ) async {
    await repo.save(fixtureProfile(), expectedRevision: -1, actionId: 'create');
    final db = await openDatabase(path);
    await db.execute(
      "CREATE TRIGGER fail_receipt BEFORE INSERT ON receipts BEGIN SELECT RAISE(ABORT,'fixture failure'); END",
    );
    final next = fixtureProfile(
      revision: 1,
      equipment: [fixtureEquipment()],
      baselines: [fixtureBaseline()],
    );
    await expectLater(
      repo.save(next, expectedRevision: 0, actionId: 'verify'),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repo.load('fixture_a'))!.revision, 0);
    expect(await db.query('revisions'), isEmpty);
    await db.execute('DROP TRIGGER fail_receipt');
    await repo.save(next, expectedRevision: 0, actionId: 'verify');
    expect((await repo.load('fixture_a'))!.startingLoads.length, 1);
  });
  testWidgets(
    'setup update leaves old load stale until explicit reconfirmation',
    (_) async {
      final old = fixtureProfile(
        equipment: [fixtureEquipment()],
        baselines: [fixtureBaseline()],
      );
      await repo.save(old, expectedRevision: -1, actionId: 'create');
      final next = fixtureProfile(
        revision: 1,
        equipment: [
          fixtureEquipment(revision: 1, settings: [25000000]),
        ],
        baselines: old.startingLoads,
      );
      await repo.save(next, expectedRevision: 0, actionId: 'equipment_change');
      await repo.close();
      repo = await SqliteTrainingSetupRepository.open(path: path);
      final saved = (await repo.load('fixture_a'))!;
      expect(saved.baselineIsCurrent(saved.startingLoads.single), isFalse);
      final db = await openDatabase(path);
      final before = TrainingSetup.decode(
        (await db.query('revisions')).single['payload'] as String,
      );
      expect(before.baselineIsCurrent(before.startingLoads.single), isTrue);
    },
  );
  testWidgets(
    'corrupt relational identity and payload versions refuse without deletion',
    (_) async {
      final original = fixtureProfile();
      await repo.save(original, expectedRevision: -1, actionId: 'create');
      final db = await openDatabase(path);
      await db.update('profiles', {'revision': 99});
      await expectLater(repo.load('fixture_a'), throwsA(isA<SetupException>()));
      await db.update('profiles', {
        'revision': 0,
        'payload': jsonEncode({...original.toJson(), 'unit': 'kg'}),
      });
      await expectLater(repo.load('fixture_a'), throwsA(isA<SetupException>()));
      await db.update('profiles', {'payload': original.encode()});
      await db.execute('PRAGMA user_version=2');
      await repo.close();
      await expectLater(
        SqliteTrainingSetupRepository.open(path: path),
        throwsA(isA<SetupException>()),
      );
      final inspect = await openDatabase(path);
      expect(
        (await inspect.query('profiles')).single['payload'],
        original.encode(),
      );
      await inspect.close();
    },
  );
}
