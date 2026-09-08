import 'dart:convert';
import 'dart:typed_data';

import 'exercise_catalog.dart';

List<int> canonicalCatalogEntriesBytes(List<ExerciseCatalogEntry> entries) {
  final sorted = [...entries]..sort((a, b) => a.id.compareTo(b.id));
  return canonicalJsonBytes(sorted.map(_entryJson).toList());
}

List<int> canonicalJsonBytes(Object? value) =>
    utf8.encode(_canonicalJson(value));

String sha256Hex(List<int> bytes) {
  final data = Uint8List.fromList(bytes);
  final bitLength = data.length * 8;
  final paddedLength = ((data.length + 9 + 63) ~/ 64) * 64;
  final padded = Uint8List(paddedLength)..setRange(0, data.length, data);
  padded[data.length] = 0x80;
  for (var index = 0; index < 8; index++) {
    padded[paddedLength - 1 - index] = (bitLength >>> (index * 8)) & 0xff;
  }

  final hash = Uint32List.fromList(const <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ]);
  const constants = <int>[
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  final words = Uint32List(64);
  for (var offset = 0; offset < padded.length; offset += 64) {
    for (var index = 0; index < 16; index++) {
      final start = offset + index * 4;
      words[index] =
          (padded[start] << 24) |
          (padded[start + 1] << 16) |
          (padded[start + 2] << 8) |
          padded[start + 3];
    }
    for (var index = 16; index < 64; index++) {
      final first =
          _rotateRight(words[index - 15], 7) ^
          _rotateRight(words[index - 15], 18) ^
          (words[index - 15] >>> 3);
      final second =
          _rotateRight(words[index - 2], 17) ^
          _rotateRight(words[index - 2], 19) ^
          (words[index - 2] >>> 10);
      words[index] = _add32(<int>[
        words[index - 16],
        first,
        words[index - 7],
        second,
      ]);
    }

    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];
    for (var index = 0; index < 64; index++) {
      final sum1 =
          _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
      final choice = (e & f) ^ ((~e) & g);
      final temp1 = _add32(<int>[
        h,
        sum1,
        choice,
        constants[index],
        words[index],
      ]);
      final sum0 =
          _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = _add32(<int>[sum0, majority]);
      h = g;
      g = f;
      f = e;
      e = _add32(<int>[d, temp1]);
      d = c;
      c = b;
      b = a;
      a = _add32(<int>[temp1, temp2]);
    }
    final values = <int>[a, b, c, d, e, f, g, h];
    for (var index = 0; index < 8; index++) {
      hash[index] = _add32(<int>[hash[index], values[index]]);
    }
  }
  return hash.map((value) => value.toRadixString(16).padLeft(8, '0')).join();
}

int _rotateRight(int value, int count) =>
    ((value >>> count) | (value << (32 - count))) & 0xffffffff;

int _add32(List<int> values) =>
    values.fold<int>(0, (sum, value) => (sum + value) & 0xffffffff);

String _canonicalJson(Object? value) {
  if (value == null || value is bool || value is int || value is String) {
    return jsonEncode(value);
  }
  if (value is List<Object?>) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  throw ArgumentError.value(value, 'value', 'Unsupported canonical JSON value');
}

Map<String, Object?> _entryJson(
  ExerciseCatalogEntry entry,
) => <String, Object?>{
  'id': entry.id,
  'wgerBaseId': entry.wgerBaseId,
  'wgerBaseUuid': entry.wgerBaseUuid,
  'wgerTranslationId': entry.wgerTranslationId,
  'wgerTranslationUuid': entry.wgerTranslationUuid,
  'wgerApiUrl': entry.wgerApiUrl.toString(),
  'wgerPageUrl': entry.wgerPageUrl.toString(),
  'sourceModifiedAt': _timestamp(entry.sourceModifiedAt),
  'name': entry.name,
  'aliases': _sortedByUnicodeScalar(entry.aliases),
  'instructions': entry.instructions,
  'language': entry.language,
  'movementPatternIds': _sorted(entry.movementPatternIds),
  'primaryMuscleIds': _sorted(entry.primaryMuscleIds),
  'secondaryMuscleIds': _sorted(entry.secondaryMuscleIds),
  'equipmentRequirements':
      ([...entry.equipmentRequirements]
            ..sort((a, b) => a.equipmentId.compareTo(b.equipmentId)))
          .map(
            (requirement) => <String, Object?>{
              'equipmentId': requirement.equipmentId,
              'quantity': requirement.quantity,
              'capabilityIds': _sorted(requirement.capabilityIds),
            },
          )
          .toList(),
  'laterality': entry.laterality.name,
  'trackingMode': switch (entry.trackingMode) {
    TrackingMode.loadReps => 'load_reps',
    TrackingMode.repsOnly => 'reps_only',
    TrackingMode.duration => 'duration',
    TrackingMode.distance => 'distance',
    TrackingMode.loadDistance => 'load_distance',
  },
  'capabilityIds': _sorted(entry.capabilityIds),
  'exclusionTagIds': _sorted(entry.exclusionTagIds),
  'variationGroupId': entry.variationGroupId,
  'substitutionGroupIds': _sorted(entry.substitutionGroupIds),
  'benchmark': switch (entry.benchmark) {
    Benchmark.barbellBackSquat => 'barbell_back_squat',
    Benchmark.flatBarbellBenchPress => 'flat_barbell_bench_press',
    Benchmark.conventionalBarbellDeadlift => 'conventional_barbell_deadlift',
    null => null,
  },
  'baseAttribution': _attributionJson(entry.baseAttribution),
  'translationAttribution': _attributionJson(entry.translationAttribution),
  'wasModified': entry.wasModified,
  'modificationNote': entry.modificationNote,
  'productReview': _reviewJson(entry.productReview),
  'scienceReview': _reviewJson(entry.scienceReview),
  'safetyReview': _reviewJson(entry.safetyReview),
  'equipmentReview': _reviewJson(entry.equipmentReview),
  'licenseReview': _reviewJson(entry.licenseReview),
  'availability': entry.availability.name,
  'disabledReason': entry.disabledReason,
};

Map<String, Object?> _attributionJson(CatalogAttribution value) =>
    <String, Object?>{
      'licenseId': value.licenseId,
      'licenseUrl': value.licenseUrl.toString(),
      'licenseAuthor': value.licenseAuthor,
      'licenseTitle': value.licenseTitle,
      'attributionSourceUrl': value.attributionSourceUrl.toString(),
    };

Map<String, Object?> _reviewJson(CatalogReview value) => <String, Object?>{
  'status': value.status.name,
  'reviewerId': value.reviewerId,
  'reviewedAt': _timestamp(value.reviewedAt),
  'evidenceReference': value.evidenceReference,
};

List<String> _sorted(Set<String> values) => values.toList()..sort();

List<String> _sortedByUnicodeScalar(Set<String> values) =>
    values.toList()..sort((left, right) {
      final leftRunes = left.runes.toList();
      final rightRunes = right.runes.toList();
      final commonLength = leftRunes.length < rightRunes.length
          ? leftRunes.length
          : rightRunes.length;
      for (var index = 0; index < commonLength; index++) {
        final comparison = leftRunes[index].compareTo(rightRunes[index]);
        if (comparison != 0) return comparison;
      }
      return leftRunes.length.compareTo(rightRunes.length);
    });

String? _timestamp(DateTime? value) =>
    value?.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');
