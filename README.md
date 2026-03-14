# code-workspace

A CLI tool written in Zig for generating VS Code multi-root workspace configuration files.

## Features

- **One-click workspace creation**: Automatically generate `.code-workspace` configuration files
- **Integrated Git Clone**: Clone repositories automatically when creating/initializing workspaces
- **Local directory scanning**: Auto-discover projects in current directory and add them to workspace

## Installation

Download the executable for your platform from [Releases](https://github.com/yourusername/code-workspace/releases) and place it in your PATH.

## Usage

### 1. create - Create a new workspace directory

Create a new directory containing the workspace file and cloned repositories.

```bash
code-workspace create <directory> [options]
```

**Examples:**

```bash
# Basic usage
code-workspace create my-project -n "My Project"

# With repository cloning
code-workspace create my-workspace \
  -c "git@github.com:user/repo1.git" \
  -c "git@github.com:user/repo2.git"

# Clone to specific subdirectories
code-workspace create my-workspace \
  -c "git@github.com:user/frontend.git web/frontend" \
  -c "git@github.com:user/backend.git api/backend"

# Force overwrite existing directory
code-workspace create my-workspace -f
```

**Generated directory structure:**

```
my-workspace/                    # Workspace root directory
├── My Workspace.code-workspace  # VS Code workspace configuration file
├── repo1/                       # Cloned repository (default directory name)
└── repo2/
```

### 2. init - Initialize in current directory

Create a workspace file in an existing directory, optionally clone repositories or scan local subdirectories.

```bash
code-workspace init [options]
```

**Examples:**

```bash
# Scan all subdirectories in current directory as projects
code-workspace init --scan

# Clone a repository to current directory
code-workspace init -c "git@github.com:user/project.git"

# Specify workspace name
code-workspace init --scan -n "My Projects"
```

**Generated directory structure (--scan mode):**

```
current-directory/
├── .vscode/                     # Created if not exists
├── project-a/                   # Existing subdirectory
├── project-b/                   # Existing subdirectory
└── My Projects.code-workspace   # Generated workspace file
```

**Generated directory structure (with clone):**

```
current-directory/
├── my-project/                  # Cloned repository
├── another-repo/                # Cloned repository
└── My Workspace.code-workspace  # Generated workspace file
```

## Command Options

### Global Options

| Option | Description |
|--------|-------------|
| `-n, --name <name>` | Workspace display name (affects `.code-workspace` filename) |
| `-f, --force` | Force overwrite existing files/directories |
| `-h, --help` | Show help message |

### create Specific

| Option | Description |
|--------|-------------|
| `-c, --clone <spec>` | Clone repository, format: `url` or `"url dir"` |

### init Specific

| Option | Description |
|--------|-------------|
| `-s, --scan` | Scan subdirectories in current directory as projects |
| `-c, --clone <spec>` | Clone repository (mutually exclusive with `--scan`) |

## Real-world Scenarios

**Scenario 1: Create a full-stack project workspace**

```bash
code-workspace create fullstack-app \
  -n "Fullstack App" \
  -c "git@github.com:myorg/web.git frontend" \
  -c "git@github.com:myorg/api.git backend" \
  -c "git@github.com:myorg/shared.git packages/shared"
```

Generated structure:
```
fullstack-app/
├── Fullstack App.code-workspace
├── frontend/
├── backend/
└── packages/
    └── shared/
```

**Scenario 2: Convert existing project directory to workspace**

```bash
cd ~/Projects/my-monorepo
code-workspace init --scan -n "Monorepo"
```

**Scenario 3: Quickly review multiple repositories**

```bash
code-workspace create zig-libs \
  -c "git@github.com:Hejsil/zig-clap.git" \
  -c "git@github.com:ziglibs/known-folders.git" \
  -c "git@github.com:mitchellh/zig-objc.git"

cd zig-libs
# Open workspace in VS Code
code "Zig Libs.code-workspace"
```

## Notes

1. **Repository directory name**: When not specified, automatically extracted from URL (removing `.git` suffix)
2. **SSH/Git configuration**: Cloning requires properly configured SSH keys or Git credentials
3. **Workspace filename**: Defaults to directory name, customizable via `-n` (spaces are preserved)

## License

MIT
