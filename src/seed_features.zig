const std = @import("std");

var enable_bastion_checker = false;
var enable_terrain_checker = false;

pub fn setFeatures(bastion_loot: bool, terrain: bool) void {
    enable_bastion_checker = bastion_loot;
    enable_terrain_checker = terrain;
}

pub fn isBastionCheckerEnabled() bool {
    return enable_bastion_checker;
}

pub fn isTerrainCheckerEnabled() bool {
    return enable_terrain_checker;
}
