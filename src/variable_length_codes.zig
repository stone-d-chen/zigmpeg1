const std = @import("std");
const FAST_BITS = 11;

pub const VariableLengthCode = struct {
    code: u24,
    value: u8,
    length: u8,
};

pub const mb_address_increment_vlc: [33]VariableLengthCode = .{
    .{ .code = 0b0000_0011_000, .value = 33, .length = 11 },
    .{ .code = 0b0000_0011_001, .value = 32, .length = 11 },
    .{ .code = 0b0000_0011_010, .value = 31, .length = 11 },
    .{ .code = 0b0000_0011_011, .value = 30, .length = 11 },
    .{ .code = 0b0000_0011_100, .value = 29, .length = 11 },
    .{ .code = 0b0000_0011_101, .value = 28, .length = 11 },
    .{ .code = 0b0000_0011_110, .value = 27, .length = 11 },
    .{ .code = 0b0000_0011_111, .value = 26, .length = 11 },
    .{ .code = 0b0000_0100_000, .value = 25, .length = 11 },
    .{ .code = 0b0000_0100_001, .value = 24, .length = 11 },
    .{ .code = 0b0000_0100_010, .value = 23, .length = 11 },
    .{ .code = 0b0000_0100_011, .value = 22, .length = 11 },
    .{ .code = 0b0000_0100_10, .value = 21, .length = 10 },
    .{ .code = 0b0000_0100_11, .value = 20, .length = 10 },
    .{ .code = 0b0000_0101_00, .value = 19, .length = 10 },
    .{ .code = 0b0000_0101_01, .value = 18, .length = 10 },
    .{ .code = 0b0000_0101_10, .value = 17, .length = 10 },
    .{ .code = 0b0000_0101_11, .value = 16, .length = 10 },
    .{ .code = 0b0000_0110, .value = 15, .length = 8 },
    .{ .code = 0b0000_0111, .value = 14, .length = 8 },
    .{ .code = 0b0000_1000, .value = 13, .length = 8 },
    .{ .code = 0b0000_1001, .value = 12, .length = 8 },
    .{ .code = 0b0000_1010, .value = 11, .length = 8 },
    .{ .code = 0b0000_1011, .value = 10, .length = 8 },
    .{ .code = 0b0000_110, .value = 9, .length = 7 },
    .{ .code = 0b0000_111, .value = 8, .length = 7 },
    .{ .code = 0b0001_0, .value = 7, .length = 5 },
    .{ .code = 0b0001_1, .value = 6, .length = 5 },
    .{ .code = 0b0010, .value = 5, .length = 4 },
    .{ .code = 0b0011, .value = 4, .length = 4 },
    .{ .code = 0b010, .value = 3, .length = 3 },
    .{ .code = 0b011, .value = 2, .length = 3 },
    .{ .code = 0b1, .value = 1, .length = 1 },
};

pub fn generateFastLookup(vlc_table: [33]VariableLengthCode) [1 << FAST_BITS]u8 {
    var table: [1 << FAST_BITS]u8 = @splat(255);

    @setEvalBranchQuota(5000);
    for (0..vlc_table.len) |i| {
        const entry = vlc_table[i];
        const code = entry.code;
        const value = entry.value;
        const length = entry.length;

        const first_index = code << FAST_BITS - @as(u4, @intCast(length));

        const num_entries = @as(usize, 1) << @as(u4, @intCast(FAST_BITS - length));

        for (0..num_entries) |index| {
            std.debug.assert(table[first_index + index] == 255);
            table[first_index + index] = value;
        }
    }
    return table;
}

pub const fast_table = generateFastLookup(mb_address_increment_vlc);
