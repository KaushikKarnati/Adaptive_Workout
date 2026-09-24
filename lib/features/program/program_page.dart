import 'package:flutter/material.dart';

import '../../domain/workout/owner_program.dart';
import 'program_logging_page.dart';
import '../setup/training_setup_page.dart';

class ProgramPage extends StatelessWidget {
  const ProgramPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your five-day program')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProgramLoggingPage(),
              ),
            ),
            child: const Text('Log workouts / history'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TrainingSetupPage(),
              ),
            ),
            child: const Text('Training setup / starting loads'),
          ),
          const Text(
            'Approved plan · Preview',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Working sets target 2–3 reps in reserve. Manual logging is available. Weight recommendations still require verified equipment, baselines and resolved warm-up setups.',
          ),
          const SizedBox(height: 16),
          for (final session in ownerProgram)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                key: Key('program_${session.id}'),
                title: Text(session.day),
                subtitle: Text(session.title),
                childrenPadding: const EdgeInsets.all(16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final block in session.blocks) ...[
                    if (block.isSuperset)
                      const Text(
                        'Superset · 3 paired rounds',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    for (final exercise in block.exercises)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${exercise.name}\n${exercise.sets} × ${exercise.minReps}–${exercise.maxReps}${exercise.eachSide ? ' each side' : ''}',
                        ),
                      ),
                    Text(
                      'Rest ${block.restSeconds} sec${block.isSuperset
                          ? ' after both exercises'
                          : block.exercises.single.eachSide
                          ? ' after both sides'
                          : ' between sets'}.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (session.id == 'wednesday')
                    const Text(
                      'Shoulder press: machine preferred, then dumbbells; each requires its own verified setup and baseline.',
                    ),
                  if (session.id == 'friday')
                    const Text(
                      'Pull-ups: verified unassisted baseline first, otherwise a verified assisted-machine baseline.',
                    ),
                  if (session.id == 'saturday')
                    const Text(
                      'Leg curl: seated preferred, then lying. Optional five-minute finisher remains off until its rules are approved.',
                    ),
                ],
              ),
            ),
          const Text(
            'Thursday · Recovery',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'No lifting. Easy walking and optional light mobility. Your supplied plan includes 8,000–10,000 total steps.',
          ),
          const SizedBox(height: 16),
          const Text(
            'These day labels preserve your plan; automatic rescheduling is not enabled.',
          ),
        ],
      ),
    ),
  );
}
