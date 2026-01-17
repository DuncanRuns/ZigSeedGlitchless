const std = @import("std");

var print_mutex: std.Thread.Mutex = .{};
var buf: [1024]u8 = undefined;

pub fn print(comptime format: []const u8, args: anytype) !void {
    print_mutex.lock();
    defer print_mutex.unlock();

    var stdout = std.fs.File.stdout().writer(&buf);
    stdout.interface.print(format, args) catch return stdout.err.?;
    stdout.interface.flush() catch return stdout.err.?;
}
