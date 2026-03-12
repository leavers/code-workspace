# code-workspace

A tiny CLI tool written in Zig for generating VS Code workspace configuration files.

## Project Overview

- **Name**: code-workspace
- **Language**: Zig (minimum version 0.15.2)
- **Version**: 0.0.0
- **License**: MIT License (Copyright 2026 Chang)
- **Purpose**: Generate VS Code workspace files (.code-workspace) programmatically

## Project Structure

```
.
├── build.zig          # Zig build script - defines build targets, tests, and dependencies
├── build.zig.zon      # Zig package manifest - package metadata and dependencies
├── src/
│   ├── main.zig       # CLI entry point (executable)
│   ├── root.zig       # Library root module - exports public API
│   └── workspace.zig  # Core workspace structures (Folder, Workspace)
├── .vscode/settings.json  # VS Code workspace color theme settings
├── .gitignore         # Git ignore patterns
├── LICENSE            # MIT License
└── README.md          # Brief project description
```

## Technology Stack

- **Language**: Zig (version 0.15.2)
- **Build System**: Zig's native build system (`build.zig`)
- **Package Manager**: Zig package manager (`build.zig.zon`)
- **Dependencies**: None (uses only Zig standard library)

## Architecture

The project follows a dual-module architecture:

1. **Library Module** (`code_workspace`):
   - Entry point: `src/root.zig`
   - Provides reusable workspace configuration structures
   - Can be imported by other Zig projects
   - Exports: `Workspace`, `Folder`, and `workspace` module

2. **Executable Module** (`code_workspace` binary):
   - Entry point: `src/main.zig`
   - CLI interface for end users
   - Imports the library module for core functionality

### Core Data Structures

Located in `src/workspace.zig`:

- **`Folder`**: Represents a folder in the workspace
  - `path`: Path to the folder (relative or absolute)
  - `name`: Display name for the folder in VS Code

- **`Workspace`**: Represents a VS Code workspace configuration
  - `folders`: Dynamic array of Folder structs
  - Supports adding folders dynamically with proper memory management
  - `toJson(allocator)`: Serializes workspace to JSON string (caller owns returned memory)

## Build Commands

All commands are run from the project root:

```bash
# Build the project (creates executable in zig-out/bin/)
zig build

# Run the executable
zig build run

# Run all tests
zig build test

# Build with specific optimization mode
zig build -Doptimize=ReleaseFast

# Show all available build options
zig build --help

# Clean build artifacts
rm -rf zig-out/ .zig-cache/
```

## Testing Strategy

Tests are embedded in source files using Zig's `test` blocks:

- **Location**: Tests are in `src/workspace.zig` alongside the code they test
- **Run**: `zig build test`
- **Framework**: Zig's built-in testing framework (`std.testing`)

### Current Test Coverage

1. **Folder creation**: Basic initialization with path and name
2. **Internationalization**: Chinese characters and spaces in paths/names
3. **Workspace management**: Adding folders, counting, empty workspace handling
4. **JSON serialization**:
   - Empty workspace serialization
   - Single and multiple folders
   - Special character escaping (quotes, backslashes, newlines, tabs)
   - Unicode characters preservation

### Writing Tests

Tests use the standard Zig pattern:

```zig
test "description of test" {
    const gpa = std.testing.allocator;  // Use testing allocator
    // Test code here
    try std.testing.expectEqual(expected, actual);
}
```

Always use `std.testing.allocator` for test memory management and use `defer` for cleanup.

## Code Style Guidelines

### Comment Style

- **Use standard Zig comments only**: `//` (regular), `///` (doc comment), and `//!` (module doc)
- **No decorative elements**: Avoid visual separators like `// ============== Tests ==============`, headers with repeated characters, or ASCII art
- **No decorative separators**: Don't use lines of `=`, `-`, `*`, or `#` to create visual sections
- **Let code structure speak**: Use clear names, doc comments, and proper module organization instead of visual separators

### Naming Conventions

- **Types/Structs**: `PascalCase` (e.g., `Workspace`, `Folder`)
- **Functions**: `snake_case` (e.g., `add_folder`, `folder_count`)
- **Variables**: `snake_case`
- **Constants**: `snake_case` or `SCREAMING_SNAKE_CASE`

### Documentation

- **Module-level**: Use `//!` at the top of files
- **Public declarations**: Use `///` before the declaration
- **Private items**: Documentation is optional

Example:
```zig
//! Workspace configuration structures

/// Represents a folder in the workspace
pub const Folder = struct {
    /// Path to the folder (relative or absolute)
    path: []const u8,
    ...
};
```

### Memory Management

- Use Zig's allocator pattern consistently
- Pass `std.mem.Allocator` explicitly to functions that need it
- Always pair allocations with `defer` deallocation
- For structs with dynamic memory, provide `init()` and `deinit()` methods

### Error Handling

- Use Zig's error union type (`!Type`)
- Propagate errors with `try` keyword
- Handle errors explicitly when recovery is needed

## Development Workflow

1. **Make changes** to source files in `src/`
2. **Run tests**: `zig build test`
3. **Run the CLI**: `zig build run`
4. **Build for release**: `zig build -Doptimize=ReleaseFast`

## VS Code Integration

The project includes `.vscode/settings.json` with custom color theming (purplish scheme) to help distinguish this project window from others. Note that `.vscode/` is in `.gitignore`, so local VS Code settings won't be committed.

The tool generates VS Code workspace files (`.code-workspace`) which are JSON configurations that define multi-root workspaces.

## Adding Dependencies

To add external dependencies:

```bash
zig fetch --save <url>
```

Then update `build.zig` to import and use the module.

## Security Considerations

- The project handles file paths - ensure proper validation when implementing file I/O
- No network operations currently
- MIT licensed - follow license terms when distributing

## Future Development Notes

- CLI is currently minimal (just prints "code-workspace CLI")
- Core workspace structures are implemented and tested
- Next steps likely include:
  - JSON serialization for workspace files
  - CLI argument parsing
  - File system scanning for workspace folder discovery
