import 'package:flutter/foundation.dart';

import '../../domain/gyms/gym_profile.dart';

class GymProfileController extends ChangeNotifier {
  GymProfileController(this.repository, {DateTime Function()? now})
    : now = now ?? (() => DateTime.now().toUtc());
  final GymProfileRepository repository;
  final DateTime Function() now;
  GymProfiles? saved, _pending;
  bool busy = false, _disposed = false;
  String? error;
  bool get locked => busy || _pending != null || saved == null;
  bool get canRetry => !busy && _pending != null;
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
    if (busy || _pending != null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      saved = await repository.load();
    } catch (_) {
      error = 'Could not open your gyms. Try again.';
    }
    busy = false;
    notifyListeners();
  }

  Future<bool> select(GymProfile gym) async {
    if (locked) return false;
    try {
      _pending = saved!.select(gym);
      return await retry();
    } catch (_) {
      error =
          'Could not add this gym. Check its details or the 50-location limit.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> clearSelection() async {
    if (locked) return false;
    _pending = GymProfiles(profiles: saved!.profiles);
    return retry();
  }

  Future<bool> setEquipment(
    String category,
    EquipmentAvailability availability,
    String notes,
  ) async {
    if (locked || saved!.selected == null) return false;
    try {
      return await select(
        saved!.selected!.update(
          GymEquipment(
            category: category,
            availability: availability,
            checkedAt: availability == EquipmentAvailability.unknown
                ? null
                : now(),
            notes: notes.trim(),
          ),
        ),
      );
    } catch (_) {
      error = 'Check the equipment details and try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> retry() async {
    if (busy || _pending == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await repository.save(_pending!, expected: saved!);
      final reloaded = await repository.load();
      if (reloaded.encode() != _pending!.encode()) {
        throw StateError('Save not confirmed');
      }
      saved = reloaded;
      _pending = null;
      busy = false;
      notifyListeners();
      return true;
    } catch (_) {
      busy = false;
      error = 'Save not confirmed. Retry your saved change, or reload to review the latest profile.';
      notifyListeners();
      return false;
    }
  }

  Future<void> discardPendingAndReload() async {
    if (busy) return;
    _pending = null;
    saved = null;
    await load();
  }
}
