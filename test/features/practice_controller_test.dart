import 'dart:async';

import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/features/practice/practice_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_practice_repository.dart';

const record = PracticeSet(
  id: 'set_1',
  exerciseId: 'practice_press',
  index: 1,
  microPounds: 30000000,
  reps: 10,
  rir: 2,
  working: true,
  validity: SetValidity.valid,
);
void main() {
  test(
    'failed write keeps zero acknowledged sets and permits safe retry',
    () async {
      final repo = FakePracticeRepository();
      final controller = PracticeController(repo);
      await controller.load();
      await controller.start();
      repo.failSave = true;
      expect(await controller.save(record), isFalse);
      expect(controller.selected!.sets, isEmpty);
      expect(controller.retryRequired, isTrue);
      expect(controller.error, isNotNull);
      repo.failSave = false;
      expect(await controller.retry(), isTrue);
      expect(controller.selected!.sets, hasLength(1));
      controller.dispose();
    },
  );
  test('duplicate taps while write is pending invoke only one write', () async {
    final repo = FakePracticeRepository();
    final controller = PracticeController(repo);
    await controller.start();
    repo.pause = Completer<void>();
    final first = controller.save(record);
    expect(await controller.save(record), isFalse);
    expect(repo.saveAttempts, 1);
    repo.pause!.complete();
    await first;
    expect(controller.selected!.sets, hasLength(1));
    controller.dispose();
  });
  test('lost read acknowledgement retries the same accepted action', () async {
    final repo = FakePracticeRepository();
    final controller = PracticeController(repo);
    await controller.start();
    repo.failLoad = true;
    expect(await controller.save(record), isFalse);
    expect(controller.selected!.sets, isEmpty);
    repo.failLoad = false;
    expect(await controller.retry(), isTrue);
    expect(controller.selected!.sets, hasLength(1));
    expect(controller.selected!.revision, 1);
    controller.dispose();
  });
  test('failed completion never displays completed state', () async {
    final repo = FakePracticeRepository();
    final controller = PracticeController(repo);
    await controller.start();
    repo.failSave = true;
    expect(await controller.complete(), isFalse);
    expect(controller.selected!.completed, isFalse);
    controller.dispose();
  });
}
