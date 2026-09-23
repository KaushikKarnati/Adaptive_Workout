import '../progression/load_progression_policy.dart';

final class WarmupSetTarget {
  const WarmupSetTarget({
    required this.microPounds,
    required this.reps,
    required this.restAfterSeconds,
  });

  final int microPounds;
  final int reps;
  final int restAfterSeconds;
  bool get isWorkingSet => false;
}

final class WarmupResult {
  WarmupResult._(this.reasonCode, List<WarmupSetTarget> sets)
    : sets = List.unmodifiable(sets);

  final String ruleSetVersion = 'owner-warmup-v1';
  final String reasonCode;
  final List<WarmupSetTarget> sets;
  bool get isBlocked => sets.isEmpty;
}

/// Calculates targets only. Execution must stop on symptoms or a rehearsal
/// that is not comfortably easy; it must never auto-advance a live load.
final class WarmupPolicy {
  const WarmupPolicy();

  /// Applied once by session composition, not once per exercise.
  static const sessionWalkingSeconds = 300;

  WarmupResult evaluate({
    required ProgressionGate? gate,
    required ProgressionContext context,
    required VerifiedLoadBaseline? baseline,
    required List<int>? availableLoadsMicroPounds,
    required bool firstExternalLoadExercise,
  }) {
    WarmupResult blocked(String reason) => WarmupResult._(reason, const []);
    if (gate == ProgressionGate.safetyStop) return blocked('safety_stop');
    if (gate != ProgressionGate.permitted) {
      return blocked('current_checks_required');
    }
    if (context.loadKind != ProgressionLoadKind.external ||
        baseline == null ||
        baseline.context != context ||
        baseline.microPounds <= 0 ||
        [
          context.profileId,
          context.slotId,
          context.exerciseId,
          context.setupId,
          context.loadConventionId,
        ].any((id) => id.trim().isEmpty) ||
        context.setCount <= 0 ||
        context.minReps <= 0 ||
        context.maxReps < context.minReps) {
      return blocked('warmup_setup_required');
    }
    final loads = availableLoadsMicroPounds;
    if (loads == null ||
        loads.isEmpty ||
        loads.any((load) => load < 0) ||
        !loads.contains(baseline.microPounds)) {
      return blocked('warmup_setup_required');
    }
    // Zero represents a verified unloaded-machine setting, never an inference
    // that the machine itself has no resistance.
    final ordered = loads.toSet().toList()..sort();
    final targets = <WarmupSetTarget>[];
    final percentages = firstExternalLoadExercise ? [50, 75] : [50];
    for (var i = 0; i < percentages.length; i++) {
      final feasible = ordered.where(
        (load) =>
            BigInt.from(load) * BigInt.from(100) <=
            BigInt.from(baseline.microPounds) * BigInt.from(percentages[i]),
      );
      if (feasible.isEmpty) return blocked('warmup_setup_required');
      targets.add(
        WarmupSetTarget(
          microPounds: feasible.last,
          reps: firstExternalLoadExercise && i == 0 ? 8 : 5,
          restAfterSeconds: firstExternalLoadExercise && i == 1 ? 90 : 60,
        ),
      );
    }
    return WarmupResult._('warmup_targets_ready', targets);
  }
}
