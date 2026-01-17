const std = @import("std");
const math = std.math;

const cubiomes = @import("cubiomes");
const Pos = cubiomes.Pos;
const Generator = cubiomes.Generator;

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
    main_pos: Pos,
    rp_pos: Pos,
};
const FAIL_RESULT: StructureSeedCheckResult = .{
    .successful = false,
    .main_pos = undefined,
    .rp_pos = undefined,
};

const Settings = struct {
    spawn_dist: c_int = 32,
    ow_structure_dist: c_int = 48,
    bastion_dist: c_int = 96,
    fortress_dist: c_int = 256,
};

const regular_settings: Settings = .{};

const overpowered_settings: Settings = .{
    .bastion_dist = 32,
    .fortress_dist = 112,
};

fn checkLower48(seed: u64, settings: Settings) StructureSeedCheckResult {
    const origin: Pos = .{ .x = 0, .z = 0 };
    const bastion_pos = findCloseStructure(origin, seed, settings.bastion_dist, cubiomes.Bastion, cubiomes.MC_1_16_1) catch return FAIL_RESULT;

    const fortress_pos = findCloseStructure(origin, seed, settings.fortress_dist, cubiomes.Fortress, cubiomes.MC_1_16_1) catch return FAIL_RESULT;

    var main_pos: Pos = .{ .x = 0, .z = 0 };
    if (0 == cubiomes.getStructurePos(cubiomes.Village, cubiomes.MC_1_16_1, seed, 0, 0, &main_pos)) return FAIL_RESULT;
    if (main_pos.x > 224 or main_pos.z > 224) return FAIL_RESULT;

    var rp_pos: Pos = .{ .x = 0, .z = 0 };
    if (0 == cubiomes.getStructurePos(cubiomes.Ruined_Portal, cubiomes.MC_1_16_1, seed, 0, 0, &rp_pos)) return FAIL_RESULT;
    if (@abs(main_pos.x - rp_pos.x) > settings.ow_structure_dist or @abs(main_pos.z - rp_pos.z) > settings.ow_structure_dist) return FAIL_RESULT;

    var sv: common.StructureVariantZig = .{};
    if (0 == cubiomes.getVariant(@ptrCast(&sv), cubiomes.Ruined_Portal, cubiomes.MC_1_16_1, seed, rp_pos.x, rp_pos.z, cubiomes.plains)) return FAIL_RESULT;

    // Check underground
    if ((sv.flags & (1 << 2)) != 0) return FAIL_RESULT;
    // Check airpocket
    if ((sv.flags & (1 << 3)) != 0) return FAIL_RESULT;
    // Check giant
    if ((sv.flags & (1 << 1)) == 0) { // All giant portals have lava
        switch (sv.start) {
            2, 7, 8, 10 => {}, // Small portals with lava
            else => return FAIL_RESULT,
        }
    }
    // Check loot
    const loot = common.getRuinedPortalLoot(seed, rp_pos.x, rp_pos.z, common.RUINED_PORTAL_SALT_1_16);
    if (loot.obsidian >= 10) loot.iron_nuggets += 27; // Reads stupidly but means that 10 obsidian can replace 27 iron nuggets (bucket)
    if (loot.iron_nuggets < 27) return FAIL_RESULT;
    if (loot.flint_and_steels < 1 and loot.fire_charges < 1 and !(loot.iron_nuggets >= 36 and loot.flint >= 1)) return FAIL_RESULT;

    var generator: Generator = undefined;
    cubiomes.setupGenerator(&generator, cubiomes.MC_1_16_1, 0);
    cubiomes.applySeed(&generator, cubiomes.DIM_NETHER, seed);

    if (0 == cubiomes.isViableStructurePos(cubiomes.Bastion, &generator, bastion_pos.x, bastion_pos.z, 0)) return FAIL_RESULT;
    if (0 == cubiomes.isViableStructurePos(cubiomes.Fortress, &generator, fortress_pos.x, fortress_pos.z, 0)) return FAIL_RESULT;

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
        .main_pos = main_pos,
        .rp_pos = rp_pos,
    };
}

fn checkSister(seed: u64, ssr: StructureSeedCheckResult, settings: Settings) bool {
    const main_pos = ssr.main_pos;
    const rp_pos = ssr.rp_pos;

    var g: Generator = undefined;
    cubiomes.setupGenerator(&g, cubiomes.MC_1_16_1, 0);
    cubiomes.applySeed(&g, cubiomes.DIM_OVERWORLD, seed);

    // Check village biome
    const village_biome = cubiomes.getBiomeAt(&g, 4, (main_pos.x >> 2) + 2, 255, (main_pos.z >> 2) + 2);
    switch (village_biome) {
        cubiomes.plains, cubiomes.savanna, cubiomes.desert => {},
        else => return false,
    }
    // Check village variant
    var sv: common.StructureVariantZig = .{};
    if (0 == cubiomes.getVariant(@ptrCast(&sv), cubiomes.Village, cubiomes.MC_1_16_1, seed, main_pos.x, main_pos.z, village_biome)) return false;
    // No abandoned
    if ((sv.flags & (1 << 0)) != 0) return false;

    // Check rp biome
    const rp_biome = cubiomes.getBiomeAt(&g, 4, (rp_pos.x >> 2) + 2, 255, (rp_pos.z >> 2) + 2);
    switch (rp_biome) {
        cubiomes.forest,
        cubiomes.birch_forest,
        cubiomes.dark_forest,
        cubiomes.flower_forest,
        cubiomes.tall_birch_forest,
        cubiomes.plains,
        cubiomes.sunflower_plains,
        cubiomes.savanna,
        cubiomes.taiga,
        cubiomes.giant_tree_taiga,
        => {},
        else => return false,
    }

    // Recheck rp variant
    if (0 == cubiomes.getVariant(@ptrCast(&sv), cubiomes.Ruined_Portal, cubiomes.MC_1_16_1, seed, rp_pos.x, rp_pos.z, rp_biome)) return false;

    if ((sv.flags & (1 << 2)) != 0) return false;
    if ((sv.flags & (1 << 1)) == 0) {
        switch (sv.start) {
            2, 7, 8, 10 => {},
            else => return false,
        }
    }

    // Check for tree biome around village
    var trees_found = false;
    const diff: c_int = 30;
    var fx: c_int = main_pos.x - diff;
    var fz: c_int = main_pos.z - diff;
    outer: while (fx <= main_pos.x + diff) : (fx += diff) {
        while (fz <= main_pos.z + diff) : (fz += diff) {
            switch (cubiomes.getCategory(cubiomes.MC_1_16_1, cubiomes.getBiomeAt(&g, 1, fx, 255, fz))) {
                cubiomes.forest,
                cubiomes.jungle,
                cubiomes.savanna,
                cubiomes.swamp,
                cubiomes.taiga,
                => {
                    trees_found = true;
                    break :outer;
                },
                else => {},
            }
        }
    }
    if (!trees_found) return false;

    // Check spawn
    const spawn_pos: Pos = cubiomes.getSpawn(&g);
    return (@abs(spawn_pos.x - main_pos.x) <= settings.spawn_dist and @abs(spawn_pos.z - main_pos.z) <= settings.spawn_dist) or (@abs(spawn_pos.x - rp_pos.x) <= settings.spawn_dist and @abs(spawn_pos.z - rp_pos.z) <= settings.spawn_dist);
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
