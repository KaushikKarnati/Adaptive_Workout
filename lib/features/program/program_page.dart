import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../domain/workout/owner_program.dart';
import '../../ui/app_components.dart';
import '../setup/training_setup_page.dart';
import 'program_logging_page.dart';

class ProgramPage extends StatelessWidget {
  const ProgramPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Program')),
      body: SafeArea(
        child: AppContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              const AppPageHeader(
                eyebrow: 'Approved plan · Preview',
                title: 'Your five-day program',
                subtitle: 'Working sets target 2–3 reps in reserve.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProgramLoggingPage(),
                  ),
                ),
                child: const Text('Log workouts / history'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TrainingSetupPage(),
                  ),
                ),
                child: const Text('Training setup / starting loads'),
              ),
              const SizedBox(height: 20),
              const AppNotice(
                text: 'Manual logging is available. Weight recommendations still require verified equipment, baselines and resolved warm-up setups.',
              ),
              const SizedBox(height: 28),
              const AppSectionHeader(title: 'Sessions'),
              const SizedBox(height: 12),
              for (final (index, session) in ownerProgram.indexed) ...[
                _SessionCard(session: session, number: index + 1),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.leaf_arrow_circlepath,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Thursday · Recovery',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No lifting. Easy walking and optional light mobility. Your supplied plan includes 8,000–10,000 total steps.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'These day labels preserve your plan; automatic rescheduling is not enabled.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.number});

  final ProgramSession session;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('program_${session.id}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: ExcludeSemantics(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              number.toString().padLeft(2, '0'),
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
        title: Text(session.day, style: theme.textTheme.titleMedium),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            session.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        children: [
          for (final (index, block) in session.blocks.indexed) ...[
            if (index > 0) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),
            ],
            if (block.isSuperset) ...[
              Text(
                'Superset · 3 paired rounds',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (final exercise in block.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${exercise.name}\n${exercise.sets} × ${exercise.minReps}–${exercise.maxReps}${exercise.eachSide ? ' each side' : ''}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            Text(
              'Rest ${block.restSeconds} sec${block.isSuperset
                  ? ' after both exercises'
                  : block.exercises.single.eachSide
                  ? ' after both sides'
                  : ' between sets'}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (session.id == 'wednesday')
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: AppNotice(
                text: 'Shoulder press: machine preferred, then dumbbells; each requires its own verified setup and baseline.',
              ),
            ),
          if (session.id == 'friday')
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: AppNotice(
                text: 'Pull-ups: verified unassisted baseline first, otherwise a verified assisted-machine baseline.',
              ),
            ),
          if (session.id == 'saturday')
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: AppNotice(
                text: 'Leg curl: seated preferred, then lying. Optional five-minute finisher remains off until its rules are approved.',
              ),
            ),
        ],
      ),
    );
  }
}
