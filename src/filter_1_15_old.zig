const std = @import("std");
const math = std.math;

const cubiomes = @import("cubiomes");
const Pos = cubiomes.Pos;
const Generator = cubiomes.Generator;
const MC_VER = cubiomes.MC_1_15_2;

const common = @import("filter_common.zig");
pub const FindSeedResults = common.FindSeedResults;

pub const StructureSeedCheckResult = struct {
    successful: bool,
    bt_pos: Pos,
    monument_pos: Pos,
    village_pos: Pos,
};

const FAIL_RESULT: StructureSeedCheckResult = .{
    .successful = false,
    .bt_pos = undefined,
    .monument_pos = undefined,
    .village_pos = undefined,
};

fn checkLower48(seed: u64) StructureSeedCheckResult {
    {
        var rng: u64 = undefined;
        cubiomes.setSeed(&rng, seed);
        const dist: f64 = (4.0 * 32.0) + (cubiomes.nextDouble(&rng) - 0.5) * 32 * 2.5;
        const angle: f64 = 2 * 3.14159265358979323846 * cubiomes.nextDouble(&rng);
        if (dist > 100 or angle > 1.309 or angle < 0.261799) return FAIL_RESULT;
    }

    var fortress_pos: Pos = undefined;
    if (0 == cubiomes.getStructurePos(cubiomes.Fortress, MC_VER, seed, 0, 0, &fortress_pos)) return FAIL_RESULT;

    // var shipwreck_pos: Pos = undefined;
    // {
    //     _ = cubiomes.getStructurePos(cubiomes.Shipwreck, MC_VER, seed, 0, 0, &shipwreck_pos); // Always succeeds
    //     if (shipwreck_pos.x > 10 or shipwreck_pos.z > 10) return FAIL_RESULT;

    // var rng = cubiomes.chunkGenerateRnd(seed, shipwreck_pos.x >> 4, shipwreck_pos.z >> 4);
    // _ = cubiomes.nextInt(&rng, 4); // Discard rotation
    // const shipwreck_variant = cubiomes.nextInt(&rng, 20);
    // switch (shipwreck_variant) {
    //     0, 7, 9, 10, 17, 19 => {
    //         // Hooray!
    //     },
    //     else => {
    //         return FAIL_RESULT;
    //     },
    // }
    // }

    var bt_found = false;
    var bt_pos: Pos = .{ .x = 0, .z = 0 };
    {
        var x: c_int = 0;
        outer: while (x <= 8) : (x += 1) {
            var z: c_int = 0;
            while (z <= 8) : (z += 1) {
                bt_found = 0 != cubiomes.getStructurePos(cubiomes.Treasure, MC_VER, seed, x, z, &bt_pos) and isGoodBTLoot(seed, x, z);
                if (bt_found) break :outer;
            }
        }
    }
    if (!bt_found) return FAIL_RESULT;

    var monument_pos: Pos = undefined;
    _ = cubiomes.getStructurePos(cubiomes.Monument, MC_VER, seed, 0, 0, &monument_pos); // Always succeeds

    if (monument_pos.x - bt_pos.x < 128 and monument_pos.z - bt_pos.z < 128) return FAIL_RESULT;
    if (monument_pos.x < bt_pos.x or monument_pos.z < bt_pos.z) return FAIL_RESULT;

    var village_pos: Pos = undefined;
    _ = cubiomes.getStructurePos(cubiomes.Village, MC_VER, seed, 1, 1, &village_pos); // Always succeeds

    if (@abs(@divFloor(village_pos.x, 8) - fortress_pos.x) > 60) return FAIL_RESULT;
    if (@abs(@divFloor(village_pos.z, 8) - fortress_pos.z) > 60) return FAIL_RESULT;

    return .{
        .successful = true,
        .bt_pos = bt_pos,
        .monument_pos = monument_pos,
        .village_pos = village_pos,
    };
}

fn checkSister(seed: u64, ssr: StructureSeedCheckResult) bool {
    const bt_pos = ssr.bt_pos;
    const monument_pos = ssr.monument_pos;
    const village_pos = ssr.village_pos;
    // const shipwreck_pos = ssr.shipwreck_pos;

    var g: Generator = undefined;
    cubiomes.setupGenerator(&g, MC_VER, 0);
    cubiomes.applySeed(&g, cubiomes.DIM_OVERWORLD, seed);

    // Check bt biome
    if (0 == cubiomes.isViableStructurePos(cubiomes.Treasure, &g, bt_pos.x, bt_pos.z, 0)) return false;
    if (0 == cubiomes.isViableStructurePos(cubiomes.Monument, &g, monument_pos.x, monument_pos.z, 0)) return false;
    // if (0 == cubiomes.isViableStructurePos(cubiomes.Shipwreck, &g, shipwreck_pos.x, shipwreck_pos.z, 0)) return false;
    const village_biome = cubiomes.getBiomeAt(&g, 1, village_pos.x, 255, village_pos.z);
    if (cubiomes.savanna != village_biome) return false;

    // Check spawn
    var s: u64 = 0;
    const spawn_pos: Pos = cubiomes.estimateSpawn(&g, &s);
    if (@abs(spawn_pos.x - bt_pos.x) > 20 or @abs(spawn_pos.z - bt_pos.z) > 20) return false;
    // spawn_pos = cubiomes.getSpawn(&g);
    // if (@abs(spawn_pos.x - bt_pos.x) > 20 or @abs(spawn_pos.z - bt_pos.z) > 20) return false;

    return true;
}

fn isGoodBTLoot(seed: u64, x: c_int, z: c_int) bool {
    const loot = common.getBTLoot(seed, x, z, common.BURIED_TREASURE_SALT_1_15);
    return (loot.iron >= 6 or (loot.iron >= 3 and loot.gold >= 3)) and loot.tnt >= 1 and loot.emeralds >= 10;
}

pub fn findSeed(init_seed: u64) !FindSeedResults {
    const start_lower_48: u48 = @truncate(init_seed);
    const start_upper_16: u16 = @truncate(init_seed >> 48);

    var lower_48_checks: u49 = 0;
    var lower_48 = start_lower_48;
    while (lower_48_checks < 0x1000000000000) {
        lower_48_checks += 1;
        lower_48 +%= 1; // +%= means Addition with wrapping
        const ssr = checkLower48(@intCast(lower_48));
        if (!ssr.successful) continue;

        var upper_16_checks: u32 = 0;
        var upper_16: u16 = start_upper_16;
        while (upper_16_checks < 50) {
            upper_16_checks += 1;
            upper_16 +%= 1;
            const seed = @as(u64, lower_48) | (@as(u64, upper_16) << 48);
            if (!checkSister(seed, ssr)) continue;
            const out: FindSeedResults = .{ .seed = seed, .lower_48_checks = lower_48_checks, .sister_checks = upper_16_checks };
            return out;
        }
    }

    return error.SeedNotFound;
}
