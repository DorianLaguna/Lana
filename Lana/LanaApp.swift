//
//  LanaApp.swift
//  Lana
//
//  Created by Dorian Ricardo Laguna Campos on 26/08/26.
//

import SwiftUI
import CoreData

@main
struct LanaApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
