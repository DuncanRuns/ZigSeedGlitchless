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
    bt_pos: Pos,
    ravine_pos: Pos,
};
const FAIL_RESULT: StructureSeedCheckResult = .{
    .successful = false,
    .bt_pos = undefined,
    .ravine_pos = undefined,
};

const Settings = struct {
    bt_dist: c_int = 32,
    ravine_dist: f64 = 80,
    bastion_dist: c_int = 96,
    fortress_dist: c_int = 256,
    require_tnt: bool = false,
};

const regular_settings: Settings = .{};

const overpowered_settings: Settings = .{
    .bt_dist = 24,
    .ravine_dist = 50,
    .bastion_dist = 32,
    .fortress_dist = 112,
    .require_tnt = true,
};

fn checkLower48(seed: u64, settings: Settings) StructureSeedCheckResult {
    const origin: Pos = .{ .x = 0, .z = 0 };
    const bastion_pos = findCloseStructure(origin, seed, settings.bastion_dist, cubiomes.Bastion, cubiomes.MC_1_16_1) catch return FAIL_RESULT;

    const fortress_pos = findCloseStructure(origin, seed, settings.fortress_dist, cubiomes.Fortress, cubiomes.MC_1_16_1) catch return FAIL_RESULT;

    var generator: Generator = undefined;
    cubiomes.setupGenerator(&generator, cubiomes.MC_1_16_1, 0);
    cubiomes.applySeed(&generator, cubiomes.DIM_NETHER, seed);

    if (0 == cubiomes.isViableStructurePos(cubiomes.Bastion, &generator, bastion_pos.x, bastion_pos.z, 0)) return FAIL_RESULT;
    if (0 == cubiomes.isViableStructurePos(cubiomes.Fortress, &generator, fortress_pos.x, fortress_pos.z, 0)) return FAIL_RESULT;

    var bt_found = false;
    var bt_pos: Pos = .{ .x = 0, .z = 0 };
    {
        var x: c_int = -10;
        outer: while (x <= 10) : (x += 1) {
            var z: c_int = -10;
            while (z <= 10) : (z += 1) {
                bt_found = 0 != cubiomes.getStructurePos(cubiomes.Treasure, cubiomes.MC_1_16_1, seed, x, z, &bt_pos) and isGoodBTLoot(seed, x, z, settings.require_tnt);
                if (bt_found) break :outer;
            }
        }
    }
    if (!bt_found) return FAIL_RESULT;

    const bt_chunk_x = @divFloor(bt_pos.x, 16);
    const bt_chunk_z = @divFloor(bt_pos.z, 16);

    var ravine_pos: Pos = undefined;
    ravine_block: {
        var x: c_int = bt_chunk_x - 7;
        while (x <= bt_chunk_x + 7) : (x += 1) {
            var z: c_int = bt_chunk_z - 7;
            while (z <= bt_chunk_z + 7) : (z += 1) {
                var r: RavineGenerator = ravines.initRavine(seed, x, z);
                if (0 == r.canSpawn or r.verticalRadiusAtCenter < 18) continue;
                ravines.simulateRavineToMiddle(&r);
                if (r.lowerY > 8 or r.upperY < 40) continue;

                const dx: f64 = @abs(r.x - @as(f64, @floatFromInt(bt_pos.x)));
                const dz: f64 = @abs(r.z - @as(f64, @floatFromInt(bt_pos.z)));

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
        .bt_pos = bt_pos,
        .ravine_pos = ravine_pos,
    };
}

fn checkSister(seed: u64, ssr: StructureSeedCheckResult, settings: Settings) bool {
    const bt_pos = ssr.bt_pos;
    const ravine_pos = ssr.ravine_pos;

    var g: Generator = undefined;
    cubiomes.setupGenerator(&g, cubiomes.MC_1_16_1, 0);
    cubiomes.applySeed(&g, cubiomes.DIM_OVERWORLD, seed);

    // Check bt biome
    if (0 == cubiomes.isViableStructurePos(cubiomes.Treasure, &g, bt_pos.x, bt_pos.z, 0)) return false;

    // Check for forest around bt
    var forest_found = false;
    var fx: c_int = bt_pos.x - 10;
    var fz: c_int = bt_pos.z - 10;
    outer: while (fx <= bt_pos.x + 10) : (fx += 10) {
        while (fz <= bt_pos.z + 10) : (fz += 10) {
            if (cubiomes.forest == cubiomes.getBiomeAt(&g, 1, fx, 255, fz)) {
                forest_found = true;
                break :outer;
            }
        }
    }

    // Check deep ocean for ravine
    if (0 == cubiomes.isDeepOcean(cubiomes.getBiomeAt(&g, 1, ravine_pos.x, 64, ravine_pos.z))) return false;
    // Check deep ocean 2 thirds of the way to ravine
    if (0 == cubiomes.isDeepOcean(cubiomes.getBiomeAt(&g, 1, @divFloor(ravine_pos.x + ravine_pos.x + bt_pos.x, 3), 64, @divFloor(ravine_pos.z + ravine_pos.z + bt_pos.z, 3)))) return false;

    // Check spawn
    const spawn_pos: Pos = cubiomes.getSpawn(&g);
    if (@abs(spawn_pos.x - bt_pos.x) > settings.bt_dist or @abs(spawn_pos.z - bt_pos.z) > settings.bt_dist) return false;

    // Check forest size
    var biome_cache: [1681]c_int = std.mem.zeroes([1681]c_int);
    if (0 != cubiomes.genBiomes(&g, &biome_cache, .{ .scale = 1, .x = fx - 20, .z = fz - 20, .sx = 41, .sz = 41, .y = 255, .sy = 1 })) return false;

    var t: u9 = 0;
    for (biome_cache) |i| {
        if (i == cubiomes.forest) {
            t += 1;
            if (t == 400) return true;
        }
    }

    return false;
}

fn isGoodBTLoot(seed: u64, x: c_int, z: c_int, require_2_tnt: bool) bool {
    var loot = common.getBTLoot(seed, x, z, common.BURIED_TREASURE_SALT_1_16);

    if (require_2_tnt and loot.tnt < 2) {
        return false;
    }

    // Check iron for flint and steel
    if (loot.iron == 0) {
        return false;
    }
    loot.iron -= 1;

    // Check pickaxe
    if (loot.diamonds >= 3) {
        loot.diamonds -= 3;
    } else if (loot.iron >= 3) {
        loot.iron -= 3;
    } else {
        return false;
    }

    // Check bucket
    if (loot.iron < 3) {
        return false;
    }
    loot.iron -= 3;

    // Check mine wood
    if (loot.tnt >= 1) {
        loot.tnt -= 1;
        // Check make pressure plate
        if (loot.iron >= 2) {
            loot.iron -= 2;
        } else if (loot.gold >= 2) {
            loot.gold -= 2;
        } else {
            return false;
        }
    } else if (loot.iron >= 3) {
        loot.iron -= 3;
    } else if (loot.gold >= 3) {
        loot.gold -= 3;
    } else {
        return false;
    }

    // Check mine gravel
    if (loot.gold >= 1) {
        loot.gold -= 1;
    } else if (loot.diamonds >= 1) {
        loot.diamonds -= 1;
    } else if (loot.iron >= 1) {
        loot.iron -= 1;
    } else if (loot.tnt >= 1) {
        loot.tnt -= 1;
    } else {
        return false;
    }

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
