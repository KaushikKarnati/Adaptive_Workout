import '../workout/owner_program.dart';
import 'practice_repository.dart';

enum LoadConvention {
  perDumbbell,
  machineSetting,
  platesOnly,
  totalLoad,
  assistance,
  bodyweight,
}

enum LoggedSide { both, left, right }

/// Manual actuals only. These records never establish a verified baseline.
class ProgramSet {
  const ProgramSet({
    required this.slot,
    required this.index,
    required this.side,
    required this.variant,
    required this.setup,
    required this.convention,
    required this.load,
    required this.reps,
    required this.rir,
    required this.validity,
    required this.warmup,
    required this.skipped,
  });
  final String slot, variant, setup;
  final int index;
  final LoggedSide side;
  final LoadConvention convention;
  final int? load, reps, rir;
  final SetValidity validity;
  final bool warmup, skipped;
  String get key =>
      '${slot}_${warmup ? 'warmup' : 'work'}_${index}_${side.name}';
  Map<String, Object?> toJson() => {
    'slot': slot,
    'index': index,
    'side': side.name,
    'variant': variant,
    'setup': setup,
    'convention': convention.name,
    'load': load,
    'reps': reps,
    'rir': rir,
    'validity': validity.name,
    'warmup': warmup,
    'skipped': skipped,
  };
  factory ProgramSet.fromJson(Map<String, dynamic> j) => ProgramSet(
    slot: j['slot'] as String,
    index: j['index'] as int,
    side: LoggedSide.values.byName(j['side'] as String),
    variant: j['variant'] as String,
    setup: j['setup'] as String,
    convention: LoadConvention.values.byName(j['convention'] as String),
    load: j['load'] as int?,
    reps: j['reps'] as int?,
    rir: j['rir'] as int?,
    validity: SetValidity.values.byName(j['validity'] as String),
    warmup: j['warmup'] as bool,
    skipped: j['skipped'] as bool,
  );
}

class ProgramLog {
  ProgramLog({
    required this.id,
    required this.profile,
    required this.programId,
    required this.startedAt,
    required this.revision,
    required this.completedAt,
    required List<ProgramSet> sets,
  }) : sets = List.unmodifiable(sets);
  final String id, profile, programId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int revision;
  final List<ProgramSet> sets;
  bool get completed => completedAt != null;
  bool get recommendationEligible => false;
  ProgramSession get plan => ownerProgram.singleWhere((p) => p.id == programId);
  List<ProgramExercise> get exercises =>
      plan.blocks.expand((b) => b.exercises).toList();
  bool get allWorkingSetsRecorded {
    for (final exercise in exercises) {
      for (var i = 1; i <= exercise.sets; i++) {
        final sides = exercise.eachSide
            ? [LoggedSide.left, LoggedSide.right]
            : [LoggedSide.both];
        for (final side in sides) {
          if (!sets.any(
            (s) =>
                s.slot == exercise.id &&
                !s.warmup &&
                s.index == i &&
                s.side == side,
          )) {
            return false;
          }
        }
      }
    }
    return true;
  }

  bool get hasSkips => sets.any((s) => !s.warmup && s.skipped);
  void validateSet(ProgramSet set) {
    final matches = exercises.where((e) => e.id == set.slot);
    if (matches.length != 1) throw const LoggingException('unknown_slot');
    final e = matches.single;
    if (set.index < 1 ||
        set.index > (set.warmup ? 100 : e.sets) ||
        (e.eachSide
            ? set.side == LoggedSide.both
            : set.side != LoggedSide.both)) {
      throw const LoggingException('invalid_set_identity');
    }
    if (!(e.alternatives.isEmpty
            ? set.variant == e.id
            : e.alternatives.contains(set.variant)) ||
        set.setup.trim().isEmpty ||
        set.setup.length > 120) {
      throw LoggingException(set.skipped ? 'invalid_skip' : 'invalid_actuals');
    }
    if (set.variant == 'assisted_machine_pull_up' &&
            set.convention != LoadConvention.assistance ||
        [
              'unassisted_pull_up',
              'hanging_knee_raise',
              'ab_wheel_rollout',
            ].contains(set.variant) &&
            set.convention != LoadConvention.bodyweight ||
        [
              'incline_dumbbell_press',
              'dumbbell_shoulder_press',
            ].contains(set.variant) &&
            set.convention != LoadConvention.perDumbbell ||
        (set.convention == LoadConvention.assistance &&
            set.variant != 'assisted_machine_pull_up') ||
        (set.convention == LoadConvention.bodyweight &&
            ![
              'unassisted_pull_up',
              'hanging_knee_raise',
              'ab_wheel_rollout',
            ].contains(set.variant)) ||
        (set.convention == LoadConvention.perDumbbell &&
            ![
              'incline_dumbbell_press',
              'dumbbell_shoulder_press',
            ].contains(set.variant))) {
      throw const LoggingException('invalid_load_convention');
    }
    if (set.skipped) {
      if (set.load != null ||
          set.reps != null ||
          set.rir != null ||
          set.validity != SetValidity.unknown) {
        throw const LoggingException('invalid_skip');
      }
      return;
    }
    if ((set.convention == LoadConvention.bodyweight
            ? set.load != null
            : set.load == null) ||
        (set.load != null && (set.load! < 0 || set.load! > 1000000000000)) ||
        set.reps == null ||
        set.reps! < 0 ||
        set.reps! > 10000 ||
        (set.rir != null && (set.rir! < 0 || set.rir! > 10000))) {
      throw const LoggingException('invalid_actuals');
    }
  }

  ProgramLog record(ProgramSet set) {
    validateSet(set);
    final existing = sets.any((s) => s.key == set.key);
    if (completed && !existing) {
      throw const LoggingException('completed_session');
    }
    if (!existing &&
        !set.skipped &&
        sets.any((s) => s.slot == set.slot && s.validity == SetValidity.pain)) {
      throw const LoggingException('exercise_stopped');
    }
    return ProgramLog(
      id: id,
      profile: profile,
      programId: programId,
      startedAt: startedAt,
      completedAt: completedAt,
      revision: revision + 1,
      sets: [
        for (final s in sets)
          if (s.key != set.key) s,
        set,
      ],
    );
  }

  ProgramLog finish(DateTime at) {
    if (completed) return this;
    if (!startedAt.isUtc || !at.isUtc || at.isBefore(startedAt)) {
      throw const LoggingException('invalid_completion_time');
    }
    if (!allWorkingSetsRecorded) {
      throw const LoggingException('unrecorded_sets');
    }
    return ProgramLog(
      id: id,
      profile: profile,
      programId: programId,
      startedAt: startedAt,
      completedAt: at,
      revision: revision + 1,
      sets: sets,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'profile': profile,
    'programId': programId,
    'version': ownerProgramVersion,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'revision': revision,
    'sets': sets.map((s) => s.toJson()).toList(),
  };
  factory ProgramLog.fromJson(Map<String, dynamic> j) {
    if (j['version'] != ownerProgramVersion) {
      throw const LoggingException('unsupported_program');
    }
    final result = ProgramLog(
      id: j['id'] as String,
      profile: j['profile'] as String,
      programId: j['programId'] as String,
      startedAt: DateTime.parse(j['startedAt'] as String),
      completedAt: j['completedAt'] == null
          ? null
          : DateTime.parse(j['completedAt'] as String),
      revision: j['revision'] as int,
      sets: (j['sets'] as List)
          .map((s) => ProgramSet.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
    );
    validateStorageId(result.id);
    validateStorageId(result.profile);
    if (!ownerProgram.any((p) => p.id == result.programId) ||
        !result.startedAt.isUtc ||
        (result.completedAt != null &&
            (!result.completedAt!.isUtc ||
                result.completedAt!.isBefore(result.startedAt)))) {
      throw const LoggingException('invalid_session');
    }
    if (result.revision < 0 ||
        result.sets.map((s) => s.key).toSet().length != result.sets.length) {
      throw const LoggingException('invalid_session');
    }
    for (final s in result.sets) {
      result.validateSet(s);
    }
    if (result.completed && !result.allWorkingSetsRecorded) {
      throw const LoggingException('incomplete_record');
    }
    return result;
  }
}

abstract interface class ProgramLogRepository {
  Future<List<ProgramLog>> load(String profile);
  Future<void> write(
    ProgramLog log, {
    required int expectedRevision,
    required String actionId,
  });
  Future<void> close();
}
