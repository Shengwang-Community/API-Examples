# HarmonyOS APIExample Architecture

## Project

`entry/` is an ArkUI Stage module targeting HarmonyOS 5.0 (API 12) or later. The
`@shengwang/rtc-full` dependency is declared in `entry/oh-package.json5` and resolved
from the ignored `entry/libs/AgoraRtcSdk.har`. `sdk-release.env` pins the public SDK ZIP
and `prepare_sdk.sh` verifies its checksum and HAR version.

## Examples

- `entry/src/main/ets/pages/basic/` contains channel join examples.
- `entry/src/main/ets/pages/advance/` contains individual advanced API examples.
- `entry/src/main/ets/pages/Data.ets` registers the basic and advanced menu entries.
- `entry/src/main/resources/base/profile/main_pages.json` registers navigable pages.
- `entry/src/main/resources/{base,en_US,zh_CN}/element/string.json` provides labels.
- `entry/src/main/cpp/` contains the optional native media extension and NAPI bridge.

Follow the nearest example for permissions and UI state updates. Each case creates its
own `RtcEngine`, stops its media work and leaves the channel before `RtcEngine.destroy()`;
late callbacks must not update a closed page. Keep SDK callbacks and UI state changes
thread-safe. Check the current SDK declarations before adding or changing an API call.

## Builds

DevEco Studio builds the `entry` module. GitHub PR checks validate scripts and SDK
packaging with offline fixtures, not ArkTS/C++ compilation. Developers can run
`cloud_build.sh` with `HARMONY_UNSIGNED_ONLY=true` to compile an unsigned HAP locally;
without that mode, Jenkins uses its external signing files to produce a signed HAP.
`.github/ci/build/build_hmos.sh` handles release source packaging. None of these build
outputs or signing assets belongs in Git.
