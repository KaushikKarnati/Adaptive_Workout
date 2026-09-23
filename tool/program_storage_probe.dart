// Physical release acceptance only. Never opens the production database.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:adaptive_workout/data/repositories/sqlite_program_log_repository.dart';
import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';

void check(bool condition) {
  if (!condition) throw StateError('acceptance failed');
}

Future<void> rejected(Future<void> Function() action) async {
  var failed = false;
  try {
    await action();
  } catch (_) {
    failed = true;
  }
  check(failed);
}

ProgramLog fresh(String profile) => ProgramLog(
  id: 'session',
  profile: profile,
  programId: 'monday',
  startedAt: DateTime.utc(2026),
  revision: 0,
  completedAt: null,
  sets: [],
);
ProgramSet actual({int reps = 10}) => ProgramSet(
  slot: 'incline_dumbbell_press',
  index: 1,
  side: LoggedSide.both,
  variant: 'incline_dumbbell_press',
  setup: 'synthetic_fixture',
  convention: LoadConvention.perDumbbell,
  load: 30000000,
  reps: reps,
  rir: 2,
  validity: SetValidity.valid,
  warmup: false,
  skipped: false,
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('PROGRAM_PROBE_PHASE');
  final directory = await getDatabasesPath();
  final result = File('$directory/program_probe_result.json');
  await result.writeAsString(
    jsonEncode({'phase': phase, 'passed': false, 'status': 'running'}),
    flush: true,
  );
  final path = '$directory/program_release_probe.sqlite';
  SqliteProgramLogRepository? repo;
  var passed = false;
  final checks = <String>[];
  try {
    if (phase == 'seed') {
      await deleteDatabase(path);
      repo = await SqliteProgramLogRepository.open(path: path);
      var log = fresh('a');
      await repo.write(log, expectedRevision: -1, actionId: 'start');
      await repo.write(fresh('b'), expectedRevision: -1, actionId: 'start');
      log = log.record(actual());
      await repo.write(log, expectedRevision: 0, actionId: 'set');
      await repo.write(log, expectedRevision: 0, actionId: 'set');
      await rejected(
        () => repo!.write(log, expectedRevision: 0, actionId: 'stale'),
      );
      checks.add('idempotent_and_stale');
      final db = await openDatabase(path);
      await db.execute(
        "CREATE TRIGGER fail_receipt BEFORE INSERT ON receipts BEGIN SELECT RAISE(ABORT, 'fixture'); END",
      );
      final corrected = log.record(actual(reps: 9));
      await rejected(
        () => repo!.write(corrected, expectedRevision: 1, actionId: 'correct'),
      );
      check((await repo.load('a')).single.sets.single.reps == 10);
      check((await db.query('revisions')).length == 1);
      await db.execute('DROP TRIGGER fail_receipt');
      await repo.write(corrected, expectedRevision: 1, actionId: 'correct');
      log = corrected.record(actual(reps: 9));
      await repo.write(log, expectedRevision: 2, actionId: 'same');
      check((await repo.load('b')).single.sets.isEmpty);
      check((await db.query('revisions')).length == 3);
      checks.add('rollback_correction_isolation');
      for (final e in log.exercises) {
        for (var i = 1; i <= e.sets; i++) {
          if (e.id == 'incline_dumbbell_press' && i == 1) continue;
          final prior = log.revision;
          log = log.record(
            ProgramSet(
              slot: e.id,
              index: i,
              side: LoggedSide.both,
              variant: '',
              setup: '',
              convention: LoadConvention.bodyweight,
              load: null,
              reps: null,
              rir: null,
              validity: SetValidity.unknown,
              warmup: false,
              skipped: true,
            ),
          );
          await repo.write(
            log,
            expectedRevision: prior,
            actionId: 'skip_$prior',
          );
        }
      }
      final before = log.revision;
      log = log.finish(DateTime.utc(2026, 2));
      await repo.write(log, expectedRevision: before, actionId: 'finish');
      await repo.write(log, expectedRevision: before, actionId: 'finish');
      final fixed = log.record(actual(reps: 8));
      await repo.write(
        fixed,
        expectedRevision: log.revision,
        actionId: 'after_finish',
      );
      check((await repo.load('a')).single.sets.length == 18);
      checks.add('completion_and_post_completion_correction');
      await repo.close();
      repo = await SqliteProgramLogRepository.open(path: path);
      check(
        (await repo.load('a')).single.sets
                .singleWhere((s) => !s.skipped)
                .reps ==
            8,
      );
      checks.add('reopen');
    } else if (phase == 'verify') {
      repo = await SqliteProgramLogRepository.open(path: path);
      final a = (await repo.load('a')).single,
          b = (await repo.load('b')).single;
      check(
        a.completed &&
            a.sets.length == 18 &&
            a.sets.singleWhere((s) => !s.skipped).reps == 8,
      );
      check(!b.completed && b.sets.isEmpty);
      checks.add('separate_process_recovery');
      final db = await openDatabase(path);
      final stored = (await db.query(
        'logs',
        where: 'profile=?',
        whereArgs: ['a'],
      )).single['prescription'];
      await db.update(
        'logs',
        {'prescription': '{}'},
        where: 'profile=?',
        whereArgs: ['a'],
      );
      await rejected(() async {
        await repo!.load('a');
      });
      await db.update(
        'logs',
        {'prescription': stored},
        where: 'profile=?',
        whereArgs: ['a'],
      );
      checks.add('prescription_mismatch_refused');
      await db.execute('PRAGMA user_version=2');
      await repo.close();
      repo = null;
      await rejected(() async {
        final unexpected = await SqliteProgramLogRepository.open(path: path);
        await unexpected.close();
      });
      final inspect = await openDatabase(path);
      check((await inspect.query('logs')).length == 2);
      await inspect.close();
      checks.add('future_schema_preserved');
    } else {
      throw StateError('phase');
    }
    passed = true;
  } catch (_) {
    passed = false;
  } finally {
    await repo?.close();
  }
  await result.writeAsString(
    jsonEncode({
      'phase': phase,
      'passed': passed,
      'checks': checks,
      'processId': pid,
    }),
    flush: true,
  );
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            passed
                ? 'Program storage $phase verified'
                : 'Program storage check failed',
          ),
        ),
      ),
    ),
  );
}
