# 0017 — Delete an individual manual workout

Status: owner-requested, September 24, 2026.

The manual workout log exposes deletion on each history row and inside an open
workout, including unfinished drafts. A confirmation identifies the original day,
workout title, saved timestamp and record count. Cancel does not write. Deletion
is permanent within the app; there is no undo or bulk deletion in this slice.

The controller submits an explicit profile, workout ID, expected revision and
stable action ID. It acknowledges only after the transaction and a reload confirm
absence. An uncertain result retains the same action for retry and blocks other
mutations. Concurrent revisions reject deletion instead of deleting newer work
that the user did not review.

Manual SQLite schema 2 adds a minimal `deletions` table transactionally when
upgrading schema 1. Existing logs, prescriptions, revisions and receipts retain
their exact payloads during migration. Unsupported newer versions still fail
without erasing data.

Deletion atomically removes the current log, all correction revisions and every
associated receipt containing workout payloads. The transaction retains only
opaque profile/workout/action IDs and expected revision in `deletions`, so a lost
acknowledgement is retryable and a stale original-start action cannot resurrect
the deleted workout. Changed delete actions conflict. All queries and deletions
are profile-scoped and parameterized. This is logical application deletion, not
an assertion of forensic erasure of device storage or external device backups.

This applies to manual records, which never feed adaptive progression. It does
not delete practice logs, verified setup or generated recommendation history, or
implement the broader Day 6 cross-store deletion contract. No actual owner workout
is deleted during development; native tests use isolated fixture databases.
