# API Example Android

*English | [中文](README.zh.md)*

This project presents a set of API examples to help you understand how to use Shengwang APIs.

## Prerequisites

- Android Studio Ladybug (2024.2.1) or later
- JDK 17
- Android SDK Platform 35
- Physical Android device
- Android simulator is supported

## Quick Start

This section shows you how to prepare, build, and run the sample application.

### Obtain an App Id

To build and run the sample application, get an App Id:

1. Create a developer account in the [Shengwang Console](https://dashboard.agora.io/signin/). Once you finish the signup process, you will be redirected to the Dashboard.
2. Navigate in the Dashboard tree on the left to **Projects** > **Project List**.
3. Save the **App Id** from the Dashboard for later use.
4. Save the **App Certificate** from the Dashboard for later use.

5. Open `Android/APIExample-Compose` and edit the `local.properties` file in the project root. Update `YOUR APP ID` with your App Id. If your Shengwang project has App Certificate enabled and you want to use the sample's built-in token generation flow, update `YOUR APP CERTIFICATE` as well.

    ```
    sdk.dir=/path/to/Android/sdk
    AGORA_APP_ID=YOUR APP ID
    AGORA_APP_CERT=YOUR APP CERTIFICATE
    ```

`AGORA_APP_ID` is required. If your project does not enable App Certificate, leave `AGORA_APP_CERT` blank. If you generate tokens on your own server, keep `AGORA_APP_CERT` empty on the client side and use the token-based examples to paste the token at runtime.

You are all set. Now connect your Android device and run the project.


## Contact Us

- Browse the [Shengwang documentation](https://doc.shengwang.cn/) for product guides and API references.
- Explore more samples in [Shengwang Community](https://github.com/Shengwang-Community).
- Ask integration questions in the [developer community](https://rtcdeveloper.com/).
- File bugs about this sample at [issues](https://github.com/Shengwang-Community/API-Examples/issues).

## License

The MIT License (MIT)
