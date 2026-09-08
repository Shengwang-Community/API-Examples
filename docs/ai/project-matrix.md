# Project Matrix

Every cross-platform requirement must review all nine rows. Record the decision in the
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

## Scope Rules

- SDK version, dependency, credential plumbing, CI, and packaging changes require review of
  every row even when source behavior is unchanged.
- Audio-only behavior normally includes both audio projects and any full-SDK project that
  exposes the same case. Video-only behavior may mark audio projects `NOT_APPLICABLE`.
- Compose, SwiftUI, and Objective-C are independent implementations. Coverage does not
  inherit from Android Views or iOS UIKit.
- A platform-specific requirement still records decisions for the other projects.
- Read the selected project's `AGENTS.md` and `ARCHITECTURE.md` before editing.

## Automation Ownership

| Concern | Source of truth |
| --- | --- |
| Post-release unsigned compilation | `.github/workflows/compile.yml`; covers all nine projects using a placeholder App ID |
| Repository policy checks | `.github/workflows/repository-policy.yml` and local `.git-hooks/` |
| Release packaging | `.github/ci/build/`; executed by Jenkins |
| Gitee synchronization | `.github/workflows/gitee-sync.yml` calls `.github/ci/sync/`; Shengwang only, after `main` updates or manual dispatch |

Azure Pipelines configuration and dedicated legacy scripts have been removed from this
repository. External Azure definitions and GitHub integrations are managed separately;
removing repository files does not disable them or remove required status checks.
