const std = @import("std");

pub fn main() !void {
    // TODO: CLI entry point
    const stdout = std.fs.File.stdout();
    _ = try stdout.write("code-workspace CLI\n");
}
