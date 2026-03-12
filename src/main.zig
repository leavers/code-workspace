//! code-workspace CLI entry point
const std = @import("std");
const cli = @import("cli.zig");
const create = @import("commands/create.zig");
const init = @import("commands/init.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = cli.parseArgs(allocator) catch |err| {
        if (err == error.ShowHelp) {
            printUsage();
            return;
        }
        printUsage();
        return err;
    };
    defer cli.deinitArgs(args, allocator);

    switch (args.command) {
        .create => {
            const opts = args.create_options.?;
            try create.createWorkspace(allocator, .{
                .workspace_dir = opts.workspace_dir,
                .name = opts.name,
                .clones = opts.clones,
                .force = opts.force,
            });
            std.debug.print("Created workspace: {s}\n", .{opts.workspace_dir});
        },
        .init => {
            const opts = args.init_options.?;
            try init.initWorkspace(allocator, .{
                .name = opts.name,
                .scan = opts.scan,
                .clones = opts.clones,
                .force = opts.force,
            });
            std.debug.print("Initialized workspace in current directory\n", .{});
        },
    }
}

fn printUsage() void {
    std.debug.print(
        \\Usage: code-workspace <command> [options]
        \\
        \\Commands:
        \\  create <dir>    Create a new workspace directory
        \\  init            Initialize workspace in current directory
        \\
        \\Options:
        \\  -n, --name <name>     Workspace display name
        \\  -c, --clone <spec>    Clone repository (format: "url" or "url dir")
        \\  -f, --force           Force overwrite if exists
        \\  -s, --scan            Scan current directory for folders (init only)
        \\  -h, --help            Show this help message
        \\
    , .{});
}
