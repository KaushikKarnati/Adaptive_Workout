import 'package:adaptive_workout/features/program/session_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 9, 24);
  test('elapsed uses saved endpoints and clamps backwards clock', () {
    expect(
      sessionElapsed(start, null, start.add(const Duration(seconds: 65))),
      const Duration(seconds: 65),
    );
    expect(
      sessionElapsed(
        start,
        start.add(const Duration(minutes: 3)),
        start.add(const Duration(days: 1)),
      ),
      const Duration(minutes: 3),
    );
    expect(
      sessionElapsed(start, null, start.subtract(const Duration(seconds: 1))),
      Duration.zero,
    );
    expect(timerText(const Duration(seconds: 65)), '01:05');
    expect(timerText(const Duration(hours: 25)), '1500:00');
  });
  test(
    'rest handles absent, invalid, restart, fractional and expired times',
    () {
      final rest = RestCountdown();
      addTearDown(rest.dispose);
      expect(rest.started, false);
      expect(rest.remaining(start), Duration.zero);
      expect(() => rest.start(0, start), throwsArgumentError);
      expect(() => rest.start(-1, start), throwsArgumentError);
      rest.start(90, start);
      expect(
        rest.remaining(start.add(const Duration(milliseconds: 500))),
        const Duration(seconds: 90),
      );
      expect(
        rest.remaining(start.add(const Duration(seconds: 90))),
        Duration.zero,
      );
      expect(rest.remaining(start.add(const Duration(days: 1))), Duration.zero);
      rest.start(60, start.add(const Duration(minutes: 2)));
      expect(
        rest.remaining(start.add(const Duration(minutes: 2))),
        const Duration(seconds: 60),
      );
      rest.clear();
      expect(rest.started, false);
    },
  );
  testWidgets('ticks, catches up after background, and stops at saved finish', (
    tester,
  ) async {
    var now = start;
    final rest = RestCountdown();
    addTearDown(rest.dispose);
    Widget panel(DateTime? end) => MaterialApp(
      home: Scaffold(
        bottomNavigationBar: SessionTimerPanel(
          start: start,
          end: end,
          rest: rest,
          now: () => now,
        ),
      ),
    );
    await tester.pumpWidget(panel(null));
    expect(find.text('Workout time  00:00'), findsOneWidget);
    rest.start(60, now);
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Workout time  00:10'), findsOneWidget);
    expect(find.text('Rest  00:50'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Rest complete'), findsOneWidget);
    await tester.tap(find.text('Clear rest'));
    await tester.pump();
    expect(find.byKey(const Key('rest_remaining')), findsNothing);
    await tester.pumpWidget(panel(now));
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Total time  02:10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('timer wraps at narrow width and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rest = RestCountdown()..start(90, start);
    addTearDown(rest.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            bottomNavigationBar: SessionTimerPanel(
              start: start,
              end: null,
              rest: rest,
              now: () => start,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
