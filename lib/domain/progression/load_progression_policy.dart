/// Pure candidate-load policy; not a complete or safety-cleared recommendation.
library;

enum ProgressionGate { permitted, blocked, safetyStop }

enum ProgressionLoadKind { external, bodyweight, assistance }

enum SetSide { bilateral, left, right }

enum ProgressionAction { blocked, hold, increase, decrease }

typedef ProgressionContext = ({
  String profileId,
  String slotId,
  String exerciseId,
  String setupId,
  String loadConventionId,
  int setCount,
  int minReps,
  int maxReps,
  bool unilateral,
  ProgressionLoadKind loadKind,
});

final class VerifiedLoadBaseline {
  const VerifiedLoadBaseline({
    required this.context,
    required this.microPounds,
  });

  final ProgressionContext context;
  final int microPounds;
}

final class ProgressionSet {
  const ProgressionSet({
    required this.index,
    required this.side,
    required this.microPounds,
    required this.reps,
    required this.rir,
    required this.valid,
    this.working = true,
  });

  final int index;
  final SetSide side;
  final int? microPounds;
  final int? reps;
  final int? rir;
  final bool? valid;
  final bool working;
}

final class ProgressionExposure {
  ProgressionExposure({
    required this.id,
    required this.sequence,
    required this.occurredAt,
    required this.context,
    required this.completed,
    required this.correctedOut,
    required List<ProgressionSet> sets,
  }) : sets = List.unmodifiable(sets);

  final String id;
  final int sequence;
  final DateTime occurredAt;
  final ProgressionContext context;
  final bool completed;
  final bool correctedOut;
  final List<ProgressionSet> sets;
}

final class LoadProgressionInput {
  LoadProgressionInput({
    required this.context,
    required this.gate,
    required this.baseline,
    required List<int>? availableLoadsMicroPounds,
    required List<ProgressionExposure>? history,
  }) : availableLoadsMicroPounds = availableLoadsMicroPounds == null
           ? null
           : List.unmodifiable(availableLoadsMicroPounds),
       history = history == null ? null : List.unmodifiable(history);

  final ProgressionContext context;
  final ProgressionGate? gate;
  final VerifiedLoadBaseline? baseline;
  final List<int>? availableLoadsMicroPounds;
  final List<ProgressionExposure>? history;
}

final class LoadProgressionResult {
  LoadProgressionResult._(
    this.action,
    this.reasonCode,
    this.candidateMicroPounds,
    List<String> evidenceIds,
  ) : evidenceIds = List.unmodifiable(evidenceIds);

  final String ruleSetVersion = 'owner-program-v1';
  final ProgressionAction action;
  final String reasonCode;
  final int? candidateMicroPounds;
  final List<String> evidenceIds;
}

final class LoadProgressionPolicy {
  const LoadProgressionPolicy();

  LoadProgressionResult evaluate(LoadProgressionInput input) {
    LoadProgressionResult blocked(String reason) => LoadProgressionResult._(
      ProgressionAction.blocked,
      reason,
      null,
      const [],
    );
    if (input.gate == ProgressionGate.safetyStop) {
      return blocked('safety_stop');
    }
    if (input.gate != ProgressionGate.permitted) {
      return blocked('current_checks_required');
    }
    final context = input.context;
    if (!_validContext(context)) return blocked('invalid_input');
    final baseline = input.baseline;
    if (baseline == null || baseline.context != context) {
      return blocked('baseline_required');
    }
    final current = baseline.microPounds;
    if (current < 0 ||
        (context.loadKind == ProgressionLoadKind.external && current == 0)) {
      return blocked('invalid_baseline');
    }
    final loads = input.availableLoadsMicroPounds;
    if (loads == null || loads.isEmpty) {
      return blocked('verified_loads_required');
    }
    if (loads.any((load) => load < 0) ||
        (context.loadKind == ProgressionLoadKind.external &&
            loads.contains(0))) {
      return blocked('invalid_available_loads');
    }
    if (!loads.contains(current)) return blocked('baseline_load_unavailable');
    final evidenceIds = <String>[];
    LoadProgressionResult hold(String reason) => LoadProgressionResult._(
      ProgressionAction.hold,
      reason,
      current,
      evidenceIds,
    );
    if (context.loadKind != ProgressionLoadKind.external) {
      return hold('bodyweight_or_assistance_hold');
    }
    final history = input.history;
    if (history == null) return hold('insufficient_evidence');
    final scoped = history
        .where(
          (entry) =>
              entry.context.profileId == context.profileId &&
              entry.context.slotId == context.slotId,
        )
        .toList();
    final ids = <String>{};
    final sequences = <int>{};
    for (final entry in scoped) {
      if (entry.id.trim().isEmpty ||
          entry.sequence < 0 ||
          !entry.occurredAt.isUtc ||
          !ids.add(entry.id) ||
          !sequences.add(entry.sequence)) {
        return blocked('invalid_history');
      }
    }
    scoped.sort((a, b) => a.sequence.compareTo(b.sequence));
    for (var i = 1; i < scoped.length; i++) {
      if (scoped[i].occurredAt.isBefore(scoped[i - 1].occurredAt)) {
        return blocked('invalid_history');
      }
    }
    final latest = scoped.skip(scoped.length > 2 ? scoped.length - 2 : 0);
    evidenceIds.addAll(latest.map((entry) => entry.id));
    final setsByExposure = <List<ProgressionSet>>[];
    for (final entry in latest) {
      if (entry.context != context || !entry.completed || entry.correctedOut) {
        return hold('insufficient_evidence');
      }
      final working = entry.sets.where((set) => set.working).toList();
      final expectedSides = context.unilateral
          ? <SetSide>{SetSide.left, SetSide.right}
          : <SetSide>{SetSide.bilateral};
      if (working.length != context.setCount * expectedSides.length) {
        return hold('insufficient_evidence');
      }
      final seen = <(int, SetSide)>{};
      for (final set in working) {
        if (set.valid != true ||
            set.microPounds != current ||
            set.reps == null ||
            set.reps! < 0 ||
            set.rir == null ||
            set.rir! < 0 ||
            set.index < 1 ||
            set.index > context.setCount ||
            !expectedSides.contains(set.side) ||
            !seen.add((set.index, set.side))) {
          return hold('insufficient_evidence');
        }
      }
      setsByExposure.add(working);
    }
    if (setsByExposure.length < 2) {
      return hold('insufficient_progression_streak');
    }
    final increase = setsByExposure.every(
      (sets) =>
          sets.every((set) => set.reps! >= context.maxReps && set.rir! >= 2),
    );
    final orderedLoads = loads.toSet().toList()..sort();
    if (increase) {
      final higher = orderedLoads.where((load) => load > current);
      if (higher.isEmpty) return hold('no_higher_load');
      final next = higher.first;
      if (!_withinPercent(next - current, current, 5)) {
        return hold('increment_above_five_percent');
      }
      return LoadProgressionResult._(
        ProgressionAction.increase,
        'progress_two_qualifying_exposures',
        next,
        evidenceIds,
      );
    }
    final decrease = setsByExposure.every(
      (sets) => sets.any((set) => set.reps! < context.minReps || set.rir! < 2),
    );
    if (decrease) {
      final lower = orderedLoads.where((load) => load < current);
      if (lower.isEmpty || !_withinPercent(current - lower.last, current, 10)) {
        return LoadProgressionResult._(
          ProgressionAction.blocked,
          'baseline_review_required',
          null,
          evidenceIds,
        );
      }
      return LoadProgressionResult._(
        ProgressionAction.decrease,
        'reduce_two_underperforming_exposures',
        lower.last,
        evidenceIds,
      );
    }
    return hold(
      setsByExposure.any(
            (sets) => sets.any((set) => set.reps! < context.maxReps),
          )
          ? 'rep_ceiling_not_met'
          : 'effort_target_not_met',
    );
  }

  bool _withinPercent(int difference, int current, int percent) =>
      BigInt.from(difference) * BigInt.from(100) <=
      BigInt.from(current) * BigInt.from(percent);

  bool _validContext(ProgressionContext context) =>
      [
        context.profileId,
        context.slotId,
        context.exerciseId,
        context.setupId,
        context.loadConventionId,
      ].every((value) => value.trim().isNotEmpty) &&
      context.setCount > 0 &&
      context.minReps > 0 &&
      context.maxReps >= context.minReps;
}
