const std = @import("std");

threadlocal var started = false;
threadlocal var bastion_checker_java_process: std.process.Child = undefined;

var java_path: []u8 = undefined;

pub fn setJavaPath(path: []u8) void {
    java_path = path;
}

pub fn getObsidianCount(world_seed: u64, chunk_x: i8, chunk_z: i8) !i8 {
    var buffer: [10]u8 = undefined;
    if (!started) {
        const allocator = std.heap.page_allocator;
        bastion_checker_java_process = std.process.Child.init(
            &[_][]const u8{ java_path, "-jar", "ZSGBastionChecker-1.2.0.jar" },
            allocator,
        );
        bastion_checker_java_process.stdin_behavior = .Pipe;
        bastion_checker_java_process.stdout_behavior = .Pipe;
        try bastion_checker_java_process.spawn();
        started = true;

        // Check for a -1 long then a 0 long
        if (try bastion_checker_java_process.stdout.?.read(buffer[0..8]) < 8) return error.BCFailedToStartError;
        if (std.mem.readInt(i64, buffer[0..8], .big) != -1) return error.BCFailedToStartError;
        if (try bastion_checker_java_process.stdout.?.read(buffer[0..8]) < 8) return error.BCFailedToStartError;
        if (std.mem.readInt(i64, buffer[0..8], .big) != 0) return error.BCFailedToStartError;
    }

    std.mem.writeInt(u64, buffer[0..8], world_seed, .big);
    buffer[8] = @bitCast(chunk_x);
    buffer[9] = @bitCast(chunk_z);
    if (try bastion_checker_java_process.stdin.?.write(buffer[0..10]) < 10) return error.BCWriteError;

    if (try bastion_checker_java_process.stdout.?.read(buffer[0..1]) < 1) return error.BCEndOfFileError;
    const out: i8 = @bitCast(buffer[0]);
    if (out < 0) return error.BCInvalidOutputError;
    return out;
}
