//
//  AppDelegate.swift
//  APIExample
//
//  Created by 张乾泽 on 2020/4/16.
//  Copyright © 2020 Agora Corp. All rights reserved.
//

import UIKit
import SSZipArchive

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        copyResource()
        return true
    }

    func copyResource() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let destinationPath = (cachesPath as NSString).appendingPathComponent(bundleId)
        if !FileManager.default.fileExists(atPath: destinationPath) {
            do {
                try FileManager.default.createDirectory(atPath: destinationPath, withIntermediateDirectories: true)
            } catch {
                print("[Resource] Failed to create directory: \(error)")
                return
            }
        }
        guard let zipPath = Bundle.main.path(forResource: "common_resource", ofType: "zip") else {
            print("[Resource] common_resource.zip not found in bundle")
            return
        }
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationPath) {
                let contents = try fileManager.contentsOfDirectory(atPath: destinationPath)
                for file in contents {
                    let filePath = (destinationPath as NSString).appendingPathComponent(file)
                    try fileManager.removeItem(atPath: filePath)
                }
            }
            let success = SSZipArchive.unzipFile(atPath: zipPath, toDestination: destinationPath)
            if success {
                print("[Resource] Successfully unzipped common_resource to: \(destinationPath)")
            } else {
                print("[Resource] Failed to unzip file")
            }
        } catch {
            print("[Resource] Error during unzip: \(error)")
        }
    }
}
