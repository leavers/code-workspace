//! Git operations module
const std = @import("std");

/// Clone specification parsed from URL
pub const CloneSpec = struct {
    /// Repository URL
    url: []const u8,
    /// Target directory (optional, extracted from URL if null)
    dir: ?[]const u8,

    /// Parse a clone specification string
    /// Format: "url" or "url dir"
    pub fn parse(allocator: std.mem.Allocator, spec: []const u8) !CloneSpec {
        if (std.mem.indexOf(u8, spec, " ")) |space_idx| {
            const url = std.mem.trim(u8, spec[0..space_idx], " ");
            const dir = std.mem.trim(u8, spec[space_idx + 1 ..], " ");

            return .{
                .url = try allocator.dupe(u8, url),
                .dir = if (dir.len > 0) try allocator.dupe(u8, dir) else null,
            };
        } else {
            return .{
                .url = try allocator.dupe(u8, std.mem.trim(u8, spec, " ")),
                .dir = null,
            };
        }
    }

    /// Free allocated memory
    pub fn deinit(self: CloneSpec, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        if (self.dir) |dir| allocator.free(dir);
    }

    /// Get the target directory name
    /// If dir is specified, use it; otherwise extract from URL
    pub fn getDirName(self: CloneSpec, allocator: std.mem.Allocator) ![]const u8 {
        if (self.dir) |d| {
            return try allocator.dupe(u8, d);
        }

        // Extract from URL: https://github.com/user/repo.git -> repo
        const url_copy = try allocator.dupe(u8, self.url);
        defer allocator.free(url_copy);

        // Slice without .git suffix for basename extraction
        const url_for_basename = if (std.mem.endsWith(u8, url_copy, ".git"))
            url_copy[0 .. url_copy.len - 4]
        else
            url_copy;

        // Get last component of path
        const basename = std.fs.path.basename(url_for_basename);

        return try allocator.dupe(u8, basename);
    }
};

/// Execute git clone command
/// Returns error.GitCloneFailed if git command fails
pub fn cloneRepository(
    allocator: std.mem.Allocator,
    repo_url: []const u8,
    target_dir: []const u8,
) !void {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{
            "git",
            "clone",
            repo_url,
            target_dir,
        },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term.Exited != 0) {
        return error.GitCloneFailed;
    }
}

// ============== Tests ==============

test "CloneSpec parse - URL only" {
    const gpa = std.testing.allocator;

    const spec = try CloneSpec.parse(gpa, "https://github.com/user/repo.git");
    defer spec.deinit(gpa);

    try std.testing.expectEqualStrings("https://github.com/user/repo.git", spec.url);
    try std.testing.expect(spec.dir == null);
}

test "CloneSpec parse - URL with dir" {
    const gpa = std.testing.allocator;

    const spec = try CloneSpec.parse(gpa, "https://github.com/user/repo.git custom/dir");
    defer spec.deinit(gpa);

    try std.testing.expectEqualStrings("https://github.com/user/repo.git", spec.url);
    try std.testing.expectEqualStrings("custom/dir", spec.dir.?);
}

test "CloneSpec getDirName - from URL with .git" {
    const gpa = std.testing.allocator;

    const spec = try CloneSpec.parse(gpa, "https://github.com/user/my-project.git");
    defer spec.deinit(gpa);

    const dir_name = try spec.getDirName(gpa);
    defer gpa.free(dir_name);

    try std.testing.expectEqualStrings("my-project", dir_name);
}

test "CloneSpec getDirName - from URL without .git" {
    const gpa = std.testing.allocator;

    const spec = try CloneSpec.parse(gpa, "https://github.com/user/my-project");
    defer spec.deinit(gpa);

    const dir_name = try spec.getDirName(gpa);
    defer gpa.free(dir_name);

    try std.testing.expectEqualStrings("my-project", dir_name);
}

test "CloneSpec getDirName - with explicit dir" {
    const gpa = std.testing.allocator;

    const spec = try CloneSpec.parse(gpa, "https://github.com/user/repo.git nested/path");
    defer spec.deinit(gpa);

    const dir_name = try spec.getDirName(gpa);
    defer gpa.free(dir_name);

    try std.testing.expectEqualStrings("nested/path", dir_name);
}

test "CloneSpec getDirName - SSH URL" {
    const gpa = std.testing.allocator;

    const spec = try CloneSpec.parse(gpa, "git@github.com:Hejsil/zig-clap.git");
    defer spec.deinit(gpa);

    const dir_name = try spec.getDirName(gpa);
    defer gpa.free(dir_name);

    try std.testing.expectEqualStrings("zig-clap", dir_name);
}
