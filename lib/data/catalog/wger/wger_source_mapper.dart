import 'dart:convert';

enum WgerImportOutcome { acceptedEnabled, acceptedDisabled, rejected }

final class WgerSnapshotValidationException implements Exception {
  const WgerSnapshotValidationException(this.code, this.field);

  final String code;
  final String field;

  @override
  String toString() => 'WgerSnapshotValidationException($code, $field)';
}

final class WgerAttributionCandidate {
  const WgerAttributionCandidate({
    required this.licenseId,
    required this.licenseUrl,
    required this.licenseAuthor,
    required this.licenseTitle,
    required this.attributionSourceUrl,
  });

  final String licenseId;
  final Uri licenseUrl;
  final String? licenseAuthor;
  final String? licenseTitle;
  final Uri attributionSourceUrl;
}

final class WgerEquipmentCandidate {
  const WgerEquipmentCandidate({
    required this.equipmentId,
    this.capabilityIds = const <String>{},
  });

  final String equipmentId;
  final Set<String> capabilityIds;
}

final class WgerMappedExerciseCandidate {
  const WgerMappedExerciseCandidate({
    required this.id,
    required this.wgerBaseId,
    required this.wgerBaseUuid,
    required this.wgerTranslationId,
    required this.wgerTranslationUuid,
    required this.wgerApiUrl,
    required this.wgerPageUrl,
    required this.sourceModifiedAt,
    required this.name,
    required this.aliases,
    required this.instructions,
    required this.primaryMuscleIds,
    required this.secondaryMuscleIds,
    required this.equipmentCandidates,
    required this.sourceCategoryId,
    required this.baseAttribution,
    required this.translationAttribution,
  });

  final String id;
  final int wgerBaseId;
  final String wgerBaseUuid;
  final int wgerTranslationId;
  final String wgerTranslationUuid;
  final Uri wgerApiUrl;
  final Uri wgerPageUrl;
  final DateTime? sourceModifiedAt;
  final String name;
  final Set<String> aliases;
  final String? instructions;
  final Set<String> primaryMuscleIds;
  final Set<String> secondaryMuscleIds;
  final List<WgerEquipmentCandidate> equipmentCandidates;
  final int sourceCategoryId;
  final WgerAttributionCandidate baseAttribution;
  final WgerAttributionCandidate translationAttribution;
}

final class WgerImportResult {
  const WgerImportResult({
    required this.sourceBaseId,
    required this.outcome,
    required this.reasonCodes,
    required this.candidate,
  });

  final int? sourceBaseId;
  final WgerImportOutcome outcome;
  final List<String> reasonCodes;
  final WgerMappedExerciseCandidate? candidate;
}

final class WgerSourceMapper {
  const WgerSourceMapper();

  static const Map<int, String> _categories = <int, String>{
    8: 'Arms',
    9: 'Legs',
    10: 'Abs',
    11: 'Chest',
    12: 'Back',
    13: 'Shoulders',
    14: 'Calves',
    15: 'Cardio',
  };
  static const Map<int, String> _muscles = <int, String>{
    1: 'Biceps brachii',
    2: 'Anterior deltoid',
    3: 'Serratus anterior',
    4: 'Pectoralis major',
    5: 'Triceps brachii',
    6: 'Rectus abdominis',
    7: 'Gastrocnemius',
    8: 'Gluteus maximus',
    9: 'Trapezius',
    10: 'Quadriceps femoris',
    11: 'Biceps femoris',
    12: 'Latissimus dorsi',
    13: 'Brachialis',
    14: 'Obliquus externus abdominis',
    15: 'Soleus',
  };
  static const Map<int, String> _equipment = <int, String>{
    1: 'Barbell',
    2: 'SZ-Bar',
    3: 'Dumbbell',
    4: 'Gym mat',
    5: 'Swiss Ball',
    6: 'Pull-up bar',
    7: 'none (bodyweight exercise)',
    8: 'Bench',
    9: 'Incline bench',
    10: 'Kettlebell',
    11: 'Resistance band',
    12: 'Cable machine',
  };
  static const Map<int, String> _licenses = <int, String>{
    1: 'CC-BY-SA 3',
    2: 'CC-BY-SA 4',
    3: 'CC0',
    4: 'CC-BY 4',
    5: 'ODbL',
  };
  static const Map<int, String> _muscleMappings = <int, String>{
    1: 'biceps',
    2: 'front_deltoids',
    4: 'chest',
    5: 'triceps',
    6: 'abdominals',
    7: 'calves',
    8: 'glutes',
    9: 'trapezius',
    10: 'quadriceps',
    11: 'hamstrings',
    12: 'lats',
    14: 'obliques',
    15: 'calves',
  };
  static const Map<int, (String, Set<String>)> _equipmentMappings =
      <int, (String, Set<String>)>{
        1: ('standard_barbell', <String>{}),
        2: ('ez_curl_bar', <String>{}),
        3: ('dumbbells', <String>{}),
        4: ('exercise_mat', <String>{}),
        5: ('stability_ball', <String>{}),
        6: ('pull_up_station', <String>{}),
        7: ('bodyweight_space', <String>{}),
        8: ('flat_bench', <String>{}),
        9: ('adjustable_bench', <String>{'adjustable_angle'}),
        10: ('kettlebells', <String>{}),
        11: ('resistance_bands', <String>{}),
        12: ('cable_station', <String>{}),
      };
  static const Map<int, (String, String)> _licenseMappings =
      <int, (String, String)>{
        1: ('cc-by-sa-3.0', 'https://creativecommons.org/licenses/by-sa/3.0/'),
        2: ('cc-by-sa-4.0', 'https://creativecommons.org/licenses/by-sa/4.0/'),
        3: ('cc0-1.0', 'https://creativecommons.org/publicdomain/zero/1.0/'),
        4: ('cc-by-4.0', 'https://creativecommons.org/licenses/by/4.0/'),
      };
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _unsafeInstructions = RegExp(
    r'<|>|https?://|[\x00-\x09\x0B-\x1F\x7F-\x9F\u202A-\u202E\u2066-\u2069]',
  );
  static final RegExp _rfc3339Timestamp = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-](\d{2}):(\d{2}))$',
  );

  List<WgerImportResult> mapPinnedSnapshot(String sourceBytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(sourceBytes);
    } on FormatException {
      throw const WgerSnapshotValidationException('invalid_json', 'root');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WgerSnapshotValidationException(
        'invalid_snapshot_root',
        'root',
      );
    }
    final List<Object?> exercises;
    try {
      _validateExactDictionary(decoded, 'categories', _categories);
      _validateExactDictionary(decoded, 'muscles', _muscles);
      _validateExactDictionary(decoded, 'equipment', _equipment);
      _validateExactDictionary(decoded, 'licenses', _licenses);
      _validateEnglishLanguage(decoded);
      exercises = _list(decoded, 'exercises');
    } on _RecordError catch (error) {
      throw WgerSnapshotValidationException(error.code, 'snapshot');
    }
    final results = exercises.map(_mapRecord).toList();
    results.sort((left, right) {
      final byId = (left.sourceBaseId ?? -1).compareTo(
        right.sourceBaseId ?? -1,
      );
      if (byId != 0) return byId;
      return left.reasonCodes.join(',').compareTo(right.reasonCodes.join(','));
    });
    return results;
  }

  WgerImportResult _mapRecord(Object? raw) {
    int? sourceBaseId;
    try {
      final record = _object(raw, 'exercise');
      sourceBaseId = _positiveInt(record, 'id');
      final baseUuid = _requiredUuid(record, 'uuid');
      final categoryId = _referenceId(record['category'], 'category');
      _requireKnownReference(
        categoryId,
        record['category'],
        _categories,
        'category',
      );

      final translations = _list(record, 'translations')
          .map((value) => _object(value, 'translations'))
          .where((value) => _isEnglishLanguageReference(value['language']))
          .toList();
      if (translations.length != 1) {
        throw const _RecordError('english_translation_cardinality');
      }
      final translation = translations.single;
      final translationId = _positiveInt(translation, 'id');
      final translationUuid = _requiredUuid(translation, 'uuid');
      final name = _requiredText(translation, 'name');
      final aliases = _mapAliases(translation);
      final reasons = <String>{
        'manual_classification_required',
        'manual_reviews_required',
      };
      final instructions = _mapInstructions(translation, reasons);
      final primaryMuscles = _mapMuscles(record, 'muscles', reasons);
      final secondaryMuscles = _mapMuscles(
        record,
        'muscles_secondary',
        reasons,
      );
      final equipment = _mapEquipment(record, reasons);
      final baseAttribution = _mapAttribution(
        record,
        sourceBaseId,
        isTranslation: false,
        reasons: reasons,
      );
      final translationAttribution = _mapAttribution(
        translation,
        translationId,
        isTranslation: true,
        reasons: reasons,
      );
      final modified = record['last_update_global'];
      final sourceModifiedAt = modified == null
          ? null
          : _utcTimestamp(modified, 'last_update_global');
      final candidate = WgerMappedExerciseCandidate(
        id: 'wger_${baseUuid.replaceAll('-', '')}',
        wgerBaseId: sourceBaseId,
        wgerBaseUuid: baseUuid,
        wgerTranslationId: translationId,
        wgerTranslationUuid: translationUuid,
        wgerApiUrl: Uri.parse(
          'https://wger.de/api/v2/exerciseinfo/$sourceBaseId/',
        ),
        wgerPageUrl: Uri.parse(
          'https://wger.de/en/exercise/$translationId/view',
        ),
        sourceModifiedAt: sourceModifiedAt,
        name: name,
        aliases: aliases,
        instructions: instructions,
        primaryMuscleIds: primaryMuscles,
        secondaryMuscleIds: secondaryMuscles,
        equipmentCandidates: equipment,
        sourceCategoryId: categoryId,
        baseAttribution: baseAttribution,
        translationAttribution: translationAttribution,
      );
      final sortedReasons = reasons.toList()..sort();
      return WgerImportResult(
        sourceBaseId: sourceBaseId,
        outcome: WgerImportOutcome.acceptedDisabled,
        reasonCodes: sortedReasons,
        candidate: candidate,
      );
    } on _RecordError catch (error) {
      return WgerImportResult(
        sourceBaseId: sourceBaseId,
        outcome: WgerImportOutcome.rejected,
        reasonCodes: <String>[error.code],
        candidate: null,
      );
    }
  }

  Set<String> _mapAliases(Map<String, dynamic> translation) {
    final aliases = <String>{};
    for (final raw in _list(translation, 'aliases')) {
      final alias = _requiredText(_object(raw, 'aliases'), 'alias');
      if (!aliases.add(alias)) throw const _RecordError('duplicate_alias');
    }
    return aliases;
  }

  String? _mapInstructions(
    Map<String, dynamic> translation,
    Set<String> reasons,
  ) {
    final raw = translation['description_source'];
    if (raw == null || raw == '') return null;
    if (raw is! String ||
        raw.trim() != raw ||
        _unsafeInstructions.hasMatch(raw)) {
      reasons.add('instructions_manual_review_required');
      return null;
    }
    return raw;
  }

  Set<String> _mapMuscles(
    Map<String, dynamic> record,
    String field,
    Set<String> reasons,
  ) {
    final mapped = <String>{};
    for (final raw in _list(record, field)) {
      final id = _referenceId(raw, field);
      _requireKnownReference(id, raw, _muscles, field);
      final value = _muscleMappings[id];
      if (value == null) {
        throw _RecordError('unsupported_muscle_$id');
      }
      mapped.add(value);
    }
    return mapped;
  }

  List<WgerEquipmentCandidate> _mapEquipment(
    Map<String, dynamic> record,
    Set<String> reasons,
  ) {
    final source = _list(record, 'equipment');
    if (source.isEmpty) reasons.add('equipment_review_empty_source');
    final mapped = <WgerEquipmentCandidate>[];
    final seen = <int>{};
    for (final raw in source) {
      final id = _referenceId(raw, 'equipment');
      _requireKnownReference(id, raw, _equipment, 'equipment');
      if (!seen.add(id)) throw const _RecordError('duplicate_equipment');
      final mapping = _equipmentMappings[id]!;
      mapped.add(
        WgerEquipmentCandidate(
          equipmentId: mapping.$1,
          capabilityIds: mapping.$2,
        ),
      );
      if (id == 8) reasons.add('bench_requirement_confirmation_required');
      if (id == 12) reasons.add('cable_capabilities_review_required');
    }
    mapped.sort((left, right) => left.equipmentId.compareTo(right.equipmentId));
    return mapped;
  }

  WgerAttributionCandidate _mapAttribution(
    Map<String, dynamic> source,
    int sourceId, {
    required bool isTranslation,
    required Set<String> reasons,
  }) {
    final licenseId = _referenceId(source['license'], 'license');
    _requireKnownReference(licenseId, source['license'], _licenses, 'license');
    final mapped = _licenseMappings[licenseId];
    if (mapped == null) throw _RecordError('unsupported_license_$licenseId');
    final author = _optionalText(source['license_author'], 'license_author');
    if (licenseId != 3 && author == null) {
      reasons.add('license_author_review_required');
    }
    final title = _optionalText(source['license_title'], 'license_title');
    return WgerAttributionCandidate(
      licenseId: mapped.$1,
      licenseUrl: Uri.parse(mapped.$2),
      licenseAuthor: author,
      licenseTitle: title,
      attributionSourceUrl: Uri.parse(
        isTranslation
            ? 'https://wger.de/en/exercise/$sourceId/view'
            : 'https://wger.de/api/v2/exerciseinfo/$sourceId/',
      ),
    );
  }

  void _validateExactDictionary(
    Map<String, dynamic> snapshot,
    String field,
    Map<int, String> expected,
  ) {
    final actual = <int, String>{};
    for (final raw in _list(snapshot, field)) {
      final value = _object(raw, field);
      final id = _positiveInt(value, 'id');
      final name = _requiredText(value, 'name');
      if (actual.containsKey(id)) {
        throw WgerSnapshotValidationException('duplicate_dictionary_id', field);
      }
      actual[id] = name;
    }
    if (actual.length != expected.length ||
        expected.entries.any((entry) => actual[entry.key] != entry.value)) {
      throw WgerSnapshotValidationException('dictionary_mismatch', field);
    }
  }

  void _validateEnglishLanguage(Map<String, dynamic> snapshot) {
    final ids = <int>{};
    final shortNames = <String>{};
    Map<String, dynamic>? english;
    for (final raw in _list(snapshot, 'languages')) {
      final language = _object(raw, 'languages');
      final id = _positiveInt(language, 'id');
      final shortName = _requiredText(language, 'short_name');
      if (!ids.add(id)) {
        throw const WgerSnapshotValidationException(
          'duplicate_dictionary_id',
          'languages',
        );
      }
      if (!shortNames.add(shortName)) {
        throw const WgerSnapshotValidationException(
          'duplicate_dictionary_name',
          'languages',
        );
      }
      if (id == 2) english = language;
    }
    if (english == null || english['short_name'] != 'en') {
      throw const WgerSnapshotValidationException(
        'dictionary_mismatch',
        'languages',
      );
    }
  }

  bool _isEnglishLanguageReference(Object? raw) {
    final id = _referenceId(raw, 'language');
    if (id != 2) return false;
    if (raw is Map<String, dynamic> &&
        raw.containsKey('short_name') &&
        raw['short_name'] != 'en') {
      throw const _RecordError('language_name_mismatch');
    }
    return true;
  }

  void _requireKnownReference(
    int id,
    Object? raw,
    Map<int, String> dictionary,
    String field,
  ) {
    if (!dictionary.containsKey(id)) throw _RecordError('unknown_${field}_id');
    if (raw is Map<String, dynamic> &&
        raw.containsKey('name') &&
        raw['name'] != dictionary[id]) {
      throw _RecordError('${field}_name_mismatch');
    }
  }

  int _referenceId(Object? raw, String field) {
    if (raw is int && raw > 0) return raw;
    if (raw is Map<String, dynamic>) return _positiveInt(raw, 'id');
    throw _RecordError('invalid_$field');
  }

  int _positiveInt(Map<String, dynamic> value, String field) {
    final result = value[field];
    if (result is! int || result < 1) throw _RecordError('invalid_$field');
    return result;
  }

  String _requiredUuid(Map<String, dynamic> value, String field) {
    final result = value[field];
    if (result is! String || !_uuid.hasMatch(result)) {
      throw _RecordError('invalid_$field');
    }
    return result;
  }

  String _requiredText(Map<String, dynamic> value, String field) {
    final result = value[field];
    if (result is! String || result.isEmpty || result.trim() != result) {
      throw _RecordError('invalid_$field');
    }
    return result;
  }

  String? _optionalText(Object? value, String field) {
    if (value == null || value == '') return null;
    if (value is! String || value.trim() != value) {
      throw _RecordError('invalid_$field');
    }
    return value;
  }

  DateTime _utcTimestamp(Object? value, String field) {
    if (value is! String) throw _RecordError('invalid_$field');
    final match = _rfc3339Timestamp.firstMatch(value);
    if (match == null || match.end != value.length) {
      throw _RecordError('invalid_$field');
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4]!);
    final minute = int.parse(match[5]!);
    final second = int.parse(match[6]!);
    final offsetHour = int.parse(match[7] ?? '0');
    final offsetMinute = int.parse(match[8] ?? '0');
    // DateTime.parse normalizes overflow. Reject it before converting zones.
    final calendarDate = DateTime.utc(year, month, day);
    if (calendarDate.year != year ||
        calendarDate.month != month ||
        calendarDate.day != day ||
        hour > 23 ||
        minute > 59 ||
        second > 59 ||
        offsetHour > 23 ||
        offsetMinute > 59) {
      throw _RecordError('invalid_$field');
    }
    final result = DateTime.tryParse(value);
    if (result == null) throw _RecordError('invalid_$field');
    final utc = result.toUtc();
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
  }

  List<Object?> _list(Map<String, dynamic> value, String field) {
    final result = value[field];
    if (result is! List<Object?>) throw _RecordError('invalid_$field');
    return result;
  }

  Map<String, dynamic> _object(Object? value, String field) {
    if (value is! Map<String, dynamic>) throw _RecordError('invalid_$field');
    return value;
  }
}

final class _RecordError implements Exception {
  const _RecordError(this.code);

  final String code;
}
