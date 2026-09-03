# Testing Strategy

## Test layers

- Domain unit tests for every calculation and decision rule
- Property and boundary tests for numerical logic
- Repository and migration tests for persistence
- Widget tests for important user interactions
- Integration tests for critical workout flows
- Deterministic simulations for long-term engine behavior
- Manual device testing before beta and release

## Algorithm test rule

Write expected input/output examples before implementing each rule. Include normal, boundary, invalid, missing-data, unit-conversion, and regression cases.

## Simulation rule

Simulation code must use seeded randomness, preserve reproducible cases, report distributions rather than only averages, and never silently change production rules.

## Initial quality commands

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
