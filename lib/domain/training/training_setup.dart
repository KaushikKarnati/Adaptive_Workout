import 'dart:convert';

import '../exercises/catalog/exercise_catalog_validator.dart';
import '../workout/owner_program.dart';
import 'setup_variations.dart';

part 'training_setup_intake.dart';

final class SetupException implements Exception {
  const SetupException(this.code);
  final String code;
  @override
  String toString() => code;
}

void requireSetup(bool valid, String code) {
  if (!valid) throw SetupException(code);
}

void validateSetupId(String value) => requireSetup(
  RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(value),
  'invalid_id',
);

int parsePounds(String text) {
  requireSetup(
    RegExp(r'^\d{1,7}(\.\d{1,6})?$').hasMatch(text.trim()),
    'invalid_pounds',
  );
  final parts = text.trim().split('.');
  final result =
      int.parse(parts[0]) * 1000000 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(6, '0')));
  requireSetup(result <= 1000000000000, 'invalid_pounds');
  return result;
}

String displayPounds(int value) {
  final whole = value ~/ 1000000;
  final fraction = (value % 1000000)
      .toString()
      .padLeft(6, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

List<T> _unique<T>(List<T> values, int maximum) {
  requireSetup(
    values.length <= maximum && values.toSet().length == values.length,
    'duplicate_or_excess_values',
  );
  return List.unmodifiable(values);
}

List<String>? _assessment(List<String>? values, Set<String> allowed) {
  if (values == null) return null;
  requireSetup(values.every(allowed.contains), 'unknown_taxonomy_id');
  return _unique(values, 32);
}

void _date(DateTime value) => requireSetup(
  value.isUtc && value.year >= 1 && value.year <= 9999,
  'invalid_time',
);

final class EquipmentSetup {
  EquipmentSetup({
    required this.id,
    required this.revision,
    required this.label,
    required this.variation,
    required this.equipmentId,
    required this.quantity,
    required List<String> capabilities,
    required this.convention,
    required List<int> workingLoads,
    required List<int> rehearsalLoads,
    required this.confirmedAt,
  }) : capabilities = _unique(capabilities, 8),
       workingLoads = _unique(workingLoads, 1000),
       rehearsalLoads = _unique(rehearsalLoads, 1000) {
    validateSetupId(id);
    requireSetup(revision >= 0 && revision <= 2147483647, 'invalid_revision');
    requireSetup(
      label.trim() == label &&
          label.isNotEmpty &&
          label.length <= 120 &&
          !RegExp(r'[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069<>]')
              .hasMatch(label),
      'invalid_label',
    );
    requireSetup(
      setupVariationNames.containsKey(variation) &&
          setupConventionsFor(variation).contains(convention),
      'invalid_variation_convention',
    );
    requireSetup(
      equipmentId == null ||
          ExerciseCatalogValidator.equipmentIds.contains(equipmentId),
      'unknown_equipment',
    );
    requireSetup(
      quantity >= 1 &&
          quantity <= 8 &&
          capabilities.every(
            ExerciseCatalogValidator.equipmentCapabilityIds.contains,
          ),
      'invalid_equipment',
    );
    requireSetup(
      workingLoads.every((v) => v > 0 && v <= 1000000000000) &&
          rehearsalLoads.every((v) => v >= 0 && v <= 1000000000000),
      'invalid_settings',
    );
    if (convention == SetupLoadConvention.bodyweight) {
      requireSetup(
        workingLoads.isEmpty && rehearsalLoads.isEmpty,
        'bodyweight_has_load',
      );
    } else if (confirmedAt != null) {
      requireSetup(workingLoads.isNotEmpty, 'working_settings_required');
    }
    if (convention == SetupLoadConvention.assistance) {
      requireSetup(!rehearsalLoads.contains(0), 'invalid_assistance');
    }
    if (confirmedAt != null) _date(confirmedAt!);
  }
  final String id, label, variation;
  final int revision, quantity;
  final String? equipmentId;
  final List<String> capabilities;
  final SetupLoadConvention convention;
  final List<int> workingLoads, rehearsalLoads;
  final DateTime? confirmedAt;
  bool get confirmed => confirmedAt != null;
  // Owner confirmation is independent of scientific/catalog approval.
  bool get recommendationEligible => false;
  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'label': label,
    'variation': variation,
    'equipmentId': equipmentId,
    'quantity': quantity,
    'capabilities': [...capabilities]..sort(),
    'convention': convention.name,
    'workingLoads': [...workingLoads]..sort(),
    'rehearsalLoads': [...rehearsalLoads]..sort(),
    'confirmedAt': confirmedAt?.toIso8601String(),
  };
  factory EquipmentSetup.fromJson(Map<String, dynamic> j) => EquipmentSetup(
    id: j['id'] as String,
    revision: j['revision'] as int,
    label: j['label'] as String,
    variation: j['variation'] as String,
    equipmentId: j['equipmentId'] as String?,
    quantity: j['quantity'] as int,
    capabilities: (j['capabilities'] as List).cast<String>(),
    convention: SetupLoadConvention.values.byName(j['convention'] as String),
    workingLoads: (j['workingLoads'] as List).cast<int>(),
    rehearsalLoads: (j['rehearsalLoads'] as List).cast<int>(),
    confirmedAt: j['confirmedAt'] == null
        ? null
        : DateTime.parse(j['confirmedAt'] as String),
  );
}

final class StartingLoad {
  StartingLoad({
    required this.id,
    required this.sessionId,
    required this.slotId,
    required this.variation,
    required this.setupId,
    required this.setupRevision,
    required this.convention,
    required this.microPounds,
    required this.confirmedAt,
  }) {
    validateSetupId(id);
    validateSetupId(setupId);
    _date(confirmedAt);
    requireSetup(
      setupRevision >= 0 && setupRevision <= 2147483647,
      'invalid_setup_revision',
    );
    final session = ownerProgram.where((s) => s.id == sessionId).firstOrNull;
    final exercise = session?.blocks
        .expand((b) => b.exercises)
        .where((e) => e.id == slotId)
        .firstOrNull;
    requireSetup(
      exercise != null &&
          setupVariantsFor(exercise).contains(variation) &&
          setupConventionsFor(variation).contains(convention),
      'invalid_slot_variation',
    );
    requireSetup(
      convention == SetupLoadConvention.bodyweight
          ? microPounds == null
          : microPounds != null &&
                microPounds! > 0 &&
                microPounds! <= 1000000000000,
      'invalid_starting_load',
    );
  }
  final String id, sessionId, slotId, variation, setupId;
  final int setupRevision;
  final SetupLoadConvention convention;
  final int? microPounds;
  final DateTime confirmedAt;
  bool get recommendationEligible => false;
  Map<String, Object?> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'slotId': slotId,
    'variation': variation,
    'setupId': setupId,
    'setupRevision': setupRevision,
    'convention': convention.name,
    'microPounds': microPounds,
    'confirmedAt': confirmedAt.toIso8601String(),
  };
  factory StartingLoad.fromJson(Map<String, dynamic> j) => StartingLoad(
    id: j['id'] as String,
    sessionId: j['sessionId'] as String,
    slotId: j['slotId'] as String,
    variation: j['variation'] as String,
    setupId: j['setupId'] as String,
    setupRevision: j['setupRevision'] as int,
    convention: SetupLoadConvention.values.byName(j['convention'] as String),
    microPounds: j['microPounds'] as int?,
    confirmedAt: DateTime.parse(j['confirmedAt'] as String),
  );
}

final class TrainingSetup {
  TrainingSetup({
    this.schemaVersion = 1,
    List<ReportedWorkingSetup> reportedWork = const [],
    List<RehearsalConfirmation> rehearsalConfirmations = const [],
    this.programVersion = ownerProgramVersion,
    required this.profileId,
    required this.revision,
    required this.updatedAt,
    required List<int> trainingDays,
    required this.preferredMinutes,
    required List<String>? supportedCapabilities,
    required List<String>? unsupportedCapabilities,
    required List<String>? limitations,
    required List<String> excludedVariations,
    required List<EquipmentSetup> equipment,
    required List<StartingLoad> startingLoads,
  }) : reportedWork = List.unmodifiable(reportedWork),
       rehearsalConfirmations = List.unmodifiable(rehearsalConfirmations),
       trainingDays = _unique(trainingDays, 7),
       supportedCapabilities = _assessment(
         supportedCapabilities,
         ExerciseCatalogValidator.functionalCapabilityIds,
       ),
       unsupportedCapabilities = _assessment(
         unsupportedCapabilities,
         ExerciseCatalogValidator.functionalCapabilityIds,
       ),
       limitations = _assessment(
         limitations,
         ExerciseCatalogValidator.limitationConflictIds,
       ),
       excludedVariations = _unique(excludedVariations, 25),
       equipment = List.unmodifiable(equipment),
       startingLoads = List.unmodifiable(startingLoads) {
    requireSetup(
      schemaVersion == 1 || schemaVersion == 2,
      'unsupported_setup_version',
    );
    requireSetup(
      schemaVersion == 2 ||
          (reportedWork.isEmpty && rehearsalConfirmations.isEmpty),
      'schema_two_required',
    );
    requireSetup(
      reportedWork.length <= 500 &&
          rehearsalConfirmations.length <= 500 &&
          reportedWork.map((r) => r.id).toSet().length == reportedWork.length &&
          rehearsalConfirmations.map((r) => r.id).toSet().length ==
              rehearsalConfirmations.length,
      'duplicate_or_excess_records',
    );
    for (final at in [
      ...reportedWork.map((r) => r.recordedAt),
      ...rehearsalConfirmations.map((r) => r.recordedAt),
    ]) {
      requireSetup(!at.isAfter(updatedAt), 'future_intake');
    }
    for (final r in rehearsalConfirmations.where((r) => r.setupId != null)) {
      final e = equipment.where((e) => e.id == r.setupId).firstOrNull;
      requireSetup(
        e != null &&
            e.variation == r.variation &&
            r.setupRevision! <= e.revision,
        'invalid_rehearsal_reference',
      );
    }
    requireSetup(supportsOwnerProgram(programVersion), 'unsupported_program');
    validateSetupId(profileId);
    _date(updatedAt);
    requireSetup(revision >= 0 && revision <= 2147483647, 'invalid_revision');
    requireSetup(
      trainingDays.every((d) => d >= 1 && d <= 7) &&
          (preferredMinutes == null ||
              preferredMinutes! > 0 && preferredMinutes! <= 2147483647),
      'invalid_preferences',
    );
    requireSetup(
      (supportedCapabilities == null) == (unsupportedCapabilities == null) &&
          !(supportedCapabilities ?? []).any(
            (unsupportedCapabilities ?? []).contains,
          ),
      'invalid_capabilities',
    );
    requireSetup(
      excludedVariations.every(setupVariationNames.containsKey),
      'unknown_exclusion',
    );
    requireSetup(
      equipment.length <= 100 &&
          equipment.map((e) => e.id).toSet().length == equipment.length &&
          startingLoads.length <= 500 &&
          startingLoads.map((e) => e.id).toSet().length == startingLoads.length,
      'duplicate_or_excess_records',
    );
    requireSetup(
      startingLoads
              .map(
                (b) => '${b.sessionId}/${b.slotId}/${b.variation}/${b.setupId}',
              )
              .toSet()
              .length ==
          startingLoads.length,
      'duplicate_baseline_context',
    );
    for (final e in equipment) {
      requireSetup(
        e.confirmedAt == null || !e.confirmedAt!.isAfter(updatedAt),
        'future_confirmation',
      );
    }
    for (final b in startingLoads) {
      final e = equipment.where((e) => e.id == b.setupId).firstOrNull;
      requireSetup(
        e != null &&
            e.variation == b.variation &&
            e.convention == b.convention &&
            b.setupRevision <= e.revision &&
            !b.confirmedAt.isAfter(updatedAt),
        'invalid_baseline_reference',
      );
      if (b.setupRevision == e!.revision) {
        requireSetup(
          e.confirmed &&
              !b.confirmedAt.isBefore(e.confirmedAt!) &&
              (b.microPounds == null || e.workingLoads.contains(b.microPounds)),
          'unverified_baseline',
        );
      }
    }
  }
  final int schemaVersion;
  final List<ReportedWorkingSetup> reportedWork;
  final List<RehearsalConfirmation> rehearsalConfirmations;
  final String profileId, programVersion;
  final int revision;
  final DateTime updatedAt;
  final List<int> trainingDays;
  final int? preferredMinutes;
  final List<String>? supportedCapabilities,
      unsupportedCapabilities,
      limitations;
  final List<String> excludedVariations;
  final List<EquipmentSetup> equipment;
  final List<StartingLoad> startingLoads;
  bool baselineIsCurrent(StartingLoad b) =>
      startingLoads.contains(b) &&
      equipment.any(
        (e) =>
            e.id == b.setupId && e.revision == b.setupRevision && e.confirmed,
      );
  bool get recommendationEligible => false;
  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    if (schemaVersion == 2) ...{
      'reportedWork': ([
        ...reportedWork,
      ]..sort((a, b) => a.id.compareTo(b.id))).map((r) => r.toJson()).toList(),
      'rehearsalConfirmations': ([
        ...rehearsalConfirmations,
      ]..sort((a, b) => a.id.compareTo(b.id))).map((r) => r.toJson()).toList(),
    },
    'programVersion': programVersion,
    'unit': 'lb',
    'profileId': profileId,
    'revision': revision,
    'updatedAt': updatedAt.toIso8601String(),
    'trainingDays': [...trainingDays]..sort(),
    'preferredMinutes': preferredMinutes,
    'supportedCapabilities': supportedCapabilities == null
        ? null
        : ([...supportedCapabilities!]..sort()),
    'unsupportedCapabilities': unsupportedCapabilities == null
        ? null
        : ([...unsupportedCapabilities!]..sort()),
    'limitations': limitations == null ? null : ([...limitations!]..sort()),
    'excludedVariations': [...excludedVariations]..sort(),
    'equipment': ([
      ...equipment,
    ]..sort((a, b) => a.id.compareTo(b.id))).map((e) => e.toJson()).toList(),
    'startingLoads': ([
      ...startingLoads,
    ]..sort((a, b) => a.id.compareTo(b.id))).map((e) => e.toJson()).toList(),
  };
  String encode() => jsonEncode(toJson());
  factory TrainingSetup.decode(String payload) {
    requireSetup(payload.length <= 2000000, 'payload_too_large');
    try {
      final j = jsonDecode(payload) as Map<String, dynamic>;
      requireSetup(
        (j['schema'] == 1 || j['schema'] == 2) &&
            j['programVersion'] is String &&
            supportsOwnerProgram(j['programVersion'] as String) &&
            j['unit'] == 'lb',
        'unsupported_setup_version_or_unit',
      );
      final result = TrainingSetup(
        schemaVersion: j['schema'] as int,
        reportedWork: j['schema'] == 2
            ? (j['reportedWork'] as List)
                  .map(
                    (r) => ReportedWorkingSetup.fromJson(
                      r as Map<String, dynamic>,
                    ),
                  )
                  .toList()
            : [],
        rehearsalConfirmations: j['schema'] == 2
            ? (j['rehearsalConfirmations'] as List)
                  .map(
                    (r) => RehearsalConfirmation.fromJson(
                      r as Map<String, dynamic>,
                    ),
                  )
                  .toList()
            : [],
        programVersion: j['programVersion'] as String,
        profileId: j['profileId'] as String,
        revision: j['revision'] as int,
        updatedAt: DateTime.parse(j['updatedAt'] as String),
        trainingDays: (j['trainingDays'] as List).cast<int>(),
        preferredMinutes: j['preferredMinutes'] as int?,
        supportedCapabilities: (j['supportedCapabilities'] as List?)
            ?.cast<String>(),
        unsupportedCapabilities: (j['unsupportedCapabilities'] as List?)
            ?.cast<String>(),
        limitations: (j['limitations'] as List?)?.cast<String>(),
        excludedVariations: (j['excludedVariations'] as List).cast<String>(),
        equipment: (j['equipment'] as List)
            .map((e) => EquipmentSetup.fromJson(e as Map<String, dynamic>))
            .toList(),
        startingLoads: (j['startingLoads'] as List)
            .map((e) => StartingLoad.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      requireSetup(result.encode() == payload, 'noncanonical_setup_payload');
      return result;
    } on SetupException {
      rethrow;
    } catch (_) {
      throw const SetupException('invalid_setup_payload');
    }
  }
}

abstract interface class TrainingSetupRepository {
  Future<TrainingSetup?> load(String profileId);
  Future<void> save(
    TrainingSetup setup, {
    required int expectedRevision,
    required String actionId,
  });
  Future<void> close();
}

/// Rejects silent setup changes and stale baseline confirmations before writing.
void validateSetupTransition(TrainingSetup? old, TrainingSetup next) {
  requireSetup(
    old == null
        ? next.revision == 0
        : next.profileId == old.profileId &&
              next.revision == old.revision + 1 &&
              !next.updatedAt.isBefore(old.updatedAt),
    'invalid_transition',
  );
  requireSetup(
    old == null || next.schemaVersion >= old.schemaVersion,
    'schema_downgrade',
  );
  for (final prior in old?.reportedWork ?? <ReportedWorkingSetup>[]) {
    requireSetup(
      next.reportedWork.any(
        (r) => jsonEncode(r.toJson()) == jsonEncode(prior.toJson()),
      ),
      'intake_history_changed',
    );
  }
  for (final prior
      in old?.rehearsalConfirmations ?? <RehearsalConfirmation>[]) {
    requireSetup(
      next.rehearsalConfirmations.any(
        (r) => jsonEncode(r.toJson()) == jsonEncode(prior.toJson()),
      ),
      'intake_history_changed',
    );
  }
  for (final r in next.rehearsalConfirmations.where(
    (r) => !(old?.rehearsalConfirmations.any((p) => p.id == r.id) ?? false),
  )) {
    if (r.setupId != null) {
      final e = next.equipment.singleWhere((e) => e.id == r.setupId);
      requireSetup(
        e.confirmed &&
            r.setupRevision == e.revision &&
            !r.recordedAt.isBefore(e.confirmedAt!),
        'stale_rehearsal_confirmation',
      );
    }
  }
  for (final prior in old?.equipment ?? <EquipmentSetup>[]) {
    requireSetup(
      next.equipment.any((e) => e.id == prior.id),
      'setup_removal_unsupported',
    );
  }
  for (final entry in next.equipment) {
    final prior = old?.equipment.where((e) => e.id == entry.id).firstOrNull;
    if (prior == null) {
      requireSetup(entry.revision == 0, 'invalid_setup_revision');
    } else if (jsonEncode(entry.toJson()) != jsonEncode(prior.toJson())) {
      requireSetup(
        entry.revision == prior.revision + 1 &&
            entry.variation == prior.variation &&
            entry.convention == prior.convention,
        'invalid_setup_change',
      );
      requireSetup(
        entry.confirmedAt == null ||
            !entry.confirmedAt!.isBefore(old!.updatedAt),
        'stale_confirmation',
      );
    }
  }
  for (final prior in old?.startingLoads ?? <StartingLoad>[]) {
    requireSetup(
      next.startingLoads.any((b) => b.id == prior.id),
      'baseline_removal_unsupported',
    );
  }
  for (final entry in next.startingLoads) {
    final prior = old?.startingLoads.where((b) => b.id == entry.id).firstOrNull;
    if (prior == null ||
        jsonEncode(prior.toJson()) != jsonEncode(entry.toJson())) {
      requireSetup(
        next.baselineIsCurrent(entry),
        'stale_baseline_confirmation',
      );
      requireSetup(
        old == null || !entry.confirmedAt.isBefore(old.updatedAt),
        'stale_confirmation',
      );
      if (prior != null) {
        requireSetup(
          entry.sessionId == prior.sessionId &&
              entry.slotId == prior.slotId &&
              entry.variation == prior.variation &&
              entry.setupId == prior.setupId,
          'baseline_context_changed',
        );
      }
    }
  }
}
