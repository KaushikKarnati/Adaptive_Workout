import '../progression/load_progression_policy.dart';
import 'warmup_policy.dart';

const warmupRuleVersion = 'owner-warmup-v2';

enum RehearsalMovement {
  assistedPullUp,
  unassistedPullUp,
  supportedKneeRaise,
  kneelingRollout,
}

typedef RehearsalContext = ({
  String profileId,
  String slotId,
  String exerciseId,
  String setupId,
  RehearsalMovement movement,
});

/// Repository-supplied verification, not inferred from logged working sets.
final class VerifiedRehearsalSetup {
  VerifiedRehearsalSetup({
    required this.context,
    required this.verificationRef,
    required this.easyAndControlled,
    this.assistanceMicroPounds,
    List<int>? availableAssistanceMicroPounds,
    this.workingRangeRef,
    this.rehearsalRangeRef,
    this.rehearsalWithinWorkingRange,
  }) : availableAssistanceMicroPounds = availableAssistanceMicroPounds == null
           ? null
           : List.unmodifiable(availableAssistanceMicroPounds);

  final RehearsalContext context;
  final String verificationRef;
  final bool? easyAndControlled;
  final int? assistanceMicroPounds;
  final List<int>? availableAssistanceMicroPounds;
  final String? workingRangeRef;
  final String? rehearsalRangeRef;
  // Explicit verified relationship; never derived from opaque range IDs.
  final bool? rehearsalWithinWorkingRange;
}

final class RehearsalTarget {
  const RehearsalTarget._({
    required this.context,
    required this.verificationRef,
    required this.reps,
    required this.restAfterSeconds,
    this.assistanceMicroPounds,
    this.rangeRef,
  });
  final RehearsalContext context;
  final String verificationRef;
  final int reps;
  final int restAfterSeconds;
  final int? assistanceMicroPounds;
  final String? rangeRef;
  bool get isWorkingSet => false;
}

final class RehearsalPlan {
  RehearsalPlan._(this.reasonCode, List<RehearsalTarget> sets)
    : sets = List.unmodifiable(sets);
  final String ruleSetVersion = warmupRuleVersion;
  final String reasonCode;
  final List<RehearsalTarget> sets;
  bool get isBlocked => sets.isEmpty;
}

/// New bodyweight/assistance targets. No catalog, baseline or UI is enabled here.
final class BodyweightWarmupPolicy {
  const BodyweightWarmupPolicy();

  RehearsalPlan pullUps({
    required ProgressionGate? gate,
    required bool? includesUnassistedWork,
    required RehearsalContext assistedContext,
    required VerifiedRehearsalSetup? assistedSetup,
    required RehearsalContext? unassistedContext,
    required VerifiedRehearsalSetup? unassistedSetup,
  }) {
    final gateIssue = _gateIssue(gate);
    if (gateIssue != null) return _blocked(gateIssue);
    if (includesUnassistedWork == null ||
        assistedContext.movement != RehearsalMovement.assistedPullUp ||
        !_validSetup(assistedContext, assistedSetup)) {
      return _blocked('warmup_setup_required');
    }
    if (includesUnassistedWork) {
      if (unassistedContext == null ||
          unassistedContext.movement != RehearsalMovement.unassistedPullUp ||
          unassistedContext.profileId != assistedContext.profileId ||
          unassistedContext.slotId != assistedContext.slotId ||
          !_validSetup(unassistedContext, unassistedSetup)) {
        return _blocked('warmup_setup_required');
      }
    } else if (unassistedContext != null || unassistedSetup != null) {
      return _blocked('invalid_input');
    }
    return RehearsalPlan._('warmup_targets_ready', [
      _target(assistedSetup!, 5, includesUnassistedWork ? 60 : 120),
      if (includesUnassistedWork) _target(unassistedSetup!, 2, 120),
    ]);
  }

  RehearsalPlan core({
    required ProgressionGate? gate,
    required RehearsalContext context,
    required VerifiedRehearsalSetup? setup,
  }) {
    final gateIssue = _gateIssue(gate);
    if (gateIssue != null) return _blocked(gateIssue);
    if ((context.movement != RehearsalMovement.supportedKneeRaise &&
            context.movement != RehearsalMovement.kneelingRollout) ||
        !_validSetup(context, setup)) {
      return _blocked('warmup_setup_required');
    }
    return RehearsalPlan._('warmup_targets_ready', [
      _target(
        setup!,
        context.movement == RehearsalMovement.supportedKneeRaise ? 5 : 3,
        60,
      ),
    ]);
  }

  RehearsalTarget _target(VerifiedRehearsalSetup setup, int reps, int rest) =>
      RehearsalTarget._(
        context: setup.context,
        verificationRef: setup.verificationRef,
        reps: reps,
        restAfterSeconds: rest,
        assistanceMicroPounds: setup.assistanceMicroPounds,
        rangeRef: setup.rehearsalRangeRef,
      );

  bool _validSetup(RehearsalContext context, VerifiedRehearsalSetup? setup) {
    if (![
          context.profileId,
          context.slotId,
          context.exerciseId,
          context.setupId,
        ].every(_validRef) ||
        setup == null ||
        setup.context != context ||
        !_validRef(setup.verificationRef) ||
        setup.easyAndControlled != true) {
      return false;
    }
    if (context.movement == RehearsalMovement.assistedPullUp) {
      final settings = setup.availableAssistanceMicroPounds;
      final assistance = setup.assistanceMicroPounds;
      return assistance != null &&
          assistance > 0 &&
          settings != null &&
          settings.isNotEmpty &&
          settings.every((value) => value > 0) &&
          settings.toSet().length == settings.length &&
          settings.contains(assistance) &&
          setup.workingRangeRef == null &&
          setup.rehearsalRangeRef == null &&
          setup.rehearsalWithinWorkingRange == null;
    }
    if (setup.assistanceMicroPounds != null ||
        setup.availableAssistanceMicroPounds != null) {
      return false;
    }
    if (context.movement == RehearsalMovement.unassistedPullUp) {
      return setup.workingRangeRef == null &&
          setup.rehearsalRangeRef == null &&
          setup.rehearsalWithinWorkingRange == null;
    }
    return _validRef(setup.workingRangeRef) &&
        _validRef(setup.rehearsalRangeRef) &&
        setup.rehearsalWithinWorkingRange == true &&
        (context.movement != RehearsalMovement.supportedKneeRaise ||
            setup.workingRangeRef == setup.rehearsalRangeRef);
  }

  RehearsalPlan _blocked(String code) => RehearsalPlan._(code, const []);
}

bool _validRef(String? value) =>
    value != null &&
    value.isNotEmpty &&
    value.length <= 128 &&
    RegExp(r'^[\x21-\x7e]+$').hasMatch(value);

String? _gateIssue(ProgressionGate? gate) => switch (gate) {
  ProgressionGate.safetyStop => 'safety_stop',
  ProgressionGate.permitted => null,
  _ => 'current_checks_required',
};

enum RehearsalFeedback { easyAndControlled, notEasyOrNotControlled, unknown }

/// Pure execution decision shared by v1 external targets and v2 rehearsals.
/// Application orchestration must bind feedback/timing to the exact saved target,
/// preserve reports and receipts, and supply a fresh current gate.
String evaluateWarmupContinuation({
  required ProgressionGate? gate,
  required bool? interrupted,
  required bool? targetCompleted,
  required RehearsalFeedback? feedback,
  required int? elapsedRestSeconds,
  required int prescribedRestSeconds,
  required bool? userContinues,
}) {
  final gateIssue = _gateIssue(gate);
  if (gateIssue != null) return gateIssue;
  if (prescribedRestSeconds <= 0 ||
      (elapsedRestSeconds != null && elapsedRestSeconds < 0)) {
    return 'invalid_input';
  }
  if (interrupted != false) return 'preparation_review_required';
  if (targetCompleted != true) return 'rehearsal_completion_required';
  if (feedback == RehearsalFeedback.notEasyOrNotControlled) {
    return 'warmup_setup_review_required';
  }
  if (feedback != RehearsalFeedback.easyAndControlled) {
    return 'warmup_feedback_required';
  }
  if (elapsedRestSeconds == null) return 'rest_time_required';
  if (elapsedRestSeconds < prescribedRestSeconds) return 'rest_incomplete';
  if (userContinues != true) return 'continuation_required';
  return 'next_planned_action_permitted';
}

/// Retains the exact approved external-load algorithm with v2 attribution.
final class ExternalWarmupPlanV2 {
  ExternalWarmupPlanV2._(WarmupResult result)
    : reasonCode = result.reasonCode,
      sets = result.sets;
  final String reasonCode;
  final List<WarmupSetTarget> sets;
  String get ruleSetVersion => warmupRuleVersion;
  bool get isBlocked => sets.isEmpty;
}

ExternalWarmupPlanV2 externalWarmupV2({
  required ProgressionGate? gate,
  required ProgressionContext context,
  required VerifiedLoadBaseline? baseline,
  required List<int>? availableLoadsMicroPounds,
  required bool firstExternalLoadExercise,
}) => ExternalWarmupPlanV2._(
  const WarmupPolicy().evaluate(
    gate: gate,
    context: context,
    baseline: baseline,
    availableLoadsMicroPounds: availableLoadsMicroPounds,
    firstExternalLoadExercise: firstExternalLoadExercise,
  ),
);
