// Approved prescription templates, not eligible catalog records or generated workouts.
const ownerProgramVersion = 'owner-program-v1';

class ProgramExercise {
  const ProgramExercise(
    this.id,
    this.name,
    this.sets,
    this.minReps,
    this.maxReps, {
    this.eachSide = false,
    this.alternatives = const [],
  });
  final String id;
  final String name;
  final int sets;
  final int minReps;
  final int maxReps;
  final bool eachSide;
  // Approved preference order; selection still requires catalog/setup checks.
  final List<String> alternatives;
  int get minRir => 2;
  int get maxRir => 3;
}

class ProgramBlock {
  const ProgramBlock(this.restSeconds, this.exercises);
  final int restSeconds;
  final List<ProgramExercise> exercises;
  bool get isSuperset => exercises.length == 2;
}

class ProgramSession {
  const ProgramSession(this.id, this.day, this.title, this.blocks);
  final String id;
  final String day;
  final String title;
  final List<ProgramBlock> blocks;
}

const ownerProgram = <ProgramSession>[
  ProgramSession('monday', 'Monday', 'Upper chest + lats', [
    ProgramBlock(120, [
      ProgramExercise(
        'incline_dumbbell_press',
        'Incline Dumbbell Press',
        3,
        6,
        10,
      ),
    ]),
    ProgramBlock(120, [
      ProgramExercise(
        'neutral_grip_lat_pulldown',
        'Neutral-Grip Lat Pulldown',
        3,
        8,
        12,
      ),
    ]),
    ProgramBlock(90, [
      ProgramExercise(
        'incline_machine_press',
        'Incline Machine Press',
        3,
        8,
        12,
      ),
      ProgramExercise('chest_supported_row', 'Chest-Supported Row', 3, 8, 12),
    ]),
    ProgramBlock(60, [
      ProgramExercise('cable_lateral_raise', 'Cable Lateral Raise', 3, 12, 20),
      ProgramExercise('cable_chest_fly', 'Cable Chest Fly', 3, 12, 15),
    ]),
  ]),
  ProgramSession('tuesday', 'Tuesday', 'Legs + abs', [
    ProgramBlock(120, [ProgramExercise('leg_press', 'Leg Press', 3, 10, 15)]),
    ProgramBlock(75, [
      ProgramExercise('leg_extension', 'Leg Extension', 3, 12, 15),
      ProgramExercise('seated_leg_curl', 'Seated Leg Curl', 3, 10, 15),
    ]),
    ProgramBlock(60, [
      ProgramExercise('machine_calf_raise', 'Machine Calf Raise', 3, 12, 20),
      ProgramExercise('cable_crunch', 'Cable Crunch', 3, 10, 15),
    ]),
  ]),
  ProgramSession('wednesday', 'Wednesday', 'Shoulders + arms + abs', [
    ProgramBlock(120, [
      ProgramExercise(
        'shoulder_press',
        'Seated Shoulder Press',
        2,
        8,
        12,
        alternatives: ['machine_shoulder_press', 'dumbbell_shoulder_press'],
      ),
    ]),
    ProgramBlock(60, [
      ProgramExercise('cable_lateral_raise', 'Cable Lateral Raise', 3, 12, 20),
      ProgramExercise('reverse_pec_deck', 'Reverse Pec Deck', 3, 12, 20),
    ]),
    ProgramBlock(60, [
      ProgramExercise('cable_curl', 'Cable Curl', 3, 8, 12),
      ProgramExercise(
        'overhead_cable_triceps_extension',
        'Overhead Cable Triceps Extension',
        3,
        10,
        15,
      ),
    ]),
    ProgramBlock(60, [
      ProgramExercise('hanging_knee_raise', 'Hanging Knee Raise', 3, 8, 15),
    ]),
  ]),
  ProgramSession('friday', 'Friday', 'Back + chest', [
    ProgramBlock(120, [
      ProgramExercise(
        'pull_up',
        'Pull-Ups / Assisted Pull-Ups',
        3,
        6,
        10,
        alternatives: ['unassisted_pull_up', 'assisted_machine_pull_up'],
      ),
    ]),
    ProgramBlock(90, [
      ProgramExercise(
        'incline_machine_press',
        'Incline Machine Press',
        3,
        8,
        12,
      ),
      ProgramExercise('seated_cable_row', 'Seated Cable Row', 3, 8, 12),
    ]),
    ProgramBlock(90, [
      ProgramExercise(
        'single_arm_cable_pulldown',
        'Single-Arm Cable Pulldown',
        3,
        10,
        15,
        eachSide: true,
      ),
    ]),
    ProgramBlock(60, [
      ProgramExercise('machine_chest_fly', 'Machine Chest Fly', 3, 12, 15),
      ProgramExercise('cable_lateral_raise', 'Cable Lateral Raise', 3, 15, 20),
    ]),
  ]),
  ProgramSession('saturday', 'Saturday', 'Legs + abs + conditioning', [
    ProgramBlock(120, [ProgramExercise('hack_squat', 'Hack Squat', 3, 8, 12)]),
    ProgramBlock(75, [
      ProgramExercise('leg_extension', 'Leg Extension', 3, 12, 15),
      ProgramExercise(
        'leg_curl',
        'Seated/Lying Leg Curl',
        3,
        10,
        15,
        alternatives: ['seated_leg_curl', 'lying_leg_curl'],
      ),
    ]),
    ProgramBlock(60, [
      ProgramExercise('machine_calf_raise', 'Machine Calf Raise', 3, 12, 20),
      ProgramExercise('ab_wheel_rollout', 'Ab-Wheel Rollout', 3, 6, 12),
    ]),
  ]),
];
