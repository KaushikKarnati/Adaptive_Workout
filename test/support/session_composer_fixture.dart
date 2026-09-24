import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog_manifest_validator.dart';
import 'package:adaptive_workout/domain/exercises/eligibility/exercise_eligibility.dart';
import 'package:adaptive_workout/domain/recommendations/recommendation_history.dart';
import 'package:adaptive_workout/domain/training/setup_variations.dart';
import 'package:adaptive_workout/domain/training/training_setup.dart';
import 'package:adaptive_workout/domain/workout/owner_program.dart';
import 'package:adaptive_workout/domain/workout/session_composer.dart';
import 'package:adaptive_workout/domain/workout/warmup_policy_v2.dart';

import 'session_catalog_fixture.dart';

final fixtureAt = DateTime.utc(2026, 9, 26);

class ComposerFixture {
  ComposerFixture(
    this.sessionId, {
    this.excluded = const [],
    this.missing = const [],
    this.reverse = false,
    this.stop = false,
    this.disabled = false,
    this.missingRehearsal = false,
    this.rehearsalLoads = const [0, 50000000, 75000000],
    this.history,
    this.setupRevision = 0,
    this.preferredMinutes = 60,
    this.assistedOnly = false,
    this.requireCatalogEquipment = false,
  }) {
    final variants = setupVariationNames.keys.toList();
    entries = [
      for (var i = 0; i < variants.length; i++)
        syntheticEntry(
          seed: i + 1,
          equipmentRequirements: requireCatalogEquipment
              ? const [
                  EquipmentRequirement(equipmentId: 'dumbbells', quantity: 2),
                ]
              : const [],
          availability: disabled
              ? ExerciseAvailability.disabled
              : ExerciseAvailability.enabled,
          disabledReason: disabled ? 'Synthetic disabled test' : null,
          laterality: variants[i] == 'single_arm_cable_pulldown'
              ? Laterality.unilateral
              : Laterality.bilateral,
          trackingMode:
              setupConventionsFor(variants[i]).singleOrNull ==
                  SetupLoadConvention.bodyweight
              ? TrackingMode.repsOnly
              : TrackingMode.loadReps,
        ),
    ];
    bindings = ProgramCatalogBindings(
      version: 'synthetic-bindings-v2',
      reviewReference: 'synthetic-review',
      catalogDigest: syntheticManifest(entries).contentSha256,
      exerciseIds: {
        for (var i = 0; i < variants.length; i++) variants[i]: entries[i].id,
      },
    );
    composer = SessionComposer(
      bindings: bindings,
      evaluator: ExerciseEligibilityEvaluator(
        catalogValidator: ExerciseCatalogManifestValidator(
          importedAt: DateTime.utc(2026, 9, 8, 13),
        ),
      ),
    );
  }
  final bool requireCatalogEquipment;
  final String sessionId;
  final List<String> excluded, missing;
  final bool reverse, stop, disabled, missingRehearsal, assistedOnly;
  final List<int> rehearsalLoads;
  final GeneratedHistory? history;
  final int setupRevision, preferredMinutes;
  late final List<ExerciseCatalogEntry> entries;
  late final ProgramCatalogBindings bindings;
  late final SessionComposer composer;
  SessionCompositionInput input({
    String id = 'generated',
    int? revisionOverride,
    DateTime? at,
  }) {
    final session = ownerProgram.singleWhere((s) => s.id == sessionId);
    final equipment = <EquipmentSetup>[];
    final baselines = <StartingLoad>[];
    final rehearsals = <SessionRehearsalVerification>[];
    for (final variant in setupVariationNames.keys) {
      if (missing.contains(variant)) continue;
      final convention = setupConventionsFor(variant).first;
      equipment.add(
        EquipmentSetup(
          id: variant,
          revision: setupRevision,
          label: 'Synthetic station',
          variation: variant,
          equipmentId: null,
          quantity: 1,
          capabilities: [],
          convention: convention,
          workingLoads: convention == SetupLoadConvention.bodyweight
              ? []
              : [90000000, 100000000, 105000000],
          rehearsalLoads: convention == SetupLoadConvention.bodyweight
              ? []
              : convention == SetupLoadConvention.assistance
              ? [70000000]
              : rehearsalLoads,
          confirmedAt: fixtureAt,
        ),
      );
    }
    for (final exercise in session.blocks.expand((b) => b.exercises)) {
      for (final variant in setupVariantsFor(exercise)) {
        if (missing.contains(variant)) continue;
        final convention = setupConventionsFor(variant).first;
        baselines.add(
          StartingLoad(
            id: '${exercise.id}_$variant',
            sessionId: sessionId,
            slotId: exercise.id,
            variation: variant,
            setupId: variant,
            setupRevision: setupRevision,
            convention: convention,
            microPounds: convention == SetupLoadConvention.bodyweight
                ? null
                : 100000000,
            confirmedAt: fixtureAt,
          ),
        );
      }
      for (final variant in [
        'unassisted_pull_up',
        'assisted_machine_pull_up',
        'supported_knee_raise',
        'kneeling_ab_wheel',
      ]) {
        if (missing.contains(variant) || missingRehearsal) continue;
        final movement = switch (variant) {
          'unassisted_pull_up' => RehearsalMovement.unassistedPullUp,
          'assisted_machine_pull_up' => RehearsalMovement.assistedPullUp,
          'supported_knee_raise' => RehearsalMovement.supportedKneeRaise,
          _ => RehearsalMovement.kneelingRollout,
        };
        final core =
            movement == RehearsalMovement.supportedKneeRaise ||
            movement == RehearsalMovement.kneelingRollout;
        rehearsals.add(
          SessionRehearsalVerification(
            setupRevision: setupRevision,
            setup: VerifiedRehearsalSetup(
              context: (
                profileId: 'fixture',
                slotId: '$sessionId/${exercise.id}',
                exerciseId: bindings.exerciseIds[variant]!,
                setupId: variant,
                movement: movement,
              ),
              verificationRef: 'synthetic_rehearsal',
              easyAndControlled: true,
              assistanceMicroPounds:
                  movement == RehearsalMovement.assistedPullUp
                  ? 70000000
                  : null,
              availableAssistanceMicroPounds:
                  movement == RehearsalMovement.assistedPullUp
                  ? [70000000]
                  : null,
              workingRangeRef: core ? 'range' : null,
              rehearsalRangeRef: core ? 'range' : null,
              rehearsalWithinWorkingRange: core ? true : null,
            ),
          ),
        );
      }
    }
    final setup = TrainingSetup(
      profileId: 'fixture',
      revision: setupRevision,
      updatedAt: fixtureAt,
      trainingDays: [1, 2, 3, 4, 5],
      preferredMinutes: preferredMinutes,
      supportedCapabilities: [],
      unsupportedCapabilities: [],
      limitations: [],
      excludedVariations: [...excluded, if (assistedOnly) 'unassisted_pull_up'],
      equipment: reverse ? equipment.reversed.toList() : equipment,
      startingLoads: reverse ? baselines.reversed.toList() : baselines,
    );
    return SessionCompositionInput(
      id: id,
      profile: 'fixture',
      sessionId: sessionId,
      createdAt: at ?? fixtureAt,
      requestedDate: fixtureAt,
      timezone: 'America/Chicago',
      setup: setup,
      history:
          history ??
          GeneratedHistory(
            profile: 'fixture',
            revision: 0,
            recommendations: [],
            occurrences: [],
          ),
      eligibility: syntheticEligibility(
        reverse ? entries.reversed.toList() : entries,
        inventory: requireCatalogEquipment
            ? [EquipmentInventoryItem(equipmentId: 'dumbbells', quantity: 2)]
            : [],
        safetyState: stop
            ? EligibilitySafetyState(
                version: '1.0.0',
                kind: EligibilitySafetyStateKind.stop,
                affectedExerciseId: entries.first.id,
              )
            : null,
      ),
      inputRevisions: {
        'profile': revisionOverride ?? setupRevision,
        'equipment': setupRevision,
        'baseline': setupRevision,
        'constraints': setupRevision,
        'safety': 0,
        'catalogSchema': 1,
        'taxonomy': 2,
      },
      rehearsals: reverse ? rehearsals.reversed.toList() : rehearsals,
    );
  }
}
