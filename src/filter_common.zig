const std = @import("std");
const math = std.math;

const cubiomes = @import("cubiomes");
const Pos = cubiomes.Pos;
const Generator = cubiomes.Generator;

pub const DESERT_PYRAMID_SALT_1_16: u32 = 40003;
pub const BURIED_TREASURE_SALT_1_16: u32 = 30001;
pub const BURIED_TREASURE_SALT_1_15: u32 = 20002;
pub const SHIPWRECK_SALT_1_15: u32 = 30005;
pub const SHIPWRECK_SALT_1_16: u32 = 40006;
pub const LAVA_LAKE_SALT_1_15: u32 = 10001;
pub const DESERT_LAVA_LAKE_SALT_1_16: u32 = 10000;
pub const RUINED_PORTAL_SALT_1_16: u32 = 40005;

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

pub const StructureVariantZig = extern struct {
    flags: u8 = 0, // combines abandoned, giant, underground, airpocket, basement, cracked
    size: u8 = 0,
    start: u8 = 0,
    biome: i16 = 0,
    rotation: u8 = 0,
    mirror: u8 = 0,
    x: i16 = 0,
    y: i16 = 0,
    z: i16 = 0,
    sx: i16 = 0,
    sy: i16 = 0,
    sz: i16 = 0,
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

pub fn getLootSeed(seed: u64, block_x: c_int, block_z: c_int, salt: u32, rng_trashing: u8) u64 {
    var rand: u64 = 0;
    cubiomes.setSeed(&rand, getDecoratorSeed(seed, block_x, block_z, salt));
    var i = rng_trashing;
    while (i > 0) : (i -= 1) {
        _ = cubiomes.next(&rand, 32);
        _ = cubiomes.next(&rand, 32);
    }
    return cubiomes.nextLong(&rand);
}

/// chest_num is 1 for the first chest, 2 for the second chest, etc.
pub fn getIndexedLootSeed(seed: u64, block_x: c_int, block_z: c_int, salt: u32, chest_num: u8, rng_trashing: u8) u64 {
    var rand: u64 = 0;
    cubiomes.setSeed(&rand, getDecoratorSeed(seed, block_x, block_z, salt));
    var i = chest_num + rng_trashing;
    while (i > 1) : (i -= 1) {
        _ = cubiomes.next(&rand, 32);
        _ = cubiomes.next(&rand, 32);
    }
    return cubiomes.nextLong(&rand);
}

const ShipwreckTreasureLoot = struct {
    iron: u8,
    diamonds: u8,
    gold: u8,
    emeralds: u8,
};

pub fn getShipwreckTreasureLoot(seed: u64, block_x: c_int, block_z: c_int, salt: u32, chest_num: u8, rng_trashing: u8) ShipwreckTreasureLoot {
    var r: u64 = 0;
    cubiomes.setSeed(&r, getIndexedLootSeed(seed, block_x, block_z, salt, chest_num, rng_trashing));
    var iron: u8 = 0;
    var iron_nuggets: u8 = 0;
    var diamonds: u8 = 0;
    var gold: u8 = 0;
    var gold_nuggets: u8 = 0;
    var emeralds: u8 = 0;

    // Pool 1 (w150): 3-6 uni rolls
    // w90 1-5 iron_ingot
    // w10 1-5 gold_ingot
    // w40 1-5 emerald
    // w5 1 diamond
    // w5 1 experience bottle
    {
        const max = nextCount(&r, 3, 6);
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&r, 150);
            if (choice < 90) {
                // 1-5 iron_ingot
                iron += @intCast(nextCount(&r, 1, 5));
            } else if (choice < 100) {
                // 1-5 gold_ingot
                gold += @intCast(nextCount(&r, 1, 5));
            } else if (choice < 140) {
                // 1-5 emerald
                emeralds += @intCast(nextCount(&r, 1, 5));
            } else if (choice < 145) {
                // 1 diamond
                diamonds += 1;
            } // else 1 experience bottle
        }
    }

    // Pool 2 (w80): 2-5 uni rolls
    // w50 1-10 iron_nugget
    // w10 1-10 gold_nugget
    // w20 1-10 lapis_lazuli
    {
        const max = nextCount(&r, 2, 5);
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&r, 80);
            // All entries in this pool are 1-10
            const amount = nextCount(&r, 1, 10);
            if (choice < 50) {
                iron_nuggets += @intCast(amount);
            } else if (choice < 70) {
                gold_nuggets += @intCast(amount);
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
    tnt: u8,
    gunpowder: u8,
    wheat: u16, // Can get up to 210 wheat so more space needed than i8
    carrots: u8,
    rotten_flesh: u16,
};

pub fn getShipwreckSupplyLoot(seed: u64, block_x: c_int, block_z: c_int, salt: u32, rng_trashing: u8) ShipwreckSupplyLoot {
    var r: u64 = 0;
    cubiomes.setSeed(&r, getLootSeed(seed, block_x, block_z, salt, rng_trashing)); // chest_num always 1
    var tnt: u8 = 0;
    var gunpowder: u8 = 0;
    var wheat: u16 = 0;
    var carrots: u8 = 0;
    var rotten_flesh: u16 = 0;

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
    const max = nextCount(&r, 3, 10);
    var i: i32 = 0;
    while (i < max) : (i += 1) {
        const choice = cubiomes.nextInt(&r, 77);
        if (choice < 8) {
            // 1-12 paper
            disposeNextCount(&r, 1, 12);
        } else if (choice < 22) {
            // 2-6 (poisonous_)potato
            disposeNextCount(&r, 2, 6);
        } else if (choice < 29) {
            // 4-8 carrot
            carrots += @intCast(nextCount(&r, 4, 8));
        } else if (choice < 36) {
            // 8-21 wheat
            wheat += @intCast(nextCount(&r, 8, 21));
        } else if (choice < 46) {
            // std.debug.print("Stew\n", .{});
            // Discard effect calculation
            cubiomes.skipNextN(&r, 2);
        } else if (choice < 52) {
            // 2-8 coal
            disposeNextCount(&r, 2, 8);
        } else if (choice < 57) {
            // 5-24 rotten_flesh
            rotten_flesh += @intCast(nextCount(&r, 5, 24));
        } else if (choice < 61) {
            // 1-3 pumpkin/bamboo
            disposeNextCount(&r, 1, 3);
        } else if (choice < 64) {
            // 1-5 gunpowder
            gunpowder += @intCast(nextCount(&r, 1, 5));
        } else if (choice < 65) {
            // 1-2 tnt
            tnt += @intCast(nextCount(&r, 1, 2));
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
    iron: u8,
    tnt: u8,
    diamonds: u8,
    gold: u8,
    emeralds: u8,
};

pub fn getBTLoot(seed: u64, chunk_x: c_int, chunk_z: c_int, salt: u32) BuriedTreasureLoot {
    var rand: u64 = 0;
    cubiomes.setSeed(&rand, getLootSeed(seed, chunk_x * 16, chunk_z * 16, salt, 0));
    var iron: u8 = 0;
    var tnt: u8 = 0;
    var diamonds: u8 = 0;
    var gold: u8 = 0;
    var emeralds: u8 = 0;

    // Pool 1 (no rng)
    // Pool 2: 5-8 uni rolls,
    // w20 1-4 iron
    // w10 1-4 gold
    // w5 1-2 tnt
    {
        const max = nextCount(&rand, 5, 8);
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&rand, 35);
            if (choice < 20) {
                // 1-4 iron_ingot
                iron += @intCast(nextCount(&rand, 1, 4));
            } else if (choice < 30) {
                // 1-4 gold_ingot
                gold += @intCast(nextCount(&rand, 1, 4));
            } else {
                // 1-2 tnt
                tnt += @intCast(nextCount(&rand, 1, 2));
            }
        }
    }
    // Pool 3: 1-3 uni rolls
    // w5 4-8 emerald
    // w5 1-2 diamond
    // w5 1-5 prismarine crystals
    {
        const max = nextCount(&rand, 1, 3);
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&rand, 15);
            if (choice < 5) {
                // 4-8 emerald
                emeralds += @intCast(nextCount(&rand, 4, 8));
            } else if (choice < 10) {
                // 1-2 diamond
                diamonds += @intCast(nextCount(&rand, 1, 2));
            } else {
                // 1-5 prismarine crystals
                disposeNextCount(&rand, 1, 5);
            }
        }
    }

    return .{ .iron = iron, .tnt = tnt, .diamonds = diamonds, .gold = gold, .emeralds = emeralds };
}

pub const DesertPyramidChestSeeds = struct {
    chest1: u64,
    chest2: u64,
    chest3: u64,
    chest4: u64,
};

pub fn getDesertPyramidChestSeeds(seed: u64, block_x: c_int, block_z: c_int, salt: u32) DesertPyramidChestSeeds {
    var rand: u64 = 0;
    cubiomes.setSeed(&rand, getDecoratorSeed(seed, block_x, block_z, salt));
    return .{
        .chest1 = cubiomes.nextLong(&rand),
        .chest2 = cubiomes.nextLong(&rand),
        .chest3 = cubiomes.nextLong(&rand),
        .chest4 = cubiomes.nextLong(&rand),
    };
}

const DesertTempleLoot = struct {
    diamonds: u8 = 0,
    gold: u8 = 0,
    iron: u8 = 0,
    enchanted_golden_apples: u8 = 0,
};

pub fn getDesertPyramidLoot(seed: u64, block_x: c_int, block_z: c_int, salt: u32) DesertTempleLoot {
    const seeds = getDesertPyramidChestSeeds(seed, block_x, block_z, salt);
    var out: DesertTempleLoot = .{};
    for ([_]u64{ seeds.chest1, seeds.chest2, seeds.chest3, seeds.chest4 }) |chest_seed| {
        const loot = getDesertPyramidSingleChestLoot(chest_seed);
        out.diamonds += loot.diamonds;
        out.gold += loot.gold;
        out.iron += loot.iron;
        out.enchanted_golden_apples += loot.enchanted_golden_apples;
    }
    return out;
}

pub fn getDesertPyramidSingleChestLoot(chest_seed: u64) DesertTempleLoot {
    var rand: u64 = 0;
    cubiomes.setSeed(&rand, chest_seed);
    // Pool 1 (w232): 2-4 uni rolls
    // w5 1-3 diamond
    // w15 1-5 iron_ingot
    // w15 2-7 gold_ingot
    // w15 1-3 emerald
    // w25 4-6 bone
    // w25 1-3 spider_eye
    // w25 3-7 rotten_flesh
    // w50 1 horse item
    // w20 1 enchanted book
    // w20 1 golden_apple
    // w2 1 enchanted_golden_apple
    // w15 nothing

    var loot: DesertTempleLoot = .{};
    {
        const max = nextCount(&rand, 2, 4);
        var i: i32 = 0;
        while (i < max) : (i += 1) {
            const choice = cubiomes.nextInt(&rand, 232);
            if (choice < 5) {
                // 1-3 diamond
                loot.diamonds += @intCast(nextCount(&rand, 1, 3));
            } else if (choice < 20) {
                // 1-5 iron_ingot
                loot.iron += @intCast(nextCount(&rand, 1, 5));
            } else if (choice < 35) {
                // 2-7 gold_ingot
                loot.gold += @intCast(nextCount(&rand, 2, 7));
            } else if (choice < 100) {
                // 1-3 emerald, 4-6 bone, 1-3 spider_eye
                disposeNextCount(&rand, 1, 3); // +3 for bone, no difference to rng disposal
            } else if (choice < 125) {
                // 3-7 rotten_flesh
                disposeNextCount(&rand, 3, 7);
            } else if (choice < 175) {
                // Horse item
            } else if (choice < 195) {
                // Enchanted book
                // 37 possible enchants
                // 0: protection, 4
                // 1: fire_protection, 4
                // 2: feather_falling, 4
                // 3: blast_protection, 4
                // 4: projectile_protection, 4
                // 5: respiration, 3
                // 6: aqua_affinity, 1
                // 7: thorns, 3
                // 8: depth_strider, 3
                // 9: frost_walker, 2
                // 10: binding_curse, 1
                // 11: sharpness, 5
                // 12: smite, 5
                // 13: bane_of_arthropods, 5
                // 14: knockback, 2
                // 15: fire_aspect, 2
                // 16: looting, 3
                // 17: sweeping, 3
                // 18: efficiency, 5
                // 19: silk_touch, 1
                // 20: unbreaking, 3
                // 21: fortune, 3
                // 22: power, 5
                // 23: punch, 2
                // 24: flame, 1
                // 25: infinity, 1
                // 26: luck_of_the_sea, 3
                // 27: lure, 3
                // 28: loyalty, 3
                // 29: impaling, 5
                // 30: riptide, 3
                // 31: channeling, 1
                // 32: multishot, 1
                // 33: quick_charge, 3
                // 34: piercing, 4
                // 35: mending, 1
                // 36: vanishing_curse, 1
                const enchant = cubiomes.nextInt(&rand, 37);
                switch (enchant) {
                    23, 9, 14, 15 => _ = cubiomes.nextInt(&rand, 2),
                    16, 17, 33, 20, 5, 21, 7, 8, 26, 27, 28, 30 => _ = cubiomes.nextInt(&rand, 3),
                    0, 1, 2, 34, 3, 4 => _ = cubiomes.nextInt(&rand, 4),
                    18, 22, 11, 12, 13, 29 => _ = cubiomes.nextInt(&rand, 5),
                    else => {},
                }
            } else if (choice < 215) {
                // golden_apple
            } else if (choice < 217) {
                // enchanted_golden_apple
                loot.enchanted_golden_apples += 1;
            } // else nothing
        }
    }
    return loot;
}

const RuinedPortalLoot = struct {
    obsidian: u8 = 0,
    flint: u8 = 0,
    iron_nuggets: u16 = 0,
    flint_and_steels: u8 = 0,
    fire_charges: u8 = 0,
    looting: u2 = 0,
};

pub fn getRuinedPortalLoot(seed: u64, block_x: c_int, block_z: c_int, salt: u32) RuinedPortalLoot {
    var rand: u64 = 0;
    const loot_seed = getLootSeed(seed, block_x, block_z, salt, 0);
    cubiomes.setSeed(&rand, loot_seed);

    // 1 Pool 4-8 rolls
    // w40 1-2 obsidian
    // w40 1-4 flint
    // w40 9-18 iron_nugget
    // w40 flint_and_steel
    // w40 fire_charge
    // w15 golden_apple
    // w15 4-24 gold_nugget
    // w15 golden_sword, enchant_randomly
    // w15 golden_axe, enchant_randomly
    // w15 golden_hoe, enchant_randomly
    // w15 golden_shovel, enchant_randomly
    // w15 golden_pickaxe, enchant_randomly
    // w15 golden_boots, enchant_randomly
    // w15 golden_chestplate, enchant_randomly
    // w15 golden_helmet, enchant_randomly
    // w15 golden_leggings, enchant_randomly
    // w5 4-12 glistering_melon_slice
    // w5 golden_horse_armor
    // w5 light_weighted_pressure_plate
    // w5 4-12 golden_carrot
    // w5 clock
    // w5 2-8 gold_ingot
    // w1 bell
    // w1 enchanted_golden_apple
    // w1 1-2 gold_block
    // Total weight: 398

    var loot: RuinedPortalLoot = .{};

    const max = nextCount(&rand, 4, 8);
    var i: i32 = 0;
    while (i < max) : (i += 1) {
        const choice = cubiomes.nextInt(&rand, 398);

        if (choice < 40) {
            // 1-2 obsidian
            loot.obsidian += @intCast(nextCount(&rand, 1, 2));
        } else if (choice < 80) {
            // 1-4 flint
            loot.flint += @intCast(nextCount(&rand, 1, 4));
        } else if (choice < 120) {
            // 9-18 iron_nugget
            loot.iron_nuggets += @intCast(nextCount(&rand, 9, 18));
        } else if (choice < 160) {
            // flint_and_steel
            loot.flint_and_steels += 1;
        } else if (choice < 200) {
            // fire_charge
            loot.fire_charges += 1;
        } else if (choice < 215) {
            // golden apple
        } else if (choice < 230) {
            // 4-24 gold_nugget
            disposeNextCount(&rand, 4, 24);
        } else if (choice < 245) {
            // golden sword, enchant_randomly
            // 0: minecraft:sharpness, 5
            // 1: minecraft:smite, 5
            // 2: minecraft:bane_of_arthropods, 5
            // 3: minecraft:knockback, 2
            // 4: minecraft:fire_aspect, 2
            // 5: minecraft:looting, 3
            // 6: minecraft:sweeping, 3
            // 7: minecraft:unbreaking, 3
            // 8: minecraft:mending, 1
            // 9: minecraft:vanishing_curse, 1
            const enchant = cubiomes.nextInt(&rand, 10);
            const level = 1 + switch (enchant) {
                3, 4 => cubiomes.nextInt(&rand, 2),
                5, 6, 7 => cubiomes.nextInt(&rand, 3),
                0, 1, 2 => cubiomes.nextInt(&rand, 5),
                else => 0,
            };
            if (enchant == 5) loot.looting = @max(loot.looting, @as(u2, @intCast(level)));
        } else if (choice < 260) {
            // golden axe, enchant_randomly
            // 0: minecraft:sharpness, 5
            // 1: minecraft:smite, 5
            // 2: minecraft:bane_of_arthropods, 5
            // 3: minecraft:efficiency, 5
            // 4: minecraft:silk_touch, 1
            // 5: minecraft:unbreaking, 3
            // 6: minecraft:fortune, 3
            // 7: minecraft:mending, 1
            // 8: minecraft:vanishing_curse, 1
            const enchant = cubiomes.nextInt(&rand, 9);
            _ = switch (enchant) {
                5, 6 => cubiomes.nextInt(&rand, 3),
                0, 1, 2, 3 => cubiomes.nextInt(&rand, 5),
                else => 0,
            };
        } else if (choice < 305) {
            // golden hoe/shovel/pickaxe, enchant_randomly
            // 0: minecraft:efficiency, 5
            // 1: minecraft:silk_touch, 1
            // 2: minecraft:unbreaking, 3
            // 3: minecraft:fortune, 3
            // 4: minecraft:mending, 1
            // 5: minecraft:vanishing_curse, 1
            const enchant = cubiomes.nextInt(&rand, 6);
            _ = switch (enchant) {
                2, 3 => cubiomes.nextInt(&rand, 3),
                0 => cubiomes.nextInt(&rand, 5),
                else => 0,
            };
        } else if (choice < 320) {
            // golden boots, enchant_randomly
            // 0: minecraft:protection, 4
            // 1: minecraft:fire_protection, 4
            // 2: minecraft:feather_falling, 4
            // 3: minecraft:blast_protection, 4
            // 4: minecraft:projectile_protection, 4
            // 5: minecraft:thorns, 3
            // 6: minecraft:depth_strider, 3
            // 7: minecraft:frost_walker, 2
            // 8: minecraft:binding_curse, 1
            // 9: minecraft:unbreaking, 3
            // 10: minecraft:mending, 1
            // 11: minecraft:vanishing_curse, 1
            const enchant = cubiomes.nextInt(&rand, 12);
            _ = switch (enchant) {
                7 => cubiomes.nextInt(&rand, 2),
                5, 6, 9 => cubiomes.nextInt(&rand, 3),
                0, 1, 2, 3, 4 => cubiomes.nextInt(&rand, 4),
                else => 0,
            };
        } else if (choice < 335) {
            // golden chestplate, enchant_randomly
            // 0: minecraft:protection, 4
            // 1: minecraft:fire_protection, 4
            // 2: minecraft:blast_protection, 4
            // 3: minecraft:projectile_protection, 4
            // 4: minecraft:thorns, 3
            // 5: minecraft:binding_curse, 1
            // 6: minecraft:unbreaking, 3
            // 7: minecraft:mending, 1
            // 8: minecraft:vanishing_curse, 1
            const enchant = cubiomes.nextInt(&rand, 9);
            _ = switch (enchant) {
                4, 6 => cubiomes.nextInt(&rand, 3),
                0, 1, 2, 3 => cubiomes.nextInt(&rand, 4),
                else => 0,
            };
        } else if (choice < 350) {
            // golden helmet, enchant_randomly
            // 0: minecraft:protection, 4
            // 1: minecraft:fire_protection, 4
            // 2: minecraft:blast_protection, 4
            // 3: minecraft:projectile_protection, 4
            // 4: minecraft:respiration, 3
            // 5: minecraft:aqua_affinity, 1
            // 6: minecraft:thorns, 3
            // 7: minecraft:binding_curse, 1
            // 8: minecraft:unbreaking, 3
            // 9: minecraft:mending, 1
            // 10: minecraft:vanishing_curse, 1
            const enchant = cubiomes.nextInt(&rand, 11);
            _ = switch (enchant) {
                4, 6, 8 => cubiomes.nextInt(&rand, 3),
                0, 1, 2, 3 => cubiomes.nextInt(&rand, 4),
                else => 0,
            };
        } else if (choice < 365) {
            // golden leggings, enchant_randomly
            // 0: minecraft:protection, 4
            // 1: minecraft:fire_protection, 4
            // 2: minecraft:blast_protection, 4
            // 3: minecraft:projectile_protection, 4
            // 4: minecraft:thorns, 3
            // 5: minecraft:binding_curse, 1
            // 6: minecraft:unbreaking, 3
            // 7: minecraft:mending, 1
            // 8: minecraft:vanishing_curse, 1
            const enchant = cubiomes.nextInt(&rand, 9);
            _ = switch (enchant) {
                4, 6 => cubiomes.nextInt(&rand, 3),
                0, 1, 2, 3 => cubiomes.nextInt(&rand, 4),
                else => 0,
            };
        } else if (choice < 370) {
            // 4-12 melon slice
            disposeNextCount(&rand, 4, 12);
        } else if (choice < 375) {
            // golden horse armor
        } else if (choice < 380) {
            // light weighted pressure plate
        } else if (choice < 385) {
            // 4-12 golden_carrot
            disposeNextCount(&rand, 4, 12);
        } else if (choice < 390) {
            // clock
        } else if (choice < 395) {
            // 2-8 gold_ingot
            disposeNextCount(&rand, 2, 8);
        } else if (choice < 396) {
            // bell
        } else if (choice < 397) {
            // enchanted golden apple
        } else {
            // 1-2 gold blocks
            disposeNextCount(&rand, 1, 2);
        }
    }
    return loot;
}

inline fn nextCount(rand: *u64, min: c_int, max: c_int) c_int {
    return cubiomes.nextInt(rand, max - min + 1) + min;
}

inline fn disposeNextCount(rand: *u64, min: c_int, max: c_int) void {
    _ = cubiomes.nextInt(rand, max - min + 1);
}

pub fn getLavaLake(world_seed: u64, block_x: c_int, block_z: c_int, salt: u32) ?cubiomes.Pos3 {
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
pub fn getLavaLakeBelowSeaLevel(world_seed: u64, block_x: c_int, block_z: c_int, salt: u32) ?cubiomes.Pos3 {
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
