// Physical-device acceptance probe. Never used as the production entry point.
import 'dart:convert';
import 'dart:io';

import 'package:adaptive_workout/data/repositories/sqlite_practice_repository.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('STORAGE_PROBE_PHASE');
  final directory = await getDatabasesPath();
  final resultFile = File('$directory/practice_recovery_result.json');
  await resultFile.writeAsString(
    jsonEncode({'phase': phase, 'passed': false, 'status': 'running'}),
    flush: true,
  );
  final path = '$directory/practice_release_probe.sqlite';
  SqlitePracticeRepository? repo;
  var passed = false;
  try {
    if (phase != 'seed' && phase != 'verify') throw StateError('invalid phase');
    if (phase == 'seed') await deleteDatabase(path);
    repo = await SqlitePracticeRepository.open(path: path);
    if (phase == 'seed') {
      final at = DateTime.utc(2026, 9, 23);
      await repo.start(
        profileId: 'probe',
        sessionId: 'session',
        actionId: 'start',
        at: at,
      );
      for (var i = 1; i <= 3; i++) {
        await repo.saveSet(
          profileId: 'probe',
          sessionId: 'session',
          actionId: 'action_$i',
          expectedRevision: i - 1,
          record: PracticeSet(
            id: 'set_$i',
            exerciseId: 'practice_press',
            index: i,
            microPounds: 30000000,
            reps: 10,
            rir: 2,
            working: true,
            validity: SetValidity.valid,
          ),
          correction: false,
          at: at,
        );
      }
    } else {
      final sessions = await repo.load('probe');
      if (sessions.length != 1) throw StateError('session count');
      final session = sessions.single;
      if (session.revision != 3 ||
          session.completed ||
          session.sets.length != 3) {
        throw StateError('recovery state');
      }
      for (var i = 0; i < 3; i++) {
        final set = session.sets[i];
        if (set.id != 'set_${i + 1}' ||
            set.microPounds != 30000000 ||
            set.reps != 10 ||
            set.rir != 2) {
          throw StateError('recovery values');
        }
      }
    }
    passed = true;
  } catch (_) {
    passed = false;
  } finally {
    await repo?.close();
  }
  await resultFile.writeAsString(
    jsonEncode({
      'phase': phase,
      'passed': passed,
      'records': passed ? 3 : null,
      'processId': pid,
    }),
    flush: true,
  );
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            passed ? 'Storage $phase verified' : 'Storage check failed',
          ),
        ),
      ),
    ),
  );
}
