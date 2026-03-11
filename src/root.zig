//! code-workspace library root
const std = @import("std");

pub const workspace = @import("workspace.zig");
pub const Folder = workspace.Folder;
pub const Workspace = workspace.Workspace;

pub const cli = @import("cli.zig");
pub const Args = cli.Args;
