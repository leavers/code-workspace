const std = @import("std");

pub fn main() !void {
    // TODO: CLI entry point
    const stdout = std.fs.File.stdout();
    _ = try stdout.write("code-workspace CLI\n");
}

test "clap dependency available" {
    const clap = @import("clap");
    _ = clap;
}

test "parseArgs basic create command" {
    const cli_mod = @import("cli.zig");
    _ = cli_mod;
}
