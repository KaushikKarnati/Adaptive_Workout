part of 'training_setup.dart';

void _intakeSlot(String sessionId, String slotId, String variation) {
  final session = ownerProgram.where((s) => s.id == sessionId).firstOrNull;
  final slot = session?.blocks
      .expand((b) => b.exercises)
      .where((e) => e.id == slotId)
      .firstOrNull;
  requireSetup(
    slot != null && setupVariantsFor(slot).contains(variation),
    'invalid_intake_context',
  );
}

void _bounded(int value, int max, [int min = 0]) =>
    requireSetup(value >= min && value <= max, 'invalid_intake_number');

enum ReportedLoadScope {
  perHand,
  stackDisplay,
  eachStack,
  totalAddedPlates,
  bodyweight,
}

/// A user's description of usual work, never a verified target or an exposure.
final class ReportedWorkingSetup {
  ReportedWorkingSetup({
    required this.id,
    required this.sourceReference,
    required this.recordedAt,
    required this.sessionId,
    required this.slotId,
    required this.variation,
    required this.convention,
    required this.load,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.minRir,
    required this.maxRir,
    required this.eachSide,
    this.loadIncrement,
    this.loadScope,
  }) {
    validateSetupId(id);
    validateSetupId(sourceReference);
    _date(recordedAt);
    _intakeSlot(sessionId, slotId, variation);
    requireSetup(
      setupConventionsFor(variation).contains(convention),
      'invalid_variation_convention',
    );
    requireSetup(
      convention == SetupLoadConvention.bodyweight
          ? load == null
          : load != null,
      'invalid_reported_load',
    );
    if (loadScope != null) {
      requireSetup(switch (convention) {
        SetupLoadConvention.perDumbbell =>
          loadScope == ReportedLoadScope.perHand,
        SetupLoadConvention.platesOnly =>
          loadScope == ReportedLoadScope.totalAddedPlates,
        SetupLoadConvention.bodyweight =>
          loadScope == ReportedLoadScope.bodyweight,
        SetupLoadConvention.machineSetting || SetupLoadConvention.assistance =>
          loadScope == ReportedLoadScope.stackDisplay ||
              loadScope == ReportedLoadScope.eachStack,
        _ => false,
      }, 'invalid_load_scope');
    }
    if (load != null) _bounded(load!, 1000000000000, 1);
    if (loadIncrement != null) _bounded(loadIncrement!, 1000000000000, 1);
    requireSetup(
      convention != SetupLoadConvention.bodyweight || loadIncrement == null,
      'bodyweight_has_load',
    );
    _bounded(sets, 1000, 1);
    requireSetup(
      (minReps == null) == (maxReps == null),
      'invalid_reported_reps',
    );
    if (minReps != null) {
      _bounded(minReps!, 10000, 1);
      _bounded(maxReps!, 10000, minReps!);
    }
    requireSetup(
      (minRir == null) == (maxRir == null),
      'invalid_reported_effort',
    );
    if (minRir != null) {
      _bounded(minRir!, 10000);
      _bounded(maxRir!, 10000, minRir!);
    }
  }
  final String id, sourceReference, sessionId, slotId, variation;

  /// Time recorded, not a claimed workout or verification time.
  final DateTime recordedAt;
  final SetupLoadConvention convention;
  final ReportedLoadScope? loadScope;
  final int? load, loadIncrement, minRir, maxRir, minReps, maxReps;
  final int sets;
  final bool eachSide;
  bool get recommendationEligible => false;
  Map<String, Object?> toJson() => {
    'id': id,
    'sourceReference': sourceReference,
    'recordedAt': recordedAt.toIso8601String(),
    'sessionId': sessionId,
    'slotId': slotId,
    'variation': variation,
    'convention': convention.name,
    'load': load,
    'loadScope': loadScope?.name,
    'loadIncrement': loadIncrement,
    'sets': sets,
    'minReps': minReps,
    'maxReps': maxReps,
    'minRir': minRir,
    'maxRir': maxRir,
    'eachSide': eachSide,
  };
  factory ReportedWorkingSetup.fromJson(Map<String, dynamic> j) =>
      ReportedWorkingSetup(
        id: j['id'] as String,
        sourceReference: j['sourceReference'] as String,
        recordedAt: DateTime.parse(j['recordedAt'] as String),
        sessionId: j['sessionId'] as String,
        slotId: j['slotId'] as String,
        variation: j['variation'] as String,
        convention: SetupLoadConvention.values.byName(
          j['convention'] as String,
        ),
        load: j['load'] as int?,
        loadScope: j['loadScope'] == null
            ? null
            : ReportedLoadScope.values.byName(j['loadScope'] as String),
        loadIncrement: j['loadIncrement'] as int?,
        sets: j['sets'] as int,
        minReps: j['minReps'] as int?,
        maxReps: j['maxReps'] as int?,
        minRir: j['minRir'] as int?,
        maxRir: j['maxRir'] as int?,
        eachSide: j['eachSide'] as bool,
      );
}

/// Immutable owner attestation. An absent exact setup link stays a draft.
/// It cannot clear safety restrictions or verify a working baseline.
final class RehearsalConfirmation {
  RehearsalConfirmation({
    required this.id,
    required this.sourceReference,
    required this.recordedAt,
    required this.sessionId,
    required this.slotId,
    required this.variation,
    required this.easyAndControlled,
    required this.symptomsReported,
    this.setupId,
    this.setupRevision,
    this.assistance,
    this.workingRangeRef,
    this.rehearsalRangeRef,
    this.withinWorkingRange,
  }) {
    validateSetupId(id);
    validateSetupId(sourceReference);
    _date(recordedAt);
    _intakeSlot(sessionId, slotId, variation);
    requireSetup(
      const [
        'assisted_machine_pull_up',
        'unassisted_pull_up',
        'supported_knee_raise',
        'kneeling_ab_wheel',
      ].contains(variation),
      'unsupported_rehearsal',
    );
    requireSetup(
      (setupId == null) == (setupRevision == null),
      'incomplete_setup_reference',
    );
    if (setupId != null) {
      validateSetupId(setupId!);
      _bounded(setupRevision!, 2147483647);
    }
    if (assistance != null) _bounded(assistance!, 1000000000000, 1);
    for (final range in [workingRangeRef, rehearsalRangeRef]) {
      if (range != null) validateSetupId(range);
    }
    if (variation == 'assisted_machine_pull_up') {
      requireSetup(
        workingRangeRef == null &&
            rehearsalRangeRef == null &&
            withinWorkingRange == null,
        'invalid_rehearsal_range',
      );
    } else {
      requireSetup(assistance == null, 'invalid_assistance');
      if (variation == 'unassisted_pull_up') {
        requireSetup(
          workingRangeRef == null &&
              rehearsalRangeRef == null &&
              withinWorkingRange == null,
          'invalid_rehearsal_range',
        );
      }
    }
    requireSetup(
      withinWorkingRange != true ||
          (workingRangeRef != null && rehearsalRangeRef != null),
      'range_required',
    );
  }
  final String id, sourceReference, sessionId, slotId, variation;
  final DateTime recordedAt;
  final String? setupId, workingRangeRef, rehearsalRangeRef;
  final int? setupRevision, assistance;
  final bool? easyAndControlled, symptomsReported, withinWorkingRange;
  bool get hasCompleteAttestation =>
      easyAndControlled == true &&
      symptomsReported == false &&
      setupId != null &&
      switch (variation) {
        'assisted_machine_pull_up' => assistance != null,
        'unassisted_pull_up' => true,
        'supported_knee_raise' =>
          withinWorkingRange == true && workingRangeRef == rehearsalRangeRef,
        _ => withinWorkingRange == true,
      };
  Map<String, Object?> toJson() => {
    'id': id,
    'sourceReference': sourceReference,
    'recordedAt': recordedAt.toIso8601String(),
    'sessionId': sessionId,
    'slotId': slotId,
    'variation': variation,
    'setupId': setupId,
    'setupRevision': setupRevision,
    'easyAndControlled': easyAndControlled,
    'symptomsReported': symptomsReported,
    'assistance': assistance,
    'workingRangeRef': workingRangeRef,
    'rehearsalRangeRef': rehearsalRangeRef,
    'withinWorkingRange': withinWorkingRange,
  };
  factory RehearsalConfirmation.fromJson(Map<String, dynamic> j) =>
      RehearsalConfirmation(
        id: j['id'] as String,
        sourceReference: j['sourceReference'] as String,
        recordedAt: DateTime.parse(j['recordedAt'] as String),
        sessionId: j['sessionId'] as String,
        slotId: j['slotId'] as String,
        variation: j['variation'] as String,
        setupId: j['setupId'] as String?,
        setupRevision: j['setupRevision'] as int?,
        easyAndControlled: j['easyAndControlled'] as bool?,
        symptomsReported: j['symptomsReported'] as bool?,
        assistance: j['assistance'] as int?,
        workingRangeRef: j['workingRangeRef'] as String?,
        rehearsalRangeRef: j['rehearsalRangeRef'] as String?,
        withinWorkingRange: j['withinWorkingRange'] as bool?,
      );
}
