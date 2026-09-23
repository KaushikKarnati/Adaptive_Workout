import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/logging/practice_repository.dart';

final class PracticeController extends ChangeNotifier {
  PracticeController(
    this.repository, {
    this.profileId = 'local_owner',
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final PracticeRepository repository;
  final String profileId;
  final DateTime Function() now;
  final _random = Random.secure();
  List<PracticeSession> sessions = const [];
  String? selectedId;
  bool busy = false;
  String? error;
  Future<void> Function()? _pending;
  bool _disposed = false;
  bool get retryRequired => _pending != null;
  bool get controlsLocked => busy || retryRequired;
  PracticeSession? get selected {
    for (final session in sessions) {
      if (session.id == selectedId) return session;
    }
    return null;
  }

  PracticeSession? get draft {
    for (final session in sessions) {
      if (!session.completed) return session;
    }
    return null;
  }

  String _id() => List.generate(
    4,
    (_) => _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
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
    if (busy || retryRequired) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      sessions = await repository.load(profileId);
      selectedId ??= draft?.id;
    } catch (_) {
      error = 'Could not open saved workouts. Try again.';
    }
    busy = false;
    notifyListeners();
  }

  void select(String? id) {
    if (controlsLocked) return;
    selectedId = id;
    error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() operation) async {
    if (controlsLocked) return false;
    _pending = operation;
    return retry();
  }

  Future<bool> retry() async {
    if (busy || _pending == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _pending!();
      final saved = await repository.load(profileId);
      sessions = saved;
      _pending = null;
      busy = false;
      notifyListeners();
      return true;
    } catch (_) {
      error =
          'Save not confirmed. Your input is kept. Retry to confirm it safely.';
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> start() async {
    if (controlsLocked) return false;
    if (draft != null) {
      select(draft!.id);
      return true;
    }
    final sessionId = _id(), actionId = _id();
    final at = now().toUtc();
    return _run(() async {
      await repository.start(
        profileId: profileId,
        sessionId: sessionId,
        actionId: actionId,
        at: at,
      );
      selectedId = sessionId;
    });
  }

  Future<bool> save(PracticeSet record, {bool correction = false}) async {
    final session = selected;
    if (session == null) return false;
    try {
      record.validate();
    } catch (_) {
      error = 'Check the entered values.';
      notifyListeners();
      return false;
    }
    final actionId = _id(), at = now().toUtc();
    return _run(
      () => repository.saveSet(
        profileId: profileId,
        sessionId: session.id,
        actionId: actionId,
        expectedRevision: session.revision,
        record: record,
        correction: correction,
        at: at,
      ),
    );
  }

  Future<bool> complete() async {
    final session = selected;
    if (session == null) return false;
    final actionId = _id(), at = now().toUtc();
    return _run(
      () => repository.complete(
        profileId: profileId,
        sessionId: session.id,
        actionId: actionId,
        expectedRevision: session.revision,
        at: at,
      ),
    );
  }
}
