//! Command line argument parsing module
const std = @import("std");
const clap = @import("clap");
const git = @import("git.zig");

/// Parsed command line arguments
pub const Args = struct {
    /// The subcommand: "create" or "init"
    command: Command,
    /// Options for create command
    create_options: ?CreateOptions,
    /// Options for init command
    init_options: ?InitOptions,

    /// The subcommand: "create" or "init"
    pub const Command = enum {
        create,
        init,
    };

    pub const CloneSpec = git.CloneSpec;

    pub const CreateOptions = struct {
        /// Workspace directory name (positional argument)
        workspace_dir: []const u8,
        /// Workspace display name (-n/--name)
        name: ?[]const u8,
        /// Repositories to clone (-c/--clone)
        clones: []const CloneSpec,
        /// Force overwrite (-f/--force)
        force: bool,
    };

    pub const InitOptions = struct {
        /// Workspace display name (-n/--name)
        name: ?[]const u8,
        /// Scan current directory for folders (--scan)
        scan: bool,
        /// Repositories to clone (-c/--clone), mutually exclusive with --scan
        clones: []const CloneSpec,
        /// Force overwrite (-f/--force)
        force: bool,
    };
};

/// Parse command line arguments
/// Caller owns the returned memory (must call deinit)
pub fn parseArgs(allocator: std.mem.Allocator) !Args {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help           Display this help and exit.
        \\-n, --name <str>     Workspace display name.
        \\-c, --clone <str>... Clone a repository (format: "url" or "url dir").
        \\-f, --force          Force overwrite if exists.
        \\-s, --scan           Scan current directory for folders (init only).
        \\
        \\<str>...
        \\
    );

    const res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .allocator = allocator,
    }) catch |err| {
        return err;
    };
    defer res.deinit();

    // Handle help flag
    if (res.args.help != 0) {
        return error.ShowHelp;
    }

    // Check for subcommand
    if (res.positionals[0].len == 0) {
        std.debug.print("Error: Missing subcommand. Use 'create' or 'init'.\n", .{});
        return error.MissingSubcommand;
    }

    const command_str = res.positionals[0][0];
    const command = std.meta.stringToEnum(Args.Command, command_str) orelse {
        std.debug.print("Error: Invalid subcommand '{s}'. Use 'create' or 'init'.\n", .{command_str});
        return error.UnknownCommand;
    };

    // Parse clones
    var clones: std.ArrayList(Args.CloneSpec) = .empty;
    errdefer clones.deinit(allocator);

    for (res.args.clone) |clone_str| {
        const spec = try parseCloneSpec(allocator, clone_str);
        try clones.append(allocator, spec);
    }

    return switch (command) {
        .create => {
            if (res.positionals[0].len < 2) {
                std.debug.print("Error: create requires <workspace-dir> argument.\n", .{});
                return error.MissingArgument;
            }

            // For create, scan is not allowed
            if (res.args.scan != 0) {
                std.debug.print("Error: --scan is not allowed with create command.\n", .{});
                return error.InvalidOption;
            }

            return Args{
                .command = .create,
                .create_options = .{
                    .workspace_dir = res.positionals[0][1],
                    .name = res.args.name,
                    .clones = try clones.toOwnedSlice(allocator),
                    .force = res.args.force != 0,
                },
                .init_options = null,
            };
        },
        .init => {
            // For init, validate scan vs clone mutual exclusion
            if (res.args.scan != 0 and res.args.clone.len > 0) {
                std.debug.print("Error: --scan and --clone cannot be used together.\n", .{});
                return error.InvalidOptionCombination;
            }

            return Args{
                .command = .init,
                .create_options = null,
                .init_options = .{
                    .name = res.args.name,
                    .scan = res.args.scan != 0,
                    .clones = try clones.toOwnedSlice(allocator),
                    .force = res.args.force != 0,
                },
            };
        },
    };
}

/// Parse clone specification string
/// Format: "url" or "url dir"
fn parseCloneSpec(allocator: std.mem.Allocator, spec: []const u8) !Args.CloneSpec {
    // Find first space to split url and dir
    if (std.mem.indexOf(u8, spec, " ")) |space_idx| {
        const url = try allocator.dupe(u8, spec[0..space_idx]);
        const dir = try allocator.dupe(u8, std.mem.trim(u8, spec[space_idx + 1 ..], " "));

        return .{
            .url = url,
            .dir = if (dir.len == 0) null else dir,
        };
    } else {
        // No space, just URL
        return .{
            .url = try allocator.dupe(u8, spec),
            .dir = null,
        };
    }
}

/// Free allocated memory in Args
pub fn deinitArgs(args: Args, allocator: std.mem.Allocator) void {
    if (args.create_options) |opts| {
        for (opts.clones) |clone| {
            allocator.free(clone.url);
            if (clone.dir) |dir| allocator.free(dir);
        }
        allocator.free(opts.clones);
    }
    if (args.init_options) |opts| {
        for (opts.clones) |clone| {
            allocator.free(clone.url);
            if (clone.dir) |dir| allocator.free(dir);
        }
        allocator.free(opts.clones);
    }
}
