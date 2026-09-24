import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/logging/program_log.dart';

class ProgramLogController extends ChangeNotifier {
  ProgramLogController(this.repository, {this.profile = 'local_owner'});
  final ProgramLogRepository repository;
  final String profile;
  List<ProgramLog> logs = [];
  String? selectedId, error;
  bool busy = false, _disposed = false;
  ProgramLog? _pending;
  ProgramLog? _pendingDelete;
  String? _action;
  ProgramLog? get pending => _pending;
  bool get locked => busy || _pending != null || _pendingDelete != null;
  ProgramLog? get selected => logs.where((l) => l.id == selectedId).firstOrNull;
  ProgramLog? get draft => logs.where((l) => !l.completed).firstOrNull;
  String _id() => List.generate(
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
      logs = await repository.load(profile);
      selectedId ??= draft?.id;
    } catch (_) {
      error = 'Could not open workouts. Try again.';
    }
    busy = false;
    notifyListeners();
  }

  void select(String? id) {
    if (locked) return;
    selectedId = id;
    notifyListeners();
  }

  Future<bool> start(String programId) async {
    if (locked) return false;
    if (draft != null) {
      select(draft!.id);
      return true;
    }
    return _save(
      ProgramLog(
        id: _id(),
        profile: profile,
        programId: programId,
        startedAt: DateTime.now().toUtc(),
        revision: 0,
        completedAt: null,
        sets: [],
      ),
    );
  }

  Future<bool> record(ProgramSet set) async {
    if (locked || selected == null) return false;
    try {
      return await _save(selected!.record(set));
    } catch (_) {
      error = 'Check your entries. Pain stops further sets for that exercise; remaining sets can be skipped.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> finish({bool endEarly = false}) async {
    if (locked || selected == null) return false;
    if (selected!.completed) return true;
    try {
      return await _save(
        selected!.finish(DateTime.now().toUtc(), endEarly: endEarly),
      );
    } catch (_) {
      error = 'Record or explicitly skip each working set before finishing. You can leave this workout saved as a draft.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(ProgramLog log) async {
    if (locked || log.profile != profile) return false;
    _pendingDelete = log;
    _action = _id();
    return retry();
  }

  Future<bool> _save(ProgramLog log) async {
    if (locked) return false;
    _pending = log;
    _action = _id();
    return retry();
  }

  Future<bool> retry() async {
    if (busy || (_pending == null && _pendingDelete == null)) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (_pendingDelete != null) {
        final deleted = _pendingDelete!;
        await repository.delete(
          profile,
          deleted.id,
          expectedRevision: deleted.revision,
          actionId: _action!,
        );
        logs = await repository.load(profile);
        if (logs.any((l) => l.id == deleted.id)) {
          throw StateError('delete_not_confirmed');
        }
        if (selectedId == deleted.id) selectedId = null;
        _pendingDelete = null;
      } else {
        await repository.write(
          _pending!,
          expectedRevision: _pending!.revision - 1,
          actionId: _action!,
        );
        logs = await repository.load(profile);
        selectedId = _pending!.id;
        _pending = null;
      }
      _action = null;
      busy = false;
      notifyListeners();
      return true;
    } catch (_) {
      error = _pendingDelete != null
          ? 'Deletion not confirmed. Retry safely.'
          : 'Save not confirmed. Your entries are kept. Retry safely.';
      busy = false;
      notifyListeners();
      return false;
    }
  }
}
