//
//  OpenCodeIslandApp.swift
//  OpenCodeIsland
//
//  Dynamic Island for interacting with OpenCode
//

import SwiftUI

@main
struct OpenCodeIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a completely custom window, so no default scene needed
        Settings {
            EmptyView()
        }
    }
}
