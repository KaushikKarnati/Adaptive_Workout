import 'package:adaptive_workout/domain/workout/owner_program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v2 changes only Wednesday shoulder set count and freezes v1', () {
    final old = ownerProgramForVersion(legacyOwnerProgramVersion);
    expect(old[2].blocks.first.exercises.single.sets, 2);
    for (var i = 0; i < old.length; i++) {
      for (var b = 0; b < old[i].blocks.length; b++) {
        final before = old[i].blocks[b];
        final after = ownerProgram[i].blocks[b];
        expect(after.restSeconds, before.restSeconds);
        for (var e = 0; e < before.exercises.length; e++) {
          final a = before.exercises[e], n = after.exercises[e];
          expect(
            [n.id, n.name, n.minReps, n.maxReps, n.eachSide, n.alternatives],
            [a.id, a.name, a.minReps, a.maxReps, a.eachSide, a.alternatives],
          );
          expect(n.sets, a.id == 'shoulder_press' ? 3 : a.sets);
        }
      }
    }
    expect(() => ownerProgram[2].blocks.clear(), throwsUnsupportedError);
    expect(
      () => ownerProgram[2].blocks.first.exercises.clear(),
      throwsUnsupportedError,
    );
    expect(() => ownerProgramForVersion('unknown'), throwsArgumentError);
  });

  test('approved program has exactly the five ordered sessions', () {
    expect(ownerProgramVersion, 'owner-program-v2');
    expect(ownerProgram.map((s) => s.id), [
      'monday',
      'tuesday',
      'wednesday',
      'friday',
      'saturday',
    ]);
    expect(() => ownerProgram.clear(), throwsUnsupportedError);
  });

  test('every prescription matches the approved transcription', () {
    const expected = [
      [
        'incline_dumbbell_press:3:6:10',
        'neutral_grip_lat_pulldown:3:8:12',
        'incline_machine_press:3:8:12',
        'chest_supported_row:3:8:12',
        'cable_lateral_raise:3:12:20',
        'cable_chest_fly:3:12:15',
      ],
      [
        'leg_press:3:10:15',
        'leg_extension:3:12:15',
        'seated_leg_curl:3:10:15',
        'machine_calf_raise:3:12:20',
        'cable_crunch:3:10:15',
      ],
      [
        'shoulder_press:3:8:12',
        'cable_lateral_raise:3:12:20',
        'reverse_pec_deck:3:12:20',
        'cable_curl:3:8:12',
        'overhead_cable_triceps_extension:3:10:15',
        'hanging_knee_raise:3:8:15',
      ],
      [
        'pull_up:3:6:10',
        'incline_machine_press:3:8:12',
        'seated_cable_row:3:8:12',
        'single_arm_cable_pulldown:3:10:15',
        'machine_chest_fly:3:12:15',
        'cable_lateral_raise:3:15:20',
      ],
      [
        'hack_squat:3:8:12',
        'leg_extension:3:12:15',
        'leg_curl:3:10:15',
        'machine_calf_raise:3:12:20',
        'ab_wheel_rollout:3:6:12',
      ],
    ];
    for (var i = 0; i < ownerProgram.length; i++) {
      expect(
        ownerProgram[i].blocks
            .expand((b) => b.exercises)
            .map((e) => '${e.id}:${e.sets}:${e.minReps}:${e.maxReps}'),
        expected[i],
      );
    }
  });

  test('P3 rest and paired rounds preserve approved boundaries', () {
    const rests = [
      [120, 120, 90, 60],
      [120, 75, 60],
      [120, 60, 60, 60],
      [120, 90, 90, 60],
      [120, 75, 60],
    ];
    const sizes = [
      [1, 1, 2, 2],
      [1, 2, 2],
      [1, 2, 2, 1],
      [1, 2, 1, 2],
      [1, 2, 2],
    ];
    for (var i = 0; i < ownerProgram.length; i++) {
      final blocks = ownerProgram[i].blocks;
      expect(blocks.map((b) => b.restSeconds), rests[i]);
      expect(blocks.map((b) => b.exercises.length), sizes[i]);
      for (final block in blocks) {
        if (block.isSuperset) {
          expect(block.exercises.map((e) => e.sets), [3, 3]);
        }
        expect(() => block.exercises.clear(), throwsUnsupportedError);
        for (final e in block.exercises) {
          expect([e.minRir, e.maxRir], [2, 3]);
        }
      }
    }
  });

  test('alternatives and unilateral prescription do not select a setup', () {
    final all = ownerProgram.expand((s) => s.blocks).expand((b) => b.exercises);
    expect(all.where((e) => e.eachSide).map((e) => e.id), [
      'single_arm_cable_pulldown',
    ]);
    expect(all.singleWhere((e) => e.id == 'shoulder_press').alternatives, [
      'machine_shoulder_press',
      'dumbbell_shoulder_press',
    ]);
    expect(all.singleWhere((e) => e.id == 'pull_up').alternatives, [
      'unassisted_pull_up',
      'assisted_machine_pull_up',
    ]);
    expect(all.singleWhere((e) => e.id == 'leg_curl').alternatives, [
      'seated_leg_curl',
      'lying_leg_curl',
    ]);
    expect(
      all.any(
        (e) => [
          'rdl',
          'lunge',
          'hip_thrust',
          'glute_bridge',
          'kickback',
          'hip_abduction',
        ].contains(e.id),
      ),
      isFalse,
    );
  });
}
