const std = @import("std");

pub const VariableLengthCode = struct {
    code: u24,
    value: u8,
    length: u8,
};

//@todo: currently the lengths table is pretty large e.g. for address increment it's 2048 but we could also just store
// values many (33) and just map to length directly
pub const CodeLookup = struct {
    bit_length: u6,
    table: []const u8,
    lengths: []const u8,
};

pub const mb_motion_vector_vlc: [33]VariableLengthCode = .{
    .{ .code = 0b1, .value = 0, .length = 1 },
    .{ .code = 0b010, .value = 1, .length = 3 },
    .{ .code = 0b0010, .value = 2, .length = 4 },
    .{ .code = 0b0001_0, .value = 3, .length = 5 },
    .{ .code = 0b0000_110, .value = 4, .length = 7 },
    .{ .code = 0b0000_1010, .value = 5, .length = 8 },
    .{ .code = 0b0000_1000, .value = 6, .length = 8 },
    .{ .code = 0b0000_0110, .value = 7, .length = 8 },
    .{ .code = 0b0000_0101_10, .value = 8, .length = 10 },
    .{ .code = 0b0000_0101_00, .value = 9, .length = 10 },
    .{ .code = 0b0000_0100_10, .value = 10, .length = 10 },
    .{ .code = 0b0000_0100_010, .value = 11, .length = 11 },
    .{ .code = 0b0000_0100_000, .value = 12, .length = 11 },
    .{ .code = 0b0000_0011_110, .value = 13, .length = 11 },
    .{ .code = 0b0000_0011_100, .value = 14, .length = 11 },
    .{ .code = 0b0000_0011_010, .value = 15, .length = 11 },
    .{ .code = 0b0000_0011_000, .value = 16, .length = 11 },
    .{ .code = 0b011, .value = @bitCast(@as(i8, -1)), .length = 3 },
    .{ .code = 0b0011, .value = @bitCast(@as(i8, -2)), .length = 4 },
    .{ .code = 0b0001_1, .value = @bitCast(@as(i8, -3)), .length = 5 },
    .{ .code = 0b0000_111, .value = @bitCast(@as(i8, -4)), .length = 7 },
    .{ .code = 0b0000_1011, .value = @bitCast(@as(i8, -5)), .length = 8 },
    .{ .code = 0b0000_1001, .value = @bitCast(@as(i8, -6)), .length = 8 },
    .{ .code = 0b0000_0111, .value = @bitCast(@as(i8, -7)), .length = 8 },
    .{ .code = 0b0000_0101_11, .value = @bitCast(@as(i8, -8)), .length = 10 },
    .{ .code = 0b0000_0101_01, .value = @bitCast(@as(i8, -9)), .length = 10 },
    .{ .code = 0b0000_0100_11, .value = @bitCast(@as(i8, -10)), .length = 10 },
    .{ .code = 0b0000_0100_011, .value = @bitCast(@as(i8, -11)), .length = 11 },
    .{ .code = 0b0000_0100_001, .value = @bitCast(@as(i8, -12)), .length = 11 },
    .{ .code = 0b0000_0011_111, .value = @bitCast(@as(i8, -13)), .length = 11 },
    .{ .code = 0b0000_0011_101, .value = @bitCast(@as(i8, -14)), .length = 11 },
    .{ .code = 0b0000_0011_011, .value = @bitCast(@as(i8, -15)), .length = 11 },
    .{ .code = 0b0000_0011_001, .value = @bitCast(@as(i8, -16)), .length = 11 },
};

const mb_motion_vector_tables = generateLookupTables(&mb_motion_vector_vlc, getMaxLength(&mb_motion_vector_vlc));

pub const mb_motion_vector_lookup: CodeLookup = .{
    .bit_length = mb_motion_vector_tables.bit_length,
    .table = &mb_motion_vector_tables.table,
    .lengths = &mb_motion_vector_tables.lengths,
};

const mb_type_I_vlc: [2]VariableLengthCode = .{
    .{ .code = 0b1, .value = 0b10000, .length = 1 },
    .{ .code = 0b01, .value = 0b10000, .length = 2 },
};
const mb_type_I_tables = generateLookupTables(&mb_type_I_vlc, getMaxLength(&mb_type_I_vlc));

pub const mb_type_I_lookup: CodeLookup = .{
    .bit_length = mb_type_I_tables.bit_length,
    .table = &mb_type_I_tables.table,
    .lengths = &mb_type_I_tables.lengths,
};

// @todo I need to check all of these.... ai is useless
pub const mb_type_P_vlc: [7]VariableLengthCode = .{
    .{ .code = 0b001, .value = 0b00010, .length = 3 },
    .{ .code = 0b01, .value = 0b01000, .length = 2 },
    .{ .code = 0b0000_1, .value = 0b01001, .length = 5 },
    .{ .code = 0b1, .value = 0b01010, .length = 1 },
    .{ .code = 0b0001_0, .value = 0b01011, .length = 5 },
    .{ .code = 0b0001_1, .value = 0b10000, .length = 5 },
    .{ .code = 0b0000_01, .value = 0b10001, .length = 6 },
};

const mb_type_P_tables = generateLookupTables(&mb_type_P_vlc, getMaxLength(&mb_type_P_vlc));

pub const mb_type_P_struct: CodeLookup = .{
    .bit_length = mb_type_P_tables.bit_length,
    .table = &mb_type_P_tables.table,
    .lengths = &mb_type_P_tables.lengths,
};

pub const mb_type_B_vlc: [10]VariableLengthCode = .{
    .{ .code = 0b010, .value = 0b00001, .length = 3 },
    .{ .code = 0b10, .value = 0b00001, .length = 2 },
    .{ .code = 0b0011, .value = 0b01000, .length = 4 },
    .{ .code = 0b000011, .value = 0b01000, .length = 6 },
    .{ .code = 0b011, .value = 0b01100, .length = 3 },
    .{ .code = 0b000010, .value = 0b01100, .length = 6 },
    .{ .code = 0b11, .value = 0b01100, .length = 2 },
    .{ .code = 0b00010, .value = 0b01100, .length = 5 },
    .{ .code = 0b00011, .value = 0b10000, .length = 5 },
    .{ .code = 0b000001, .value = 0b10000, .length = 6 },
};

const mb_type_B_tables = generateLookupTables(&mb_type_B_vlc, getMaxLength(&mb_type_B_vlc));

pub const mb_type_B_struct: CodeLookup = .{
    .bit_length = mb_type_B_tables.lengths,
    .table = &mb_type_B_tables.table,
    .lengths = &mb_type_B_tables.lengths,
};

// let's not support this...
// pub const mb_type_D_vlc: [1]VariableLengthCode = .{
//     .{ .code = 0b1, .value = 0b10000, .length = 1 },
// };

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

pub const address_increment_tables = generateLookupTables(&mb_address_increment_vlc, getMaxLength(&mb_address_increment_vlc));

pub const mb_address_increment_lookup: CodeLookup = .{
    .bit_length = address_increment_tables.bit_length,
    .table = &address_increment_tables.table,
    .lengths = &address_increment_tables.lengths,
};

// something annoying it seems like anonymous structs can't take comptime defined variables

fn getMaxLength(vlc_table: []const VariableLengthCode) u8 {
    var max_bit_length: u8 = 0;

    for (0..vlc_table.len) |i| {
        const entry = vlc_table[i];
        const bit_length = entry.length;
        if (bit_length > max_bit_length) max_bit_length = bit_length;
    }

    return max_bit_length;
}

// @todo do we just return a CodeLookup and force the functions to take a pointer to a CodeLookup?
// I guess we can make a multi-item array?
pub fn generateLookupTables(vlc_table: []const VariableLengthCode, comptime bits: usize) struct { bit_length: u8, table: [1 << bits]u8, lengths: [1 << bits]u8 } {
    var table: [1 << bits]u8 = @splat(255);
    var lengths: [1 << bits]u8 = @splat(0);
    var max_bit_length: u8 = 0;

    @setEvalBranchQuota(5000);
    for (0..vlc_table.len) |i| {
        const entry = vlc_table[i];
        const code = entry.code;
        const value = entry.value;
        const bit_length = entry.length;

        if (bit_length > max_bit_length) max_bit_length = bit_length;

        if (value == 255) {
            // we're using this as a sentinal value so if we're casting from -1 we might be overwriting a value
            // either we switch to an optional or something or just deal with it
        }
        const first_index = code << bits - @as(u4, @intCast(bit_length));

        const num_entries = @as(usize, 1) << @as(u4, @intCast(bits - bit_length));

        for (0..num_entries) |index| {
            std.debug.assert(table[first_index + index] == 255);
            table[first_index + index] = value;
            lengths[first_index + index] = bit_length;
        }
    }
    std.debug.assert(max_bit_length == bits);
    return .{ .bit_length = max_bit_length, .table = table, .lengths = lengths };
}
