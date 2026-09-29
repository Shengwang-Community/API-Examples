# HarmonyOS Agent Guide

This platform contains one ArkTS/ArkUI project with a small C++ NAPI extension. Read
`ARCHITECTURE.md` and `APIExample/AGENTS.md` before changing examples or dependencies.

The project targets HarmonyOS NEXT (HarmonyOS 5.0, API 12+), not earlier Android-compatible
HarmonyOS versions. Keep its SDK version and build scripts independent of the
other platforms. Never commit a local HAR, signing file, App ID, App Certificate, or Token.
GitHub PR checks cover scripts and SDK packaging with offline fixtures, not ArkTS/C++
compilation. Verify app builds separately with DevEco Studio or a real Jenkins QA build.
