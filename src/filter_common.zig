const std = @import("std");
const math = std.math;

const cubiomes = @import("cubiomes");
const Pos = cubiomes.Pos;
const Generator = cubiomes.Generator;

pub const BURIED_TREASURE_SALT_1_16: u32 = 30001;
pub const BURIED_TREASURE_SALT_1_15: u32 = 20002;
pub const SHIPWRECK_SALT_1_15: u32 = 30005;
pub const LAVA_LAKE_SALT_1_15: u32 = 10001;

pub const FindSeedResults = struct {
    seed: u64,
    lower_48_checks: u49,
    sister_checks: u32,
};

pub const Filter = struct {
    findSeed: *const fn (init_seed: u64) FindSeedResults,
    isValidSeed: *const fn (seed: u64) bool,
    isValidStructureSeed: *const fn (seed: u64) bool,
};

pub fn findCloseStructure(pos: Pos, seed: u64, search_range: i32, structure_type: c_int, mc_version: c_int) !Pos {
    const chunk_pos: Pos = .{ .x = pos.x >> 4, .z = pos.z >> 4 };
    const chunk_x: i32 = chunk_pos.x;
    const chunk_z: i32 = chunk_pos.z;

    var config: cubiomes.StructureConfig = undefined;
    if (0 == cubiomes.getStructureConfig(structure_type, mc_version, &config)) return error.FailedToGetStructureConfig;
    const gap: i32 = config.regionSize - config.chunkRange;
    const region_size: f32 = @floatFromInt(config.regionSize);

    const search_chunk_range: i32 = @intFromFloat(math.ceil(@as(f32, @floatFromInt(search_range)) / 16));
    const minrx: i32 = @intFromFloat(math.floor(@as(f32, @floatFromInt(chunk_x + gap - search_chunk_range)) / region_size));
    const maxrx: i32 = @intFromFloat(math.floor(@as(f32, @floatFromInt(chunk_x + search_chunk_range)) / region_size));
    const minrz: i32 = @intFromFloat(math.floor(@as(f32, @floatFromInt(chunk_z + gap - search_chunk_range)) / region_size));
    const maxrz: i32 = @intFromFloat(math.floor(@as(f32, @floatFromInt(chunk_z + search_chunk_range)) / region_size));
    var rx = minrx;
    while (rx <= maxrx) : (rx += 1) {
        var rz = minrz;
        while (rz <= maxrz) : (rz += 1) {
            var potentialPos: Pos = undefined;
            if (0 == cubiomes.getStructurePos(structure_type, mc_version, seed, rx, rz, &potentialPos))
                continue;

            if ((@abs(pos.x - potentialPos.x) > search_range) or (@abs(pos.z - potentialPos.z) > search_range))
                continue;

            return potentialPos;
        }
    }
    return error.FailedToFindStructure;
}

pub fn findCloseStructureG(pos: Pos, seed: u64, search_range: i32, structure_type: c_int, mc_version: c_int, generator: [*c]Generator) !Pos {
    const chunk_pos: Pos = .{ .x = pos.x >> 4, .z = pos.z >> 4 };
    const chunk_x: i32 = chunk_pos.x;
    const chunk_z: i32 = chunk_pos.z;

    var config: cubiomes.StructureConfig = undefined;
    if (0 == cubiomes.getStructureConfig(structure_type, mc_version, &config)) return error.FailedToGetStructureConfig;
    const gap: i32 = config.regionSize - config.chunkRange;
    const region_size: f32 = @floatFromInt(config.regionSize);

    const search_chunk_range: i32 = @intFromFloat(math.ceil(@as(f32, @floatFromInt(search_range)) / 16));
    const minrx: i32 = @intFromFloat(math.floor(@as(f32, @floatFromInt(chunk_x + gap - search_chunk_range)) / region_size));
    const maxrx: i32 = @intFromFloat(math.floor(@as(f32, @floatFromInt(chunk_x + search_chunk_range)) / region_size));
    const minrz: i32 = @intFromFloat(math.floor(@as(f32, @floatFromInt(chunk_z + gap - search_chunk_range)) / region_size));
    const maxrz: i32 = @intFromFloat(math.floor(@as(f32, @floatFromInt(chunk_z + search_chunk_range)) / region_size));
    var rx = minrx;
    while (rx <= maxrx) : (rx += 1) {
        var rz = minrz;
        while (rz <= maxrz) : (rz += 1) {
            var potentialPos: Pos = undefined;
            if (0 == cubiomes.getStructurePos(structure_type, mc_version, seed, rx, rz, &potentialPos))
                continue;

            if ((@abs(pos.x - potentialPos.x) > search_range) or (@abs(pos.z - potentialPos.z) > search_range))
                continue;

            if (0 == cubiomes.isViableStructurePos(structure_type, generator, pos.x, pos.z, 0))
                continue;

            return potentialPos;
        }
    }
    return error.FailedToFindStructure;
}

pub fn getPopulationSeed(world_seed: u64, block_x: c_int, block_z: c_int) u64 {
    var rand: u64 = undefined;
    cubiomes.setSeed(&rand, world_seed);
    const a: u64 = cubiomes.nextLong(&rand) | 1;
    const b: u64 = cubiomes.nextLong(&rand) | 1;

    const popSeed: u64 = @as(u64, @bitCast(@as(i64, @intCast(block_x)))) *% a +% @as(u64, @bitCast(@as(i64, @intCast(block_z)))) *% b ^ world_seed;
    return popSeed & 0xFFFFFFFFFFFF;
}

pub fn getDecoratorSeed(world_seed: u64, block_x: c_int, block_z: c_int, salt: u32) u64 {
    const populationSeed: u64 = getPopulationSeed(world_seed, block_x, block_z);
    return (populationSeed + salt) & 0xFFFFFFFFFFFF;
}

pub fn getLootSeed(seed: u64, block_x: c_int, block_z: c_int, salt: u32) u64 {
    var rand: u64 = 0;
    cubiomes.setSeed(&rand, getDecoratorSeed(seed, block_x, block_z, salt));
    return cubiomes.nextLong(&rand);
}

/// chest_num is 1 for the first chest, 2 for the second chest, etc.
/// chest_num <= 1 is equivalent to getLootSeed.
pub fn getIndexedLootSeed(seed: u64, block_x: c_int, block_z: c_int, salt: u32, chest_num: u8) u64 {
    var rand: u64 = 0;
    cubiomes.setSeed(&rand, getDecoratorSeed(seed, block_x, block_z, salt));
    var i = chest_num;
    while (i > 1) : (i -= 1) {
        _ = cubiomes.nextLong(&rand);
    }
    return cubiomes.nextLong(&rand);
}

const ShipwreckTreasureLoot = struct {
    iron: i8,
    diamonds: i8,
    gold: i8,
    emeralds: i8,
};

pub fn getShipwreckTreasureLoot(seed: u64, block_x: c_int, block_z: c_int, salt: u32, chest_num: u8) ShipwreckTreasureLoot {
    var r: u64 = 0;
    cubiomes.setSeed(&r, getIndexedLootSeed(seed, block_x, block_z, salt, chest_num));
    var iron: i8 = 0;
    var iron_nuggets: i8 = 0;
    var diamonds: i8 = 0;
    var gold: i8 = 0;
    var gold_nuggets: i8 = 0;
    var emeralds: i8 = 0;

    // Pool 1 (w150): 3-6 uni rolls, w90 1-5 iron_ingot, w10 1-5 gold_ingot, w40 1-5 emerald, w5 1 diamond, w5 1 experience bottle
    {
        const max = cubiomes.nextInt(&r, 4) + 3;
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&r, 150);
            if (choice < 90) {
                iron += @truncate(cubiomes.nextInt(&r, 5) + 1);
            } else if (choice < 100) {
                gold += @truncate(cubiomes.nextInt(&r, 5) + 1);
            } else if (choice < 140) {
                emeralds += @truncate(cubiomes.nextInt(&r, 5) + 1);
            } else if (choice < 145) {
                diamonds += 1;
            } // else 1 experience bottle
        }
    }

    // Pool 2 (w80): 2-5 uni rolls, w50 1-10 iron_nugget, w10 1-10 gold_nugget, w20 1-10 lapis_lazuli
    {
        const max = cubiomes.nextInt(&r, 4) + 2;
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&r, 80);
            const amount = cubiomes.nextInt(&r, 10) + 1; // All entries in this pool are 1-10
            if (choice < 50) {
                iron_nuggets += @truncate(amount);
            } else if (choice < 70) {
                gold_nuggets += @truncate(amount);
            } // else amount lapis
        }
    }
    return .{
        .iron = iron + @divFloor(iron_nuggets, 9),
        .diamonds = diamonds,
        .gold = gold + @divFloor(gold_nuggets, 9),
        .emeralds = emeralds,
    };
}

const ShipwreckSupplyLoot = struct {
    tnt: i8,
    gunpowder: i8,
    wheat: i16, // Can get up to 210 wheat so more space needed than i8
    carrots: i8,
    rotten_flesh: i8,
};

pub fn getShipwreckSupplyLoot(seed: u64, block_x: c_int, block_z: c_int, salt: u32) ShipwreckSupplyLoot {
    var r: u64 = 0;
    cubiomes.setSeed(&r, getLootSeed(seed, block_x, block_z, salt)); // chest_num always 1
    var tnt: i8 = 0;
    var gunpowder: i8 = 0;
    var wheat: i16 = 0;
    var carrots: i8 = 0;
    var rotten_flesh: i8 = 0;

    // Only 1 Pool (w77) 3-10 uni rolls
    // w8 1-12 paper
    // w14 2-6 (poisonous_)potato
    // w7 4-8 carrot
    // w7 8-21 wheat
    // w10 stew + effect calc
    // w6 2-8 coal
    // w5 5-24 rotten_flesh
    // w4 1-3 pumpkin/bamboo
    // w3 1-5 gunpowder
    // w1 1-2 tnt
    // w3 leather_helmet + enchant_randomly
    // w3 leather_chestplate + enchant_randomly
    // w3 leather_leggings + enchant_randomly
    // w3 leather_boots + enchant_randomly
    const max = cubiomes.nextInt(&r, 8) + 3;
    var i: i32 = 0;
    while (i < max) : (i += 1) {
        const choice = cubiomes.nextInt(&r, 77);
        if (choice < 8) {
            // std.debug.print("Paper\n", .{});
            _ = cubiomes.nextInt(&r, 12);
        } else if (choice < 22) {
            // std.debug.print("Potato\n", .{});
            _ = cubiomes.nextInt(&r, 5);
        } else if (choice < 29) {
            // std.debug.print("Carrot\n", .{});
            carrots += @truncate(cubiomes.nextInt(&r, 5) + 4);
        } else if (choice < 36) {
            // std.debug.print("wheat\n", .{});
            wheat += @truncate(cubiomes.nextInt(&r, 14) + 8);
        } else if (choice < 46) {
            // std.debug.print("Stew\n", .{});
            // Discard effect calculation
            _ = switch (cubiomes.nextInt(&r, 6)) {
                0, 5 => cubiomes.nextInt(&r, 3),
                4 => cubiomes.nextInt(&r, 11),
                else => cubiomes.nextInt(&r, 4),
            };
        } else if (choice < 52) {
            // std.debug.print("Coal\n", .{});
            _ = cubiomes.nextInt(&r, 7);
        } else if (choice < 57) {
            // std.debug.print("Flesh\n", .{});
            rotten_flesh += @truncate(cubiomes.nextInt(&r, 20) + 5);
        } else if (choice < 61) {
            // std.debug.print("Pump/Bamb\n", .{});
            _ = cubiomes.nextInt(&r, 3);
        } else if (choice < 64) {
            // std.debug.print("Gunpowder\n", .{});
            gunpowder += @truncate(cubiomes.nextInt(&r, 5) + 1);
        } else if (choice < 65) {
            // std.debug.print("Tnt\n", .{});
            tnt += @truncate(cubiomes.nextInt(&r, 2) + 1);
        } else if (choice < 68) {
            // std.debug.print("Helmet\n", .{});
            _ = switch (cubiomes.nextInt(&r, 11)) {
                0, 1, 2, 3 => cubiomes.nextInt(&r, 4),
                4, 6, 8 => cubiomes.nextInt(&r, 3),
                else => 0,
            };
        } else if (choice < 74) {
            // std.debug.print("Chest/Legs\n", .{});
            _ = switch (cubiomes.nextInt(&r, 9)) {
                0, 1, 2, 3 => cubiomes.nextInt(&r, 4),
                4, 6 => cubiomes.nextInt(&r, 3),
                else => 0,
            };
        } else if (choice < 77) {
            // std.debug.print("Boots\n", .{});
            _ = switch (cubiomes.nextInt(&r, 12)) {
                0, 1, 2, 3, 4 => cubiomes.nextInt(&r, 4),
                7 => cubiomes.nextInt(&r, 2),
                5, 6, 9 => cubiomes.nextInt(&r, 3),
                else => 0,
            };
        }
    }

    return .{
        .tnt = tnt,
        .gunpowder = gunpowder,
        .wheat = wheat,
        .carrots = carrots,
        .rotten_flesh = rotten_flesh,
    };
}

const BuriedTreasureLoot = struct {
    iron: i8,
    tnt: i8,
    diamonds: i8,
    gold: i8,
    emeralds: i8,
};

pub fn getBTLoot(seed: u64, chunk_x: c_int, chunk_z: c_int, salt: u32) BuriedTreasureLoot {
    var rand: u64 = 0;
    cubiomes.setSeed(&rand, getLootSeed(seed, chunk_x * 16, chunk_z * 16, salt));
    var iron: i8 = 0;
    var tnt: i8 = 0;
    var diamonds: i8 = 0;
    var gold: i8 = 0;
    var emeralds: i8 = 0;

    // Pool 1 (no rng)
    // Pool 2: 5-8 uni rolls, w20 iron, w10 gold, w5 tnt
    {
        const max = cubiomes.nextInt(&rand, 4) + 5;
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&rand, 35);
            if (choice < 20) {
                iron += @truncate(cubiomes.nextInt(&rand, 4) + 1);
            } else if (choice < 30) {
                gold += @truncate(cubiomes.nextInt(&rand, 4) + 1);
            } else {
                tnt += @truncate(cubiomes.nextInt(&rand, 2) + 1);
            }
        }
    }
    // Pool 3: 1-3 uni rolls, w5 emerald, w5 diamond, w5 prismarine crystals
    {
        const max = cubiomes.nextInt(&rand, 3) + 1;
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&rand, 15);
            if (choice < 5) {
                emeralds += @truncate(cubiomes.nextInt(&rand, 5) + 4);
            } else if (choice < 10) {
                diamonds += @truncate(cubiomes.nextInt(&rand, 2) + 1);
            } else {
                _ = cubiomes.next(&rand, 31);
            }
        }
    }

    return .{ .iron = iron, .tnt = tnt, .diamonds = diamonds, .gold = gold, .emeralds = emeralds };
}

pub const LavaLake = struct { x: c_int, y: c_int, z: c_int };

pub fn getLavaLake(world_seed: u64, block_x: c_int, block_z: c_int, salt: u32) ?LavaLake {
    var r: u64 = undefined;
    cubiomes.setSeed(&r, getDecoratorSeed(world_seed, block_x, block_z, salt));
    if (cubiomes.nextInt(&r, 8) != 0) return null;

    const block_in_chunk_x = cubiomes.nextInt(&r, 16);
    const block_in_chunk_z = cubiomes.nextInt(&r, 16);
    const y = cubiomes.nextInt(&r, cubiomes.nextInt(&r, 248) + 8);
    if (y < 63 or cubiomes.nextInt(&r, 10) == 0) {
        return .{
            .x = block_in_chunk_x + block_x,
            .y = y,
            .z = block_in_chunk_z + block_z,
        };
    }
    return null;
}

// Slightly faster variation for only the more likely lakes
pub fn getLavaLakeBelowSeaLevel(world_seed: u64, block_x: c_int, block_z: c_int, salt: u32) ?LavaLake {
    var r: u64 = undefined;
    cubiomes.setSeed(&r, getDecoratorSeed(world_seed, block_x, block_z, salt));
    if (cubiomes.nextInt(&r, 8) != 0) return null;

    const block_in_chunk_x = cubiomes.nextInt(&r, 16);
    const block_in_chunk_z = cubiomes.nextInt(&r, 16);
    const y = cubiomes.nextInt(&r, cubiomes.nextInt(&r, 248) + 8);
    if (y < 63) {
        return .{
            .x = block_in_chunk_x + block_x,
            .y = y,
            .z = block_in_chunk_z + block_z,
        };
    }
    return null;
}
