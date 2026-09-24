import 'dart:io';
import 'dart:ui' as ui;

import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:adaptive_workout/features/history/workout_history_page.dart';
import 'package:adaptive_workout/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/logging/program_log_test.dart' show entry;
import '../support/fake_program_log_repository.dart';

void main() {
  testWidgets('optional history visual review with synthetic records', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE_HISTORY')) return;
    await tester.runAsync(() async {
      for (final family in [
        'Ahem',
        'Roboto',
        '.SF UI Text',
        '.SF UI Display',
      ]) {
        final font = FontLoader(family)
          ..addFont(
            File('/System/Library/Fonts/SFNS.ttf')
                .readAsBytes()
                .then((b) => ByteData.sublistView(b)),
          );
        await font.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeProgramLogRepository();
    for (var i = 0; i < 3; i++) {
      repo.logs['visual$i'] = ProgramLog(
        id: 'visual$i',
        profile: 'local_owner',
        programId: 'monday',
        startedAt: DateTime.utc(2026, 9, 10 + i * 4, 15),
        completedAt: DateTime.utc(2026, 9, 10 + i * 4, 16),
        endedEarly: true,
        revision: 1,
        sets: [
          for (var n = 1; n <= 3; n++)
            entry(
              index: n,
              setup: 'Home dumbbells',
              load: (30 + i * 5) * 1000000,
              reps: 12 - n,
            ),
        ],
      );
    }
    for (final dark in [false, true]) {
      for (final graphs in [false, true]) {
        await tester.pumpWidget(const SizedBox());
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: AppTheme.build(dark ? Brightness.dark : Brightness.light)
                  .copyWith(
                    textTheme: AppTheme.build(
                      dark ? Brightness.dark : Brightness.light,
                    ).textTheme.apply(fontFamily: 'Ahem'),
                  ),
              debugShowCheckedModeBanner: false,
              home: WorkoutHistoryPage(repository: repo, graphs: graphs),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (graphs) {
          await tester.scrollUntilVisible(
            find.text('Recorded sets'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/adaptive-${graphs ? 'graphs' : 'history'}-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
