/// Practice data is deliberately isolated from real recommendation evidence.
const practiceExercises = <String, String>{
  'practice_press': 'Practice press',
  'practice_row': 'Practice row',
};

enum SetValidity { unknown, valid, invalid, pain }

final class PracticeSet {
  const PracticeSet({
    required this.id,
    required this.exerciseId,
    required this.index,
    required this.microPounds,
    required this.reps,
    required this.rir,
    required this.working,
    required this.validity,
    this.skipped = false,
  });
  final String id;
  final String exerciseId;
  final int index;
  final int? microPounds;
  final int? reps;
  final int? rir;
  final bool working;
  final SetValidity validity;
  final bool skipped;

  void validate() {
    validateStorageId(id);
    if (!practiceExercises.containsKey(exerciseId) ||
        index < 1 ||
        index > 10000) {
      throw const LoggingException('invalid_set_identity');
    }
    if (skipped) {
      if (microPounds != null ||
          reps != null ||
          rir != null ||
          validity != SetValidity.unknown) {
        throw const LoggingException('invalid_skip');
      }
    } else if (microPounds == null ||
        microPounds! < 0 ||
        microPounds! > 1000000000000 ||
        reps == null ||
        reps! < 0 ||
        reps! > 10000 ||
        (rir != null && (rir! < 0 || rir! > 10000))) {
      throw const LoggingException('invalid_actuals');
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'index': index,
    'microPounds': microPounds,
    'reps': reps,
    'rir': rir,
    'working': working,
    'validity': validity.name,
    'skipped': skipped,
  };

  factory PracticeSet.fromJson(Map<String, dynamic> data) {
    try {
      final result = PracticeSet(
        id: data['id'] as String,
        exerciseId: data['exerciseId'] as String,
        index: data['index'] as int,
        microPounds: data['microPounds'] as int?,
        reps: data['reps'] as int?,
        rir: data['rir'] as int?,
        working: data['working'] as bool,
        validity: SetValidity.values.byName(data['validity'] as String),
        skipped: data['skipped'] as bool,
      );
      result.validate();
      return result;
    } catch (_) {
      throw const LoggingException('invalid_stored_set');
    }
  }
}

final class PracticeSession {
  PracticeSession({
    required this.id,
    required this.profileId,
    required this.startedAt,
    required this.completedAt,
    required this.revision,
    required List<PracticeSet> sets,
  }) : sets = List.unmodifiable(sets);
  final String id;
  final String profileId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int revision;
  final List<PracticeSet> sets;
  bool get completed => completedAt != null;
  bool get isPractice => true;
}

final class LoggingException implements Exception {
  const LoggingException(this.code);
  final String code;
  @override
  String toString() => 'LoggingException($code)';
}

void validateStorageId(String id) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(id)) {
    throw const LoggingException('invalid_id');
  }
}

/// Decimal input is parsed exactly, never through floating point.
int parsePounds(String text) {
  final match = RegExp(r'^(\d{1,7})(?:\.(\d{1,6}))?$').firstMatch(text.trim());
  if (match == null) throw const LoggingException('invalid_load');
  final value =
      int.parse(match[1]!) * 1000000 +
      int.parse((match[2] ?? '').padRight(6, '0'));
  if (value > 1000000000000) throw const LoggingException('invalid_load');
  return value;
}

String formatPounds(int value) {
  final whole = value ~/ 1000000;
  final fraction = (value % 1000000)
      .toString()
      .padLeft(6, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

abstract interface class PracticeRepository {
  Future<List<PracticeSession>> load(String profileId);
  Future<void> start({
    required String profileId,
    required String sessionId,
    required String actionId,
    required DateTime at,
  });
  Future<void> saveSet({
    required String profileId,
    required String sessionId,
    required String actionId,
    required int expectedRevision,
    required PracticeSet record,
    required bool correction,
    required DateTime at,
  });
  Future<void> complete({
    required String profileId,
    required String sessionId,
    required String actionId,
    required int expectedRevision,
    required DateTime at,
  });
  Future<void> close();
}
