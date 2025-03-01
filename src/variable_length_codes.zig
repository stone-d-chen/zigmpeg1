const std = @import("std");
const FAST_BITS = 11;

pub const VariableLengthCode = struct {
    code: u24,
    value: u8,
    length: u8,
};

pub const CodeLookup = struct {
    bit_length: u6,
    table: []const u8,
    lengths: []const u8,
};

const mb_type_I_vlc: [2]VariableLengthCode = .{
    .{ .code = 0b1, .value = 0b10000, .length = 1 },
    .{ .code = 0b01, .value = 0b10000, .length = 2 },
};
const mb_type_I_tables = generateLookupTables(&mb_type_I_vlc, 2);

pub const mb_type_I_lookup: CodeLookup = .{
    .bit_length = 2,
    .table = &mb_type_I_tables.table,
    .lengths = &mb_type_I_tables.lengths,
};

pub const mb_type_P_vlc: [7]VariableLengthCode = .{
    .{ .code = 0b001, .value = 0b00000, .length = 3 },
    .{ .code = 0b01, .value = 0b01000, .length = 2 },
    .{ .code = 0b00001, .value = 0b01000, .length = 5 },
    .{ .code = 0b1, .value = 0b01000, .length = 1 },
    .{ .code = 0b00010, .value = 0b01000, .length = 5 },
    .{ .code = 0b00001, .value = 0b10000, .length = 5 },
    .{ .code = 0b0010, .value = 0b00000, .length = 4 },
};

const mb_type_P_tables = generateLookupTables(&mb_type_P_vlc, 2);

pub const mb_type_P_struct: CodeLookup = .{
    .bit_length = 5,
    .table = &mb_type_P_tables.table,
    .lengths = &&mb_type_P_tables.lengths,
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

const mb_type_B_tables = generateLookupTables(&mb_type_B_vlc, 6);

pub const mb_type_B_struct: CodeLookup = .{
    .bit_length = 5,
    .table = &mb_type_B_tables.table,
    .lengths = &mb_type_B_tables.lengths,
};

// let's not support this...
pub const mb_type_D_vlc: [1]VariableLengthCode = .{
    .{ .code = 0b1, .value = 0b10000, .length = 1 },
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

pub const address_increment_tables = generateLookupTables(&mb_address_increment_vlc, FAST_BITS);

pub const mb_address_increment_lookup: CodeLookup = .{
    .bit_length = 11,
    .table = &address_increment_tables.table,
    .lengths = &address_increment_tables.lengths,
};

pub fn generateLookupTables(vlc_table: []const VariableLengthCode, comptime bits: usize) struct { table: [1 << bits]u8, lengths: [1 << bits]u8 } {
    var table: [1 << bits]u8 = @splat(255);
    var lengths: [1 << bits]u8 = @splat(0);

    @setEvalBranchQuota(5000);
    for (0..vlc_table.len) |i| {
        const entry = vlc_table[i];
        const code = entry.code;
        const value = entry.value;
        const bit_length = entry.length;

        const first_index = code << bits - @as(u4, @intCast(bit_length));

        const num_entries = @as(usize, 1) << @as(u4, @intCast(bits - bit_length));

        for (0..num_entries) |index| {
            std.debug.assert(table[first_index + index] == 255);
            table[first_index + index] = value;
            lengths[first_index + index] = bit_length;
        }
    }
    return .{ .table = table, .lengths = lengths };
}
