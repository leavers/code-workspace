//! Workspace preparation with atomic operations
//! Creates workspace in temp dir, then moves to final location on success
const std = @import("std");
const Workspace = @import("workspace.zig").Workspace;
const Folder = @import("workspace.zig").Folder;
const git = @import("git.zig");
const CloneSpec = git.CloneSpec;

/// Generate a unique temporary directory name
fn generateTempDirName(allocator: std.mem.Allocator, prefix: []const u8) ![]const u8 {
    const timestamp = std.time.milliTimestamp();
    var prng = std.Random.DefaultPrng.init(@intCast(timestamp));
    const random = prng.random();
    const suffix = random.int(u32);
    return try std.fmt.allocPrint(allocator, "{s}-{d}-{d}", .{ prefix, timestamp, suffix });
}

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
    // Create temp directory with unique name
    const temp_name = try generateTempDirName(allocator, ".tmp-workspace");
    defer allocator.free(temp_name);
    
    const temp_path = try std.fs.path.join(allocator, &.{ options.temp_parent, temp_name });
    errdefer allocator.free(temp_path);

    // Actually create the directory (simplified - in real impl use mkdtemp)
    try std.fs.cwd().makeDir(temp_path);
    errdefer std.fs.cwd().deleteTree(temp_path) catch {};

    // Build workspace configuration
    var workspace = Workspace.init(allocator);
    defer workspace.deinit(allocator);

    // Track allocated dir_names for cleanup after workspace is written
    var dir_names = std.ArrayList([]const u8).empty;
    defer {
        for (dir_names.items) |name| allocator.free(name);
        dir_names.deinit(allocator);
    }

    // Clone repositories
    for (options.clones) |clone_spec| {
        const dir_name = try clone_spec.getDirName(allocator);
        try dir_names.append(allocator, dir_name);

        const target_path = try std.fs.path.join(allocator, &.{ temp_path, dir_name });
        defer allocator.free(target_path);

        try git.cloneRepository(allocator, clone_spec.url, target_path);

        // Add to workspace (path is relative to workspace root)
        try workspace.addFolder(allocator, Folder.init(dir_name, dir_name));
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
