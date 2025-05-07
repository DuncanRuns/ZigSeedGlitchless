const std = @import("std");
const FindSeedResults = @import("filter_common.zig").FindSeedResults;
const Filter = @import("filter_common.zig").Filter;

pub fn getFilter(filter_code: u32) !Filter {
    switch (filter_code) {
        1 => return @import("filter_1_16_mapless.zig").interface,
        2 => return @import("filter_1_16_mapless.zig").interface_overpowered,
        3 => return @import("filter_1_15.zig").interface,
        4 => return @import("filter_1_16_village.zig").interface,
        5 => return @import("filter_1_16_village.zig").interface_overpowered,
        6 => return @import("filter_1_16_temple.zig").interface,
        7 => return @import("filter_1_16_temple.zig").interface_overpowered,
        8 => return @import("filter_1_16_shipwreck.zig").interface,
        9 => return @import("filter_1_16_shipwreck.zig").interface_overpowered,
        else => return error.FilterDoesNotExist,
    }
}
