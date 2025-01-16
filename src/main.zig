const std = @import("std");
const token = @import("token.zig");
const Thread = std.Thread;
const FindSeedResults = @import("filter_common.zig").FindSeedResults;
const filters = @import("filters.zig");

var config = struct {
    filter: u32 = undefined,
    threads: u8 = undefined,
    offline: bool = undefined,
    java: []u8 = undefined,
}{};

var seed_results = struct {
    found: bool = false,
    mutex: Thread.Mutex = Thread.Mutex{},
    fsr: FindSeedResults = undefined,
    is: token.InitialSeeding = undefined,
}{};

fn findSeed() !void {
    if (config.threads <= 1) {
        try findSeedSingleThreaded();
        return;
    }

    for (0..config.threads) |i| {
        _ = try Thread.spawn(.{}, findSeedSpawnedThread, .{i});
    }

    while (!seed_results.found) {
        std.time.sleep(5_000_000);
    }
}

fn findSeedSpawnedThread(thread_num: usize) !void {
    _ = thread_num;
    // std.debug.print("Thread {d} spawned!\n", .{thread_num});
    const is = try token.generateInitialSeeding(config.offline);
    const filter = try filters.getFilter(config.filter);
    const fsr = filter.findSeed(is.init_seed);

    seed_results.mutex.lock();
    defer seed_results.mutex.unlock();
    if (seed_results.found) return;
    seed_results.found = true;
    seed_results.is = is;
    seed_results.fsr = fsr;
}

fn findSeedSingleThreaded() !void {
    seed_results.is = try token.generateInitialSeeding(config.offline);
    const init_seed = seed_results.is.init_seed;
    seed_results.fsr = (try filters.getFilter(config.filter)).findSeed(init_seed);
    seed_results.found = true;
}

fn run() !void {
    const out = std.io.getStdOut().writer();
    try findSeed();

    try out.print("Seed: {d}\n", .{@as(i64, @bitCast(seed_results.fsr.seed))});
    const fsr = seed_results.fsr;
    if (!config.offline) try token.printToken(seed_results.is, fsr.lower_48_checks, fsr.sister_checks, fsr.seed, config.filter);
    std.process.exit(0); // Kills extra threads
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Open the file `config.json`
    const file = try std.fs.cwd().openFile("config.json", .{});
    defer file.close();

    // Read the contents of `config.json` into a buffer
    const file_contents = try allocator.alloc(u8, try file.getEndPos());
    defer allocator.free(file_contents);
    _ = try file.readAll(file_contents);

    // Parse the JSON
    const parsed_config = try std.json.parseFromSlice(@TypeOf(config), allocator, file_contents, .{});
    defer parsed_config.deinit();
    config = parsed_config.value;
    @import("bastion_checker.zig").setJavaPath(parsed_config.value.java);

    return run();
}
