# Testing Strategy

> Scope update approved September 23, 2026: the product owner is the sole initial tester, using an iPhone 17 Pro. The September 29 target is a private offline build; broader supported-iOS compatibility remains required and must be verified separately. Earlier references below to two testers or an invited friend are superseded for this initial phase. Photo evaluation requiring a second evaluator remains unresolved and cannot be claimed complete. For week one, the owner-supplied program replaces the earlier strength-first plan and the old barbell benchmark goals are deferred. The three-month outcome period and existing safety/review gates are unchanged. See [the implementation tracker](IMPLEMENTATION_WEEK_ONE.md).


## Test layers

- Domain unit tests for every calculation and decision rule
- Property and boundary tests for numerical logic
- Repository and migration tests for persistence
- Widget tests for important user interactions
- Integration tests for critical workout flows
- Deterministic simulations for long-term engine behavior
- A three-month private device test by both initial testers before any broader beta, followed by supported-device testing before release
- A TestFlight readiness review covering adherence, strength, aesthetics or body composition, flexibility, reliability and usability, and recommendation safety, with no category omitted
- Adherence is calculated for each tester over the full three-month period and must be at least 80% of planned workouts; a carried-forward workout counts only when completed
- Strength-outcome reporting covers only the approved barbell back squat, flat barbell bench press, and conventional barbell deadlift without combining or silently substituting non-equivalent variants
- Estimated one-repetition-maximum reporting uses only sets that satisfy the approved eligibility rules and never requires a true maximum attempt
- Each tester must improve estimated one-repetition maximum by at least 5% in each approved benchmark over the three-month private test; reports must show each lift separately and must not imply that this result is guaranteed for other users
- Eligible-set estimates use `load × (1 + (completed repetitions + RIR) / 30)` with 2 to 10 completed repetitions, integer RIR from 0 to 3, and completed repetitions plus RIR from 3 to 10
- Eligibility tests reject warm-ups; missing or invalid load, repetitions, RIR, variation, or validity status; and assisted, failed, partial-range, pain-affected, or technique-invalid sets
- Load tests include the applicable bar weight, normalize units before calculation, compare unrounded values, and restrict rounding to display
- Baseline and final values for each lift are independently calculated as the median of all eligible estimates from the first and last three qualifying sessions, respectively, with at least two eligible sets required per session
- Insufficient comparable data returns `insufficient evidence`, and no exercise or materially different variation may be silently substituted
- Each tester's baseline and final comparison sets must use the same documented benchmark setup and technique standard
- Each tester satisfies the aesthetics criterion either by reducing average waist circumference by at least 2.5 cm or by keeping it within 1 cm of baseline while meeting the approved standardized-photo definition criterion
- Baseline and final waist values are each the average of three measurements collected using the approved site and consistent morning conditions; seven-day average body weight and smart-scale estimates are context only
- Standardized photos use matching front, side, and back views, lighting, camera distance, clothing, and poses; the testers may voluntarily share and assess them outside the app
- Private-test builds do not request photo-library access or store, import, analyze, or synchronize body images
- Matching baseline and final photos are randomly labeled A and B, and the evaluator submits all front, side, and back scores before learning which images are final
- Each view is scored `+1` for visibly more muscular definition, `0` for no meaningful difference, or `-1` for visibly less muscular definition; the photo path requires a total of at least `+2` for the final images and no `-1` view
- A comparison with inconsistent lighting, pose, distance, clothing, or framing is invalid and cannot contribute to the result; photo scoring is reported as subjective private-test evidence rather than scientific proof of body-composition change
- Flexibility reporting separately records the three-attempt average for each side of the ankle knee-to-wall and active straight-leg raise tests and the three-attempt average for shoulder flexion
- Flexibility improvement thresholds are 2 cm for the more restricted ankle, 5 degrees for the more restricted active straight-leg raise, and 8 degrees for shoulder flexion
- Each tester must exceed the threshold in at least two of the three flexibility measures without any measure worsening beyond its threshold; pain stops the affected test and follows the safety process
- Flexibility results must not be described as an injury diagnosis, proof of safer lifting, or evidence of reduced injury risk
- Baseline and final flexibility tests occur before training at approximately the same time of day, with no lifting or dedicated stretching earlier that day and with the same room, equipment, camera, evaluator, and setup
- Testing uses five minutes of easy walking, three practice attempts, and then three valid recorded attempts per side separated by 30 seconds; the average is reported
- Pain stops the affected test, observable compensation or setup error invalidates an attempt, and inability to collect three valid attempts returns `insufficient evidence`
- Knee-to-wall tests are barefoot with heel flat and knee tracking over the second toe; great-toe-to-wall distance is recorded to 0.1 cm at the farthest valid knee contact
- Active straight-leg raises use a supine position, secured straight non-test leg, straight test knee, relaxed ankle, and a fixed perpendicular side photo at the first knee bend, pelvic movement, or comfortable active end range
- Shoulder-flexion tests use a marked standing position 1.5 metres from a side-on shoulder-level camera, thumb upward, elbow straight, neutral trunk, and comfortable active end range without leaning or arching
- A tester within one improvement threshold of a documented valid measurement ceiling at baseline meets that measure by maintaining it without threshold-level decline; ceiling status and value must be recorded before testing and cannot arise from pain, compensation, or invalid setup
- No workout record may be lost, duplicated, or corrupted during the private test
- At least 98% of started workouts must complete without a crash, frozen screen, or app defect that prevents completion; the report must show both the numerator and denominator
- No critical or high-severity defect may remain unresolved before TestFlight readiness is approved
- Each tester must independently demonstrate starting and resuming a workout, logging and correcting a set, skipping work, requesting a supported replacement, completing a workout, and finding a previous workout
- Each tester records a one-to-five ease-of-use score after every completed workout, and at least 80% of each tester's completed workouts must score four or five
- A critical workflow fails usability review if it repeatedly causes confusion or requires external instructions, even when the numerical ease-of-use threshold passes
- Safety validation requires zero recommendations that violate an explicit limitation, excluded movement, unavailable-equipment constraint, or approved load or volume boundary
- Safety validation requires zero injuries or concerning events to which an app recommendation may reasonably have contributed and zero unresolved safety incidents at the end of the private test
- Pain or concerning-symptom input must stop the affected exercise, preserve the report, avoid automatic substitution, and avoid any load or volume increase
- Every unsafe or clearly unsuitable recommendation must become a preserved regression case; the affected path remains disabled until its cause is corrected, its regression test passes, and relevant deterministic simulations are replayed successfully
- Missing or invalid safety information must return an explicit no-recommendation result
- Tests and product language must not diagnose injury, prescribe rehabilitation, claim injury prevention, or imply medical clearance; symptom wording and escalation instructions require qualified clinical review before outside testing

## Algorithm test rule

Write expected input/output examples before implementing each rule. Include normal, boundary, invalid, missing-data, unit-conversion, and regression cases.

For exercise selection, tests must also cover:

- Identical explicit inputs produce identical recommendations
- Catalog iteration order does not change selection
- Stable tie-breaking between equally scored candidates
- Equipment and capability constraints remove ineligible exercises
- User exclusions are respected
- A supported exception produces an eligible engine-selected substitute
- Pain or concerning-symptom input follows the safety path rather than an ordinary substitution path
- No feasible candidate returns an explicit constrained or no-recommendation result
- Recommendation explanations match the rules that actually affected selection
- Eligibility and safety results remain understandable and operable with VoiceOver, Voice Control, 200-percent Larger Text, Reduce Motion, and Differentiate Without Color enabled
- Each result uses visible text and programmatic semantics rather than color, motion, sound, or an icon alone, and exposes one clear primary action
- Any future AI-assisted explanation preserves the deterministic status, reason codes, parameters, and safety action exactly; core filtering remains functional when AI is unavailable
- Historical recommendations remain interpretable using their recorded rule-set and catalog versions
- Catalog import is reproducible from the recorded wger snapshot identifier and produces the expected manifest and integrity digest
- Every imported record retains its wger base and translation IDs and UUIDs, API and page URLs, both attribution records, modification disclosure, and review status
- Records with missing, unsupported, or inconsistent license metadata are rejected; attribution output covers every shipped wger-derived record
- Imported HTML, active content, malformed URLs, unknown enums, invalid relationships, duplicate identifiers, and unsupported values are rejected or converted only through an explicitly tested allowlist
- Wger images and videos are absent from the V1 bundle, and core workouts require no live wger network access
- An imported record remains ineligible for recommendation until all required product, scientific, safety, equipment, and licensing reviews pass
- Catalog contract tests cover every required field, allowed enum, referenced identifier, null-versus-empty rule, length bound, uniqueness constraint, and selectable-state invariant in `EXERCISE_CATALOG.md`
- Property tests demonstrate that source-only and presentation-only fields cannot change exercise eligibility, ranking inputs, or recommendation output
- Reordering catalog entries or set-valued identifiers does not change the validated entity set or deterministic recommendation output
- Canonicalization tests sort entries and set-valued IDs before applying RFC 8785 and verify the expected lowercase SHA-256 digest from fixed fixtures
- Eligibility tests recompute the canonical explicit-constraint digest, reject a supplied mismatch before safety evaluation, and prove that each included constraint field affects the digest while excluded presentation and candidate fields do not
- Eligibility monotonicity tests prove that adding a hard exclusion cannot make an ineligible candidate eligible, and combined-failure tests retain every applicable reason in canonical order
- Boundary tests cover every maximum in `EXERCISE_TAXONOMIES.md`, including exact-limit acceptance, one-over rejection, entry-count limits, and decompressed-size limits
- Wger mapping fixtures cover every source muscle, equipment, category, language, and license ID listed in `WGER_MAPPING.md`; an upstream ID/name mismatch fails import instead of silently remapping
- A missed workout remains the next recommendation and shifts later workouts forward without changing their order
- Schedule behavior depends on an explicit requested date and history rather than the wall clock
- The initial two-person build remains functional without HealthKit authorization or health data

## Simulation rule

Simulation code must use seeded randomness, preserve reproducible cases, report distributions rather than only averages, and never silently change production rules.

## Initial quality commands

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```


## Approved week-one progression policy

`test/domain/progression/load_progression_policy_test.dart` covers the approved increase/hold/reduce examples, exact 5%/10% limits, equipment rounding bounds, missing or invalid set evidence, incomplete/corrected sessions, changed baselines, independent left/right results, profile/slot isolation, duplicate history, deterministic input ordering and explicit gate precedence. These synthetic policy tests do not establish that a real catalog or user is cleared, that history is durable, or that the future application integration cannot bypass validation. Those remain separate integration requirements.


## Practice storage acceptance

Pure domain/controller and widget tests cover strict input parsing, unknown RIR, retry after write/read failure, duplicate taps, completion failure and 200% text layout. The iPhone integration tests exercise actual SQLite transactions, correction history, profile isolation, uniqueness, unsupported-schema preservation, failed action-receipt rollback and close/reopen recovery. Run both integration files in README order with `--no-uninstall` to verify acknowledged records after the first app process terminates.

This is practice-only storage, not full real-program logging. A process killed while an uncommitted write is in flight, physical power loss, future forward migrations, device backup/file-protection behavior and VoiceOver interactions remain additional acceptance work. Do not represent injected transaction rollback as a completed physical-power-loss test.

### Physical release restart fallback

On September 23 the six native database tests passed, but the separate restart test's debug harness failed at Flutter/DDS/VM-service communication. For an independent check, build `tool/storage_recovery_probe.dart` in release mode with `--dart-define=STORAGE_PROBE_PHASE=seed`, install without uninstalling, and launch. Copy `Documents/practice_recovery_result.json` from the app container and require `phase=seed, passed=true`. Rebuild with phase `verify`, install without uninstalling, terminate the existing process and launch again. Require `phase=verify, passed=true`, three records and a different process ID. Both phases passed on the physical iPhone. The probe writes only its separate fixture database and result file. Always restore the regular `lib/main.dart` release build afterward. This is committed-write restart recovery; abrupt power loss remains unverified.

### Manual program logging

Run `flutter test integration_test/program_log_repository_test.dart -d <physical-device-id> --no-uninstall -v`. Its four native tests cover receipts/stale actions, correction history, profile isolation, transactional rollback, one-draft uniqueness, unsupported schema/prescription preservation, completion and post-completion corrections. Only `program_logging_fixture.sqlite` is removed.

For full process recovery, build `tool/program_storage_probe.dart` in release mode with `--dart-define=PROGRAM_PROBE_PHASE=seed`, install without uninstalling and launch. Copy `Documents/program_probe_result.json` and require seed/pass. Rebuild with phase `verify`, install and terminate/relaunch. Require verify/pass and a different process ID. The probe exercises only `program_release_probe.sqlite`, never production data. Restore `lib/main.dart` afterward. This tests acknowledged-write recovery, not physical power loss during a transaction.
