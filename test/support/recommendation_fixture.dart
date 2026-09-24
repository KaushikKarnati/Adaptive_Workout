import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:adaptive_workout/domain/recommendations/recommendation_history.dart';

final generatedTime = DateTime.utc(2026, 9, 25);
RecommendedSlot generatedSlot({
  String setup = 'machine',
  int setupRevision = 0,
  String baseline = 'baseline_r0',
  String exercise = 'fixture_press',
  bool unilateral = false,
  LoadConvention convention = LoadConvention.machineSetting,
}) => RecommendedSlot(
  id: 'press',
  exerciseId: exercise,
  blockId: 'block1',
  setupId: setup,
  setupRevision: setupRevision,
  baselineReference: baseline,
  convention: convention,
  unilateral: unilateral,
  targets: [
    for (final side
        in unilateral ? [LoggedSide.left, LoggedSide.right] : [LoggedSide.both])
      SetTarget(
        index: 1,
        side: side,
        warmup: true,
        load: convention == LoadConvention.bodyweight ? null : 50000000,
        minReps: 5,
        maxReps: 5,
        minRir: 4,
        maxRir: 6,
        restSeconds: 90,
      ),
    for (var i = 1; i <= 2; i++)
      for (final side
          in unilateral
              ? [LoggedSide.left, LoggedSide.right]
              : [LoggedSide.both])
        SetTarget(
          index: i,
          side: side,
          warmup: false,
          load: convention == LoadConvention.bodyweight ? null : 100000000,
          minReps: 8,
          maxReps: 12,
          minRir: 2,
          maxRir: 3,
          restSeconds: 120,
        ),
  ],
);
RecommendationSnapshot generatedPlan({
  String id = 'rec0',
  String profile = 'fixture',
  int history = 0,
  String program = 'fixture_program_v1',
  RecommendedSlot? slot,
  DateTime? at,
  Map<String, int> evidence = const {},
  RecommendationStatus status = RecommendationStatus.ready,
}) => RecommendationSnapshot(
  id: id,
  profile: profile,
  programId: 'fixture_program',
  programVersion: program,
  sessionTemplate: 'session_a',
  ruleVersion: 'fixture_rules_v1',
  catalogVersion: 'fixture_catalog_v1',
  catalogDigest: List.filled(64, 'a').join(),
  createdAt: at ?? generatedTime,
  requestedDate: generatedTime,
  timezone: 'America/Chicago',
  historyRevision: history,
  inputRevisions: {
    'profile': 0,
    'equipment': 0,
    'baseline': 0,
    'constraints': 0,
    'safety': 0,
    'catalogSchema': 1,
    'taxonomy': 2,
  },
  evidence: evidence,
  status: status,
  reasons: [
    status == RecommendationStatus.ready
        ? 'fixture_ready'
        : 'catalog_review_required',
  ],
  slots: status == RecommendationStatus.ready ? [slot ?? generatedSlot()] : [],
  walkSeconds: 300,
  preferredMinutes: 60,
  estimatedSeconds: null,
);
GeneratedOccurrence generatedStart(
  RecommendationSnapshot plan, {
  String id = 'session0',
  int sequence = 0,
  DateTime? at,
}) => GeneratedOccurrence(
  id: id,
  profile: plan.profile,
  recommendationId: plan.id,
  sequence: sequence,
  revision: 0,
  startedAt: at ?? plan.createdAt,
  updatedAt: at ?? plan.createdAt,
  endedAt: null,
  status: OccurrenceStatus.active,
  sets: [],
  stoppedSlots: [],
);
ProgramSet generatedActual({
  int index = 1,
  LoggedSide side = LoggedSide.both,
  bool warmup = false,
  bool skipped = false,
  int reps = 12,
  int? rir = 2,
  SetValidity validity = SetValidity.valid,
  RecommendedSlot? slot,
  int? load = 100000000,
}) {
  final s = slot ?? generatedSlot();
  return ProgramSet(
    slot: s.id,
    index: index,
    side: side,
    variant: s.exerciseId,
    setup: s.setupId,
    convention: s.convention,
    load: skipped || s.convention == LoadConvention.bodyweight ? null : load,
    reps: skipped ? null : reps,
    rir: skipped ? null : rir,
    validity: skipped ? SetValidity.unknown : validity,
    warmup: warmup,
    skipped: skipped,
  );
}

GeneratedOccurrence generatedComplete(
  RecommendationSnapshot plan, {
  String id = 'session0',
  int sequence = 0,
}) {
  var s = generatedStart(plan, id: id, sequence: sequence);
  for (final slot in plan.slots) {
    for (final t in slot.targets.where((t) => !t.warmup)) {
      s = s.record(
        generatedActual(slot: slot, index: t.index, side: t.side),
        s.updatedAt.add(const Duration(seconds: 1)),
        plan,
      );
    }
  }
  return s.finish(
    s.updatedAt.add(const Duration(seconds: 1)),
    OccurrenceStatus.completed,
    plan,
  );
}

GeneratedHistory generatedHistory(
  List<RecommendationSnapshot> plans,
  List<GeneratedOccurrence> sessions,
) => GeneratedHistory(
  profile: 'fixture',
  revision: sessions.fold(0, (n, s) => n + s.revision + 1),
  recommendations: plans,
  occurrences: sessions,
);
