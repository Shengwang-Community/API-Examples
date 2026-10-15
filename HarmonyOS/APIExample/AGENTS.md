# HarmonyOS APIExample Agent Guide

Read `ARCHITECTURE.md` before changing an example. Use ArkTS and the project's existing
ArkUI components. Check `entry/src/main/ets/pages/Data.ets` and
`entry/src/main/resources/base/profile/main_pages.json` to find reachable cases.

The project uses `@shengwang/rtc-full` 4.6.3 from `sdk-release.env` and the local HAR
path in `entry/oh-package.json5`. Run `bash HarmonyOS/APIExample/prepare_sdk.sh` from the
repository root before a build. Never commit the ignored HAR or generated files.

Each case owns its engine: leave the channel, stop case-owned media, and destroy the engine
when the page closes. Guard asynchronous callbacks against disposed pages and keep UI state
updates on the appropriate ArkUI thread. Register new pages in both `Data.ets` and
`main_pages.json`, with resource strings in all existing locales.

`KeyCenter.ets` must not contain a real App ID or App Certificate in a commit. PR checks
run without DevEco, RTC SDK downloads, or signing secrets; they do not compile this app.
For token-required samples, use a
developer-controlled server; never send an App Certificate from the client.

The project skills under `.agents/skills/` cover case discovery, implementation, and review.
