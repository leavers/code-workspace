//! code-workspace library root
const std = @import("std");

// Core data structures
pub const workspace = @import("workspace.zig");
pub const Folder = workspace.Folder;
pub const Workspace = workspace.Workspace;

// CLI and commands
pub const cli = @import("cli.zig");
pub const Args = cli.Args;
pub const commands = struct {
    pub const create = @import("commands/create.zig");
};

// Utilities
pub const git = @import("git.zig");
pub const CloneSpec = git.CloneSpec;

// Workspace preparation
pub const workspace_builder = @import("workspace_builder.zig");
