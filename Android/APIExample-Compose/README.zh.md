# API Example Android

*[English](README.md) | 中文*

这个开源示例项目使用 Jetpack Compose 演示声网 RTC SDK 的部分 API，帮助开发者理解和使用声网 RTC SDK。

## 环境准备

- Android Studio Ladybug (2024.2.1) 或更高版本
- JDK 17
- Android SDK Platform 35
- Android 真机设备
- 支持模拟器

## 运行示例程序

这个段落主要讲解了如何编译和运行实例程序。

### 创建声网账号并获取 App ID

在编译和启动实例程序前，你需要首先获取一个可用的App Id:

1. 登录[声网控制台](https://dashboard.agora.io/signin/)并创建开发者账号
2. 前往后台页面，点击左部导航栏的 **项目 > 项目列表** 菜单
3. 复制后台的 **App Id** 并备注，稍后启动应用时会用到它
4. 复制后台的 **App 证书** 并备注，稍后启动应用时会用到它

5. 打开 `Android/APIExample-Compose` 并编辑项目根目录下的 `local.properties`，填入你的 App ID。如果你的声网项目开启了 App Certificate，并且你希望使用示例内置的 token 生成功能，再填入 `YOUR APP CERTIFICATE`

    ```
    sdk.dir=/path/to/Android/sdk
    AGORA_APP_ID=YOUR APP ID
    AGORA_APP_CERT=YOUR APP CERTIFICATE
    ```

`AGORA_APP_ID` 为必填项。如果你的项目没有开启 App Certificate，`AGORA_APP_CERT` 留空即可。如果你使用自己的服务端生成 token，建议不要在客户端填写 `AGORA_APP_CERT`，直接使用 token 方式的示例在运行时粘贴 token。

然后你就可以编译并运行项目了。

## 联系我们

- 产品指南和 API 参考见[声网文档中心](https://doc.shengwang.cn/)
- 更多官方示例和社区项目见 [Shengwang Community](https://github.com/Shengwang-Community)
- 若遇到问题需要开发者帮助，你可以到 [开发者社区](https://rtcdeveloper.com/) 提问
- 如果需要售后技术支持，可以在[声网控制台](https://dashboard.agora.io)提交工单
- 如果发现了示例代码的 bug，欢迎提交 [issue](https://github.com/Shengwang-Community/API-Examples/issues)

## 代码许可

The MIT License (MIT)
