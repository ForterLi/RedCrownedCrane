//
//  RedCrownedCrane_DemoApp.swift
//  RedCrownedCrane-Demo
//
//  Created by forterli on 2023/3/24.
//

import SwiftUI
import GRDB
import CloudKit
import RedCrownedCrane


let synaEngine = RCSynaEngine.init(objects: [DemoItem.self], container: CKContainer(identifier: "iCloud.com.forter.dsdsd.CloudKit"))
var dbQueue: DatabaseQueue = {
    let fileManager = FileManager()
    let folderURL = try! fileManager
        .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("database", isDirectory: true)

    if CommandLine.arguments.contains("-reset") {
        try? fileManager.removeItem(at: folderURL)
    }
    
    try! fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    

    let dbURL = folderURL.appendingPathComponent("db.sqlite")
    let dbPool = try! DatabaseQueue(path: dbURL.path)
    return dbPool
}()



class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        application.registerForRemoteNotifications()
        try? dbQueue.write { db in
            try db.create(table: "demoItem") { t in
                t.primaryKey("identifiable", .text)
                t.column("name", .text).notNull()
                t.column("isDeleted", .boolean).notNull()
                t.column("modifiedAt", .date).notNull()
            }
        }
        synaEngine.pull()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        synaEngine.application(didReceiveRemoteNotification: userInfo)
        completionHandler(.newData)
    }
}


@main
struct RedCrownedCrane_DemoApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


