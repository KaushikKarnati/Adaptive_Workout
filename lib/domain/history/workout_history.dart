import '../logging/program_log.dart';
import '../logging/practice_repository.dart';

/// Descriptive manual-log views only; never recommendation evidence.
List<ProgramLog> filterWorkoutHistory(
  Iterable<ProgramLog> logs, {
  required String profile,
  String query = '',
  DateTime? since,
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty);
  final result = logs.where((log) {
    final text =
        '${log.plan.day} ${log.plan.title} ${log.exercises.map((e) => e.name).join(' ')} ${log.sets.map((s) => '${s.variant} ${s.setup}').join(' ')}'
            .toLowerCase();
    return log.profile == profile &&
        log.completed &&
        (since == null || !log.startedAt.isBefore(since)) &&
        words.every(text.contains);
  }).toList();
  result.sort((a, b) {
    final date = b.startedAt.compareTo(a.startedAt);
    return date == 0 ? a.id.compareTo(b.id) : date;
  });
  return result;
}

typedef ExerciseSeriesKey = ({
  String version,
  String program,
  String slot,
  String variant,
  String setup,
  LoadConvention convention,
  LoggedSide side,
});

class HistoryPoint {
  const HistoryPoint(this.log, this.set);
  final ProgramLog log;
  final ProgramSet set;
}

class ExerciseHistorySeries {
  ExerciseHistorySeries(this.key, this.name, this.points);
  final ExerciseSeriesKey key;
  final String name;
  final List<HistoryPoint> points;
}

/// Every plotted point is an actual set, ordered by session and set index.
/// No estimated strength, volume, or inferred bodyweight is calculated.
List<ExerciseHistorySeries> exerciseHistory(Iterable<ProgramLog> logs) {
  final groups = <ExerciseSeriesKey, ExerciseHistorySeries>{};
  final ordered = logs.where((l) => l.completed).toList()
    ..sort((a, b) {
      final date = a.startedAt.compareTo(b.startedAt);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
  for (final log in ordered) {
    final sets = log.sets.toList()..sort((a, b) => a.index.compareTo(b.index));
    for (final set in sets) {
      if (set.warmup ||
          set.skipped ||
          set.validity != SetValidity.valid ||
          set.reps == null ||
          set.reps! <= 0 ||
          (set.convention != LoadConvention.bodyweight && set.load == null)) {
        continue;
      }
      final key = (
        version: log.programVersion,
        program: log.programId,
        slot: set.slot,
        variant: set.variant,
        setup: set.setup,
        convention: set.convention,
        side: set.side,
      );
      final exercise = log.exercises.where((e) => e.id == set.slot).firstOrNull;
      if (exercise == null) continue;
      groups
          .putIfAbsent(key, () => ExerciseHistorySeries(key, exercise.name, []))
          .points
          .add(HistoryPoint(log, set));
    }
  }
  return groups.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}
