# API Example iOS

*English | [中文](README.zh.md)*

This project presents a set of API examples to help you understand how to use Shengwang APIs.

## Problem
After users upgrade their iOS devices to iOS 14.0, and use an app that integrates the Shengwang RTC SDK for iOS for the first time, users see a prompt for finding local network devices. The following picture shows the pop-up prompt:

![](../pictures/ios_14_privacy.png)

[Solution](https://docs.agora.io/en/api-reference/faq/integration/local_network_privacy)

## Prerequisites

- Xcode 13.0+
- Physical iOS device (iPhone or iPad)
- iOS simulator is NOT supported

## Quick Start

This section shows you how to prepare, build, and run the sample application.

### Prepare Dependencies

Change to the sample directory and install the project dependencies with CocoaPods. See the [official CocoaPods guide](https://guides.cocoapods.org/using/getting-started.html) for installation instructions.

```bash
cd iOS/APIExample-OC
pod install
```

Verify `APIExample-OC.xcworkspace` has been properly generated.

### Obtain an App Id

To build and run the sample application, get an App Id:

1. Create a developer account in the [Shengwang Console](https://dashboard.agora.io/signin/). Once you finish the signup process, you will be redirected to the Dashboard.
2. Navigate in the Dashboard tree on the left to **Projects** > **Project List**.
3. Save the **App Id** from the Dashboard for later use.
4. Generate a temp **Access Token** (valid for 24 hours) from dashboard page with given channel name, save for later use.

5. Open `APIExample-OC.xcworkspace` and edit the `KeyCenter.m` file. In the `KeyCenter` struct, update `<#Your App Id#>` with your App Id, and change `<#Temp Access Token#>` with the temp Access Token generated from dashboard. Note you can leave the token variable `nil` if your project has not turned on security token.

    ``` objective-c
    /**
      Shengwang assigns App IDs to app developers to identify projects and organizations.
     If you have multiple completely separate apps in your organization, for example built by different teams,
     you should use different App IDs.
     If applications need to communicate with each other, they should use the same App ID.
     To get an App ID, open the Shengwang Console (https://console.agora.io/) and create a project;
     then the APP ID can be found in the project detail page.
     */
     static NSString * const APPID = <# YOUR APPID#>
     
     /**
      Shengwang provides App Certificates for generating tokens. You can deploy a token generator on your server,
     or use the console to generate a temporary token.
     To get an App Certificate, open the Shengwang Console (https://console.agora.io/) and create a project with App Certificate authentication enabled;
     then the APP Certificate can be found in the project detail page.If the project does not have certificates enabled, leave this field blank.
     PS: It is unsafe to place the App Certificate on the client side, it is recommended to place it on the server side to ensure that the App Certificate is not leaked.
     */
     static NSString * const Certificate = <#YOUR Certificate#>
        
    ```

You are all set. Now connect your iPhone or iPad device and run the project.

## Contact Us

- Browse the [Shengwang documentation](https://doc.shengwang.cn/) for product guides and API references.
- Explore more samples in [Shengwang Community](https://github.com/Shengwang-Community).
- Ask integration questions in the [developer community](https://rtcdeveloper.com/).
- File bugs about this sample at [issues](https://github.com/Shengwang-Community/API-Examples/issues).

## License

The MIT License (MIT)
