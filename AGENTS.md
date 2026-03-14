# code-workspace

A CLI tool written in Zig for generating VS Code workspace configuration files.

## Project Overview

- **Name**: code-workspace
- **Language**: Zig (minimum version 0.15.2)
- **License**: MIT License (Copyright 2026 Chang)
- **Purpose**: Generate VS Code workspace files (.code-workspace) programmatically with git clone support

## Project Structure

```
.
├── build.zig                  # Zig build script
├── build.zig.zon              # Zig package manifest
├── src/
│   ├── main.zig               # CLI entry point
│   ├── cli.zig                # Command line argument parsing (using zig-clap)
│   ├── workspace.zig          # Core workspace structures (Folder, Workspace)
│   ├── git.zig                # Git operations (clone, URL parsing)
│   ├── workspace_builder.zig  # Atomic workspace preparation
│   └── commands/
│       ├── create.zig         # `create` command implementation
│       └── init.zig           # `init` command implementation
├── .vscode/settings.json      # VS Code workspace color theme settings
├── .gitignore                 # Git ignore patterns
├── LICENSE                    # MIT License
└── README.md                  # Project description
```

## Technology Stack

- **Language**: Zig (version 0.15.2)
- **Build System**: Zig's native build system (`build.zig`)
- **Package Manager**: Zig package manager (`build.zig.zon`)
- **Dependencies**: 
  - [zig-clap](https://github.com/Hejsil/zig-clap) (0.11.0) - Command line argument parsing

## Architecture

This is a **pure CLI tool** (not a library). All code is organized under the executable module.

### Module Organization

| File | Purpose |
|------|---------|
| `main.zig` | CLI entry point, command dispatch |
| `cli.zig` | Argument parsing using zig-clap |
| `workspace.zig` | Core data structures and JSON serialization |
| `git.zig` | Git clone operations and URL parsing |
| `workspace_builder.zig` | Atomic workspace creation (temp dir + move) |
| `commands/create.zig` | `create` command implementation |
| `commands/init.zig` | `init` command implementation |

### Core Data Structures

Located in `src/workspace.zig`:

- **`Folder`**: Represents a folder in the workspace
  - `path`: Path to the folder (relative or absolute)
  - `name`: Display name for the folder in VS Code

- **`Workspace`**: Represents a VS Code workspace configuration
  - `folders`: Dynamic array of Folder structs
  - `toJson(allocator)`: Serializes workspace to formatted JSON
  - `writeToFile(allocator, path, overwrite)`: Writes to .code-workspace file

## Build Commands

```bash
# Build the project
zig build

# Run with arguments
zig build run -- create my-workspace -n "My Workspace"
zig build run -- init --scan
zig build run -- --help

# Run tests
zig build test

# Build for release
zig build -Doptimize=ReleaseFast

# Clean build artifacts
rm -rf zig-out/ .zig-cache/
```

## CLI Usage

### Create a new workspace directory

```bash
code-workspace create <directory> [options]

Options:
  -n, --name <name>       Workspace display name (default: directory name)
  -c, --clone <spec>      Clone a repository (format: "url" or "url dir")
  -f, --force             Overwrite if directory exists
  -h, --help              Show help

Examples:
  code-workspace create my-project -n "My Project"
  code-workspace create my-workspace -c "git@github.com:user/repo.git"
  code-workspace create my-workspace -c "git@github.com:user/repo.git subdir/repo" -f
```

### Initialize workspace in current directory

```bash
code-workspace init [options]

Options:
  -n, --name <name>       Workspace display name (default: current dir name)
  -c, --clone <spec>      Clone a repository (cannot use with --scan)
  -s, --scan              Scan current directory for subdirectories
  -f, --force             Overwrite if .code-workspace file exists
  -h, --help              Show help

Examples:
  code-workspace init --scan
  code-workspace init -n "My Workspace" -c "git@github.com:user/repo.git"
```

## Testing Strategy

Tests are embedded in source files using Zig's `test` blocks:

```bash
# Run all tests
zig build test
```

### Test Coverage

- **Workspace**: Creation, folder management, JSON serialization
- **Git operations**: URL parsing, clone specification parsing
- **Commands**: create and init command logic
- **CLI**: Argument parsing (basic validation)

## Code Style Guidelines

### Comment Style

- Use standard Zig comments: `//`, `///`, `//!`
- No decorative separators (lines of `=`, `-`, `*`, etc.)
- Let code structure speak through clear names and doc comments

### Naming Conventions

- **Types/Structs**: `PascalCase`
- **Functions/Variables**: `snake_case`
- **Constants**: `snake_case` or `SCREAMING_SNAKE_CASE`

### Memory Management

- Pass `std.mem.Allocator` explicitly
- Use `defer` for cleanup
- ArrayList pattern: `var list: std.ArrayList(T) = .empty; defer list.deinit(allocator);`

### Error Handling

- Use error unions (`!Type`)
- Propagate with `try`
- Define custom errors as needed

## Development Workflow

1. Edit source files in `src/`
2. Run tests: `zig build test`
3. Run CLI: `zig build run -- <command>`
4. Build release: `zig build -Doptimize=ReleaseFast`

## Adding Dependencies

```bash
zig fetch --save git+https://github.com/user/repo#tag
```

Update `build.zig` to import the module.

## Security Considerations

- Validates file paths before operations
- Uses atomic operations (temp dir + move) for workspace creation
- Git commands are executed with user permissions
- MIT licensed
