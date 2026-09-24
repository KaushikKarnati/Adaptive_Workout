import 'package:adaptive_workout/ui/app_haptics.dart';

class FakeHapticsDriver implements HapticsDriver {
  @override
  bool supported = true;
  bool storedEnabled = true;
  bool failLoad = false;
  bool failSave = false;
  bool failPlay = false;
  final events = <String>[];

  @override
  Future<bool> loadEnabled() async {
    if (failLoad) throw StateError('unavailable');
    return storedEnabled;
  }

  @override
  Future<void> saveEnabled(bool enabled) async {
    if (failSave) throw StateError('unavailable');
    storedEnabled = enabled;
  }

  @override
  Future<void> play(String kind) async {
    if (failPlay) throw StateError('unavailable');
    events.add(kind);
  }
}
