//
//  AppDelegate.swift
//  APIExample
//
//  Created by 张乾泽 on 2020/8/28.
//  Copyright © 2020 Agora Corp. All rights reserved.
//

import Cocoa
import Foundation
import SSZipArchive

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        copyResource()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func copyResource() {
        guard let bundleId = Bundle.main.bundleIdentifier else { 
            print("[Resource] Failed to get bundle identifier")
            return 
        }
        
        let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let destinationPath = (cachesPath as NSString).appendingPathComponent(bundleId)
        
        print("🔍 [Sandbox] Bundle ID: \(bundleId)")
        print("🔍 [Sandbox] Caches: \(cachesPath)")
        print("🔍 [Sandbox] Destination: \(destinationPath)")
        
        // 创建目录
        if !FileManager.default.fileExists(atPath: destinationPath) {
            do {
                try FileManager.default.createDirectory(atPath: destinationPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("[Resource] Failed to create directory: \(error)")
                return
            }
        }
        
        // 查找资源文件
        guard let zipPath = Bundle.main.path(forResource: "common_resource", ofType: "zip") else {
            print("[Resource] common_resource.zip not found in bundle")
            return
        }
        
        do {
            let fileManager = FileManager.default
            
            // 清理旧文件
            if fileManager.fileExists(atPath: destinationPath) {
                let contents = try fileManager.contentsOfDirectory(atPath: destinationPath)
                for file in contents {
                    let filePath = (destinationPath as NSString).appendingPathComponent(file)
                    try fileManager.removeItem(atPath: filePath)
                }
            }
            
            // 使用SSZipArchive解压文件
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

