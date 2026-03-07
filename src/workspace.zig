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
        return .{
            .folders = std.ArrayList(Folder).init(allocator),
        };
    }

    /// Deallocate the workspace
    pub fn deinit(self: *Workspace) void {
        self.folders.deinit();
    }

    /// Add a folder to the workspace
    pub fn addFolder(self: *Workspace, folder: Folder) !void {
        try self.folders.append(folder);
    }

    /// Get the number of folders in the workspace
    pub fn folderCount(self: *const Workspace) usize {
        return self.folders.items.len;
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
    defer workspace.deinit();

    // Path and name with Chinese characters and spaces
    try workspace.addFolder(Folder.init("项目/我的工作区", "我的工作区"));
    try workspace.addFolder(Folder.init("resources/awesome 资源", "Awesome 资源库"));
    try workspace.addFolder(Folder.init("libs/依赖库 v2", "依赖库 V2 版本"));

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
    defer workspace.deinit();

    // Initially empty
    try std.testing.expectEqual(@as(usize, 0), workspace.folderCount());

    // Add folders
    try workspace.addFolder(Folder.init("project-a", "Project A"));
    try std.testing.expectEqual(@as(usize, 1), workspace.folderCount());

    try workspace.addFolder(Folder.init("libs/project-b", "Project B"));
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
    defer workspace.deinit();

    try std.testing.expectEqual(@as(usize, 0), workspace.folderCount());
}
