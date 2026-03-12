//! Create command implementation
const std = @import("std");
const code_workspace = @import("code_workspace");
const Workspace = code_workspace.Workspace;
const Folder = code_workspace.Folder;
const git = code_workspace.git;
const CloneSpec = git.CloneSpec;
const workspace_builder = code_workspace.workspace_builder;

pub const CreateOptions = struct {
    /// Target workspace directory
    workspace_dir: []const u8,
    /// Workspace display name (defaults to workspace_dir if null)
    name: ?[]const u8,
    /// Repositories to clone
    clones: []const CloneSpec,
    /// Force overwrite if directory exists
    force: bool,
};

/// Create a workspace with git cloning support
/// Uses atomic operations: prepares in temp dir, then moves on success
pub fn createWorkspace(
    allocator: std.mem.Allocator,
    options: CreateOptions,
) !void {
    // Determine workspace name
    const workspace_name = options.name orelse std.fs.path.basename(options.workspace_dir);

    // Check if target exists (without force)
    if (!options.force) {
        if (std.fs.cwd().access(options.workspace_dir, .{})) {
            return error.DirectoryAlreadyExists;
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        }
    }

    // Prepare workspace in temp directory
    const temp_parent = std.fs.path.dirname(options.workspace_dir) orelse ".";

    var prepared = workspace_builder.prepareWorkspace(allocator, .{
        .name = workspace_name,
        .clones = options.clones,
        .temp_parent = temp_parent,
    }) catch |err| {
        // Cleanup is handled by workspace_builder on failure
        return err;
    };
    // Note: prepared must be moved or cleaned up manually on success path

    // Move to final location
    prepared.moveTo(allocator, options.workspace_dir) catch |err| {
        // If move fails, clean up temp directory
        prepared.cleanup(allocator);
        return err;
    };
}
