# Security and Privacy Baseline

## V1 threat surface

The proposed V1 stores workout and profile information locally and does not require an account or workout-generation server. This reduces exposure but does not remove risks involving device storage, exports, logs, dependencies, app permissions, and payments.

## Baseline requirements

- Collect only data required for product behavior.
- Core functionality must work without network access.
- Request no permission without a user-visible feature need.
- Keep secrets and signing materials outside source control.
- Prevent sensitive values from entering application logs or crash reports.
- Validate and safely parse all imports and deep links.
- Use platform billing through RevenueCat only when subscriptions are introduced.
- Provide understandable local-data export and deletion controls.
- Pin and audit dependencies through normal Flutter tooling and CI.
- Document every added network endpoint and transmitted field.
- Record the provenance, license, version, and integrity information for imported exercise-catalog content.
- Reject malformed catalog records and unsupported enum or unit values before they reach the domain engine.
- Treat pain, limitation, readiness, and workout-history data as sensitive health-adjacent information.
- Do not send sensitive profile or workout data to a remote recommendation service in V1.
- Request access only to approved health-data types at the point the related feature is enabled; denial or partial access must not block unrelated core functionality.
- Keep platform health data local unless a separately approved cloud integration documents its account, OAuth, retention, deletion, and transmitted-field behavior.
- Keep private-test progress photos outside the application; the two testers may voluntarily share photos with each other, but the app must not request photo-library access or store, import, analyze, or synchronize body images.

## Release gates

- Threat model reviewed
- Secret scan clean
- Static analysis clean
- Dependency review complete
- Export/import abuse cases tested
- Database migration and recovery tested
- iOS and Android permissions reviewed
- Privacy policy matches actual behavior
- Exercise content and media licenses permit the shipped commercial use

## Reddit TestFlight gate

Before recruiting TestFlight participants from Reddit, the Apple Health integration must complete permission, data-minimization, denial, partial-data, local-storage, deletion, and recommendation-rule review. The initial two-person build must remain functional without health-data access.
