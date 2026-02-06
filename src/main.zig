const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("lazy-md v0.1.0\n", .{});
    try stdout.print("Terminal-based markdown editor\n", .{});
}

test "basic test" {
    try std.testing.expect(true);
}
