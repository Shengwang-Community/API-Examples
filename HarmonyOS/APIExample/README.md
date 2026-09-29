# Shengwang RTC API Examples for HarmonyOS

[English](README.md) | [中文](README.zh.md)

This project uses Shengwang RTC SDK 4.6.3 and targets HarmonyOS NEXT (HarmonyOS 5.0, API 12 or later). It does not support earlier Android-compatible HarmonyOS releases.

## Requirements

- DevEco Studio with the HarmonyOS 5.0 SDK (API 12 or later)
- A compatible physical device for running the examples
- A Shengwang project App ID from the [console](https://console.shengwang.cn/)

## Get Started

1. From the repository root, run `bash HarmonyOS/APIExample/prepare_sdk.sh`. The script downloads the pinned [4.6.3 full SDK](https://download.shengwang.cn/sdk/release/Shengwang_Native_SDK_for_HarmonyOS_v4.6.3_FULL.zip), verifies its SHA-256 checksum and package version, and installs `entry/libs/AgoraRtcSdk.har`. The HAR is ignored by Git. If you already have a different local HAR, move it aside first or explicitly set `HARMONY_SDK_FORCE=1` to replace it.
2. Open `HarmonyOS/APIExample` in DevEco Studio and install project dependencies if prompted.
3. For a running app, set `AppID` in `entry/src/main/ets/common/KeyCenter.ets` to your App ID. Do not commit a real App ID. Keep `AppCertificate` empty: certificates belong on a token server, not in an app or this repository.
4. Configure your own local debug signing in DevEco Studio and run the `entry` module on a HarmonyOS NEXT device.

`TokenServerUrl` is defined in `entry/src/main/ets/util/TokenUtils.ets`. For certificate-enabled projects, replace it with a token service you control. The app posts `appId`, `channelName`, `uid`, and `expireSeconds` and expects a JSON response containing `token`. Keep the App Certificate on that server. When the URL is empty, examples use an empty token for projects without certificate authentication; the manual token example accepts a token entered on screen.

GitHub PR checks validate the SDK scripts and packaging with offline fixtures; they do not compile the HarmonyOS app. Build it with DevEco Studio before release. Release signing and source packaging run separately in Jenkins.

For problems with the samples, open an [issue](https://github.com/Shengwang-Community/API-Examples/issues). See the [HarmonyOS SDK resources](https://doc.shengwang.cn/doc/rtc/harmonyos/resources) for downloads and documentation.
