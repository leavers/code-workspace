//! Init command implementation
const std = @import("std");
const Workspace = @import("../workspace.zig").Workspace;
const Folder = @import("../workspace.zig").Folder;
const git = @import("../git.zig");
const CloneSpec = git.CloneSpec;
const workspace_builder = @import("../workspace_builder.zig");

pub const InitOptions = struct {
    /// Workspace display name (defaults to current directory name if null)
    name: ?[]const u8,
    /// Scan current directory for folders (--scan)
    scan: bool,
    /// Repositories to clone (mutually exclusive with scan)
    clones: []const CloneSpec,
    /// Force overwrite if .code-workspace file exists
    force: bool,
};

/// Initialize workspace in current directory
pub fn initWorkspace(
    allocator: std.mem.Allocator,
    options: InitOptions,
) !void {
    // Get current directory name as default workspace name
    var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &cwd_buf);
    const workspace_name = options.name orelse std.fs.path.basename(cwd);

    // Scan directories if requested
    var folders: std.ArrayList(Folder) = .empty;
    defer folders.deinit(allocator);

    if (options.scan) {
        // Validate: scan and clones are mutually exclusive
        if (options.clones.len > 0) {
            return error.ScanAndCloneMutuallyExclusive;
        }

        // Scan current directory for subdirectories
        var dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch |err| {
            return err;
        };
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            // Skip hidden directories and files
            if (entry.name[0] == '.') continue;

            // Only include directories
            if (entry.kind == .directory) {
                try folders.append(allocator, Folder.init(entry.name, entry.name));
            }
        }
    }

    // If clones are provided, prepare them in temp directory
    if (options.clones.len > 0) {
        const prepared = try workspace_builder.prepareWorkspace(allocator, .{
            .name = workspace_name,
            .clones = options.clones,
            .temp_parent = ".",
        });
        // Move only the workspace file to current directory
        try prepared.moveWorkspaceFile(allocator, ".");
        return;
    }

    // No clones, just create workspace file with scanned or empty folders
    var workspace = Workspace.init(allocator);
    defer workspace.deinit(allocator);

    for (folders.items) |folder| {
        try workspace.addFolder(allocator, folder);
    }

    const file_name = try std.mem.concat(allocator, u8, &.{ workspace_name, ".code-workspace" });
    defer allocator.free(file_name);

    // Check if file exists (without force)
    if (!options.force) {
        if (std.fs.cwd().access(file_name, .{})) {
            return error.WorkspaceFileAlreadyExists;
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        }
    }

    try workspace.writeToFile(allocator, file_name, options.force);
}

// ============== Tests ==============

test "initWorkspace creates workspace file" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Change to temp directory for the test
    const original_cwd = std.fs.cwd();
    defer original_cwd.setAsCwd() catch {};

    try tmp_dir.dir.setAsCwd();

    try initWorkspace(gpa, .{
        .name = "TestWorkspace",
        .scan = false,
        .clones = &.{},
        .force = false,
    });

    // Verify file was created
    const file = try tmp_dir.dir.openFile("TestWorkspace.code-workspace", .{});
    file.close();
}

test "initWorkspace scan mode" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create some subdirectories
    try tmp_dir.dir.makeDir("project-a");
    try tmp_dir.dir.makeDir("project-b");

    const original_cwd = std.fs.cwd();
    defer original_cwd.setAsCwd() catch {};

    try tmp_dir.dir.setAsCwd();

    try initWorkspace(gpa, .{
        .name = null, // Use directory name
        .scan = true,
        .clones = &.{},
        .force = false,
    });

    // Verify file was created
    // File name should be the temp directory name (random)
    var found = false;
    var iter = tmp_dir.dir.iterate();
    while (try iter.next()) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".code-workspace")) {
            found = true;
            break;
        }
    }
    try std.testing.expect(found);
}

test "initWorkspace rejects scan with clones" {
    const gpa = std.testing.allocator;

    try std.testing.expectError(
        error.ScanAndCloneMutuallyExclusive,
        initWorkspace(gpa, .{
            .name = "test",
            .scan = true,
            .clones = &.{.{ .url = "https://github.com/user/repo.git", .dir = null }},
            .force = false,
        }),
    );
}
