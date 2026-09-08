# Release Risks

This file records verified repository-specific conditions that can change implementation or
validation decisions. Jenkins execution state, QA status, artifact URLs, and temporary
incidents belong in the release ticket rather than this document.

| Area | Verified risk | Required handling |
| --- | --- | --- |
| Public SDK availability | Release branches can reference an SDK version before Maven, CocoaPods, or the Windows download endpoint publishes it. | Use an approved local/internal SDK source for pre-release validation or record the public-source build as blocked. Run `.github/workflows/compile.yml` after the version reaches `main`. |
| Apple release contents | Shengwang iOS and macOS release archives install and retain complete Pods dependencies; they do not add a separate standalone SDK archive. | Verify both the workspace and retained Pods in Jenkins packaging output. Do not remove Pods when producing the final source archive. |
| Android native extensions | Optional extension projects use SDK headers and native assets outside the normal Maven dependency. | Review headers and matching native assets whenever the RTC SDK version changes. |
| Apple signing | Repository compilation disables signing and cannot prove that Jenkins signing certificates or profiles are valid. | Keep signing verification in the release pipeline and record its evidence in the release ticket. |
| Windows SDK layout | The local/public full SDK maps x86 files into `windows/APIExample/sdk/` and x86_64 files into `sdk/x64/`; the layout differs from the Agora repository. | Run `install.ps1` and MSBuild on a Windows worker after dependency or packaging changes. Do not copy Agora path assumptions. |
| Gitee synchronization | Only Shengwang mirrors GitHub content to Gitee, and the synchronization includes repository-specific transformations. | Keep the workflow limited to `main` updates or manual dispatch and validate transformation failures before pushing mirrored branches or tags. |
| Packaging versus compilation | GitHub Actions checks source compilation; `.github/ci/build/` owns distributable artifacts. | Do not report compile CI success as proof that release packages were produced correctly. |

Update this file only when the condition is reproducible from tracked code or current release
automation. Remove entries when the underlying condition no longer exists.
