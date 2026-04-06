# Security Policy

## Supported Versions

This project is currently source-first and does not maintain long-term support branches. Security fixes are expected to land on `main`.

## Reporting A Vulnerability

If you discover a security issue:

1. Do not post full details in a public GitHub issue.
2. Use GitHub Private Vulnerability Reporting for the repository if it is enabled.
3. If private reporting is not enabled, contact the maintainer privately through GitHub before disclosing details publicly.

Please include:

- A clear description of the issue
- Reproduction steps
- Impact assessment
- Any relevant logs or screenshots with secrets redacted

## Sensitive Areas In This Project

Please report issues involving:

- Keychain credential access
- Token refresh and credential persistence
- Logging of auth-related data
- Provider requests that could expose tokens or account details
- Packaging or release artifacts that weaken local security expectations
