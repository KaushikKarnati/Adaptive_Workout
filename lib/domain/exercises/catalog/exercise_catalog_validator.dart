import 'exercise_catalog.dart';

final class CatalogValidationIssue {
  const CatalogValidationIssue(this.code, this.field);

  final String code;
  final String field;

  @override
  String toString() => '$code:$field';
}

final class ExerciseCatalogValidator {
  const ExerciseCatalogValidator({
    required this.importedAt,
    this.allowedEvidenceHosts = const <String>{},
  });

  final DateTime importedAt;
  final Set<String> allowedEvidenceHosts;

  static final RegExp _stableId = RegExp(r'^[a-z][a-z0-9_]{1,63}$');
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _forbiddenMarkup = RegExp(r'<[^>]*>');
  static final RegExp _urlText = RegExp(r'https?://');
  static final RegExp _forbiddenControl = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u202A-\u202E\u2066-\u2069]',
  );
  static final RegExp _forbiddenControlExceptLineFeed = RegExp(
    r'[\x00-\x09\x0B-\x1F\x7F-\x9F\u202A-\u202E\u2066-\u2069]',
  );

  static const Set<String> movementPatternIds = <String>{
    'squat',
    'hinge',
    'lunge',
    'horizontal_push',
    'vertical_push',
    'horizontal_pull',
    'vertical_pull',
    'loaded_carry',
    'elbow_flexion',
    'elbow_extension',
    'knee_flexion',
    'knee_extension',
    'hip_abduction',
    'hip_adduction',
    'shoulder_abduction',
    'shoulder_external_rotation',
    'calf_raise',
    'trunk_flexion',
    'trunk_extension',
    'trunk_rotation',
    'anti_extension',
    'anti_rotation',
    'anti_lateral_flexion',
    'mobility',
  };

  static const Set<String> muscleIds = <String>{
    'chest',
    'lats',
    'upper_back',
    'trapezius',
    'front_deltoids',
    'side_deltoids',
    'rear_deltoids',
    'biceps',
    'triceps',
    'forearms_grip',
    'abdominals',
    'obliques',
    'spinal_erectors',
    'quadriceps',
    'hamstrings',
    'glutes',
    'hip_adductors',
    'hip_abductors',
    'calves',
  };

  static const Set<String> equipmentIds = <String>{
    'bodyweight_space',
    'exercise_mat',
    'standard_barbell',
    'ez_curl_bar',
    'weight_plates',
    'power_rack',
    'flat_bench',
    'adjustable_bench',
    'dumbbells',
    'kettlebells',
    'stability_ball',
    'cable_station',
    'pull_up_station',
    'dip_station',
    'smith_machine',
    'leg_press_machine',
    'hack_squat_machine',
    'leg_extension_machine',
    'leg_curl_machine',
    'chest_press_machine',
    'shoulder_press_machine',
    'row_machine',
    'lat_pulldown_machine',
    'pec_fly_reverse_fly_machine',
    'hip_abduction_adduction_machine',
    'calf_raise_machine',
    'plate_loaded_machine',
    'resistance_bands',
    'cardio_machine',
  };

  static const Set<String> equipmentCapabilityIds = <String>{
    'safety_arms',
    'adjustable_height',
    'adjustable_angle',
    'independent_arms',
    'dual_cable',
    'high_pulley',
    'low_pulley',
    'straight_bar_attachment',
    'rope_attachment',
    'single_handle_attachment',
    'ankle_strap_attachment',
    'weight_assistance',
    'incremental_loading',
  };

  static const Set<String> functionalCapabilityIds = <String>{
    'standing_supported',
    'standing_unsupported',
    'seated_supported',
    'supine_position',
    'prone_position',
    'floor_transfer',
    'overhead_arm_position',
    'front_rack_position',
    'bar_on_back_position',
    'single_leg_support',
    'deep_knee_flexion',
    'loaded_hip_hinge',
    'sustained_grip',
  };

  static const Set<String> limitationConflictIds = <String>{
    'avoid_overhead_arm_position',
    'avoid_front_rack_position',
    'avoid_bar_on_back_position',
    'avoid_floor_transfer',
    'avoid_prone_position',
    'avoid_single_leg_support',
    'avoid_deep_knee_flexion',
    'avoid_loaded_hip_hinge',
    'avoid_sustained_grip',
  };

  static const Map<String, String> licenseUrls = <String, String>{
    'cc0-1.0': 'https://creativecommons.org/publicdomain/zero/1.0/',
    'cc-by-4.0': 'https://creativecommons.org/licenses/by/4.0/',
    'cc-by-sa-3.0': 'https://creativecommons.org/licenses/by-sa/3.0/',
    'cc-by-sa-4.0': 'https://creativecommons.org/licenses/by-sa/4.0/',
  };

  List<CatalogValidationIssue> validate(ExerciseCatalogEntry entry) {
    final issues = <CatalogValidationIssue>[];
    void issue(String code, String field) =>
        issues.add(CatalogValidationIssue(code, field));

    if (!_stableId.hasMatch(entry.id)) {
      issue('invalid_id', 'id');
    }
    if (entry.wgerBaseId < 1) {
      issue('invalid_positive_integer', 'wgerBaseId');
    }
    if (entry.wgerTranslationId < 1) {
      issue('invalid_positive_integer', 'wgerTranslationId');
    }
    if (!_uuid.hasMatch(entry.wgerBaseUuid)) {
      issue('invalid_uuid', 'wgerBaseUuid');
    }
    if (!_uuid.hasMatch(entry.wgerTranslationUuid)) {
      issue('invalid_uuid', 'wgerTranslationUuid');
    }
    _validateWgerUrl(entry.wgerApiUrl, 'wgerApiUrl', issues);
    _validateWgerUrl(entry.wgerPageUrl, 'wgerPageUrl', issues);
    if (entry.sourceModifiedAt != null) {
      if (!_isSecondPrecisionUtc(entry.sourceModifiedAt!)) {
        issue('invalid_timestamp', 'sourceModifiedAt');
      } else if (entry.sourceModifiedAt!.isAfter(importedAt.toUtc())) {
        issue('future_timestamp', 'sourceModifiedAt');
      }
    }
    _validateText(entry.name, 'name', 80, issues);
    if (entry.aliases.length > 20) issue('too_many_values', 'aliases');
    for (final alias in entry.aliases) {
      _validateText(alias, 'aliases', 80, issues);
    }
    if (entry.instructions != null) {
      _validateText(
        entry.instructions!,
        'instructions',
        4000,
        issues,
        allowLineFeed: true,
      );
    }
    if (entry.language != 'en') issue('unsupported_language', 'language');
    _validateIds(
      entry.movementPatternIds,
      movementPatternIds,
      'movementPatternIds',
      1,
      4,
      issues,
    );
    _validateIds(
      entry.primaryMuscleIds,
      muscleIds,
      'primaryMuscleIds',
      1,
      8,
      issues,
    );
    _validateIds(
      entry.secondaryMuscleIds,
      muscleIds,
      'secondaryMuscleIds',
      0,
      12,
      issues,
    );
    if (entry.primaryMuscleIds
        .intersection(entry.secondaryMuscleIds)
        .isNotEmpty) {
      issue('overlapping_muscles', 'secondaryMuscleIds');
    }
    if (entry.equipmentRequirements.length > 8) {
      issue('too_many_values', 'equipmentRequirements');
    }
    final seenEquipment = <String>{};
    for (final requirement in entry.equipmentRequirements) {
      if (!equipmentIds.contains(requirement.equipmentId)) {
        issue('unknown_taxonomy_id', 'equipmentRequirements.equipmentId');
      }
      if (!seenEquipment.add(requirement.equipmentId)) {
        issue('duplicate_value', 'equipmentRequirements.equipmentId');
      }
      if (requirement.quantity < 1 || requirement.quantity > 8) {
        issue('out_of_range', 'equipmentRequirements.quantity');
      }
      _validateIds(
        requirement.capabilityIds,
        equipmentCapabilityIds,
        'equipmentRequirements.capabilityIds',
        0,
        8,
        issues,
      );
    }
    _validateIds(
      entry.capabilityIds,
      functionalCapabilityIds,
      'capabilityIds',
      0,
      32,
      issues,
    );
    _validateIds(
      entry.exclusionTagIds,
      limitationConflictIds,
      'exclusionTagIds',
      0,
      32,
      issues,
    );
    if (entry.variationGroupId != null &&
        !_stableId.hasMatch(entry.variationGroupId!)) {
      issue('invalid_id', 'variationGroupId');
    }
    _validateStableIds(
      entry.substitutionGroupIds,
      'substitutionGroupIds',
      8,
      issues,
    );
    _validateAttribution(entry.baseAttribution, 'baseAttribution', issues);
    _validateAttribution(
      entry.translationAttribution,
      'translationAttribution',
      issues,
    );
    if (entry.wasModified) {
      if (entry.modificationNote == null) {
        issue('required_when_modified', 'modificationNote');
      } else {
        _validateText(entry.modificationNote!, 'modificationNote', 500, issues);
      }
    } else if (entry.modificationNote != null) {
      issue('must_be_null', 'modificationNote');
    }
    for (final review in entry.reviews.indexed) {
      _validateReview(review.$2, 'reviews.${review.$1}', issues);
    }
    if (entry.availability == ExerciseAvailability.enabled) {
      if (entry.disabledReason != null) issue('must_be_null', 'disabledReason');
      if (entry.reviews.any(
        (review) => review.status != ReviewStatus.approved,
      )) {
        issue('enabled_without_approvals', 'availability');
      }
    } else if (entry.disabledReason == null) {
      issue('required_when_disabled', 'disabledReason');
    } else {
      _validateText(entry.disabledReason!, 'disabledReason', 500, issues);
    }
    return issues;
  }

  void _validateIds(
    Set<String> values,
    Set<String> allowed,
    String field,
    int minimum,
    int maximum,
    List<CatalogValidationIssue> issues,
  ) {
    if (values.length < minimum || values.length > maximum) {
      issues.add(CatalogValidationIssue('value_count_out_of_range', field));
    }
    if (values.any((value) => !allowed.contains(value))) {
      issues.add(CatalogValidationIssue('unknown_taxonomy_id', field));
    }
  }

  void _validateStableIds(
    Set<String> values,
    String field,
    int maximum,
    List<CatalogValidationIssue> issues,
  ) {
    if (values.length > maximum) {
      issues.add(CatalogValidationIssue('too_many_values', field));
    }
    if (values.any((value) => !_stableId.hasMatch(value))) {
      issues.add(CatalogValidationIssue('invalid_id', field));
    }
  }

  void _validateReview(
    CatalogReview review,
    String field,
    List<CatalogValidationIssue> issues,
  ) {
    if (review.status == ReviewStatus.pending) {
      if (review.reviewerId != null ||
          review.reviewedAt != null ||
          review.evidenceReference != null) {
        issues.add(
          CatalogValidationIssue('pending_review_has_decision', field),
        );
      }
      return;
    }
    if (review.reviewerId == null ||
        review.reviewedAt == null ||
        review.evidenceReference == null) {
      issues.add(CatalogValidationIssue('decided_review_incomplete', field));
      return;
    }
    if (!_stableId.hasMatch(review.reviewerId!)) {
      issues.add(CatalogValidationIssue('invalid_reviewer_id', field));
    }
    if (!_isSecondPrecisionUtc(review.reviewedAt!)) {
      issues.add(CatalogValidationIssue('invalid_timestamp', field));
    } else if (review.reviewedAt!.isAfter(importedAt.toUtc())) {
      issues.add(CatalogValidationIssue('future_timestamp', field));
    }
    _validateEvidenceReference(review.evidenceReference!, field, issues);
  }

  void _validateAttribution(
    CatalogAttribution value,
    String field,
    List<CatalogValidationIssue> issues,
  ) {
    final expectedUrl = licenseUrls[value.licenseId];
    if (expectedUrl == null) {
      issues.add(CatalogValidationIssue('unsupported_license', field));
    } else if (value.licenseUrl.toString() != expectedUrl) {
      issues.add(CatalogValidationIssue('license_url_mismatch', field));
    }
    _validateHttpsUrl(value.licenseUrl, field, issues, 'creativecommons.org');
    _validateWgerUrl(value.attributionSourceUrl, field, issues);
    if (value.licenseId != 'cc0-1.0' && value.licenseAuthor == null) {
      issues.add(CatalogValidationIssue('missing_license_author', field));
    }
    if (value.licenseAuthor != null) {
      _validateText(value.licenseAuthor!, field, 200, issues);
    }
    if (value.licenseTitle != null) {
      _validateText(value.licenseTitle!, field, 200, issues);
    }
  }

  void _validateWgerUrl(
    Uri value,
    String field,
    List<CatalogValidationIssue> issues,
  ) {
    _validateHttpsUrl(value, field, issues, 'wger.de');
  }

  void _validateEvidenceReference(
    String value,
    String field,
    List<CatalogValidationIssue> issues,
  ) {
    _validateText(value, field, 500, issues, allowUrl: true);
    final uri = Uri.tryParse(value);
    final isRepositoryDocument =
        value.startsWith('docs/') &&
        !value.contains('\\') &&
        !value.contains('//') &&
        uri != null &&
        !uri.hasScheme &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.pathSegments.every(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        );
    final isAllowedHttpsUrl =
        uri != null &&
        uri.scheme == 'https' &&
        allowedEvidenceHosts.contains(uri.host) &&
        !uri.hasFragment &&
        uri.userInfo.isEmpty &&
        uri.toString().length <= 2048 &&
        uri.toString().runes.every((rune) => rune <= 0x7f);
    if (!isRepositoryDocument && !isAllowedHttpsUrl) {
      issues.add(CatalogValidationIssue('invalid_evidence_reference', field));
    }
  }

  void _validateHttpsUrl(
    Uri value,
    String field,
    List<CatalogValidationIssue> issues,
    String host,
  ) {
    if (value.scheme != 'https' ||
        value.host != host ||
        value.hasFragment ||
        value.userInfo.isNotEmpty ||
        value.toString().length > 2048 ||
        !value.toString().runes.every((rune) => rune <= 0x7f)) {
      issues.add(CatalogValidationIssue('invalid_url', field));
    }
  }

  void _validateText(
    String value,
    String field,
    int maximum,
    List<CatalogValidationIssue> issues, {
    bool allowLineFeed = false,
    bool allowUrl = false,
  }) {
    final trimmed = value.trim();
    if (trimmed != value || value.isEmpty || value.runes.length > maximum) {
      issues.add(
        CatalogValidationIssue('invalid_text_length_or_whitespace', field),
      );
    }
    final controls = allowLineFeed
        ? _forbiddenControlExceptLineFeed
        : _forbiddenControl;
    if (controls.hasMatch(value) ||
        _forbiddenMarkup.hasMatch(value) ||
        (!allowUrl && _urlText.hasMatch(value))) {
      issues.add(CatalogValidationIssue('unsafe_text', field));
    }
  }

  bool _isSecondPrecisionUtc(DateTime value) =>
      value.isUtc && value.millisecond == 0 && value.microsecond == 0;
}
