# HarmonyOS 声网 RTC API 示例

[English](README.md) | 中文

本工程使用声网 RTC SDK 4.6.3，面向 HarmonyOS NEXT（HarmonyOS 5.0，API 12 及以上），不兼容早期兼容 Android 的 HarmonyOS 版本。

## 环境准备

- 安装 HarmonyOS 5.0 SDK（API 12 及以上）的 DevEco Studio
- 用于运行示例的 HarmonyOS NEXT 真机
- 从[声网控制台](https://console.shengwang.cn/)获取项目 App ID

## 快速开始

1. 在仓库根目录运行 `bash HarmonyOS/APIExample/prepare_sdk.sh`。脚本下载固定版本的[声网 4.6.3 完整 SDK](https://download.shengwang.cn/sdk/release/Shengwang_Native_SDK_for_HarmonyOS_v4.6.3_FULL.zip)，校验 SHA-256 和 HAR 包版本，并放入 `entry/libs/AgoraRtcSdk.har`。HAR 不会被 Git 提交；若本地已有其他版本，请先将其移走，或显式设置 `HARMONY_SDK_FORCE=1` 覆盖。
2. 使用 DevEco Studio 打开 `HarmonyOS/APIExample`，按提示安装工程依赖。
3. 运行前将 `entry/src/main/ets/common/KeyCenter.ets` 中的 `AppID` 改为自己的 App ID，勿将真实值提交到仓库。`AppCertificate` 应保持为空；证书只能保存在自己的 Token 服务端。
4. 在 DevEco Studio 配置本地调试签名，然后在 HarmonyOS NEXT 真机上运行 `entry` 模块。

`TokenServerUrl` 定义在 `entry/src/main/ets/util/TokenUtils.ets` 中。对于启用证书鉴权的项目，请将它替换为自己控制的 Token 服务地址。应用提交 `appId`、`channelName`、`uid`、`expireSeconds`，服务返回包含 `token` 的 JSON；App 证书只保存在服务端。地址为空时，普通示例使用空 Token，手动 Token 示例可在页面输入 Token。

GitHub PR 只使用离线样例检查 SDK 脚本及打包逻辑，不编译鸿蒙工程。发版前请用 DevEco Studio 验证编译；Jenkins 另外负责发布签名及源码打包。

如有示例问题，请在[本仓库](https://github.com/Shengwang-Community/API-Examples/issues)提交 issue。下载和使用 SDK 请参见[声网 HarmonyOS 资源页](https://doc.shengwang.cn/doc/rtc/harmonyos/resources)。
