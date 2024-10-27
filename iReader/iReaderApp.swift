//
//  iReaderApp.swift
//  iReader
//
//  Created by Jian Cheng on 2024/8/3.
//

import SwiftUI

@main
struct iReaderApp: App {
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(settingsViewModel)
        }
    }
}
