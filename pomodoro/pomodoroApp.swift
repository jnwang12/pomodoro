//
//  pomodoroApp.swift
//  pomodoro
//
//  Created by Joy Wang on 7/29/26.
//

import SwiftUI

@main
struct pomodoroApp: App {
    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
        MenuBarExtra("my pomodoro", systemImage: "lasso"){
            MenuBarContentView()
        }
        
        .menuBarExtraStyle(.window)
    }
}
