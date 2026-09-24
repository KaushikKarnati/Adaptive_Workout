import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/training/setup_variations.dart';
import '../../domain/training/training_setup.dart';

class TrainingSetupController extends ChangeNotifier {
  TrainingSetupController(
    this.repository, {
    this.profileId = 'local_owner',
    DateTime Function()? now,
    String Function()? newId,
  }) : now = now ?? (() => DateTime.now().toUtc()),
       newId = newId ?? _randomId;
  final TrainingSetupRepository repository;
  final String profileId;
  final DateTime Function() now;
  final String Function() newId;
  TrainingSetup? saved, _pending;
  String? _actionId, error;
  bool busy = false, loaded = false, _disposed = false;
  bool get locked => busy || _pending != null;
  bool get canRetry => !busy && _pending != null;
  static String _randomId() => List.generate(
    4,
    (_) => Random.secure().nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
  ).join();
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    if (locked) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      saved = await repository.load(profileId);
      loaded = true;
    } catch (_) {
      error = 'Could not open setup. Try again.';
    }
    busy = false;
    notifyListeners();
  }

  TrainingSetup _next({
    required DateTime at,
    List<int>? days,
    int? minutes,
    List<String>? exclusions,
    List<EquipmentSetup>? equipment,
    List<StartingLoad>? loads,
    List<ReportedWorkingSetup>? reports,
    List<RehearsalConfirmation>? rehearsals,
  }) => TrainingSetup(
    schemaVersion: reports != null || rehearsals != null
        ? 2
        : saved?.schemaVersion ?? 1,
    reportedWork: reports ?? saved?.reportedWork ?? [],
    rehearsalConfirmations: rehearsals ?? saved?.rehearsalConfirmations ?? [],
    profileId: profileId,
    revision: (saved?.revision ?? -1) + 1,
    updatedAt: at,
    trainingDays: days ?? saved?.trainingDays ?? [],
    preferredMinutes: minutes ?? saved?.preferredMinutes,
    supportedCapabilities: saved?.supportedCapabilities,
    unsupportedCapabilities: saved?.unsupportedCapabilities,
    limitations: saved?.limitations,
    excludedVariations: exclusions ?? saved?.excludedVariations ?? [],
    equipment: equipment ?? saved?.equipment ?? [],
    startingLoads: loads ?? saved?.startingLoads ?? [],
  );

  /// Append observations without changing equipment or confirmed baselines.
  Future<bool> saveIntake({
    List<ReportedWorkingSetup> reports = const [],
    List<RehearsalConfirmation> rehearsals = const [],
  }) async {
    if (locked || !loaded) return false;
    try {
      requireSetup(reports.isNotEmpty || rehearsals.isNotEmpty, 'empty_intake');
      return await _save(
        _next(
          at: now(),
          reports: [...?saved?.reportedWork, ...reports],
          rehearsals: [...?saved?.rehearsalConfirmations, ...rehearsals],
        ),
      );
    } catch (_) {
      return _invalid();
    }
  }

  Future<bool> savePreferences(
    List<int> days,
    String minutes,
    List<String> exclusions,
  ) async {
    if (locked || !loaded) return false;
    try {
      requireSetup(
        RegExp(r'^\d+$').hasMatch(minutes.trim()),
        'invalid_duration',
      );
      return await _save(
        _next(
          at: now(),
          days: days,
          minutes: int.parse(minutes.trim()),
          exclusions: exclusions,
        ),
      );
    } catch (_) {
      return _invalid();
    }
  }

  Future<bool> saveMachine({
    String? existingId,
    required String label,
    required String sessionId,
    required String slotId,
    required String variation,
    required SetupLoadConvention convention,
    required String workingSettings,
    required String rehearsalSettings,
    required String startingWeight,
    required bool confirmed,
    String? equipmentId,
    int quantity = 1,
    List<String> capabilities = const [],
  }) async {
    if (locked || !loaded) return false;
    try {
      final at = now();
      final previous = saved?.equipment
          .where((e) => e.id == existingId)
          .firstOrNull;
      requireSetup(existingId == null || previous != null, 'unknown_setup');
      List<int> settings(String text) => text.trim().isEmpty
          ? []
          : text.split(',').map((s) => parsePounds(s)).toList();
      final machine = EquipmentSetup(
        id: existingId ?? newId(),
        revision: previous == null ? 0 : previous.revision + 1,
        label: label.trim(),
        variation: variation,
        equipmentId: equipmentId,
        quantity: quantity,
        capabilities: capabilities,
        convention: convention,
        workingLoads: settings(workingSettings),
        rehearsalLoads: settings(rehearsalSettings),
        confirmedAt: confirmed ? at : null,
      );
      final equipment = [
        ...?saved?.equipment.where((e) => e.id != machine.id),
        machine,
      ];
      final loads = [...?saved?.startingLoads];
      if (confirmed) {
        final prior = loads
            .where(
              (b) =>
                  b.setupId == machine.id &&
                  b.sessionId == sessionId &&
                  b.slotId == slotId &&
                  b.variation == variation,
            )
            .firstOrNull;
        final baseline = StartingLoad(
          id: prior?.id ?? newId(),
          sessionId: sessionId,
          slotId: slotId,
          variation: variation,
          setupId: machine.id,
          setupRevision: machine.revision,
          convention: convention,
          microPounds: convention == SetupLoadConvention.bodyweight
              ? null
              : parsePounds(startingWeight),
          confirmedAt: at,
        );
        loads.removeWhere((b) => b.id == baseline.id);
        loads.add(baseline);
      } else {
        requireSetup(
          startingWeight.trim().isEmpty,
          'confirm_starting_load_first',
        );
      }
      return await _save(_next(at: at, equipment: equipment, loads: loads));
    } catch (_) {
      return _invalid();
    }
  }

  bool _invalid() {
    error = 'Check your entries. Use exact pounds, unique settings and an explicit confirmation for a starting load.';
    notifyListeners();
    return false;
  }

  Future<bool> _save(TrainingSetup next) {
    validateSetupTransition(saved, next);
    _pending = next;
    _actionId = newId();
    return retry();
  }

  Future<bool> retry() async {
    if (busy || _pending == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.save(
        _pending!,
        expectedRevision: _pending!.revision - 1,
        actionId: _actionId!,
      );
      saved = await repository.load(profileId);
      requireSetup(
        saved != null && saved!.revision >= _pending!.revision,
        'save_not_confirmed',
      );
      _pending = null;
      _actionId = null;
      busy = false;
      notifyListeners();
      return true;
    } catch (_) {
      error = 'Save not confirmed. Your entries are kept. Retry safely.';
      busy = false;
      notifyListeners();
      return false;
    }
  }
}
