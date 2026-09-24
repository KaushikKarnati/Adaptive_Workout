import '../workout/owner_program.dart';

enum SetupLoadConvention {
  perDumbbell,
  machineSetting,
  platesOnly,
  totalExternal,
  assistance,
  bodyweight,
}

/// Preparation keys only. These do not constitute reviewed catalog identities.
const setupVariationNames = <String, String>{
  'incline_dumbbell_press': 'Incline dumbbell press',
  'neutral_grip_lat_pulldown': 'Neutral-grip lat pulldown',
  'incline_machine_press': 'Incline machine press',
  'chest_supported_row': 'Chest-supported row',
  'cable_lateral_raise': 'Cable lateral raise',
  'cable_chest_fly': 'Cable chest fly',
  'leg_press': 'Leg press',
  'leg_extension': 'Leg extension',
  'seated_leg_curl': 'Seated leg curl',
  'lying_leg_curl': 'Lying leg curl',
  'machine_calf_raise': 'Machine calf raise',
  'cable_crunch': 'Cable crunch',
  'machine_shoulder_press': 'Seated machine shoulder press',
  'dumbbell_shoulder_press': 'Seated dumbbell shoulder press',
  'reverse_pec_deck': 'Reverse pec deck',
  'cable_curl': 'Cable curl',
  'overhead_cable_triceps_extension': 'Overhead cable triceps extension',
  'supported_knee_raise': 'Supported captain’s-chair knee raise',
  'unassisted_pull_up': 'Unassisted pull-up',
  'assisted_machine_pull_up': 'Machine-assisted pull-up',
  'seated_cable_row': 'Seated cable row',
  'single_arm_cable_pulldown': 'Single-arm cable pulldown',
  'machine_chest_fly': 'Machine chest fly',
  'hack_squat': 'Hack squat',
  'kneeling_ab_wheel': 'Kneeling ab-wheel rollout',
};

List<String> setupVariantsFor(ProgramExercise exercise) =>
    switch (exercise.id) {
      'seated_leg_curl' ||
      'leg_curl' => const ['seated_leg_curl', 'lying_leg_curl'],
      'hanging_knee_raise' => const ['supported_knee_raise'],
      'ab_wheel_rollout' => const ['kneeling_ab_wheel'],
      _ =>
        exercise.alternatives.isEmpty ? [exercise.id] : exercise.alternatives,
    };

List<SetupLoadConvention> setupConventionsFor(String variant) =>
    switch (variant) {
      'unassisted_pull_up' ||
      'supported_knee_raise' ||
      'kneeling_ab_wheel' => const [SetupLoadConvention.bodyweight],
      'assisted_machine_pull_up' => const [SetupLoadConvention.assistance],
      'incline_dumbbell_press' ||
      'dumbbell_shoulder_press' => const [SetupLoadConvention.perDumbbell],
      'chest_supported_row' => const [
        SetupLoadConvention.machineSetting,
        SetupLoadConvention.platesOnly,
        SetupLoadConvention.totalExternal,
        SetupLoadConvention.perDumbbell,
      ],
      _ =>
        setupVariationNames.containsKey(variant)
            ? const [
                SetupLoadConvention.machineSetting,
                SetupLoadConvention.platesOnly,
                SetupLoadConvention.totalExternal,
              ]
            : const [],
    };
