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

## Release gates

- Threat model reviewed
- Secret scan clean
- Static analysis clean
- Dependency review complete
- Export/import abuse cases tested
- Database migration and recovery tested
- iOS and Android permissions reviewed
- Privacy policy matches actual behavior
