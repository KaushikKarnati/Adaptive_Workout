import 'dart:convert';

import '../exercises/catalog/catalog_integrity.dart';
import '../exercises/eligibility/exercise_eligibility.dart';
import '../exercises/catalog/exercise_catalog.dart';
import '../logging/program_log.dart';
import '../logging/practice_repository.dart' show LoggingException;
import '../progression/load_progression_policy.dart';
import '../recommendations/recommendation_history.dart';
import '../training/setup_variations.dart';
import '../training/training_setup.dart';
import 'owner_program.dart';
import 'session_planning_policy.dart';
import 'warmup_policy.dart';
import 'warmup_policy_v2.dart';

const sessionCompositionVersion = 'owner-session-v2';
const generatedProgramVersion = 'owner-generated-v3';
const generatedProgramId = 'owner-program';

/// Trusted, reviewed configuration, never name matching or user-editable text.
/// Empty production bindings keep the actual program disabled.
final class ProgramCatalogBindings {
  ProgramCatalogBindings({
    required this.version,
    required this.reviewReference,
    required this.catalogDigest,
    required Map<String, String> exerciseIds,
  }) : exerciseIds = Map.unmodifiable(exerciseIds) {
    validateSetupId(version);
    validateSetupId(reviewReference);
    requireSetup(
      RegExp(r'^[a-f0-9]{64}$').hasMatch(catalogDigest),
      'invalid_digest',
    );
    for (final e in exerciseIds.entries) {
      requireSetup(setupVariationNames.containsKey(e.key), 'unknown_variation');
      validateSetupId(e.value);
    }
    requireSetup(
      exerciseIds.values.toSet().length == exerciseIds.length,
      'ambiguous_binding',
    );
  }
  final String version, reviewReference, catalogDigest;
  final Map<String, String> exerciseIds;
}

final class SessionRehearsalVerification {
  const SessionRehearsalVerification({
    required this.setupRevision,
    required this.setup,
  });
  final int setupRevision;
  final VerifiedRehearsalSetup setup;
}

/// Repositories must supply a single coherent, complete input envelope.
final class SessionCompositionInput {
  SessionCompositionInput({
    required this.id,
    required this.profile,
    required this.sessionId,
    required this.createdAt,
    required this.requestedDate,
    required this.timezone,
    required this.setup,
    required this.history,
    required this.eligibility,
    required Map<String, int> inputRevisions,
    required List<SessionRehearsalVerification> rehearsals,
  }) : inputRevisions = Map.unmodifiable(inputRevisions),
       rehearsals = List.unmodifiable(rehearsals);
  final String id, profile, sessionId, timezone;
  final DateTime createdAt, requestedDate;
  final TrainingSetup? setup;
  final GeneratedHistory? history;
  final ExerciseEligibilityRequest eligibility;
  final Map<String, int> inputRevisions;
  final List<SessionRehearsalVerification> rehearsals;
}

/// A candidate is informational until a separate fresh confirmation transaction.
final class SessionLoadProposal {
  const SessionLoadProposal(this.slotId, this.baselineReference, this.result);
  final String slotId, baselineReference;
  final LoadProgressionResult result;
}

final class SessionCompositionResult {
  SessionCompositionResult._(
    this.reason, {
    this.snapshot,
    List<SessionLoadProposal> proposals = const [],
    Map<String, String> slotReasons = const {},
  }) : proposals = List.unmodifiable(proposals),
       slotReasons = Map.unmodifiable(slotReasons);
  final String reason;
  final RecommendationSnapshot? snapshot;
  final List<SessionLoadProposal> proposals;
  final Map<String, String> slotReasons;
  bool get isReady => snapshot?.status == RecommendationStatus.ready;

  /// Rehearse both superset members before round one; then alternate by round.
  List<({String slotId, SetTarget target})> get executionOrder {
    final slots = snapshot?.slots ?? <RecommendedSlot>[];
    final ordered = <({String slotId, SetTarget target})>[];
    for (final block in slots.map((s) => s.blockId).toSet()) {
      final members = slots.where((s) => s.blockId == block).toList();
      for (final s in members) {
        for (final t in s.targets.where((t) => t.warmup)) {
          ordered.add((slotId: s.id, target: t));
        }
      }
      final rounds = members.first.targets
          .where((t) => !t.warmup)
          .map((t) => t.index)
          .toSet();
      for (final round in rounds) {
        for (final s in members) {
          for (final t in s.targets.where(
            (t) => !t.warmup && t.index == round,
          )) {
            ordered.add((slotId: s.id, target: t));
          }
        }
      }
    }
    return List.unmodifiable(ordered);
  }

  // No approved duration model exists. Unknown never means within preference.
  DurationFit get durationFit => DurationFit.estimateRequired;
}

final class SessionComposer {
  const SessionComposer({required this.evaluator, required this.bindings});
  final ExerciseEligibilityEvaluator evaluator;
  final ProgramCatalogBindings bindings;

  SessionCompositionResult compose(SessionCompositionInput input) {
    try {
      return _compose(input);
    } on LoggingException {
      return SessionCompositionResult._('invalid_input');
    } on SetupException {
      return SessionCompositionResult._('invalid_input');
    }
  }

  SessionCompositionResult _compose(SessionCompositionInput input) {
    SessionCompositionResult rejected(String reason) =>
        SessionCompositionResult._(reason);
    final setup = input.setup;
    final history = input.history;
    final session = ownerProgram
        .where((s) => s.id == input.sessionId)
        .firstOrNull;
    if (setup == null || history == null) {
      return rejected('required_input_missing');
    }
    if (session == null ||
        setup.profileId != input.profile ||
        history.profile != input.profile ||
        input.createdAt.isBefore(setup.updatedAt) ||
        !input.createdAt.isUtc ||
        !input.requestedDate.isUtc ||
        input.requestedDate !=
            DateTime.utc(
              input.requestedDate.year,
              input.requestedDate.month,
              input.requestedDate.day,
            ) ||
        setup.preferredMinutes == null) {
      return rejected('invalid_input');
    }
    if (history.occurrences.any((s) => s.updatedAt.isAfter(input.createdAt))) {
      return rejected('invalid_history');
    }
    if (history.occurrences.any((s) => s.status == OccurrenceStatus.active)) {
      return rejected('resume_session');
    }
    // Do not turn a durable symptom flag into a clear caller-supplied gate.
    if (history.occurrences.any((s) => s.stoppedSlots.isNotEmpty) ||
        setup.rehearsalConfirmations.any((r) => r.symptomsReported == true)) {
      return rejected('safety_stop');
    }
    if (setup.rehearsalConfirmations.any(
      (r) => r.sessionId == input.sessionId && r.easyAndControlled == false,
    )) {
      return rejected('warmup_setup_review_required');
    }
    if ([
      'profile',
      'equipment',
      'baseline',
      'constraints',
    ].any((key) => input.inputRevisions[key] != setup.revision)) {
      return rejected('stale_input');
    }
    final eligibility = evaluator.evaluate(input.eligibility);
    if (eligibility.status != EligibilityResultStatus.evaluated &&
        eligibility.status != EligibilityResultStatus.constrainedNoCandidate) {
      return rejected(eligibility.status.wireName);
    }
    if (bindings.catalogDigest != input.eligibility.catalogContentSha256) {
      return rejected('binding_catalog_mismatch');
    }
    if (!_same(
          input.eligibility.functionalCapabilityAssessment?.supportedIds,
          setup.supportedCapabilities,
        ) ||
        !_same(
          input.eligibility.functionalCapabilityAssessment?.unsupportedIds,
          setup.unsupportedCapabilities,
        ) ||
        !_same(
          input.eligibility.limitationAssessment?.ids,
          setup.limitations,
        )) {
      return rejected('constraint_setup_mismatch');
    }
    final slots = <RecommendedSlot>[];
    final proposals = <SessionLoadProposal>[];
    final reasons = <String, String>{};
    final evidence = <String, int>{};
    var firstExternal = true;
    for (var blockIndex = 0; blockIndex < session.blocks.length; blockIndex++) {
      final block = session.blocks[blockIndex];
      for (var position = 0; position < block.exercises.length; position++) {
        final exercise = block.exercises[position];
        final variants = setupVariantsFor(exercise);
        // Complete preference coverage is required before selecting a fallback.
        if (variants.any(
          (v) =>
              !bindings.exerciseIds.containsKey(v) ||
              !(input.eligibility.candidateExerciseIds ?? []).contains(
                bindings.exerciseIds[v],
              ),
        )) {
          reasons[exercise.id] = 'catalog_binding_required';
          continue;
        }
        EquipmentSetup? equipment;
        StartingLoad? baseline;
        String? selectedId;
        for (final variant in variants) {
          if (setup.excludedVariations.contains(variant)) continue;
          final catalogId = bindings.exerciseIds[variant]!;
          if (!eligibility.eligibleExerciseIds.contains(catalogId)) continue;
          final candidates = setup.startingLoads
              .where(
                (b) =>
                    b.sessionId == session.id &&
                    b.slotId == exercise.id &&
                    b.variation == variant &&
                    setup.baselineIsCurrent(b),
              )
              .toList();
          if (candidates.length > 1) {
            return rejected('setup_selection_required');
          }
          if (candidates.isEmpty) continue;
          baseline = candidates.single;
          equipment = setup.equipment.singleWhere(
            (e) => e.id == baseline!.setupId,
          );
          selectedId = catalogId;
          break;
        }
        if (equipment == null || baseline == null || selectedId == null) {
          reasons[exercise.id] = 'eligible_setup_and_baseline_required';
          continue;
        }
        final entry = input.eligibility.catalog!.singleWhere(
          (e) => e.id == selectedId,
        );
        if ((entry.laterality == Laterality.unilateral) != exercise.eachSide ||
            entry.laterality == Laterality.alternating ||
            !_matchesEquipment(entry, equipment, input.eligibility)) {
          reasons[exercise.id] = 'catalog_setup_mismatch';
          continue;
        }
        final convention = _convention(equipment.convention);
        final sides = exercise.eachSide
            ? [LoggedSide.left, LoggedSide.right]
            : [LoggedSide.both];
        final work = <SetTarget>[
          for (var round = 1; round <= exercise.sets; round++)
            for (final side in sides)
              SetTarget(
                index: round,
                side: side,
                warmup: false,
                load: baseline.microPounds,
                minReps: exercise.minReps,
                maxReps: exercise.maxReps,
                minRir: exercise.minRir,
                maxRir: exercise.maxRir,
                // Superset rest follows the last member of each paired round.
                restSeconds:
                    position == block.exercises.length - 1 && side == sides.last
                    ? block.restSeconds
                    : 0,
              ),
        ];
        RecommendedSlot slot(List<SetTarget> targets) => RecommendedSlot(
          id: exercise.id,
          exerciseId: selectedId!,
          blockId: 'block_${blockIndex + 1}',
          setupId: equipment!.id,
          setupRevision: equipment.revision,
          baselineReference:
              'baseline_${sha256Hex(utf8.encode(jsonEncode(baseline!.toJson())))}',
          convention: convention,
          unilateral: exercise.eachSide,
          targets: targets,
        );
        final provisional = slot(work);
        final context = progressionContext(
          input.profile,
          generatedProgramId,
          session.id,
          provisional,
        );
        final verified = VerifiedLoadBaseline(
          context: context,
          microPounds: baseline.microPounds ?? 0,
        );
        final progression = const LoadProgressionPolicy().evaluate(
          LoadProgressionInput(
            context: context,
            gate: ProgressionGate.permitted,
            baseline: verified,
            availableLoadsMicroPounds: convention == LoadConvention.bodyweight
                ? [0]
                : equipment.workingLoads,
            history: history.progression(
              programId: generatedProgramId,
              programVersion: generatedProgramVersion,
              sessionTemplate: session.id,
              current: provisional,
            ),
          ),
        );
        if (progression.action == ProgressionAction.blocked) {
          reasons[exercise.id] = progression.reasonCode;
          continue;
        }
        for (final id in progression.evidenceIds) {
          evidence[id] = history.occurrences
              .singleWhere((s) => s.id == id)
              .revision;
        }
        final warmups = <SetTarget>[];
        if (context.loadKind == ProgressionLoadKind.external) {
          final plan = externalWarmupV2(
            gate: ProgressionGate.permitted,
            context: context,
            baseline: verified,
            availableLoadsMicroPounds: {
              ...equipment.rehearsalLoads,
              baseline.microPounds!,
            }.toList(),
            firstExternalLoadExercise: firstExternal,
          );
          firstExternal = false;
          if (plan.isBlocked) {
            reasons[exercise.id] = plan.reasonCode;
            continue;
          }
          for (var i = 0; i < plan.sets.length; i++) {
            final t = plan.sets[i];
            for (final side in sides) {
              warmups.add(
                SetTarget(
                  index: i + 1,
                  side: side,
                  warmup: true,
                  load: t.microPounds,
                  minReps: t.reps,
                  maxReps: t.reps,
                  minRir: null,
                  maxRir: null,
                  restSeconds: side == sides.last ? t.restAfterSeconds : 0,
                ),
              );
            }
          }
        } else {
          final plan = _bodyweight(
            input,
            equipment,
            exercise.id,
            selectedId,
            eligibility.eligibleExerciseIds,
          );
          if (plan == null || plan.isBlocked) {
            reasons[exercise.id] = plan?.reasonCode ?? 'warmup_setup_required';
            continue;
          }
          for (var i = 0; i < plan.sets.length; i++) {
            final t = plan.sets[i];
            final rehearsalEquipment = setup.equipment.singleWhere(
              (e) => e.id == t.context.setupId,
            );
            warmups.add(
              SetTarget(
                index: i + 1,
                side: LoggedSide.both,
                warmup: true,
                load: t.assistanceMicroPounds,
                minReps: t.reps,
                maxReps: t.reps,
                minRir: null,
                maxRir: null,
                restSeconds: t.restAfterSeconds,
                rangeReference: t.rangeRef,
                rehearsalIdentity: RehearsalIdentity(
                  exerciseId: t.context.exerciseId,
                  setupId: rehearsalEquipment.id,
                  setupRevision: rehearsalEquipment.revision,
                  convention: _convention(rehearsalEquipment.convention),
                  verificationReference: t.verificationRef,
                ),
              ),
            );
          }
        }
        reasons[exercise.id] = progression.reasonCode;
        if (progression.action == ProgressionAction.increase ||
            progression.action == ProgressionAction.decrease) {
          proposals.add(
            SessionLoadProposal(
              exercise.id,
              provisional.baselineReference,
              progression,
            ),
          );
        }
        final range = _rehearsals(input)
            .where(
              (v) =>
                  v.setup.context.profileId == input.profile &&
                  v.setup.context.slotId ==
                      '${input.sessionId}/${exercise.id}' &&
                  v.setup.context.exerciseId == selectedId &&
                  v.setup.context.setupId == equipment!.id &&
                  v.setupRevision == equipment.revision,
            )
            .firstOrNull
            ?.setup
            .workingRangeRef;
        final rangedWork = range == null
            ? work
            : work
                  .map(
                    (t) => SetTarget(
                      index: t.index,
                      side: t.side,
                      warmup: false,
                      load: t.load,
                      minReps: t.minReps,
                      maxReps: t.maxReps,
                      minRir: t.minRir,
                      maxRir: t.maxRir,
                      restSeconds: t.restSeconds,
                      rangeReference: range,
                    ),
                  )
                  .toList();
        slots.add(slot([...warmups, ...rangedWork]));
      }
    }
    final ready =
        slots.length == session.blocks.expand((b) => b.exercises).length;
    final snapshot = RecommendationSnapshot(
      schemaVersion: 2,
      generationReferences: {
        'bindings': bindings.version,
        'bindingReview': bindings.reviewReference,
        'warmup': warmupRuleVersion,
        'progression': 'owner-program-v1',
        'catalogSchema': input.eligibility.schemaVersion!,
        'taxonomy': input.eligibility.taxonomyVersion!,
        'eligibility': input.eligibility.eligibilityRuleSetVersion!,
        'constraints': input.eligibility.constraintSnapshotSha256!,
      },
      slotReasons: reasons,
      proposedLoads: ready
          ? {
              for (final p in proposals)
                p.slotId: p.result.candidateMicroPounds!,
            }
          : {},
      id: input.id,
      profile: input.profile,
      programId: generatedProgramId,
      programVersion: generatedProgramVersion,
      sessionTemplate: session.id,
      ruleVersion: sessionCompositionVersion,
      catalogVersion: input.eligibility.catalogVersion!,
      catalogDigest: bindings.catalogDigest,
      createdAt: input.createdAt,
      requestedDate: input.requestedDate,
      timezone: input.timezone,
      historyRevision: history.revision,
      inputRevisions: input.inputRevisions,
      evidence: evidence,
      status: ready ? RecommendationStatus.ready : RecommendationStatus.blocked,
      reasons: [
        ready ? 'session_ready' : 'session_setup_required',
        'duration_estimate_required',
        if (ready && proposals.isNotEmpty) 'load_change_confirmation_required',
      ],
      slots: ready ? slots : [],
      walkSeconds: ready ? WarmupPolicy.sessionWalkingSeconds : 0,
      preferredMinutes: setup.preferredMinutes!,
      estimatedSeconds: null,
    );
    return SessionCompositionResult._(
      ready ? 'session_ready' : 'session_setup_required',
      snapshot: snapshot,
      proposals: ready ? proposals : [],
      slotReasons: reasons,
    );
  }

  List<SessionRehearsalVerification> _rehearsals(
    SessionCompositionInput input,
  ) => [
    ...input.rehearsals,
    for (final r in input.setup!.rehearsalConfirmations)
      if (r.hasCompleteAttestation &&
          bindings.exerciseIds.containsKey(r.variation) &&
          input.setup!.equipment.any(
            (e) =>
                e.id == r.setupId &&
                e.confirmed &&
                e.revision == r.setupRevision &&
                !r.recordedAt.isBefore(e.confirmedAt!),
          ))
        SessionRehearsalVerification(
          setupRevision: r.setupRevision!,
          setup: VerifiedRehearsalSetup(
            context: (
              profileId: input.profile,
              slotId: '${r.sessionId}/${r.slotId}',
              exerciseId: bindings.exerciseIds[r.variation]!,
              setupId: r.setupId!,
              movement: switch (r.variation) {
                'assisted_machine_pull_up' => RehearsalMovement.assistedPullUp,
                'unassisted_pull_up' => RehearsalMovement.unassistedPullUp,
                'supported_knee_raise' => RehearsalMovement.supportedKneeRaise,
                _ => RehearsalMovement.kneelingRollout,
              },
            ),
            verificationRef: r.id,
            easyAndControlled: r.easyAndControlled,
            assistanceMicroPounds: r.assistance,
            availableAssistanceMicroPounds:
                r.variation == 'assisted_machine_pull_up'
                ? input.setup!.equipment
                      .singleWhere((e) => e.id == r.setupId)
                      .rehearsalLoads
                : null,
            workingRangeRef: r.workingRangeRef,
            rehearsalRangeRef: r.rehearsalRangeRef,
            rehearsalWithinWorkingRange: r.withinWorkingRange,
          ),
        ),
  ];

  RehearsalPlan? _bodyweight(
    SessionCompositionInput input,
    EquipmentSetup work,
    String slot,
    String exerciseId,
    List<String> eligible,
  ) {
    final setup = input.setup!;
    VerifiedRehearsalSetup? verified(
      String variant,
      RehearsalMovement movement, {
      String? exactSetup,
    }) {
      final id = bindings.exerciseIds[variant];
      if (id == null ||
          !eligible.contains(id) ||
          setup.excludedVariations.contains(variant)) {
        return null;
      }
      final matches = _rehearsals(input)
          .where(
            (v) =>
                v.setup.context.profileId == input.profile &&
                v.setup.context.slotId == '${input.sessionId}/$slot' &&
                v.setup.context.exerciseId == id &&
                v.setup.context.movement == movement &&
                (exactSetup == null || v.setup.context.setupId == exactSetup),
          )
          .toList();
      if (matches.length != 1) return null;
      final verification = matches.single;
      final r = verification.setup;
      final equipments = setup.equipment.where(
        (e) =>
            e.id == r.context.setupId &&
            e.variation == variant &&
            e.confirmed &&
            // A rehearsal verification pins the equipment revision explicitly.
            verification.setupRevision == e.revision,
      );
      if (equipments.length != 1) return null;
      final e = equipments.single;
      final entry = input.eligibility.catalog!.singleWhere((c) => c.id == id);
      if (entry.laterality != Laterality.bilateral ||
          !_matchesEquipment(entry, e, input.eligibility)) {
        return null;
      }
      if (movement == RehearsalMovement.assistedPullUp &&
          (!_same(r.availableAssistanceMicroPounds, e.rehearsalLoads) ||
              !e.rehearsalLoads.contains(r.assistanceMicroPounds))) {
        return null;
      }
      return r;
    }

    const policy = BodyweightWarmupPolicy();
    if (work.variation == 'unassisted_pull_up' ||
        work.variation == 'assisted_machine_pull_up') {
      final unassisted = work.variation == 'unassisted_pull_up';
      final assisted = verified(
        'assisted_machine_pull_up',
        RehearsalMovement.assistedPullUp,
        exactSetup: unassisted ? null : work.id,
      );
      final body = unassisted
          ? verified(
              'unassisted_pull_up',
              RehearsalMovement.unassistedPullUp,
              exactSetup: work.id,
            )
          : null;
      if (assisted == null || (unassisted && body == null)) return null;
      return policy.pullUps(
        gate: ProgressionGate.permitted,
        includesUnassistedWork: unassisted,
        assistedContext: assisted.context,
        assistedSetup: assisted,
        unassistedContext: body?.context,
        unassistedSetup: body,
      );
    }
    final movement = switch (work.variation) {
      'supported_knee_raise' => RehearsalMovement.supportedKneeRaise,
      'kneeling_ab_wheel' => RehearsalMovement.kneelingRollout,
      _ => null,
    };
    if (movement == null) return null;
    final body = verified(work.variation, movement, exactSetup: work.id);
    if (body == null) return null;
    return policy.core(
      gate: ProgressionGate.permitted,
      context: body.context,
      setup: body,
    );
  }
}

bool _same<T>(List<T>? a, List<T>? b) =>
    a != null && b != null && a.length == b.length && a.toSet().containsAll(b);
LoadConvention _convention(SetupLoadConvention c) => switch (c) {
  SetupLoadConvention.totalExternal => LoadConvention.totalLoad,
  _ => LoadConvention.values.byName(c.name),
};

// The guarded evaluator checks the whole inventory; this connects its reviewed
// equipment requirement to the exact private machine selected for the target.
bool _matchesEquipment(
  ExerciseCatalogEntry entry,
  EquipmentSetup equipment,
  ExerciseEligibilityRequest request,
) {
  if (entry.trackingMode !=
      (equipment.convention == SetupLoadConvention.bodyweight
          ? TrackingMode.repsOnly
          : TrackingMode.loadReps)) {
    return false;
  }
  if (equipment.equipmentId == null) return entry.equipmentRequirements.isEmpty;
  final requirements = entry.equipmentRequirements.where(
    (r) => r.equipmentId == equipment.equipmentId,
  );
  return requirements.isNotEmpty &&
      requirements.every(
        (r) =>
            equipment.quantity >= r.quantity &&
            equipment.capabilities.toSet().containsAll(r.capabilityIds),
      ) &&
      (request.equipmentInventory ?? []).any(
        (e) =>
            e.equipmentId == equipment.equipmentId &&
            e.quantity >= equipment.quantity &&
            e.capabilityIds.toSet().containsAll(equipment.capabilities),
      );
}
