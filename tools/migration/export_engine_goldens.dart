// Run from the repository root with Dart while the reference is available.
// These are synthetic fixtures, not approved production catalog records.
import 'dart:convert';
import 'dart:io';
import '../../test/support/session_composer_fixture.dart';
import '../../lib/domain/workout/owner_program.dart';

void main() {
  final output = StringBuffer(
    '// Generated from the preserved Dart ComposerFixture by tools/migration/export_engine_goldens.dart.\n'
    '// Synthetic test data only; never bundle in the application.\n'
    'enum EngineComposerGoldens {\n'
    '    static let snapshots: [String: String] = [\n',
  );
  for (final session in ownerProgram) {
    final fixture = ComposerFixture(session.id);
    final snapshot = fixture.composer.compose(fixture.input()).snapshot!;
    output.writeln('        ${jsonEncode(session.id)}: #"${snapshot.encode()}"#,');
  }
  output.write('    ]\n}\n');
  File('native/Packages/WorkoutCore/Tests/WorkoutCoreTests/EngineComposerGoldens.swift')
      .writeAsStringSync(output.toString());
}
