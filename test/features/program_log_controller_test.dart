import 'package:adaptive_workout/features/program/program_log_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_program_log_repository.dart';
import '../domain/logging/program_log_test.dart' show entry;

void main() {
  test(
    'delete failures and lost acknowledgement retain safe retry identity',
    () async {
      final repo = FakeProgramLogRepository();
      final c = ProgramLogController(repo);
      addTearDown(c.dispose);
      await c.start('monday');
      await c.record(entry());
      final log = c.selected!;
      repo.failWrite = true;
      expect(await c.delete(log), isFalse);
      expect(c.locked, isTrue);
      expect(await c.start('friday'), isFalse);
      expect(repo.logs, hasLength(1));
      repo.failWrite = false;
      repo.failRead = true;
      expect(await c.retry(), isFalse);
      expect(repo.logs, isEmpty);
      expect(c.locked, isTrue);
      expect(await c.retry(), isTrue);
      expect(c.locked, isFalse);
      expect(c.selected, isNull);
      expect(c.logs, isEmpty);
      expect(await c.start('friday'), isTrue);
    },
  );

  test('failed write retains pending actuals and retries once', () async {
    final repo = FakeProgramLogRepository();
    final controller = ProgramLogController(repo);
    addTearDown(controller.dispose);
    await controller.start('monday');
    repo.failWrite = true;
    expect(await controller.record(entry()), isFalse);
    expect(controller.pending!.sets.single.reps, 10);
    expect(await controller.record(entry(index: 2)), isFalse);
    repo.failWrite = false;
    expect(await controller.retry(), isTrue);
    expect(controller.selected!.sets.length, 1);
  });
  test(
    'lost read acknowledgement retries same action without duplicate',
    () async {
      final repo = FakeProgramLogRepository();
      final c = ProgramLogController(repo);
      addTearDown(c.dispose);
      await c.start('monday');
      repo.failRead = true;
      expect(await c.record(entry()), isFalse);
      expect(repo.writes, 2);
      expect(await c.retry(), isTrue);
      expect(repo.writes, 2);
      expect(c.selected!.sets.length, 1);
      expect(await c.start('tuesday'), isTrue);
      expect(c.selected!.programId, 'monday');
    },
  );
}
