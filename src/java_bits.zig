const std = @import("std");

threadlocal var started = false;
threadlocal var process: std.process.Child = undefined;

var java_path: []u8 = undefined;

pub fn setJavaPath(path: []u8) void {
    java_path = path;
}

fn ensureStarted() !void {
    var buffer: [10]u8 = undefined;
    if (!started) {
        const allocator = std.heap.page_allocator;
        process = std.process.Child.init(
            &[_][]const u8{ java_path, "-jar", "ZSGJavaBits-2.0.0.jar" },
            allocator,
        );
        process.stdin_behavior = .Pipe;
        process.stdout_behavior = .Pipe;
        try process.spawn();
        started = true;

        // Check for a -1 long then a 0 long
        if (try process.stdout.?.read(buffer[0..8]) < 8) return error.JBFailedToStartError;
        if (std.mem.readInt(i64, buffer[0..8], .big) != -1) return error.JBFailedToStartError;
        if (try process.stdout.?.read(buffer[0..8]) < 8) return error.JBFailedToStartError;
        if (std.mem.readInt(i64, buffer[0..8], .big) != 0) return error.JBFailedToStartError;
    }
}

pub fn getObsidianCount(world_seed: u64, chunk_x: i8, chunk_z: i8) !i8 {
    try ensureStarted();

    var buffer: [11]u8 = undefined;
    buffer[0] = 0; // Command
    std.mem.writeInt(u64, buffer[1..9], world_seed, .big); // Seed
    buffer[9] = @bitCast(chunk_x); // Bastion chunk x
    buffer[10] = @bitCast(chunk_z); // Bastion chunk z
    if (try process.stdin.?.write(buffer[0..11]) < 11) return error.JBWriteError;

    if (try process.stdout.?.read(buffer[0..1]) < 1) return error.JBEndOfFileError;
    const out: i8 = @bitCast(buffer[0]);
    if (out < 0) return error.JBInvalidOutputError;
    return out;
}

pub fn checkTerrain(world_seed: u64, bastion_cx: i8, bastion_cz: i8, fortress_cx: i8, fortress_cz: i8) !bool {
    try ensureStarted();

    var buffer: [13]u8 = undefined;
    buffer[0] = 1; // Command 1: Check for terrain
    std.mem.writeInt(u64, buffer[1..9], world_seed, .big); // Seed
    buffer[9] = @bitCast(bastion_cx); // Bastion chunk x
    buffer[10] = @bitCast(bastion_cz); // Bastion chunk z
    buffer[11] = @bitCast(fortress_cx); // Fortress chunk x
    buffer[12] = @bitCast(fortress_cz); // Fortress chunk z
    if (try process.stdin.?.write(buffer[0..13]) < 13) return error.JBWriteError;

    if (try process.stdout.?.read(buffer[0..1]) < 1) return error.JBEndOfFileError;
    return buffer[0] == 1;
}
