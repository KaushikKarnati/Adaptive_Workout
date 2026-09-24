import 'dart:async';

import 'package:adaptive_workout/domain/gyms/gym_profile.dart';
import 'package:adaptive_workout/features/gyms/gym_profile_page.dart';
import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_gym_profile_repository.dart';
import '../support/fake_haptics_driver.dart';

class _DelayedGymRepository extends FakeGymProfileRepository {
  Completer<void>? saveGate;

  @override
  Future<void> save(GymProfiles next, {required GymProfiles expected}) async {
    await saveGate?.future;
    await super.save(next, expected: expected);
  }
}

Future<void> showGym(
  WidgetTester tester,
  FakeGymProfileRepository repo,
  FakeHapticsDriver driver,
) async {
  final haptics = AppHaptics(driver: driver);
  await haptics.load();
  addTearDown(haptics.dispose);
  await tester.pumpWidget(
    AppHapticsScope(
      haptics: haptics,
      child: MaterialApp(home: GymProfilePage(repository: repo)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('gym selection cues only after confirmed save and reload', (
    tester,
  ) async {
    final repo = _DelayedGymRepository();
    final driver = FakeHapticsDriver();
    await showGym(tester, repo, driver);
    expect(driver.events, isEmpty);
    repo.saveGate = Completer<void>();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!(homewoodGymId);
    await tester.pump();
    expect(driver.events, isEmpty);
    repo.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(driver.events, ['selection']);
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!(homewoodGymId);
    await tester.pumpAndSettle();
    expect(driver.events, ['selection']);
  });

  testWidgets('failed confirmation errors then retry acknowledges saved gym', (
    tester,
  ) async {
    final repo = FakeGymProfileRepository();
    final driver = FakeHapticsDriver();
    await showGym(tester, repo, driver);
    repo.failRead = true;
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!(homewoodGymId);
    await tester.pumpAndSettle();
    expect(repo.stored.selectedId, homewoodGymId);
    expect(driver.events, ['error']);
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(driver.events, ['error', 'success']);
    await tester.scrollUntilVisible(find.text('Clear selected gym'), 400);
    await tester.tap(find.text('Clear selected gym'));
    await tester.pumpAndSettle();
    expect(repo.stored.selectedId, isNull);
    expect(driver.events, ['error', 'success', 'success']);
  });

  testWidgets(
    'gym validation, changed status and save have distinct feedback',
    (tester) async {
      final repo = FakeGymProfileRepository();
      final driver = FakeHapticsDriver();
      await showGym(tester, repo, driver);
      await tester.tap(find.text('Add another gym'));
      await tester.pumpAndSettle();
      expect(driver.events, isEmpty);
      await tester.tap(find.text('Add gym'));
      await tester.pumpAndSettle();
      expect(driver.events, ['error']);
      await tester.enterText(
        find.widgetWithText(TextField, 'Gym name'),
        'My gym',
      );
      await tester.pump();
      expect(driver.events, ['error']);
      await tester.tap(find.text('Add gym'));
      await tester.pumpAndSettle();
      expect(driver.events, ['error', 'success']);
      await tester.scrollUntilVisible(find.text('dumbbells'), 300);
      await tester.ensureVisible(find.text('dumbbells'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dumbbells'));
      await tester.pumpAndSettle();
      final status = find.byType(
        DropdownButtonFormField<EquipmentAvailability>,
      );
      tester
          .widget<DropdownButtonFormField<EquipmentAvailability>>(status)
          .onChanged!(EquipmentAvailability.available);
      await tester.pump();
      expect(driver.events, ['error', 'success', 'selection']);
      tester
          .widget<DropdownButtonFormField<EquipmentAvailability>>(status)
          .onChanged!(EquipmentAvailability.available);
      await tester.pump();
      expect(driver.events, ['error', 'success', 'selection']);
      await tester.tap(find.text('Save equipment'));
      await tester.pumpAndSettle();
      expect(driver.events, ['error', 'success', 'selection', 'success']);
    },
  );

  testWidgets('muted gym actions and cancel remain quiet', (tester) async {
    final repo = FakeGymProfileRepository();
    final driver = FakeHapticsDriver()..storedEnabled = false;
    await showGym(tester, repo, driver);
    await tester.tap(find.text('Add another gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .onChanged!(homewoodGymId);
    await tester.pumpAndSettle();
    expect(repo.stored.selectedId, homewoodGymId);
    expect(driver.events, isEmpty);
  });
}
