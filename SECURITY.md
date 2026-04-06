# Security Policy

## Supported Versions

Security fixes are made in `main`.

## Reporting A Vulnerability

If you find a security issue:

1. Do not post full details in a public GitHub issue.
2. Use GitHub Private Vulnerability Reporting if it is available.
3. If private reporting is not available, contact the maintainer privately through GitHub before sharing details publicly.

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
- App packaging or release artifacts that weaken local security expectations
