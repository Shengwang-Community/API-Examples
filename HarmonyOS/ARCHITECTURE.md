# HarmonyOS Platform Architecture

`APIExample/` is the HarmonyOS NEXT sample app. ArkUI screens live under
`APIExample/entry/src/main/ets/pages/basic/` and `pages/advance/`; the optional raw media
extension lives in `APIExample/entry/src/main/cpp/`.

The SDK dependency is `@shengwang/rtc-full`, a local HAR extracted from the fixed public
SDK ZIP by `APIExample/prepare_sdk.sh`. The HAR and generated build directories are ignored.
GitHub CI checks the SDK scripts and packaging with offline fixtures, but does not compile
the app. Jenkins downloads a selected SDK ZIP, embeds this project in its source package,
builds a debug HAP, and signs it with externally configured development credentials for QA.

See `APIExample/ARCHITECTURE.md` for example registration and lifecycle rules.
