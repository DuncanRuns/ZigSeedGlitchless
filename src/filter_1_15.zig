const std = @import("std");
const math = std.math;

const cubiomes = @import("cubiomes");
const Pos = cubiomes.Pos;
const Generator = cubiomes.Generator;
const MC_VER = cubiomes.MC_1_15_2;

const ravines = @import("ravines");
const RavineGenerator = ravines.RavineGenerator;

const common = @import("filter_common.zig");
pub const FindSeedResults = common.FindSeedResults;

pub const interface: common.Filter = .{
    .findSeed = &findSeed,
    .isValidSeed = &isValidSeed,
    .isValidStructureSeed = &isValidStructureSeed,
};

const StructureSeedCheckResult = struct {
    successful: bool,
    shipwreck_pos: Pos,
    monument_pos: Pos,
    village_pos: Pos,
};

const FAIL_RESULT: StructureSeedCheckResult = .{
    .successful = false,
    .shipwreck_pos = undefined,
    .monument_pos = undefined,
    .village_pos = undefined,
};

fn checkLower48(seed: u64) StructureSeedCheckResult {
    {
        var rng: u64 = undefined;
        cubiomes.setSeed(&rng, seed);
        const dist: f64 = (4.0 * 32.0) + (cubiomes.nextDouble(&rng) - 0.5) * 32 * 2.5;
        const angle: f64 = 2 * 3.14159265358979323846 * cubiomes.nextDouble(&rng);
        if (dist > 100 or angle > 0.959931 or angle < 0.610865) return FAIL_RESULT;
    }

    var fortress_pos: Pos = undefined;
    if (0 == cubiomes.getStructurePos(cubiomes.Fortress, MC_VER, seed, 0, 0, &fortress_pos)) return FAIL_RESULT;

    var shipwreck_pos: Pos = undefined;
    {
        _ = cubiomes.getStructurePos(cubiomes.Shipwreck, MC_VER, seed, 0, 0, &shipwreck_pos); // Always succeeds

        var rng = cubiomes.chunkGenerateRnd(seed, shipwreck_pos.x >> 4, shipwreck_pos.z >> 4);
        const rot = cubiomes.nextInt(&rng, 4);
        const shipwreck_variant = cubiomes.nextInt(&rng, 20);
        switch (shipwreck_variant) {
            0, 7, 10, 17 => {
                // Hooray! All these variants have the same chest positions
            },
            else => {
                return FAIL_RESULT;
            },
        }
        // 1st chest in chunk for rotation 1 (facing east)
        // 2nd chest in chunk for rotations 0, 2, and 3
        const treasure_chest_num: u8 = switch (rot) {
            1 => 1,
            else => 2,
        };
        const treasure_chest_pos: Pos = switch (rot) {
            0 => .{ .x = shipwreck_pos.x, .z = shipwreck_pos.z + 16 },
            1 => .{ .x = shipwreck_pos.x - 16, .z = shipwreck_pos.z + 16 },
            else => .{ .x = shipwreck_pos.x, .z = shipwreck_pos.z },
        };
        const supply_chest_pos: Pos = switch (rot) {
            2 => .{ .x = shipwreck_pos.x, .z = shipwreck_pos.z + 16 },
            3 => .{ .x = shipwreck_pos.x - 16, .z = shipwreck_pos.z },
            else => .{ .x = shipwreck_pos.x, .z = shipwreck_pos.z },
        };

        const supply_loot = common.getShipwreckSupplyLoot(seed, supply_chest_pos.x, supply_chest_pos.z, common.SHIPWRECK_SALT_1_15);
        if (supply_loot.gunpowder < 5 and supply_loot.tnt == 0) {
            return FAIL_RESULT;
        }
        const treasure_loot = common.getShipwreckTreasureLoot(seed, treasure_chest_pos.x, treasure_chest_pos.z, common.SHIPWRECK_SALT_1_15, treasure_chest_num);
        if (treasure_loot.iron < 7 and (treasure_loot.diamonds < 3 or treasure_loot.iron < 4) and (treasure_loot.diamonds < 1 or treasure_loot.iron < 6) and (treasure_loot.diamonds < 4 or treasure_loot.iron < 3)) {
            return FAIL_RESULT;
        }
        if ((supply_loot.rotten_flesh < 32 or treasure_loot.emeralds < 7) and treasure_loot.emeralds < 10) {
            return FAIL_RESULT;
        }
    }

    var monument_pos: Pos = undefined;
    _ = cubiomes.getStructurePos(cubiomes.Monument, MC_VER, seed, 0, 0, &monument_pos); // Always succeeds

    if (monument_pos.x - shipwreck_pos.x < 128 and monument_pos.z - shipwreck_pos.z < 128) return FAIL_RESULT;
    if (monument_pos.x < shipwreck_pos.x or monument_pos.z < shipwreck_pos.z) return FAIL_RESULT;

    var village_pos: Pos = undefined;
    _ = cubiomes.getStructurePos(cubiomes.Village, MC_VER, seed, 1, 1, &village_pos); // Always succeeds

    // if (common.getLavaLakeBelowSeaLevel(seed, village_pos.x + 16, village_pos.z + 16, common.LAVA_LAKE_SALT_1_15)) |lake| {
    //     // std.debug.print("{d}\n", .{lake.y});
    //     if (lake.y < 22) {
    //         return FAIL_RESULT;
    //     }
    // } else {
    //     return FAIL_RESULT;
    // }

    if (@abs(@divFloor(monument_pos.x, 8) - fortress_pos.x) > 60) return FAIL_RESULT;
    if (@abs(@divFloor(monument_pos.z, 8) - fortress_pos.z) > 60) return FAIL_RESULT;

    return .{
        .successful = true,
        .shipwreck_pos = shipwreck_pos,
        .monument_pos = monument_pos,
        .village_pos = village_pos,
    };
}

fn checkSister(seed: u64, ssr: StructureSeedCheckResult) bool {
    const shipwreck_pos = ssr.shipwreck_pos;
    const monument_pos = ssr.monument_pos;
    const village_pos = ssr.village_pos;

    var g: Generator = undefined;
    cubiomes.setupGenerator(&g, MC_VER, 0);
    cubiomes.applySeed(&g, cubiomes.DIM_OVERWORLD, seed);

    // Check shipwreck biome
    if (0 == cubiomes.isViableStructurePos(cubiomes.Shipwreck, &g, shipwreck_pos.x, shipwreck_pos.z, 0)) return false;
    const shipwreck_biome = cubiomes.getBiomeAt(&g, 1, shipwreck_pos.x + 9, 127, shipwreck_pos.z + 9);
    if (shipwreck_biome == cubiomes.beach or shipwreck_biome == cubiomes.snowy_beach) return false;
    if (0 == cubiomes.isViableStructurePos(cubiomes.Monument, &g, monument_pos.x, monument_pos.z, 0)) return false;
    const village_biome = cubiomes.getBiomeAt(&g, 1, village_pos.x, 255, village_pos.z);
    if (cubiomes.savanna != village_biome) return false;

    // Check spawn
    const spawn_pos: Pos = cubiomes.getSpawn(&g);
    if (@abs(spawn_pos.x - shipwreck_pos.x) > 30 or @abs(spawn_pos.z - shipwreck_pos.z) > 30) return false;

    return true;
}

fn findSeed(init_seed: u64) FindSeedResults {
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
        while (upper_16_checks < 200) {
            upper_16_checks += 1;
            upper_16 +%= 1;
            const seed = @as(u64, lower_48) | (@as(u64, upper_16) << 48);
            if (!checkSister(seed, ssr)) continue;
            const out: FindSeedResults = .{ .seed = seed, .lower_48_checks = lower_48_checks, .sister_checks = upper_16_checks };
            return out;
        }
    }

    @panic("Filter is way too heavy! No seed found!");
}

fn isValidSeed(seed: u64) bool {
    const ssr = checkLower48(seed);
    if (!ssr.successful) return false;
    return checkSister(seed, ssr);
}

fn isValidStructureSeed(seed: u64) bool {
    return checkLower48(seed).successful;
}
