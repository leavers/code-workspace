//! Workspace configuration structures
const std = @import("std");

/// Represents a folder in the workspace
pub const Folder = struct {
    /// Path to the folder (relative or absolute)
    path: []const u8,
    /// Display name for the folder in VS Code
    name: []const u8,

    /// Create a new folder
    pub fn init(path: []const u8, name: []const u8) Folder {
        return .{
            .path = path,
            .name = name,
        };
    }
};

/// Represents a VS Code workspace configuration
pub const Workspace = struct {
    /// List of folders in the workspace
    folders: std.ArrayList(Folder),

    /// Create a new empty workspace
    pub fn init(allocator: std.mem.Allocator) Workspace {
        _ = allocator;
        return .{
            .folders = .empty,
        };
    }

    /// Deallocate the workspace
    pub fn deinit(self: *Workspace, allocator: std.mem.Allocator) void {
        self.folders.deinit(allocator);
    }

    /// Add a folder to the workspace
    pub fn addFolder(self: *Workspace, allocator: std.mem.Allocator, folder: Folder) !void {
        try self.folders.append(allocator, folder);
    }

    /// Get the number of folders in the workspace
    pub fn folderCount(self: *const Workspace) usize {
        return self.folders.items.len;
    }

    /// Serialize the workspace to JSON format
    /// Caller owns the returned memory and must free it with allocator.free()
    pub fn toJson(self: *const Workspace, allocator: std.mem.Allocator) ![]u8 {
        var out: std.io.Writer.Allocating = .init(allocator);
        defer out.deinit();

        var stringifier = std.json.Stringify{
            .writer = &out.writer,
            .options = .{ .whitespace = .indent_2 },
        };

        // {
        try stringifier.beginObject();
        //   "folders": [
        try stringifier.objectField("folders");
        try stringifier.beginArray();
        for (self.folders.items) |folder| {
            //   { "path": "...", "name": "..." }
            try stringifier.beginObject();
            try stringifier.objectField("path");
            try stringifier.write(folder.path);
            try stringifier.objectField("name");
            try stringifier.write(folder.name);
            try stringifier.endObject();
        }
        //   ]
        try stringifier.endArray();
        // }
        try stringifier.endObject();

        return try allocator.dupe(u8, out.writer.buffer[0..out.writer.end]);
    }

    // Write the workspace configuration to a .code-workspace file
    /// Creates parent directories if they don't exist
    /// Returns error.FileAlreadyExists if file already exists (unless overwrite=true)
    pub fn writeToFile(
        self: *const Workspace,
        allocator: std.mem.Allocator,
        file_path: []const u8,
        overwrite: bool,
    ) !void {
        // Check if file already exists
        if (!overwrite) {
            if (std.fs.cwd().access(file_path, .{})) {
                return error.FileAlreadyExists;
            } else |err| switch (err) {
                error.FileNotFound => {}, // Good, file doesn't exist
                else => return err, // Other error, propagate it
            }
        }

        // Create parent directories if needed
        if (std.fs.path.dirname(file_path)) |parent_dir| {
            try std.fs.cwd().makePath(parent_dir);
        }

        // Generate JSON content
        const json_content = try self.toJson(allocator);
        defer allocator.free(json_content);

        // Write to file
        var file = try std.fs.cwd().createFile(file_path, .{
            .truncate = true,
        });
        defer file.close();

        try file.writeAll(json_content);
    }
};

test "Folder creation" {
    const folder = Folder.init("src/my-project", "my-project");
    try std.testing.expectEqualStrings("src/my-project", folder.path);
    try std.testing.expectEqualStrings("my-project", folder.name);
}

test "Folder with Chinese characters and spaces" {
    const gpa = std.testing.allocator;

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    // Path and name with Chinese characters and spaces
    try workspace.addFolder(gpa, Folder.init("项目/我的工作区", "我的工作区"));
    try workspace.addFolder(gpa, Folder.init("resources/awesome 资源", "Awesome 资源库"));
    try workspace.addFolder(gpa, Folder.init("libs/依赖库 v2", "依赖库 V2 版本"));

    try std.testing.expectEqual(@as(usize, 3), workspace.folderCount());

    // Verify Chinese characters are preserved correctly
    try std.testing.expectEqualStrings("项目/我的工作区", workspace.folders.items[0].path);
    try std.testing.expectEqualStrings("我的工作区", workspace.folders.items[0].name);

    try std.testing.expectEqualStrings("resources/awesome 资源", workspace.folders.items[1].path);
    try std.testing.expectEqualStrings("Awesome 资源库", workspace.folders.items[1].name);

    try std.testing.expectEqualStrings("libs/依赖库 v2", workspace.folders.items[2].path);
    try std.testing.expectEqualStrings("依赖库 V2 版本", workspace.folders.items[2].name);
}

test "Workspace creation and folder management" {
    const gpa = std.testing.allocator;

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    // Initially empty
    try std.testing.expectEqual(@as(usize, 0), workspace.folderCount());

    // Add folders
    try workspace.addFolder(gpa, Folder.init("project-a", "Project A"));
    try std.testing.expectEqual(@as(usize, 1), workspace.folderCount());

    try workspace.addFolder(gpa, Folder.init("libs/project-b", "Project B"));
    try std.testing.expectEqual(@as(usize, 2), workspace.folderCount());

    // Verify folder contents
    try std.testing.expectEqualStrings("project-a", workspace.folders.items[0].path);
    try std.testing.expectEqualStrings("Project A", workspace.folders.items[0].name);
    try std.testing.expectEqualStrings("libs/project-b", workspace.folders.items[1].path);
    try std.testing.expectEqualStrings("Project B", workspace.folders.items[1].name);
}

test "Empty workspace" {
    const gpa = std.testing.allocator;

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    try std.testing.expectEqual(@as(usize, 0), workspace.folderCount());
}

test "JSON serialization - empty workspace" {
    const gpa = std.testing.allocator;

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    const json = try workspace.toJson(gpa);
    defer gpa.free(json);

    const expected =
        \\{
        \\  "folders": []
        \\}
    ;
    try std.testing.expectEqualStrings(expected, json);
}

test "JSON serialization - single folder" {
    const gpa = std.testing.allocator;

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    try workspace.addFolder(gpa, Folder.init("my-project", "My Project"));

    const json = try workspace.toJson(gpa);
    defer gpa.free(json);

    const expected =
        \\{
        \\  "folders": [
        \\    {
        \\      "path": "my-project",
        \\      "name": "My Project"
        \\    }
        \\  ]
        \\}
    ;
    try std.testing.expectEqualStrings(expected, json);
}

test "JSON serialization - multiple folders" {
    const gpa = std.testing.allocator;

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    try workspace.addFolder(gpa, Folder.init("project-a", "Project A"));
    try workspace.addFolder(gpa, Folder.init("libs/project-b", "Project B"));

    const json = try workspace.toJson(gpa);
    defer gpa.free(json);

    const expected =
        \\{
        \\  "folders": [
        \\    {
        \\      "path": "project-a",
        \\      "name": "Project A"
        \\    },
        \\    {
        \\      "path": "libs/project-b",
        \\      "name": "Project B"
        \\    }
        \\  ]
        \\}
    ;
    try std.testing.expectEqualStrings(expected, json);
}

test "JSON serialization - special characters escaping" {
    const gpa = std.testing.allocator;

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    // Test quotes, backslashes, newlines, and tabs
    try workspace.addFolder(gpa, Folder.init(
        "path/with\"quotes\\and\\backslashes",
        "Name with\nnewlines\rand\ttabs",
    ));

    const json = try workspace.toJson(gpa);
    defer gpa.free(json);

    const expected =
        \\{
        \\  "folders": [
        \\    {
        \\      "path": "path/with\"quotes\\and\\backslashes",
        \\      "name": "Name with\nnewlines\rand\ttabs"
        \\    }
        \\  ]
        \\}
    ;
    try std.testing.expectEqualStrings(expected, json);
}

test "JSON serialization - unicode characters" {
    const gpa = std.testing.allocator;

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    try workspace.addFolder(gpa, Folder.init("项目/路径", "我的工作区"));

    const json = try workspace.toJson(gpa);
    defer gpa.free(json);

    const expected =
        \\{
        \\  "folders": [
        \\    {
        \\      "path": "项目/路径",
        \\      "name": "我的工作区"
        \\    }
        \\  ]
        \\}
    ;
    try std.testing.expectEqualStrings(expected, json);
}

test "Write workspace to file" {
    const gpa = std.testing.allocator;

    // Use a temporary directory for testing
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    try workspace.addFolder(gpa, Folder.init("my-project", "My Project"));

    // Construct file path in temp directory
    const file_path = try std.fs.path.join(gpa, &[_][]const u8{
        tmp_dir.dir.fd,
        "test.code-workspace",
    });
    defer gpa.free(file_path);

    // Write the file
    try workspace.writeToFile(gpa, file_path, false);

    // Verify file exists and has correct content
    const content = try tmp_dir.dir.readFileAlloc(gpa, "test.code-workspace", 1024);
    defer gpa.free(content);

    const expected =
        \\{
        \\  "folders": [
        \\    {
        \\      "path": "my-project",
        \\      "name": "My Project"
        \\    }
        \\  ]
        \\}
    ;
    try std.testing.expectEqualStrings(expected, content);
}

test "Write workspace creates parent directories" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    try workspace.addFolder(gpa, Folder.init("src", "Source"));

    // Path with nested directories that don't exist yet
    const file_path = try std.fs.path.join(gpa, &[_][]const u8{
        tmp_dir.dir.fd,
        "nested",
        "deep",
        "workspace.code-workspace",
    });
    defer gpa.free(file_path);

    // Should create parent directories automatically
    try workspace.writeToFile(gpa, file_path, false);

    // Verify file was created
    const file = try std.fs.cwd().openFile(file_path, .{});
    file.close();
}

test "Write workspace fails if file exists" {
    const gpa = std.testing.allocator;

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var workspace = Workspace.init(gpa);
    defer workspace.deinit(gpa);

    try workspace.addFolder(gpa, Folder.init("project", "Project"));

    const file_path = try std.fs.path.join(gpa, &[_][]const u8{
        tmp_dir.dir.fd,
        "existing.code-workspace",
    });
    defer gpa.free(file_path);

    // First write should succeed
    try workspace.writeToFile(gpa, file_path, false);

    // Second write without overwrite should fail
    try std.testing.expectError(
        error.FileAlreadyExists,
        workspace.writeToFile(gpa, file_path, false),
    );

    // Write with overwrite=true should succeed
    try workspace.writeToFile(gpa, file_path, true);
}
