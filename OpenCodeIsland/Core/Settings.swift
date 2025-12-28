//
//  Settings.swift
//  OpenCodeIsland
//
//  App settings manager using UserDefaults
//

import Foundation

/// Available WhisperKit models for speech-to-text
enum WhisperModel: String, CaseIterable, Codable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case largev2 = "large-v2"
    case largev3 = "large-v3"
    case largev3Turbo = "large-v3-turbo"
    
    var displayName: String {
        switch self {
        case .tiny: return "Tiny (~40MB)"
        case .base: return "Base (~75MB)"
        case .small: return "Small (~250MB)"
        case .medium: return "Medium (~750MB)"
        case .largev2: return "Large v2 (~1.5GB)"
        case .largev3: return "Large v3 (~1.5GB)"
        case .largev3Turbo: return "Large v3 Turbo (~800MB)"
        }
    }
    
    var description: String {
        switch self {
        case .tiny: return "Fastest, lowest accuracy"
        case .base: return "Fast, good for dictation"
        case .small: return "Balanced speed/accuracy"
        case .medium: return "High accuracy, slower"
        case .largev2: return "Very high accuracy"
        case .largev3: return "Best accuracy"
        case .largev3Turbo: return "Fast + high accuracy"
        }
    }
}

enum AppSettings {
    static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let summonHotkey = "summonHotkey"
        static let selectedScreen = "selectedScreen"
        static let defaultAgentID = "defaultAgentID"
        static let defaultModelID = "defaultModelID"  // Format: "providerID/modelID"
        static let workingDirectory = "workingDirectory"
        static let whisperModel = "whisperModel"
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
    
    // MARK: - WhisperKit Settings
    
    /// User's preferred WhisperKit model for speech-to-text
    static var whisperModel: WhisperModel {
        get {
            if let rawValue = defaults.string(forKey: Keys.whisperModel),
               let model = WhisperModel(rawValue: rawValue) {
                return model
            }
            return .base  // Default to base model
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.whisperModel)
        }
    }
}
