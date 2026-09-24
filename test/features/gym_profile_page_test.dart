import 'package:adaptive_workout/domain/gyms/gym_profile.dart';
import 'package:adaptive_workout/features/gyms/gym_profile_page.dart';
import 'package:adaptive_workout/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_gym_profile_repository.dart';

void main() {
  testWidgets(
    'select Homewood, confirm equipment, and reopen saved inventory',
    (tester) async {
      final repo = FakeGymProfileRepository();
      await tester.pumpWidget(
        MaterialApp(home: GymProfilePage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLUB4 Homewood').last);
      await tester.pumpAndSettle();
      expect(repo.stored.selectedId, homewoodGymId);
      await tester.scrollUntilVisible(
        find.text('0 equipment categories confirmed available'),
        150,
      );
      expect(
        find.text('0 equipment categories confirmed available'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('dumbbells'), 250);
      await tester.tap(find.text('dumbbells'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not checked').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Available').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save equipment'));
      await tester.pumpAndSettle();
      expect(repo.stored.selected!.availableCategories, ['dumbbells']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(home: GymProfilePage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1 equipment categories confirmed available'),
        150,
      );
      expect(
        find.text('1 equipment categories confirmed available'),
        findsOneWidget,
      );
    },
  );
  testWidgets('cancel adds no gym; custom gym starts empty', (tester) async {
    final repo = FakeGymProfileRepository();
    await tester.pumpWidget(
      MaterialApp(home: GymProfilePage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add another gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.stored.profiles, isEmpty);
    await tester.tap(find.text('Add another gym'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Gym name'),
      'My second gym',
    );
    await tester.tap(find.text('Add gym'));
    await tester.pumpAndSettle();
    expect(repo.stored.selected!.name, 'My second gym');
    expect(repo.stored.selected!.availableCategories, isEmpty);
  });
  for (final brightness in Brightness.values) {
    testWidgets('large text fits ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeGymProfileRepository()
        ..stored = GymProfiles(profiles: []).select(homewoodProfile());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: GymProfilePage(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('dumbbells'), 250);
      await tester.tap(find.text('dumbbells'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
