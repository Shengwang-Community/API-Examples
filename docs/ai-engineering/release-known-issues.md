# API Examples Release Known Issues

Source: [API Example release issue list](https://confluence.agoralab.co/pages/viewpage.action?pageId=1898512518), Confluence page `1898512518`, version 13.

Use this file as the local release-risk checklist for API Examples. The Confluence page remains the source for team discussion history; this document keeps the actionable gates close to the repository workflow.

## Release Risk Checklist

| Area | Risk | Required Gate |
| --- | --- | --- |
| Build machines | Internal build machines can become unreachable when network changes alter the machine IP. | Before release packaging, verify Jenkins node connectivity and confirm node IP or label mapping when a build machine was recently offline. |
| Third-party beauty licenses | Third-party beauty licenses can expire, especially short-lived licenses. | Track license expiration dates and confirm renewal status before release branches are packaged. |
| Android extensions | Android Extension cases depend on SDK `include` files that must match the SDK update. | During SDK version bumps, verify extension `include` files are updated together with the SDK dependency. |
| iOS/macOS signing | Build-machine certificates can expire and break packaging. | Print or inspect certificate expiration during submission/release preparation; refresh certificates before expiration. |
| SDK versions | Projects can miss SDK version updates during release branch creation. | On every release branch, verify each platform project's SDK version against the release target. |
| Windows packaging | Windows scripts can fail because of path length limits or script permission issues. | Exercise Windows CI/build and dependency-install scripts after script path or packaging changes. |
| Pipeline integration | API Examples release pipelines depend on SDK release pipeline integration and CI team configuration. | Confirm domestic and overseas pipeline status before declaring release automation ready. |
| Manual release process | Release handbooks can drift from current scripts and pipeline behavior. | Review operation manuals when packaging scripts, signing, or pipeline entrypoints change. |
| Smoke testing time | Manual self-test time can exceed the release window. | Prefer a minimum automated smoke plan; record unsupported platforms or device coverage gaps explicitly. |

## Release Branch Gate

When creating or validating a release branch:

1. Confirm the target SDK version for each platform.
2. Check project-level SDK version files:
   - Android: each project's `gradle.properties` and dependency declarations.
   - iOS: each project's `Podfile`.
   - macOS: `macOS/Podfile`.
   - Windows: project SDK package or dependency location used by the build scripts.
3. Verify Android Extension `include` files when SDK headers are part of the case.
4. Run or review the relevant CI packaging path for changed platforms.
5. Record skipped build checks with owner, reason, and follow-up.

## Packaging Gate

Before declaring packaging ready:

1. Verify Jenkins nodes or build-machine labels are reachable.
2. Confirm signing certificates are valid for iOS and macOS package creation.
3. Confirm Windows scripts are not affected by path length or permission changes.
4. Confirm third-party license assets required by sample cases are valid.
5. Confirm API Examples pipeline integration status for the target distribution region.

## Automation Backlog

These items should be considered automation candidates rather than one-time manual reminders:

- Jenkins node reachability and IP/label drift detection.
- Third-party beauty license expiration reminder.
- Android Extension `include` freshness check during SDK bumps.
- SDK version consistency check across platform projects.
- iOS/macOS certificate expiration printing in CI.
- Windows path length and script permission preflight.
- Minimal Android/iOS device smoke, with BrowserStack or equivalent if approved.
