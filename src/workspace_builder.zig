//! Workspace preparation with atomic operations
//! Creates workspace in temp dir, then moves to final location on success
const std = @import("std");
const code_workspace = @import("code_workspace");
const Workspace = code_workspace.Workspace;
const Folder = code_workspace.Folder;
const git = code_workspace.git;
const CloneSpec = git.CloneSpec;

pub const BuilderOptions = struct {
    /// Workspace display name
    name: []const u8,
    /// Repositories to clone
    clones: []const CloneSpec,
    /// Parent directory for the temp workspace
    temp_parent: []const u8,
};

/// Result of workspace preparation
pub const PreparedWorkspace = struct {
    /// Path to the temporary directory containing the workspace
    temp_path: []const u8,
    /// Name of the workspace
    name: []const u8,

    /// Move the prepared workspace to its final destination
    pub fn moveTo(self: PreparedWorkspace, allocator: std.mem.Allocator, target_path: []const u8) !void {
        try std.fs.rename(std.fs.cwd(), self.temp_path, std.fs.cwd(), target_path);
        allocator.free(self.temp_path);
    }

    /// Move only the .code-workspace file (for init command)
    pub fn moveWorkspaceFile(self: PreparedWorkspace, allocator: std.mem.Allocator, target_dir: []const u8) !void {
        const file_name = try std.mem.concat(allocator, u8, &.{ self.name, ".code-workspace" });
        defer allocator.free(file_name);

        const src_path = try std.fs.path.join(allocator, &.{ self.temp_path, file_name });
        defer allocator.free(src_path);

        const dst_path = try std.fs.path.join(allocator, &.{ target_dir, file_name });
        defer allocator.free(dst_path);

        try std.fs.rename(std.fs.cwd(), src_path, std.fs.cwd(), dst_path);

        // Clean up temp directory
        try std.fs.cwd().deleteTree(self.temp_path);
        allocator.free(self.temp_path);
    }

    /// Clean up the temp directory on failure
    pub fn cleanup(self: PreparedWorkspace, allocator: std.mem.Allocator) void {
        std.fs.cwd().deleteTree(self.temp_path) catch {};
        allocator.free(self.temp_path);
    }
};

/// Prepare workspace in temporary directory
/// On success: returns PreparedWorkspace (caller must move or cleanup)
/// On failure: temp directory is cleaned up automatically
pub fn prepareWorkspace(
    allocator: std.mem.Allocator,
    options: BuilderOptions,
) !PreparedWorkspace {
    // Create temp directory
    const temp_path = try std.fs.path.join(allocator, &.{ options.temp_parent, ".tmp-workspace-XXXXXX" });
    errdefer allocator.free(temp_path);

    // Actually create the directory (simplified - in real impl use mkdtemp)
    try std.fs.cwd().makeDir(temp_path);
    errdefer std.fs.cwd().deleteTree(temp_path) catch {};

    // Build workspace configuration
    var workspace = Workspace.init(allocator);
    defer workspace.deinit();

    // Clone repositories
    for (options.clones) |clone_spec| {
        const dir_name = try clone_spec.getDirName(allocator);
        defer allocator.free(dir_name);

        const target_path = try std.fs.path.join(allocator, &.{ temp_path, dir_name });
        defer allocator.free(target_path);

        try git.cloneRepository(allocator, clone_spec.url, target_path);

        // Add to workspace (path is relative to workspace root)
        try workspace.addFolder(Folder.init(dir_name, dir_name));
    }

    // Write workspace file
    const file_name = try std.mem.concat(allocator, u8, &.{ options.name, ".code-workspace" });
    defer allocator.free(file_name);

    const file_path = try std.fs.path.join(allocator, &.{ temp_path, file_name });
    defer allocator.free(file_path);

    try workspace.writeToFile(allocator, file_path, false);

    return PreparedWorkspace{
        .temp_path = temp_path,
        .name = try allocator.dupe(u8, options.name),
    };
}
