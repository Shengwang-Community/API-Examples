# Project Matrix

Every cross-platform requirement must review all ten rows. Record the decision in the
change contract; this document defines the stable project inventory and dependency sources.

| Project | Path | SDK dependency | Project guidance |
| --- | --- | --- | --- |
| Android Views full | `Android/APIExample/` | `cn.shengwang.rtc:full-sdk`; version in `gradle.properties` | `Android/APIExample/AGENTS.md` |
| Android Views audio | `Android/APIExample-Audio/` | `cn.shengwang.rtc:voice-sdk`; version in `gradle.properties` | `Android/APIExample-Audio/AGENTS.md` |
| Android Compose | `Android/APIExample-Compose/` | `cn.shengwang.rtc:full-sdk`; version in `gradle.properties` | `Android/APIExample-Compose/AGENTS.md` |
| iOS UIKit full | `iOS/APIExample/` | `ShengwangRtcEngine_iOS` in `Podfile` | `iOS/APIExample/AGENTS.md` |
| iOS UIKit audio | `iOS/APIExample-Audio/` | `ShengwangAudio_iOS` in `Podfile` | `iOS/APIExample-Audio/AGENTS.md` |
| iOS SwiftUI | `iOS/APIExample-SwiftUI/` | `ShengwangRtcEngine_iOS` in `Podfile` | `iOS/APIExample-SwiftUI/AGENTS.md` |
| iOS Objective-C | `iOS/APIExample-OC/` | `ShengwangRtcEngine_iOS` in `Podfile` | `iOS/APIExample-OC/AGENTS.md` |
| macOS AppKit | `macOS/` | `ShengwangRtcEngine_macOS` in `Podfile` | `macOS/AGENTS.md` |
| Windows MFC | `windows/APIExample/` | Local `../../sdk` or public `Shengwang_Native_SDK_for_Windows_*_FULL.zip` | `windows/AGENTS.md` |
| HarmonyOS ArkUI | `HarmonyOS/APIExample/` | `@shengwang/rtc-full` from the pinned public 4.6.3 ZIP, installed as a local HAR | `HarmonyOS/APIExample/AGENTS.md` |

## Android SDK source

All three Android projects resolve `cn.shengwang.rtc` and `cn.shengwang.infra` exclusively
from [the official Shengwang Maven repository](https://download.shengwang.cn/maven/) when a local
`../../sdk` directory is absent. Repository routing is declared in each project's
`settings.gradle` or `settings.gradle.kts`; use the fixed `rtc_sdk_version` from
`gradle.properties`. Plugin and other third-party dependency repositories are separate.

The checked-in settings are included in source packages. Cloud build adapters and Gitee
synchronization do not inject an Aliyun Maven repository for RTC dependencies. Validate
Maven resolution without a local SDK and with a fresh dependency cache; compiling with a
bundled SDK does not validate the public repository.

## Scope Rules

- SDK version, dependency, credential plumbing, CI, and packaging changes require review of
  every row even when source behavior is unchanged.
- Audio-only behavior normally includes both audio projects and any full-SDK project that
  exposes the same case. Video-only behavior may mark audio projects `NOT_APPLICABLE`.
- Compose, SwiftUI, and Objective-C are independent implementations. Coverage does not
  inherit from Android Views or iOS UIKit.
- A platform-specific requirement still records decisions for the other projects.
- Read the selected project's `AGENTS.md` and `ARCHITECTURE.md` before editing.

## HarmonyOS SDK source

`HarmonyOS/APIExample/sdk-release.env` pins the public full SDK URL and SHA-256 digest.
`prepare_sdk.sh` extracts the HAR to the ignored `entry/libs/` directory and checks its
package version. Jenkins may pass an explicit `sdk_url` for QA builds; the GitHub
PR check uses offline SDK fixtures and never downloads the pinned SDK or uses signing credentials.

## Automation Ownership

| Concern | Source of truth |
| --- | --- |
| Main PR checks | `.github/workflows/compile.yml`; compiles Android, iOS, macOS, and Windows with a placeholder App ID; tests HarmonyOS SDK scripts/packaging offline without compiling the app |
| Repository policy checks | `.github/workflows/repository-policy.yml` and local `.git-hooks/` |
| Jenkins packaging | `.github/ci/build/`; includes development-signed HarmonyOS debug HAP and source ZIP for QA |
| Gitee synchronization | `.github/workflows/gitee-sync.yml` calls `.github/ci/sync/`; Shengwang only, after `main` updates or manual dispatch |

Azure Pipelines configuration and dedicated legacy scripts have been removed from this
repository. External Azure definitions and GitHub integrations are managed separately;
removing repository files does not disable them or remove required status checks.
