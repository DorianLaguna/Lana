//
//  LanaApp.swift
//  Lana
//
//  Created by Dorian Ricardo Laguna Campos on 26/08/26.
//

import SwiftUI

@main
struct LanaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(appDelegate: appDelegate)
        }
    }
}
