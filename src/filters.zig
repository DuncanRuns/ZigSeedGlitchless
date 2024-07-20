const std = @import("std");
const FindSeedResults = @import("filter_common.zig").FindSeedResults;
const Filter = @import("filter_common.zig").Filter;

pub fn getFilter(filter_code: u32) !Filter {
    switch (filter_code) {
        115 => return @import("filter_1_15.zig").interface,
        116 => return @import("filter_1_16.zig").interface,
        else => return error.FilterDoesNotExist,
    }
}
