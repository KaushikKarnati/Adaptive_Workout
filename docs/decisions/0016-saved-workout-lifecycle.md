# 0016 — Saved-workout lifecycle orchestration

Status: implemented bounded backend slice, September 24, 2026.

`SavedWorkoutService` operates on existing generated occurrences through
`RecommendationHistoryRepository`. Resumption reloads the exact saved prescription
and corrected actuals. It never regenerates an interrupted session or reads manual
or practice records.

Set entry and completion prepare immutable actions with explicit timestamps,
action IDs and expected history/occurrence revisions. Commit uses the existing
transactional repository and then reloads validated state. Callers retain the
prepared action after an uncertain result and retry that exact payload. Concurrent
changes reject stale actions; callers must reload before preparing a new action.
After process restart, reload the durable occurrence before offering another action.
No success is reported on write or read failure.

Normal completion requires every prescribed working target to be recorded or
explicitly skipped under the existing domain contract. Explicit early finish
retains partial actuals without inventing missing sets. Both terminal states
advance the scoped program queue once because queue position is derived from
committed occurrences, rather than written to a second cursor. Corrections change
actual history revisions without consuming another queue entry. Persistent pain
stops remain governed by the existing occurrence validation.

Scheduling reads complete profile history and scopes sequence entries to the
stable program ID. An active occurrence in a different program blocks a new queue
lookup. The caller supplies ordered templates, selected weekdays, requested civil
date and a conversion of the last terminal instant to the user's civil date. The
next opportunity is strictly after that end date. No timezone package, UTC-date
assumption, missed-day advancement, or new exercise selection rule is introduced.

This service does not create or authorize an executable occurrence. Fresh safety,
rehearsal continuation, cross-store generation, target confirmation and live UI
wiring remain separate pending work. The current app still exposes manual logging;
this change must not be described as a fully connected adaptive workout app or a
completed Day 5 acceptance gate.

Validation includes application fixtures for resumption, completion/early finish,
retries after uncertain writes, concurrent revisions, calendar boundaries, scope
isolation and failures. A separate native SQLite integration fixture closes and
reopens the database around logging and early finish, then retries the terminal
action and checks the audit and next queue position. Database reopen tests do not
claim operating-system process-kill or power-loss coverage.
