//
//  Settings.swift
//  OpenCodeIsland
//
//  App settings manager using UserDefaults
//

import Foundation

enum AppSettings {
    static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let summonHotkey = "summonHotkey"
        static let selectedScreen = "selectedScreen"
        static let defaultAgentID = "defaultAgentID"
        static let defaultModelID = "defaultModelID"  // Format: "providerID/modelID"
        static let workingDirectory = "workingDirectory"
    }

    // MARK: - Hotkey Settings
    
    /// The hotkey configuration for summoning the island
    /// Stored as encoded HotkeyType data
    static var summonHotkeyData: Data? {
        get { defaults.data(forKey: Keys.summonHotkey) }
        set { defaults.set(newValue, forKey: Keys.summonHotkey) }
    }
    
    // MARK: - OpenCode Settings
    
    /// User's preferred default agent ID
    static var defaultAgentID: String? {
        get { defaults.string(forKey: Keys.defaultAgentID) }
        set { defaults.set(newValue, forKey: Keys.defaultAgentID) }
    }
    
    /// User's preferred default model ID (format: "providerID/modelID")
    static var defaultModelID: String? {
        get { defaults.string(forKey: Keys.defaultModelID) }
        set { defaults.set(newValue, forKey: Keys.defaultModelID) }
    }
    
    /// Custom working directory override (nil uses home directory)
    static var workingDirectory: String? {
        get { defaults.string(forKey: Keys.workingDirectory) }
        set { defaults.set(newValue, forKey: Keys.workingDirectory) }
    }
    
    /// Get the effective working directory (custom or home directory)
    static var effectiveWorkingDirectory: String {
        if let custom = workingDirectory, !custom.isEmpty {
            return custom
        }
        return NSHomeDirectory()
    }
}
