# Repository Instructions

## Mission

Build an offline-first adaptive workout application that generates transparent, deterministic recommendations from approved product and training-science specifications.

## Read before changing code

1. This file.
2. `docs/ARCHITECTURE.md`.
3. The relevant specification under `docs/`.

If a requirement is ambiguous, identify the ambiguity. Do not invent product behavior or fitness science.

## Architecture rules

- Keep domain logic independent of Flutter widgets, databases, and network services.
- Widgets must not contain workout-generation or progression rules.
- Database access must occur through repositories, never directly from widgets.
- The workout engine must produce the same output for the same explicit inputs.
- Avoid unnecessary dependencies. Explain and obtain approval before adding one.
- Preserve offline operation for all core workout functionality.

## Security and privacy

- Never hardcode or commit credentials, tokens, signing keys, or personal secrets.
- Minimize collected user data, permissions, logging, and network access.
- Validate imported, exported, and user-entered data.
- Use parameterized database APIs.
- Do not log sensitive health or workout data in production.
- Do not weaken security controls to make a feature or test pass.

## Testing

- Every algorithmic rule requires unit tests.
- Every bug fix requires a regression test.
- Cover normal, boundary, invalid, and missing-data cases.
- Keep simulations separate from production logic.

Before declaring implementation complete, run when available:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Report commands that could not run and why. Never claim a check passed unless it ran successfully.

## Change discipline

- Work on one bounded feature at a time.
- Do not modify unrelated code.
- Inspect the final diff for regressions, security issues, and unnecessary complexity.
- Update relevant documentation when behavior or architecture changes.
- Prefer small, descriptive commits.

## Definition of done

- Approved behavior is implemented without unrelated changes.
- Tests cover the behavior and pass.
- Formatting and static analysis pass.
- No unexplained warnings or hardcoded secrets exist.
- Relevant documentation is current.
- Remaining risks and unverified assumptions are reported.
