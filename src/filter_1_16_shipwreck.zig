const std = @import("std");
const math = std.math;

const cubiomes = @import("cubiomes");
const Pos = cubiomes.Pos;
const Generator = cubiomes.Generator;

const ravines = @import("ravines");
const RavineGenerator = ravines.RavineGenerator;

const common = @import("filter_common.zig");
const findCloseStructure = common.findCloseStructure;
pub const FindSeedResults = common.FindSeedResults;

const seed_features = @import("seed_features.zig");
const java_bits = @import("java_bits.zig");

pub const interface: common.Filter = .{
    .findSeed = &findSeedRegular,
    .isValidSeed = &isValidSeedRegular,
    .isValidStructureSeed = &isValidStructureSeedRegular,
};

pub const interface_overpowered: common.Filter = .{
    .findSeed = &findSeedOverpowered,
    .isValidSeed = &isValidSeedOverpowered,
    .isValidStructureSeed = &isValidStructureSeedOverpowered,
};

pub const StructureSeedCheckResult = struct {
    successful: bool,
    shipwreck_pos: Pos,
    ravine_pos: Pos,
};
const FAIL_RESULT: StructureSeedCheckResult = .{
    .successful = false,
    .shipwreck_pos = undefined,
    .ravine_pos = undefined,
};

const Settings = struct {
    sw_dist: c_int = 48,
    ravine_dist: f64 = 80,
    bastion_dist: c_int = 96,
    fortress_dist: c_int = 256,
    require_full_tools: bool = true, // Doesn't affect filter time for non-op filter so it can be in both
};

const regular_settings: Settings = .{};

const overpowered_settings: Settings = .{
    .ravine_dist = 50,
    .bastion_dist = 32,
    .fortress_dist = 112,
};

fn checkLower48(seed: u64, settings: Settings) StructureSeedCheckResult {
    const origin: Pos = .{ .x = 0, .z = 0 };
    const bastion_pos = findCloseStructure(origin, seed, settings.bastion_dist, cubiomes.Bastion, cubiomes.MC_1_16_1) catch return FAIL_RESULT;

    const fortress_pos = findCloseStructure(origin, seed, settings.fortress_dist, cubiomes.Fortress, cubiomes.MC_1_16_1) catch return FAIL_RESULT;

    var shipwreck_pos: Pos = .{ .x = 0, .z = 0 };
    {
        _ = cubiomes.getStructurePos(cubiomes.Shipwreck, cubiomes.MC_1_16_1, seed, 0, 0, &shipwreck_pos);
        if (shipwreck_pos.x > 208 or shipwreck_pos.z > 208) return FAIL_RESULT;

        var rng = cubiomes.chunkGenerateRnd(seed, shipwreck_pos.x >> 4, shipwreck_pos.z >> 4);
        const rot = cubiomes.nextInt(&rng, 4);
        switch (cubiomes.nextInt(&rng, 20)) {
            0, 7, 10, 17 => {},
            else => {
                return FAIL_RESULT;
            },
        }
        if (rot != 3) return FAIL_RESULT;
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

        const supply_loot = common.getShipwreckSupplyLoot(seed, supply_chest_pos.x, supply_chest_pos.z, common.SHIPWRECK_SALT_1_16, 1);
        const food_val = supply_loot.wheat + supply_loot.carrots * 6;
        if (food_val < 30) {
            return FAIL_RESULT;
        }
        var treasure_loot = common.getShipwreckTreasureLoot(seed, treasure_chest_pos.x, treasure_chest_pos.z, common.SHIPWRECK_SALT_1_16, treasure_chest_num, treasure_chest_num); // Just happens to be the same number

        // Pickaxe
        if (treasure_loot.diamonds >= 3) {
            treasure_loot.diamonds -= 3;
        } else if (treasure_loot.iron >= 3) {
            treasure_loot.iron -= 3;
        } else {
            return FAIL_RESULT;
        }

        // Bucket
        if (treasure_loot.iron >= 3) {
            treasure_loot.iron -= 3;
        } else {
            return FAIL_RESULT;
        }

        // Flint and Steel
        if (treasure_loot.iron >= 1) {
            treasure_loot.iron -= 1;
        } else {
            return FAIL_RESULT;
        }

        if (settings.require_full_tools) { // Always true, but should compile out since settings are const
            // Axe
            if (treasure_loot.diamonds >= 3) {
                treasure_loot.diamonds -= 3;
            } else if (treasure_loot.iron >= 3) {
                treasure_loot.iron -= 3;
            } else if (treasure_loot.gold >= 3) {
                treasure_loot.gold -= 3;
            } else {
                return FAIL_RESULT;
            }

            // Shovel
            if (treasure_loot.diamonds >= 1) {
                treasure_loot.diamonds -= 1;
            } else if (treasure_loot.iron >= 1) {
                treasure_loot.iron -= 1;
            } else if (treasure_loot.gold >= 1) {
                treasure_loot.gold -= 1;
            } else {
                return FAIL_RESULT;
            }
        }
    }

    var generator: Generator = undefined;
    cubiomes.setupGenerator(&generator, cubiomes.MC_1_16_1, 0);
    cubiomes.applySeed(&generator, cubiomes.DIM_NETHER, seed);

    if (0 == cubiomes.isViableStructurePos(cubiomes.Bastion, &generator, bastion_pos.x, bastion_pos.z, 0)) return FAIL_RESULT;
    if (0 == cubiomes.isViableStructurePos(cubiomes.Fortress, &generator, fortress_pos.x, fortress_pos.z, 0)) return FAIL_RESULT;

    const sw_chunk_x = @divFloor(shipwreck_pos.x, 16);
    const sw_chunk_z = @divFloor(shipwreck_pos.z, 16);

    var ravine_pos: Pos = undefined;
    ravine_block: {
        var x: c_int = sw_chunk_x - 7;
        while (x <= sw_chunk_x + 7) : (x += 1) {
            var z: c_int = sw_chunk_z - 7;
            while (z <= sw_chunk_z + 7) : (z += 1) {
                var r: RavineGenerator = ravines.initRavine(seed, x, z);
                if (0 == r.canSpawn or r.verticalRadiusAtCenter < 18) continue;
                ravines.simulateRavineToMiddle(&r);
                if (r.lowerY > 8 or r.upperY < 40) continue;

                const dx: f64 = @abs(r.x - @as(f64, @floatFromInt(shipwreck_pos.x)));
                const dz: f64 = @abs(r.z - @as(f64, @floatFromInt(shipwreck_pos.z)));

                if (dx > settings.ravine_dist or dz > settings.ravine_dist) continue;
                if (dx < 25 and dz < 25) continue;
                ravine_pos = .{ .x = @intFromFloat(r.x), .z = @intFromFloat(r.z) };
                break :ravine_block;
            }
        }
        return FAIL_RESULT;
    }

    if (seed_features.isBastionCheckerEnabled()) {
        const obsidian = java_bits.getObsidianCount(seed, @truncate(@divFloor(bastion_pos.x, 16)), @truncate(@divFloor(bastion_pos.z, 16))) catch @panic("Can't run bastion checker!");
        if (obsidian < 20) return FAIL_RESULT;
    }

    if (seed_features.isTerrainCheckerEnabled()) {
        const bx: i8 = @truncate(@divFloor(bastion_pos.x, 16));
        const bz: i8 = @truncate(@divFloor(bastion_pos.z, 16));
        const fx: i8 = @truncate(@divFloor(fortress_pos.x, 16));
        const fz: i8 = @truncate(@divFloor(fortress_pos.z, 16));
        if (!(java_bits.checkTerrain(seed, bx, bz, fx, fz) catch @panic("Can't run terrain checker!"))) return FAIL_RESULT;
    }

    return .{
        .successful = true,
        .shipwreck_pos = shipwreck_pos,
        .ravine_pos = ravine_pos,
    };
}

fn checkSister(seed: u64, ssr: StructureSeedCheckResult, settings: Settings) bool {
    const shipwreck_pos = ssr.shipwreck_pos;
    const ravine_pos = ssr.ravine_pos;

    var g: Generator = undefined;
    cubiomes.setupGenerator(&g, cubiomes.MC_1_16_1, 0);
    cubiomes.applySeed(&g, cubiomes.DIM_OVERWORLD, seed);

    // Check shipwreck biome
    const shipwreck_biome = cubiomes.getBiomeAt(&g, 4, (shipwreck_pos.x >> 2) + 2, 127, (shipwreck_pos.z >> 2) + 2);
    if (0 == cubiomes.isOceanic(shipwreck_biome)) return false;

    // Check deep ocean for ravine
    if (0 == cubiomes.isDeepOcean(cubiomes.getBiomeAt(&g, 1, ravine_pos.x, 64, ravine_pos.z))) return false;
    // Check deep ocean 2 thirds of the way to ravine
    if (0 == cubiomes.isDeepOcean(cubiomes.getBiomeAt(&g, 1, @divFloor(ravine_pos.x + ravine_pos.x + shipwreck_pos.x, 3), 64, @divFloor(ravine_pos.z + ravine_pos.z + shipwreck_pos.z, 3)))) return false;

    // Check spawn
    const spawn_pos_est: Pos = cubiomes.estimateSpawn(&g, null);
    if (@abs(spawn_pos_est.x - shipwreck_pos.x) > settings.sw_dist or @abs(spawn_pos_est.z - shipwreck_pos.z) > settings.sw_dist) return false;
    // Make sure it isn't janky spawn
    const spawn_pos: Pos = cubiomes.getSpawn(&g);
    if (spawn_pos.x != spawn_pos_est.x or spawn_pos.z != spawn_pos_est.z) return false;

    return true;
}

fn findSeed(init_seed: u64, settings: Settings) FindSeedResults {
    const start_lower_48: u48 = @truncate(init_seed);
    const start_upper_16: u16 = @truncate(init_seed >> 48);

    var lower_48_checks: u49 = 0;
    var lower_48 = start_lower_48;
    while (lower_48_checks < 0x1000000000000) {
        lower_48_checks += 1;
        lower_48 +%= 1; // +%= means Addition with wrapping
        const ssr = checkLower48(@intCast(lower_48), settings);
        if (!ssr.successful) continue;

        var upper_16_checks: u32 = 0;
        var upper_16: u16 = start_upper_16;
        // Sister checking limit used to be way lower since finding a better sister set was more worth it.
        // But now since the structure checks are so heavy, it's not worth it to skip any sister seeds.
        while (upper_16_checks < 65536) {
            upper_16_checks += 1;
            upper_16 +%= 1;
            const seed = @as(u64, lower_48) | (@as(u64, upper_16) << 48);
            if (!checkSister(seed, ssr, settings)) continue;
            const out: FindSeedResults = .{ .seed = seed, .lower_48_checks = lower_48_checks, .sister_checks = upper_16_checks };
            return out;
        }
    }

    @panic("Filter is way too heavy! No seed found!");
}

fn findSeedRegular(init_seed: u64) FindSeedResults {
    return findSeed(init_seed, regular_settings);
}

fn isValidSeedRegular(seed: u64) bool {
    const ssr = checkLower48(seed, regular_settings);
    if (!ssr.successful) return false;
    return checkSister(seed, ssr, regular_settings);
}

fn isValidStructureSeedRegular(seed: u64) bool {
    return checkLower48(seed, regular_settings).successful;
}

fn findSeedOverpowered(init_seed: u64) FindSeedResults {
    return findSeed(init_seed, overpowered_settings);
}

fn isValidSeedOverpowered(seed: u64) bool {
    const ssr = checkLower48(seed, overpowered_settings);
    if (!ssr.successful) return false;
    return checkSister(seed, ssr, overpowered_settings);
}

fn isValidStructureSeedOverpowered(seed: u64) bool {
    return checkLower48(seed, overpowered_settings).successful;
}
