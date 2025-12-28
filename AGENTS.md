# AGENTS.md - OpenCode Island

> Guidelines for AI agents working in this codebase

## Project Overview

OpenCode Island is a native macOS menu bar app (Swift/SwiftUI) that provides a Dynamic Island-style interface for interacting with OpenCode. Users summon the island with a customizable hotkey, type prompts, and receive streaming results.

## Build Commands

```bash
# Development build (unsigned)
xcodebuild -scheme OpenCodeIsland -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Release build (unsigned)
xcodebuild -scheme OpenCodeIsland -configuration Release build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Release archive (for distribution)
xcodebuild archive -scheme OpenCodeIsland -configuration Release \
  -archivePath build/OpenCodeIsland.xcarchive -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Signed release build (requires Apple Developer ID)
./scripts/build.sh
```

**Requirements:** macOS 15.0+ (Sequoia), Xcode with Swift 5.0+

## Testing

No test suite currently exists. Add tests via Xcode: File > New > Target > Unit Testing Bundle.

## Dependencies (Swift Package Manager)

- `swift-markdown` (0.5.0+) - Markdown rendering
- `Sparkle` (2.0.0+) - Auto-update framework  
- `mixpanel-swift` (master) - Analytics

## Architecture

### File Structure

```
OpenCodeIsland/
  App/                  # App lifecycle (AppDelegate, WindowManager)
  Core/                 # HotkeyManager, NotchViewModel, NotchGeometry, Settings
  Events/               # EventMonitor for keyboard/mouse events
  Models/               # Agent, PromptSession
  Services/
    OpenCode/           # Server communication layer
      OpenCodeClient.swift      # Low-level HTTP client (actor)
      OpenCodeService.swift     # High-level service (@MainActor)
      OpenCodeModels.swift      # Codable API types
      OpenCodeError.swift       # Error types with LocalizedError
      OpenCodeServerManager.swift  # Server process lifecycle
    Update/             # Sparkle auto-update driver
  UI/
    Components/         # ProcessingSpinner, MarkdownRenderer, etc.
    Views/              # NotchView, NotchMenuView
    Window/             # NotchWindow, NotchWindowController
```

### Key Files

| File | Purpose |
|------|---------|
| `Core/NotchViewModel.swift` | Main state machine (prompt/processing/result states) |
| `Core/HotkeyManager.swift` | Global hotkey detection (double-tap, key combos) |
| `Services/OpenCode/OpenCodeService.swift` | High-level OpenCode API wrapper |
| `Services/OpenCode/OpenCodeClient.swift` | Low-level HTTP client (actor-based) |
| `UI/Views/NotchView.swift` | Main SwiftUI view |

## Code Style Guidelines

### File Header

```swift
//
//  FileName.swift
//  OpenCodeIsland
//
//  Brief description
//

import Foundation
```

### Import Order

1. Foundation/Swift standard library
2. Apple frameworks (AppKit, Combine, SwiftUI)
3. Third-party packages (Sparkle, Mixpanel, Markdown)

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Types/Classes | PascalCase | `HotkeyManager`, `NotchViewModel` |
| Properties/Methods | camelCase | `promptText`, `submitPrompt()` |
| Booleans | `is`/`has`/`can` prefix | `isProcessing`, `hasPendingRetry` |
| Enums | PascalCase type, camelCase cases | `enum NotchStatus { case closed, opened }` |

### MARK Comments

Use `// MARK: -` to organize code sections:
```swift
// MARK: - Published State
// MARK: - Initialization  
// MARK: - Private Helpers
```

### Concurrency Patterns

- **`@MainActor`** for UI-related classes (`NotchViewModel`, `OpenCodeService`, `AppDelegate`)
- **`actor`** for thread-safe data access (`OpenCodeClient`)
- **`Task`** for async work, check `Task.isCancelled` in long operations
- **Combine** for reactive state (`@Published`, `PassthroughSubject`)

### Error Handling

Use `LocalizedError` with computed properties:
```swift
enum OpenCodeError: LocalizedError {
    case serverNotRunning
    case httpError(statusCode: Int, message: String?)
    
    var errorDescription: String? { /* Full message */ }
    var shortDescription: String { /* UI-friendly message */ }
    var isRetryable: Bool { /* Can retry this error? */ }
}
```

### Settings (UserDefaults)

Use the `AppSettings` enum pattern:
```swift
enum AppSettings {
    private enum Keys {
        static let defaultAgentID = "defaultAgentID"
    }
    
    static var defaultAgentID: String? {
        get { UserDefaults.standard.string(forKey: Keys.defaultAgentID) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultAgentID) }
    }
}
```

## Critical: Panel Sizing and Hit Testing

**When adding UI elements to panels, you MUST update `openedSize` in `NotchViewModel.swift`.**

The app uses custom hit testing. If content extends beyond `openedSize`:
1. Clicks are detected as "outside" the panel
2. `handleMouseDown` closes the panel before buttons receive events
3. **Buttons appear broken** even though they render correctly

**Fix:** Update the height in `NotchViewModel.openedSize` for the content type:
```swift
case .menu:
    return CGSize(width: min(screenRect.width * 0.4, 480), height: 700)
```

Related files: `NotchViewModel.swift` (`openedSize`), `NotchGeometry.swift` (`openedScreenRect`), `NotchWindow.swift` (`sendEvent`)

## Common Tasks

### Adding a New Content State

1. Add case to `NotchContentType` enum in `NotchViewModel.swift`
2. Add size in `openedSize` computed property
3. Add view case in `NotchView.contentView`

### Adding Menu Items

1. Add row to `NotchMenuView.swift`
2. **Update menu height** in `NotchViewModel.openedSize`
3. Test clicking items at the bottom of the panel

### Modifying Hotkeys

- Types: `HotkeyManager.swift` - `HotkeyType` enum
- Detection: `handleFlagsChanged()`, `handleDoubleTapModifier()`
- Presets: `HotkeyType.presets` array

### Working with OpenCode API

```swift
// Service handles connection, sessions, and streaming
let service = OpenCodeService()
await service.connect()

// Submit prompt (blocks until complete)
let result = try await service.submitPrompt("Hello", agentID: "build")

// Or with images
let parts: [PromptPart] = [
    .text("What's in this image?"),
    .image(base64Data: imageData, mediaType: "image/png")
]
let result = try await service.submitPrompt(parts: parts)
```
