import 'package:adaptive_workout/application/session_generation_service.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/domain/workout/session_composer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_composer_fixture.dart';

class FakeGenerationSource implements SessionGenerationSource {
  FakeGenerationSource(this.fixture);
  final ComposerFixture fixture;
  int revision = 0;
  bool changeDuringCapture = false;
  bool failSave = false;
  final Map<String, String> receipts = {};
  String? saved;
  @override
  Future<CapturedSessionInputs> capture(String requestId) async {
    final input = CapturedSessionInputs(
      revisionToken: '$revision',
      input: fixture.input(id: requestId),
    );
    if (changeDuringCapture) revision++;
    return input;
  }

  @override
  Future<void> saveIfCurrent({
    required CapturedSessionInputs captured,
    required SessionCompositionResult result,
    required String actionId,
  }) async {
    final payload = result.snapshot!.encode();
    if (receipts.containsKey(actionId)) {
      if (receipts[actionId] != payload) {
        throw const LoggingException('action_conflict');
      }
      return;
    }
    if (captured.revisionToken != '$revision') {
      throw const LoggingException('stale_input');
    }
    if (failSave) throw const LoggingException('storage_unavailable');
    saved = payload;
    receipts[actionId] = payload;
  }
}

void main() {
  test(
    'save ready and blocked results; identical action retry has one receipt',
    () async {
      for (final f in [
        ComposerFixture('monday'),
        ComposerFixture('monday', missing: ['incline_dumbbell_press']),
      ]) {
        final source = FakeGenerationSource(f);
        final service = SessionGenerationService(
          source: source,
          composer: f.composer,
        );
        final r = await service.generate('request', actionId: 'action');
        expect(source.saved, r.snapshot!.encode());
        expect(
          (await service.generate(
            'request',
            actionId: 'action',
          )).snapshot!.encode(),
          source.saved,
        );
        expect(source.receipts, hasLength(1));
        await expectLater(
          service.generate('changed', actionId: 'action'),
          throwsA(isA<LoggingException>()),
        );
      }
    },
  );
  test('stale source or storage failure never reports saved success', () async {
    for (final stale in [true, false]) {
      final f = ComposerFixture('monday');
      final source = FakeGenerationSource(f)
        ..changeDuringCapture = stale
        ..failSave = !stale;
      final service = SessionGenerationService(
        source: source,
        composer: f.composer,
      );
      await expectLater(
        service.generate('request', actionId: 'action'),
        throwsA(isA<LoggingException>()),
      );
      expect(source.saved, isNull);
      expect(source.receipts, isEmpty);
    }
  });
  test('safety failure is never saved as an executable result', () async {
    final f = ComposerFixture('monday', stop: true);
    final source = FakeGenerationSource(f);
    final r = await SessionGenerationService(
      source: source,
      composer: f.composer,
    ).generate('request', actionId: 'action');
    expect(r.reason, 'safety_stop');
    expect(source.saved, isNull);
  });
}
