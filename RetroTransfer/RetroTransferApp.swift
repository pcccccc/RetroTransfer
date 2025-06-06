//
//  RetroTransferApp.swift
//  RetroTransfer
//
//  Created by pc on 2025/5/14.
//

import SwiftUI
import ActivityKit
import UIKit

@main
struct RetroTransferApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        
                    } else if newPhase == .active {

                    }
                }

        }
    }
    
    init() {
       if #available(iOS 16.1, *) {
           if ActivityAuthorizationInfo().areActivitiesEnabled {
               print("设备支持Live Activity")
           } else {
               print("设备不支持Live Activity")
           }
       } else {
           print("系统版本不支持Live Activity")
       }
       NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
           print("end")
           if #available(iOS 16.1, *) {
               
                   for activity in Activity<ServerAttributes>.activities {
                       Task {
                           await activity.end(dismissalPolicy: .immediate)
                       }
                   }
               
           }
       }
    }
}

