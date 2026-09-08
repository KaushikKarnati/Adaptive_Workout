part of 'exercise_eligibility.dart';

enum _SafetyGateDisposition { continueEvaluation, safetyStop }

final class _SafetyGateDecision {
  _SafetyGateDecision({
    required this.disposition,
    required List<EligibilityIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final _SafetyGateDisposition disposition;
  final List<EligibilityIssue> issues;
}

final class _SafetyGate {
  const _SafetyGate();

  _SafetyGateDecision evaluate({
    required EligibilitySafetyState safetyState,
    required Set<String> candidateExerciseIds,
    required String constraintSnapshotSha256,
  }) {
    if (safetyState.kind == EligibilitySafetyStateKind.stop) {
      return _SafetyGateDecision(
        disposition: _SafetyGateDisposition.safetyStop,
        issues: <EligibilityIssue>[
          EligibilityIssue._(EligibilityReasonCode.painReportRequiresStop, {
            'exerciseId': safetyState.affectedExerciseId,
          }),
        ],
      );
    }

    final applicableRestrictions = safetyState.restrictions.where(
      (restriction) =>
          candidateExerciseIds.contains(restriction.exerciseId) &&
          restriction.constraintSnapshotSha256 == constraintSnapshotSha256,
    );
    final issues = applicableRestrictions
        .map(
          (restriction) => EligibilityIssue._(
            EligibilityReasonCode.unresolvedSafetyIncident,
            {
              'exerciseId': restriction.exerciseId!,
              'originatingRecommendationId':
                  restriction.originatingRecommendationId!,
              'regressionTestReference': restriction.regressionTestReference!,
              'reviewReference': restriction.reviewReference!,
              'reviewState': restriction.reviewState!.name,
            },
          ),
        )
        .toList();
    if (issues.isNotEmpty) {
      return _SafetyGateDecision(
        disposition: _SafetyGateDisposition.safetyStop,
        issues: _sortedEligibilityIssues(issues),
      );
    }

    return _SafetyGateDecision(
      disposition: _SafetyGateDisposition.continueEvaluation,
      issues: const [],
    );
  }
}
