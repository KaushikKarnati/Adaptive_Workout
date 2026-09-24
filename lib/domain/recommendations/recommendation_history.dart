import 'dart:convert';

import '../logging/practice_repository.dart';
import '../logging/program_log.dart';
import '../progression/load_progression_policy.dart';

void checkHistory(bool ok, String reason) {
  if (!ok) throw LoggingException(reason);
}

void _id(String value) => validateStorageId(value);
void _reference(String value) => checkHistory(
  RegExp(r'^[a-zA-Z0-9_.:/-]{1,128}$').hasMatch(value),
  'invalid_reference',
);
void _number(int value, int max, [int min = 0]) =>
    checkHistory(value >= min && value <= max, 'invalid_number');
void _utc(DateTime value) => checkHistory(value.isUtc, 'utc_required');
Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

/// Exact rehearsal identity when it differs from the working slot (schema 2).
final class RehearsalIdentity {
  RehearsalIdentity({
    required this.exerciseId,
    required this.setupId,
    required this.setupRevision,
    required this.convention,
    required this.verificationReference,
  }) {
    for (final v in [exerciseId, setupId, verificationReference]) {
      _id(v);
    }
    _number(setupRevision, 2147483647);
  }
  final String exerciseId, setupId, verificationReference;
  final int setupRevision;
  final LoadConvention convention;
  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    'setupId': setupId,
    'setupRevision': setupRevision,
    'convention': convention.name,
    'verificationReference': verificationReference,
  };
  factory RehearsalIdentity.fromJson(Map<String, dynamic> j) =>
      RehearsalIdentity(
        exerciseId: j['exerciseId'] as String,
        setupId: j['setupId'] as String,
        setupRevision: j['setupRevision'] as int,
        convention: LoadConvention.values.byName(j['convention'] as String),
        verificationReference: j['verificationReference'] as String,
      );
}

/// Immutable target: load is null only for bodyweight. Range references describe
/// verified bodyweight rehearsal range without inventing a numeric resistance.
final class SetTarget {
  SetTarget({
    required this.index,
    required this.side,
    required this.warmup,
    required this.load,
    required this.minReps,
    required this.maxReps,
    required this.minRir,
    required this.maxRir,
    required this.restSeconds,
    this.rangeReference,
    this.rehearsalIdentity,
  }) {
    _number(index, 1000, 1);
    _number(minReps, 10000, 1);
    _number(maxReps, 10000, minReps);
    checkHistory((minRir == null) == (maxRir == null), 'invalid_effort');
    checkHistory(warmup || minRir != null, 'working_effort_required');
    if (minRir != null) {
      _number(minRir!, 10000);
      _number(maxRir!, 10000, minRir!);
    }
    checkHistory(
      warmup || rehearsalIdentity == null,
      'working_identity_override',
    );
    _number(restSeconds, 86400);
    if (load != null) _number(load!, 1000000000000);
    if (rangeReference != null) _id(rangeReference!);
  }
  final int index, minReps, maxReps, restSeconds;
  final int? minRir, maxRir;
  final RehearsalIdentity? rehearsalIdentity;
  final LoggedSide side;
  final bool warmup;
  final int? load;
  final String? rangeReference;
  String get key => '${warmup ? 'warmup' : 'work'}_${index}_${side.name}';
  Map<String, Object?> toJson() => {
    'index': index,
    'side': side.name,
    'warmup': warmup,
    'load': load,
    'minReps': minReps,
    'maxReps': maxReps,
    'minRir': minRir,
    'maxRir': maxRir,
    'restSeconds': restSeconds,
    'rangeReference': rangeReference,
    if (rehearsalIdentity != null)
      'rehearsalIdentity': rehearsalIdentity!.toJson(),
  };
  factory SetTarget.fromJson(Map<String, dynamic> j) => SetTarget(
    index: j['index'] as int,
    side: LoggedSide.values.byName(j['side'] as String),
    warmup: j['warmup'] as bool,
    load: j['load'] as int?,
    minReps: j['minReps'] as int,
    maxReps: j['maxReps'] as int,
    minRir: j['minRir'] as int?,
    maxRir: j['maxRir'] as int?,
    restSeconds: j['restSeconds'] as int,
    rangeReference: j['rangeReference'] as String?,
    rehearsalIdentity: j['rehearsalIdentity'] == null
        ? null
        : RehearsalIdentity.fromJson(_map(j['rehearsalIdentity'])),
  );
}

final class RecommendedSlot {
  RecommendedSlot({
    required this.id,
    required this.exerciseId,
    required this.blockId,
    required this.setupId,
    required this.setupRevision,
    required this.baselineReference,
    required this.convention,
    required this.unilateral,
    required List<SetTarget> targets,
  }) : targets = List.unmodifiable(targets) {
    for (final value in [id, exerciseId, blockId, setupId, baselineReference]) {
      _id(value);
    }
    _number(setupRevision, 2147483647);
    checkHistory(
      targets.isNotEmpty && targets.length <= 1000,
      'invalid_targets',
    );
    checkHistory(
      targets.map((t) => t.key).toSet().length == targets.length,
      'duplicate_target',
    );
    final work = targets.where((t) => !t.warmup).toList();
    checkHistory(work.isNotEmpty, 'working_targets_required');
    for (final t in targets) {
      final targetConvention = t.rehearsalIdentity?.convention ?? convention;
      checkHistory(
        unilateral ? t.side != LoggedSide.both : t.side == LoggedSide.both,
        'invalid_side',
      );
      checkHistory(
        targetConvention == LoadConvention.bodyweight
            ? t.load == null
            : t.load != null,
        'invalid_load',
      );
      if (targetConvention != LoadConvention.bodyweight) {
        checkHistory(
          t.load! > 0 ||
              (t.warmup && targetConvention != LoadConvention.assistance),
          'invalid_load',
        );
      }
    }
    final sides = unilateral
        ? [LoggedSide.left, LoggedSide.right]
        : [LoggedSide.both];
    final count = work.length ~/ sides.length;
    checkHistory(count * sides.length == work.length, 'invalid_working_sets');
    for (var i = 1; i <= count; i++) {
      for (final side in sides) {
        checkHistory(
          work.any((t) => t.index == i && t.side == side),
          'missing_working_target',
        );
      }
    }
    // Existing progression requires a uniform working prescription per slot.
    checkHistory(
      work.every(
        (t) =>
            t.minReps == work.first.minReps &&
            t.maxReps == work.first.maxReps &&
            t.load == work.first.load,
      ),
      'mixed_working_prescription',
    );
  }
  final String id, exerciseId, blockId, setupId, baselineReference;
  final int setupRevision;
  final LoadConvention convention;
  final bool unilateral;
  final List<SetTarget> targets;
  Map<String, Object?> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'blockId': blockId,
    'setupId': setupId,
    'setupRevision': setupRevision,
    'baselineReference': baselineReference,
    'convention': convention.name,
    'unilateral': unilateral,
    'targets': targets.map((t) => t.toJson()).toList(),
  };
  factory RecommendedSlot.fromJson(Map<String, dynamic> j) => RecommendedSlot(
    id: j['id'] as String,
    exerciseId: j['exerciseId'] as String,
    blockId: j['blockId'] as String,
    setupId: j['setupId'] as String,
    setupRevision: j['setupRevision'] as int,
    baselineReference: j['baselineReference'] as String,
    convention: LoadConvention.values.byName(j['convention'] as String),
    unilateral: j['unilateral'] as bool,
    targets: (j['targets'] as List)
        .map((t) => SetTarget.fromJson(_map(t)))
        .toList(),
  );
}

enum RecommendationStatus { ready, blocked }

final class RecommendationSnapshot {
  RecommendationSnapshot({
    this.schemaVersion = 1,
    Map<String, String> generationReferences = const {},
    Map<String, String> slotReasons = const {},
    Map<String, int> proposedLoads = const {},
    required this.id,
    required this.profile,
    required this.programId,
    required this.programVersion,
    required this.sessionTemplate,
    required this.ruleVersion,
    required this.catalogVersion,
    required this.catalogDigest,
    required this.createdAt,
    required this.requestedDate,
    required this.timezone,
    required this.historyRevision,
    required Map<String, int> inputRevisions,
    required Map<String, int> evidence,
    required this.status,
    required List<String> reasons,
    required List<RecommendedSlot> slots,
    required this.walkSeconds,
    required this.preferredMinutes,
    required this.estimatedSeconds,
  }) : generationReferences = Map.unmodifiable(generationReferences),
       slotReasons = Map.unmodifiable(slotReasons),
       proposedLoads = Map.unmodifiable(proposedLoads),
       inputRevisions = Map.unmodifiable(inputRevisions),
       evidence = Map.unmodifiable(evidence),
       reasons = List.unmodifiable(reasons),
       slots = List.unmodifiable(slots) {
    checkHistory(
      schemaVersion == 1 || schemaVersion == 2,
      'unsupported_snapshot',
    );
    checkHistory(
      generationReferences.length <= 20 &&
          slotReasons.length <= 100 &&
          proposedLoads.length <= 100,
      'too_many_references',
    );
    for (final e in [...generationReferences.entries, ...slotReasons.entries]) {
      _id(e.key);
      _reference(e.value);
    }
    for (final e in proposedLoads.entries) {
      _id(e.key);
      _number(e.value, 1000000000000, 1);
      checkHistory(
        status == RecommendationStatus.ready &&
            slots.any(
              (s) =>
                  s.id == e.key &&
                  s.convention != LoadConvention.bodyweight &&
                  s.convention != LoadConvention.assistance,
            ),
        'invalid_proposal',
      );
    }
    checkHistory(
      schemaVersion == 2 ||
          (generationReferences.isEmpty &&
              slotReasons.isEmpty &&
              proposedLoads.isEmpty),
      'schema_two_required',
    );
    if (schemaVersion == 1) {
      checkHistory(
        slots
            .expand((s) => s.targets)
            .every((t) => t.minRir != null && t.rehearsalIdentity == null),
        'schema_two_required',
      );
    }
    for (final value in [id, profile, programId, sessionTemplate]) {
      _id(value);
    }
    for (final value in [programVersion, ruleVersion, catalogVersion]) {
      _reference(value);
    }
    checkHistory(
      RegExp(r'^[a-f0-9]{64}$').hasMatch(catalogDigest),
      'invalid_catalog_digest',
    );
    _utc(createdAt);
    _utc(requestedDate);
    checkHistory(
      requestedDate ==
          DateTime.utc(
            requestedDate.year,
            requestedDate.month,
            requestedDate.day,
          ),
      'invalid_civil_date',
    );
    checkHistory(
      timezone.isNotEmpty && timezone.length <= 128,
      'invalid_timezone',
    );
    _number(historyRevision, 2147483647);
    _number(walkSeconds, 86400);
    _number(preferredMinutes, 2147483647, 1);
    if (estimatedSeconds != null) _number(estimatedSeconds!, 2147483647);
    checkHistory(
      inputRevisions.keys.toSet().containsAll([
        'profile',
        'equipment',
        'baseline',
        'constraints',
        'safety',
        'catalogSchema',
        'taxonomy',
      ]),
      'missing_input_references',
    );
    checkHistory(
      inputRevisions.length <= 100 && evidence.length <= 10000,
      'too_many_references',
    );
    for (final entry in [...inputRevisions.entries, ...evidence.entries]) {
      _id(entry.key);
      _number(entry.value, 2147483647);
    }
    checkHistory(
      reasons.isNotEmpty &&
          reasons.length <= 100 &&
          reasons.toSet().length == reasons.length,
      'invalid_reasons',
    );
    for (final reason in reasons) {
      _id(reason);
    }
    checkHistory(
      slots.length <= 100 &&
          slots.map((s) => s.id).toSet().length == slots.length,
      'invalid_slots',
    );
    checkHistory(
      status == RecommendationStatus.ready ? slots.isNotEmpty : slots.isEmpty,
      'invalid_status_targets',
    );
  }
  final Map<String, String> generationReferences, slotReasons;
  final Map<String, int> proposedLoads;
  final int schemaVersion;
  final String id,
      profile,
      programId,
      programVersion,
      sessionTemplate,
      ruleVersion,
      catalogVersion,
      catalogDigest,
      timezone;
  final DateTime createdAt, requestedDate;
  final int historyRevision, walkSeconds, preferredMinutes;
  final int? estimatedSeconds;
  final Map<String, int> inputRevisions, evidence;
  final RecommendationStatus status;
  final List<String> reasons;
  final List<RecommendedSlot> slots;
  Map<String, Object?> toJson() => {
    'schema': schemaVersion,
    if (schemaVersion == 2) ...{
      'generationReferences': {
        for (final k in generationReferences.keys.toList()..sort())
          k: generationReferences[k],
      },
      'slotReasons': {
        for (final k in slotReasons.keys.toList()..sort()) k: slotReasons[k],
      },
      'proposedLoads': _sorted(proposedLoads),
    },
    'unit': 'lb',
    'id': id,
    'profile': profile,
    'programId': programId,
    'programVersion': programVersion,
    'sessionTemplate': sessionTemplate,
    'ruleVersion': ruleVersion,
    'catalogVersion': catalogVersion,
    'catalogDigest': catalogDigest,
    'createdAt': createdAt.toIso8601String(),
    'requestedDate': requestedDate.toIso8601String(),
    'timezone': timezone,
    'historyRevision': historyRevision,
    'inputRevisions': _sorted(inputRevisions),
    'evidence': _sorted(evidence),
    'status': status.name,
    'reasons': reasons,
    'slots': slots.map((s) => s.toJson()).toList(),
    'walkSeconds': walkSeconds,
    'preferredMinutes': preferredMinutes,
    'estimatedSeconds': estimatedSeconds,
  };
  String encode() => jsonEncode(toJson());
  factory RecommendationSnapshot.decode(String payload) {
    final j = _decode(payload, recommendation: true);
    if (j['schema'] == 2) {
      checkHistory(
        j['generationReferences'] is Map &&
            j['slotReasons'] is Map &&
            j['proposedLoads'] is Map,
        'invalid_generation_metadata',
      );
    }
    final r = RecommendationSnapshot(
      schemaVersion: j['schema'] as int,
      generationReferences: j['schema'] == 2
          ? Map<String, String>.from(j['generationReferences'] as Map)
          : const {},
      slotReasons: j['schema'] == 2
          ? Map<String, String>.from(j['slotReasons'] as Map)
          : const {},
      proposedLoads: j['schema'] == 2
          ? Map<String, int>.from(j['proposedLoads'] as Map)
          : const {},
      id: j['id'] as String,
      profile: j['profile'] as String,
      programId: j['programId'] as String,
      programVersion: j['programVersion'] as String,
      sessionTemplate: j['sessionTemplate'] as String,
      ruleVersion: j['ruleVersion'] as String,
      catalogVersion: j['catalogVersion'] as String,
      catalogDigest: j['catalogDigest'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      requestedDate: DateTime.parse(j['requestedDate'] as String),
      timezone: j['timezone'] as String,
      historyRevision: j['historyRevision'] as int,
      inputRevisions: Map<String, int>.from(j['inputRevisions'] as Map),
      evidence: Map<String, int>.from(j['evidence'] as Map),
      status: RecommendationStatus.values.byName(j['status'] as String),
      reasons: List<String>.from(j['reasons'] as List),
      slots: (j['slots'] as List)
          .map((s) => RecommendedSlot.fromJson(_map(s)))
          .toList(),
      walkSeconds: j['walkSeconds'] as int,
      preferredMinutes: j['preferredMinutes'] as int,
      estimatedSeconds: j['estimatedSeconds'] as int?,
    );
    checkHistory(r.encode() == payload, 'noncanonical_snapshot');
    return r;
  }
}

Map<String, int> _sorted(Map<String, int> source) => {
  for (final k in source.keys.toList()..sort()) k: source[k]!,
};
Map<String, dynamic> _decode(String payload, {bool recommendation = false}) {
  checkHistory(payload.length <= 2000000, 'payload_too_large');
  final j = _map(jsonDecode(payload));
  checkHistory(
    (j['schema'] == 1 || (recommendation && j['schema'] == 2)) &&
        j['unit'] == 'lb',
    'unsupported_snapshot',
  );
  return j;
}

enum OccurrenceStatus { active, completed, endedEarly }

final class GeneratedOccurrence {
  GeneratedOccurrence({
    required this.id,
    required this.profile,
    required this.recommendationId,
    required this.sequence,
    required this.revision,
    required this.startedAt,
    required this.updatedAt,
    required this.endedAt,
    required this.status,
    required List<ProgramSet> sets,
    required List<String> stoppedSlots,
  }) : sets = List.unmodifiable(sets),
       stoppedSlots = List.unmodifiable(stoppedSlots) {
    for (final v in [id, profile, recommendationId]) {
      _id(v);
    }
    _number(sequence, 2147483647);
    _number(revision, 2147483647);
    _utc(startedAt);
    _utc(updatedAt);
    checkHistory(!updatedAt.isBefore(startedAt), 'invalid_time');
    checkHistory(
      (status == OccurrenceStatus.active) == (endedAt == null),
      'invalid_terminal_state',
    );
    if (endedAt != null) {
      _utc(endedAt!);
      checkHistory(
        !endedAt!.isBefore(startedAt) && !updatedAt.isBefore(endedAt!),
        'invalid_time',
      );
    }
    checkHistory(
      sets.length <= 100000 &&
          sets.map((s) => s.key).toSet().length == sets.length,
      'duplicate_actual',
    );
    checkHistory(
      stoppedSlots.toSet().length == stoppedSlots.length,
      'duplicate_stop',
    );
  }
  final String id, profile, recommendationId;
  final int sequence, revision;
  final DateTime startedAt, updatedAt;
  final DateTime? endedAt;
  final OccurrenceStatus status;
  final List<ProgramSet> sets;
  final List<String> stoppedSlots;
  void validateAgainst(RecommendationSnapshot plan) {
    checkHistory(
      plan.id == recommendationId &&
          plan.profile == profile &&
          plan.status == RecommendationStatus.ready,
      'recommendation_mismatch',
    );
    checkHistory(!startedAt.isBefore(plan.createdAt), 'invalid_start_time');
    for (final id in stoppedSlots) {
      checkHistory(plan.slots.any((s) => s.id == id), 'unknown_stop');
    }
    for (final set in sets) {
      final slots = plan.slots.where((s) => s.id == set.slot);
      checkHistory(slots.length == 1, 'unknown_slot');
      final slot = slots.single;
      final matches = slot.targets.where(
        (t) => '${slot.id}_${t.key}' == set.key,
      );
      checkHistory(matches.length == 1, 'unknown_target');
      final identity = matches.single.rehearsalIdentity;
      final convention = identity?.convention ?? slot.convention;
      checkHistory(
        set.variant == (identity?.exerciseId ?? slot.exerciseId) &&
            set.setup == (identity?.setupId ?? slot.setupId) &&
            set.convention == convention,
        'actual_context_mismatch',
      );
      if (set.skipped) {
        checkHistory(
          set.load == null &&
              set.reps == null &&
              set.rir == null &&
              set.validity == SetValidity.unknown,
          'invalid_skip',
        );
      } else {
        checkHistory(
          convention == LoadConvention.bodyweight
              ? set.load == null
              : set.load != null,
          'invalid_load',
        );
        if (set.load != null) _number(set.load!, 1000000000000);
        checkHistory(set.reps != null, 'missing_reps');
        _number(set.reps!, 10000);
        if (set.rir != null) _number(set.rir!, 10000);
      }
      if (set.validity == SetValidity.pain) {
        checkHistory(stoppedSlots.contains(set.slot), 'missing_safety_stop');
      }
    }
    if (status == OccurrenceStatus.completed) {
      for (final slot in plan.slots) {
        for (final t in slot.targets.where((t) => !t.warmup)) {
          checkHistory(
            sets.any((s) => s.key == '${slot.id}_${t.key}'),
            'unrecorded_sets',
          );
        }
      }
    }
  }

  GeneratedOccurrence record(
    ProgramSet set,
    DateTime at,
    RecommendationSnapshot plan,
  ) {
    final exists = sets.any((s) => s.key == set.key);
    checkHistory(
      status == OccurrenceStatus.active || exists,
      'terminal_session',
    );
    checkHistory(
      exists || set.skipped || !stoppedSlots.contains(set.slot),
      'exercise_stopped',
    );
    final next = _copy(
      at: at,
      sets: [
        for (final s in sets)
          if (s.key != set.key) s,
        set,
      ],
      stops: {
        ...stoppedSlots,
        if (set.validity == SetValidity.pain) set.slot,
      }.toList()..sort(),
    );
    next.validateAgainst(plan);
    return next;
  }

  GeneratedOccurrence finish(
    DateTime at,
    OccurrenceStatus state,
    RecommendationSnapshot plan,
  ) {
    checkHistory(
      status == OccurrenceStatus.active && state != OccurrenceStatus.active,
      'invalid_finish',
    );
    final next = _copy(at: at, state: state, end: at);
    next.validateAgainst(plan);
    return next;
  }

  GeneratedOccurrence _copy({
    required DateTime at,
    List<ProgramSet>? sets,
    List<String>? stops,
    OccurrenceStatus? state,
    DateTime? end,
  }) {
    checkHistory(!at.isBefore(updatedAt), 'nonmonotonic_time');
    return GeneratedOccurrence(
      id: id,
      profile: profile,
      recommendationId: recommendationId,
      sequence: sequence,
      revision: revision + 1,
      startedAt: startedAt,
      updatedAt: at,
      endedAt: end ?? endedAt,
      status: state ?? status,
      sets: sets ?? this.sets,
      stoppedSlots: stops ?? stoppedSlots,
    );
  }

  Map<String, Object?> toJson() => {
    'schema': 1,
    'unit': 'lb',
    'id': id,
    'profile': profile,
    'recommendationId': recommendationId,
    'sequence': sequence,
    'revision': revision,
    'startedAt': startedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'status': status.name,
    'sets': (sets.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((s) => s.toJson())
        .toList(),
    'stoppedSlots': stoppedSlots.toList()..sort(),
  };
  String encode() => jsonEncode(toJson());
  factory GeneratedOccurrence.decode(String payload) {
    final j = _decode(payload);
    final r = GeneratedOccurrence(
      id: j['id'] as String,
      profile: j['profile'] as String,
      recommendationId: j['recommendationId'] as String,
      sequence: j['sequence'] as int,
      revision: j['revision'] as int,
      startedAt: DateTime.parse(j['startedAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      endedAt: j['endedAt'] == null
          ? null
          : DateTime.parse(j['endedAt'] as String),
      status: OccurrenceStatus.values.byName(j['status'] as String),
      sets: (j['sets'] as List)
          .map((s) => ProgramSet.fromJson(_map(s)))
          .toList(),
      stoppedSlots: List<String>.from(j['stoppedSlots'] as List),
    );
    checkHistory(r.encode() == payload, 'noncanonical_occurrence');
    return r;
  }
}

/// Validates a single audited mutation; cannot replace a whole workout silently.
void validateOccurrenceTransition(
  GeneratedOccurrence old,
  GeneratedOccurrence next,
  RecommendationSnapshot plan,
) {
  checkHistory(
    old.id == next.id &&
        old.profile == next.profile &&
        old.recommendationId == next.recommendationId &&
        old.sequence == next.sequence &&
        old.startedAt == next.startedAt &&
        next.revision == old.revision + 1,
    'invalid_transition',
  );
  GeneratedOccurrence? expected;
  if (old.status != next.status) {
    expected = old.finish(next.updatedAt, next.status, plan);
  } else {
    final changed = next.sets
        .where(
          (s) => !old.sets.any(
            (o) => jsonEncode(o.toJson()) == jsonEncode(s.toJson()),
          ),
        )
        .toList();
    if (changed.length == 1) {
      expected = old.record(changed.single, next.updatedAt, plan);
    }
  }
  checkHistory(
    expected != null && expected.encode() == next.encode(),
    'invalid_transition',
  );
}

final class GeneratedHistory {
  GeneratedHistory({
    required this.profile,
    required this.revision,
    required List<RecommendationSnapshot> recommendations,
    required List<GeneratedOccurrence> occurrences,
  }) : recommendations = List.unmodifiable(recommendations),
       occurrences = List.unmodifiable(occurrences) {
    _id(profile);
    _number(revision, 2147483647);
    checkHistory(
      recommendations.every((r) => r.profile == profile) &&
          recommendations.map((r) => r.id).toSet().length ==
              recommendations.length,
      'invalid_recommendations',
    );
    final ordered = occurrences.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    checkHistory(
      ordered.map((s) => s.id).toSet().length == ordered.length &&
          ordered.map((s) => s.recommendationId).toSet().length ==
              ordered.length,
      'duplicate_occurrence',
    );
    for (var i = 0; i < ordered.length; i++) {
      final s = ordered[i];
      checkHistory(
        s.profile == profile && s.sequence == i,
        'incomplete_history',
      );
      checkHistory(
        i == ordered.length - 1 || s.status != OccurrenceStatus.active,
        'multiple_active',
      );
      if (i > 0) {
        checkHistory(
          !s.startedAt.isBefore(ordered[i - 1].endedAt!),
          'nonmonotonic_sequence',
        );
      }
      final plans = recommendations.where((r) => r.id == s.recommendationId);
      checkHistory(plans.length == 1, 'missing_recommendation');
      s.validateAgainst(plans.single);
    }
    checkHistory(
      revision == occurrences.fold<int>(0, (sum, s) => sum + s.revision + 1),
      'history_revision_mismatch',
    );
  }
  final String profile;
  final int revision;
  final List<RecommendationSnapshot> recommendations;
  final List<GeneratedOccurrence> occurrences;
  bool isStale(RecommendationSnapshot r) =>
      r.profile != profile || r.historyRevision != revision;

  List<ProgressionExposure> progression({
    required String programId,
    required String programVersion,
    required String sessionTemplate,
    required RecommendedSlot current,
  }) {
    final context = progressionContext(
      profile,
      programId,
      sessionTemplate,
      current,
    );
    final result = <ProgressionExposure>[];
    for (final s in occurrences) {
      final r = recommendations.singleWhere((r) => r.id == s.recommendationId);
      if (r.programId != programId || r.sessionTemplate != sessionTemplate) {
        continue;
      }
      final slots = r.slots.where((slot) => slot.id == current.id);
      if (slots.isEmpty) {
        // A historical program revision may omit this slot. Do not bridge it
        // when looking for consecutive evidence in the same session sequence.
        result.add(
          ProgressionExposure(
            id: s.id,
            sequence: s.sequence,
            occurredAt: s.startedAt,
            context: context,
            completed: false,
            correctedOut: false,
            sets: const [],
          ),
        );
        continue;
      }
      final slot = slots.single;
      result.add(
        ProgressionExposure(
          id: s.id,
          sequence: s.sequence,
          occurredAt: s.startedAt,
          context: progressionContext(
            profile,
            programId,
            sessionTemplate,
            slot,
          ),
          completed:
              s.status == OccurrenceStatus.completed &&
              r.programVersion == programVersion &&
              slot.baselineReference == current.baselineReference &&
              _workingPrescription(slot) == _workingPrescription(current) &&
              !s.stoppedSlots.contains(slot.id) &&
              progressionContext(profile, programId, sessionTemplate, slot) ==
                  context,
          correctedOut: false,
          sets: s.sets
              .where((a) => a.slot == slot.id && !a.warmup)
              .map(
                (a) => ProgressionSet(
                  index: a.index,
                  side: switch (a.side) {
                    LoggedSide.both => SetSide.bilateral,
                    LoggedSide.left => SetSide.left,
                    LoggedSide.right => SetSide.right,
                  },
                  microPounds: a.load,
                  reps: a.reps,
                  rir: a.rir,
                  valid: a.skipped
                      ? false
                      : switch (a.validity) {
                          SetValidity.valid => true,
                          SetValidity.unknown => null,
                          _ => false,
                        },
                ),
              )
              .toList(),
        ),
      );
    }
    result.sort((a, b) => a.sequence.compareTo(b.sequence));
    return List.unmodifiable(result);
  }
}

ProgressionContext progressionContext(
  String profile,
  String program,
  String session,
  RecommendedSlot slot,
) {
  final work = slot.targets.where((t) => !t.warmup).toList();
  return (
    profileId: profile,
    slotId: jsonEncode([program, session, slot.id]),
    exerciseId: slot.exerciseId,
    setupId: jsonEncode([slot.setupId, slot.setupRevision]),
    loadConventionId: slot.convention.name,
    setCount: work.length ~/ (slot.unilateral ? 2 : 1),
    minReps: work.first.minReps,
    maxReps: work.first.maxReps,
    unilateral: slot.unilateral,
    loadKind: switch (slot.convention) {
      LoadConvention.bodyweight => ProgressionLoadKind.bodyweight,
      LoadConvention.assistance => ProgressionLoadKind.assistance,
      _ => ProgressionLoadKind.external,
    },
  );
}

abstract interface class RecommendationHistoryRepository {
  Future<GeneratedHistory> load(String profile);
  Future<void> saveRecommendation(
    RecommendationSnapshot recommendation, {
    required String actionId,
  });
  Future<void> saveOccurrence(
    GeneratedOccurrence occurrence, {
    required int expectedRevision,
    required int expectedHistoryRevision,
    required String actionId,
  });
  Future<List<GeneratedOccurrence>> audit(String profile, String occurrenceId);
  Future<void> close();
}

String _workingPrescription(RecommendedSlot slot) => jsonEncode(
  slot.targets.where((t) => !t.warmup).map((t) => t.toJson()).toList(),
);
