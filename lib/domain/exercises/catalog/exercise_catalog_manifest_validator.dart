import 'catalog_integrity.dart';
import 'exercise_catalog.dart';
import 'exercise_catalog_validator.dart';

final class ExerciseCatalogManifestValidator {
  const ExerciseCatalogManifestValidator({
    required this.importedAt,
    this.allowedEvidenceHosts = const <String>{},
  });

  final DateTime importedAt;
  final Set<String> allowedEvidenceHosts;

  static final RegExp _semanticVersion = RegExp(
    r'^(?:[0-9]|[1-9][0-9]{1,2})\.(?:[0-9]|[1-9][0-9]{1,2})\.(?:[0-9]|[1-9][0-9]{1,2})$',
  );
  static final RegExp _catalogVersion = RegExp(
    r'^[0-9]{4}\.(?:0[1-9]|1[0-2])\.(?:0[1-9]|[12][0-9]|3[01])\.(?:[1-9]|[1-9][0-9]{1,2})$',
  );
  static final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');

  List<CatalogValidationIssue> validate(
    ExerciseCatalogManifest manifest,
    List<ExerciseCatalogEntry> entries,
  ) {
    final issues = <CatalogValidationIssue>[];
    void issue(String code, String field) =>
        issues.add(CatalogValidationIssue(code, field));

    if (manifest.schemaVersion != '1.0.0') {
      issue('unsupported_schema_version', 'manifest.schemaVersion');
    }
    if (!_isValidCatalogVersion(manifest.catalogVersion)) {
      issue('invalid_catalog_version', 'manifest.catalogVersion');
    }
    if (manifest.taxonomyVersion != 'v2') {
      issue('unsupported_taxonomy_version', 'manifest.taxonomyVersion');
    }
    if (manifest.provider != 'wger') {
      issue('unsupported_provider', 'manifest.provider');
    }
    _validateUpstreamUrl(manifest.upstreamBaseUrl, issues);
    if (!_isSecondPrecisionUtc(manifest.retrievedAt) ||
        manifest.retrievedAt.toUtc().isAfter(importedAt.toUtc())) {
      issue('invalid_retrieved_at', 'manifest.retrievedAt');
    }
    if (manifest.sourceRevision != null &&
        (!_isPrintableAscii(manifest.sourceRevision!) ||
            manifest.sourceRevision!.isEmpty ||
            manifest.sourceRevision!.length > 128)) {
      issue('invalid_source_revision', 'manifest.sourceRevision');
    }
    if (manifest.entryCount < 1 || manifest.entryCount > 5000) {
      issue('entry_count_out_of_range', 'manifest.entryCount');
    }
    if (manifest.entryCount != entries.length) {
      issue('entry_count_mismatch', 'manifest.entryCount');
    }
    if (!_sha256.hasMatch(manifest.contentSha256)) {
      issue('invalid_sha256', 'manifest.contentSha256');
    }
    if (!_semanticVersion.hasMatch(manifest.importToolVersion)) {
      issue('unsupported_import_tool_version', 'manifest.importToolVersion');
    }

    _detectDuplicates(entries, issues);
    final entryValidator = ExerciseCatalogValidator(
      importedAt: importedAt,
      allowedEvidenceHosts: allowedEvidenceHosts,
    );
    for (final indexed in entries.indexed) {
      for (final entryIssue in entryValidator.validate(indexed.$2)) {
        issues.add(
          CatalogValidationIssue(
            entryIssue.code,
            'entries.${indexed.$1}.${entryIssue.field}',
          ),
        );
      }
    }

    final canonicalBytes = canonicalCatalogEntriesBytes(entries);
    if (canonicalBytes.length > 16 * 1024 * 1024) {
      issue('entries_payload_too_large', 'entries');
    }
    if (_sha256.hasMatch(manifest.contentSha256) &&
        sha256Hex(canonicalBytes) != manifest.contentSha256) {
      issue('integrity_digest_mismatch', 'manifest.contentSha256');
    }
    return issues;
  }

  void _detectDuplicates(
    List<ExerciseCatalogEntry> entries,
    List<CatalogValidationIssue> issues,
  ) {
    final ids = <String>{};
    final baseIds = <int>{};
    final baseUuids = <String>{};
    final translationIds = <int>{};
    final translationUuids = <String>{};
    final benchmarks = <Benchmark>{};
    for (final indexed in entries.indexed) {
      final entry = indexed.$2;
      void duplicate(bool added, String field) {
        if (!added) {
          issues.add(
            CatalogValidationIssue(
              'duplicate_value',
              'entries.${indexed.$1}.$field',
            ),
          );
        }
      }

      duplicate(ids.add(entry.id), 'id');
      duplicate(baseIds.add(entry.wgerBaseId), 'wgerBaseId');
      duplicate(baseUuids.add(entry.wgerBaseUuid), 'wgerBaseUuid');
      duplicate(
        translationIds.add(entry.wgerTranslationId),
        'wgerTranslationId',
      );
      duplicate(
        translationUuids.add(entry.wgerTranslationUuid),
        'wgerTranslationUuid',
      );
      if (entry.benchmark != null) {
        duplicate(benchmarks.add(entry.benchmark!), 'benchmark');
      }
    }
  }

  void _validateUpstreamUrl(Uri value, List<CatalogValidationIssue> issues) {
    if (value.scheme != 'https' ||
        value.host != 'wger.de' ||
        value.userInfo.isNotEmpty ||
        value.hasFragment ||
        value.toString().length > 2048 ||
        !value.toString().runes.every((rune) => rune <= 0x7f)) {
      issues.add(
        const CatalogValidationIssue('invalid_url', 'manifest.upstreamBaseUrl'),
      );
    }
  }

  bool _isSecondPrecisionUtc(DateTime value) =>
      value.isUtc && value.millisecond == 0 && value.microsecond == 0;

  bool _isValidCatalogVersion(String value) {
    if (!_catalogVersion.hasMatch(value)) return false;
    final parts = value.split('.');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    final parsed = DateTime.utc(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  bool _isPrintableAscii(String value) =>
      value.runes.every((rune) => rune >= 0x20 && rune <= 0x7e);
}
