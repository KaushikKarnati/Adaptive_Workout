# Retained source fixtures

`wger/pinned_snapshot.json` is synthetic importer test data. `wger/benchmark_snapshot_2026_09_08.json` preserves the pinned upstream three-exercise snapshot used by the previous implementation. The raw files were copied byte for byte during the Swift migration; Swift test fixtures embed the same content so the unit suite is self-contained.

See [benchmark provenance, attribution and review gates](../../docs/catalog/BENCHMARK_CATALOG_2026_09_08.md) for source authors, licenses, SHA-256 and modifications. Retaining these records does not approve their training instructions or activate them. All three production catalog entries remain disabled.

Migration generators are preserved in the Git reference checkpoint recorded in [migration evidence](../../docs/SWIFT_MIGRATION_STATUS.md). The maintained project does not need Dart to build or test.
