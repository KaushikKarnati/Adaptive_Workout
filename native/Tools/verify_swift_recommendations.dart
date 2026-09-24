import 'dart:convert';
import 'dart:io';
import 'package:adaptive_workout/domain/recommendations/recommendation_history.dart';

// Run against a synthetic export produced with RECOMMENDATION_PARITY_EXPORT set
// on the native recommendation repository tests, never a personal database.
void main(List<String> args) {
  final values = jsonDecode(File(args.single).readAsStringSync()) as Map<String, dynamic>;
  for (final payload in values['recommendations'] as List) {
    if (RecommendationSnapshot.decode(payload as String).encode() != payload) {
      throw StateError('Recommendation canonical bytes changed');
    }
  }
  for (final payload in values['occurrences'] as List) {
    final occurrence = GeneratedOccurrence.decode(payload as String);
    if (occurrence.encode() != payload || !occurrence.stoppedSlots.contains('press')) {
      throw StateError('Occurrence or sticky safety stop changed');
    }
  }
  print('Swift synthetic recommendation and occurrence exports accepted by Dart.');
}
