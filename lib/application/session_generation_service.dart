import '../domain/workout/session_composer.dart';

/// Capture and compare-and-save share the source's consistency boundary. An
/// adapter must atomically check every input revision and save the snapshot,
/// slot reasons, proposed loads and action receipt, or reject without a write.
/// Independent reads from the current separate SQLite stores do not satisfy
/// this contract. No production adapter is registered until that boundary exists.
abstract interface class SessionGenerationSource {
  Future<CapturedSessionInputs> capture(String requestId);
  Future<void> saveIfCurrent({
    required CapturedSessionInputs captured,
    required SessionCompositionResult result,
    required String actionId,
  });
}

final class CapturedSessionInputs {
  const CapturedSessionInputs({
    required this.revisionToken,
    required this.input,
  });
  final String revisionToken;
  final SessionCompositionInput input;
}

final class SessionGenerationService {
  const SessionGenerationService({
    required this.source,
    required this.composer,
  });
  final SessionGenerationSource source;
  final SessionComposer composer;

  Future<SessionCompositionResult> generate(
    String requestId, {
    required String actionId,
  }) async {
    final captured = await source.capture(requestId);
    final result = composer.compose(captured.input);
    if (result.snapshot != null) {
      // Propagate conflicts/failures; never report an unsaved plan as committed.
      await source.saveIfCurrent(
        captured: captured,
        result: result,
        actionId: actionId,
      );
    }
    return result;
  }
}
