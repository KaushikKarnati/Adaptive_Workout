import 'package:adaptive_workout/domain/training/setup_variations.dart';
import 'package:adaptive_workout/domain/training/training_setup.dart';

ReportedWorkingSetup syntheticReport({String id = 'report', DateTime? at}) =>
    ReportedWorkingSetup(
      id: id,
      sourceReference: 'synthetic',
      recordedAt: at ?? DateTime.utc(2026),
      sessionId: 'monday',
      slotId: 'incline_dumbbell_press',
      variation: 'incline_dumbbell_press',
      convention: SetupLoadConvention.perDumbbell,
      load: 30000000,
      loadScope: ReportedLoadScope.perHand,
      loadIncrement: 2500000,
      sets: 3,
      minReps: 9,
      maxReps: 11,
      minRir: null,
      maxRir: null,
      eachSide: false,
    );
RehearsalConfirmation syntheticRehearsal({
  String id = 'rehearsal',
  String? setupId,
  int? setupRevision,
  bool? symptoms = false,
  bool? easy = true,
}) => RehearsalConfirmation(
  id: id,
  sourceReference: 'synthetic',
  recordedAt: DateTime.utc(2026),
  sessionId: 'friday',
  slotId: 'pull_up',
  variation: 'assisted_machine_pull_up',
  easyAndControlled: easy,
  symptomsReported: symptoms,
  assistance: 60000000,
  setupId: setupId,
  setupRevision: setupRevision,
);
TrainingSetup withIntake(
  TrainingSetup base, {
  List<ReportedWorkingSetup> reports = const [],
  List<RehearsalConfirmation> rehearsals = const [],
  int? revision,
  DateTime? at,
}) => TrainingSetup(
  schemaVersion: 2,
  programVersion: base.programVersion,
  profileId: base.profileId,
  revision: revision ?? base.revision,
  updatedAt: at ?? base.updatedAt,
  trainingDays: base.trainingDays,
  preferredMinutes: base.preferredMinutes,
  supportedCapabilities: base.supportedCapabilities,
  unsupportedCapabilities: base.unsupportedCapabilities,
  limitations: base.limitations,
  excludedVariations: base.excludedVariations,
  equipment: base.equipment,
  startingLoads: base.startingLoads,
  reportedWork: reports,
  rehearsalConfirmations: rehearsals,
);
