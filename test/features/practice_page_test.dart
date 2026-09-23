import 'package:adaptive_workout/features/practice/practice_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_practice_repository.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('practice_load')), '30.5');
  await tester.enterText(find.byKey(const Key('practice_reps')), '10');
  await tester.enterText(find.byKey(const Key('practice_rir')), '2');
}

void main() {
  testWidgets('save, completion and history render only acknowledged records', (
    tester,
  ) async {
    final repo = FakePracticeRepository();
    await tester.pumpWidget(
      AdaptiveWorkoutApp(home: PracticePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'start_practice');
    await _enter(tester);
    await _tap(tester, 'save_practice_set');
    await tester.scrollUntilVisible(
      find.byKey(const Key('saved_count')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 saved records'), findsOneWidget);
    expect(repo.sessions.single.sets.single.microPounds, 30500000);
    await _tap(tester, 'complete_practice');
    expect(find.byKey(const Key('completion_saved')), findsOneWidget);
    await _tap(tester, 'practice_back');
    expect(find.text('Completed practice'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      AdaptiveWorkoutApp(home: PracticePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed practice'), findsOneWidget);
  });
  testWidgets(
    'failed save preserves typed values and retry adds exactly one set',
    (tester) async {
      final repo = FakePracticeRepository();
      await tester.pumpWidget(
        AdaptiveWorkoutApp(home: PracticePage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'start_practice');
      await _enter(tester);
      repo.failSave = true;
      await _tap(tester, 'save_practice_set');
      await tester.scrollUntilVisible(
        find.byKey(const Key('save_error')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('save_error')), findsOneWidget);
      expect(repo.sessions.single.sets, isEmpty);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('practice_load')))
            .controller!
            .text,
        '30.5',
      );
      repo.failSave = false;
      await tester.ensureVisible(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repo.sessions.single.sets, hasLength(1));
      expect(find.byKey(const Key('save_error')), findsNothing);
    },
  );
  testWidgets('invalid numeric entry never writes', (tester) async {
    final repo = FakePracticeRepository();
    await tester.pumpWidget(
      AdaptiveWorkoutApp(home: PracticePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'start_practice');
    await _enter(tester);
    await tester.enterText(find.byKey(const Key('practice_reps')), '2.5');
    await _tap(tester, 'save_practice_set');
    expect(find.byKey(const Key('input_error')), findsOneWidget);
    expect(repo.saveAttempts, 0);
  });
  testWidgets('pain stops only the affected practice movement', (tester) async {
    final repo = FakePracticeRepository();
    repo.sessions.add(
      PracticeSession(
        id: 'draft',
        profileId: 'local_owner',
        startedAt: DateTime.utc(2026, 9, 23),
        completedAt: null,
        revision: 1,
        sets: const [
          PracticeSet(
            id: 'practice_press_1',
            exerciseId: 'practice_press',
            index: 1,
            microPounds: 30000000,
            reps: 10,
            rir: 2,
            working: true,
            validity: SetValidity.pain,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      AdaptiveWorkoutApp(home: PracticePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('save_practice_set')),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save_practice_set')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice row').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save_practice_set')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('practice form supports large text on narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakePracticeRepository();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PracticePage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'start_practice');
    expect(tester.takeException(), isNull);
  });
}
