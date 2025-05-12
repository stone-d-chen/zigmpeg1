const std = @import("std");

pub const VLCType = u16;
const FAST_BITS = 12;

pub const VariableLengthCode = struct {
    code: u24,
    value: VLCType,
    length: u8,
};

//@todo: currently the lengths table is pretty large e.g. for address increment it's 2048 but we could also just store
// values many (33) and just map to length directly
pub const CodeLookup = struct {
    bit_length: u6,
    table: []const VLCType,
    lengths: []const u8,
};

const CodeKey = struct { code: u24, length: u8 };

pub const CodeMap = std.AutoArrayHashMap(CodeKey, VLCType);

// @todo let ac_vlc use an acceleration table
pub fn initCodeMap(allocator: std.mem.Allocator) !CodeMap {
    var map = CodeMap.init(allocator);
    for (0..111) |ind| {
        const code = ac_vlc[ind];

        try map.put(.{ .code = code.code, .length = code.length }, code.value);
    }
    return map;
}

pub const ac_vlc: [111]VariableLengthCode = .{
    //   .{ .code = 0b1, .value = 0x00_01, .length = 1 },
    .{ .code = 0b11, .value = 0x00_01, .length = 2 },
    .{ .code = 0b0100, .value = 0x00_02, .length = 4 },
    .{ .code = 0b0010_1, .value = 0x00_03, .length = 5 },
    .{ .code = 0b0000_110, .value = 0x00_04, .length = 7 },
    .{ .code = 0b0010_0110, .value = 0x00_05, .length = 8 },
    .{ .code = 0b0010_0001, .value = 0x00_06, .length = 8 },
    .{ .code = 0b0000_0010_10, .value = 0x00_07, .length = 10 },
    .{ .code = 0b0000_0001_1101, .value = 0x00_08, .length = 12 },
    .{ .code = 0b0000_0001_1000, .value = 0x00_09, .length = 12 },
    .{ .code = 0b0000_0001_0011, .value = 0x00_0A, .length = 12 },
    .{ .code = 0b0000_0001_0000, .value = 0x00_0B, .length = 12 },
    .{ .code = 0b0000_0000_1101_0, .value = 0x00_0C, .length = 13 },
    .{ .code = 0b0000_0000_1100_1, .value = 0x00_0D, .length = 13 },
    .{ .code = 0b0000_0000_1100_0, .value = 0x00_0E, .length = 13 },
    .{ .code = 0b0000_0000_1011_1, .value = 0x00_0F, .length = 13 },
    .{ .code = 0b0000_0000_0111_11, .value = 0x00_10, .length = 14 },
    .{ .code = 0b0000_0000_0111_10, .value = 0x00_11, .length = 14 },
    .{ .code = 0b0000_0000_0111_01, .value = 0x00_12, .length = 14 },
    .{ .code = 0b0000_0000_0111_00, .value = 0x00_13, .length = 14 },
    .{ .code = 0b0000_0000_0110_11, .value = 0x00_14, .length = 14 },
    .{ .code = 0b0000_0000_0110_10, .value = 0x00_15, .length = 14 },
    .{ .code = 0b0000_0000_0110_01, .value = 0x00_16, .length = 14 },
    .{ .code = 0b0000_0000_0110_00, .value = 0x00_17, .length = 14 },
    .{ .code = 0b0000_0000_0101_11, .value = 0x00_18, .length = 14 },
    .{ .code = 0b0000_0000_0101_10, .value = 0x00_19, .length = 14 },
    .{ .code = 0b0000_0000_0101_01, .value = 0x00_1A, .length = 14 },
    .{ .code = 0b0000_0000_0101_00, .value = 0x00_1B, .length = 14 },
    .{ .code = 0b0000_0000_0100_11, .value = 0x00_1C, .length = 14 },
    .{ .code = 0b0000_0000_0100_10, .value = 0x00_1D, .length = 14 },
    .{ .code = 0b0000_0000_0100_01, .value = 0x00_1E, .length = 14 },
    .{ .code = 0b0000_0000_0100_00, .value = 0x00_1F, .length = 14 },
    .{ .code = 0b0000_0000_0011_000, .value = 0x00_20, .length = 15 },
    .{ .code = 0b0000_0000_0010_111, .value = 0x00_21, .length = 15 },
    .{ .code = 0b0000_0000_0010_110, .value = 0x00_22, .length = 15 },
    .{ .code = 0b0000_0000_0010_101, .value = 0x00_23, .length = 15 },
    .{ .code = 0b0000_0000_0010_100, .value = 0x00_24, .length = 15 },
    .{ .code = 0b0000_0000_0010_011, .value = 0x00_25, .length = 15 },
    .{ .code = 0b0000_0000_0010_010, .value = 0x00_26, .length = 15 },
    .{ .code = 0b0000_0000_0010_001, .value = 0x00_27, .length = 15 },
    .{ .code = 0b0000_0000_0010_000, .value = 0x00_28, .length = 15 },
    .{ .code = 0b011, .value = 0x01_01, .length = 3 },
    .{ .code = 0b0001_10, .value = 0x01_02, .length = 6 },
    .{ .code = 0b0010_0101, .value = 0x01_03, .length = 8 },
    .{ .code = 0b0000_0011_00, .value = 0x01_04, .length = 10 },
    .{ .code = 0b0000_0001_1011, .value = 0x01_05, .length = 12 },
    .{ .code = 0b0000_0000_1011_0, .value = 0x01_06, .length = 13 },
    .{ .code = 0b0000_0000_1010_1, .value = 0x01_07, .length = 13 },
    .{ .code = 0b0000_0000_0011_111, .value = 0x01_08, .length = 15 },
    .{ .code = 0b0000_0000_0011_110, .value = 0x01_09, .length = 15 },
    .{ .code = 0b0000_0000_0011_101, .value = 0x01_0A, .length = 15 },
    .{ .code = 0b0000_0000_0011_100, .value = 0x01_0B, .length = 15 },
    .{ .code = 0b0000_0000_0011_011, .value = 0x01_0C, .length = 15 },
    .{ .code = 0b0000_0000_0011_010, .value = 0x01_0D, .length = 15 },
    .{ .code = 0b0000_0000_0011_001, .value = 0x01_0E, .length = 15 },
    .{ .code = 0b0000_0000_0001_0011, .value = 0x01_0F, .length = 16 },
    .{ .code = 0b0000_0000_0001_0010, .value = 0x01_10, .length = 16 },
    .{ .code = 0b0000_0000_0001_0001, .value = 0x01_11, .length = 16 },
    .{ .code = 0b0000_0000_0001_0000, .value = 0x01_12, .length = 16 },
    .{ .code = 0b0101, .value = 0x02_01, .length = 4 },
    .{ .code = 0b0000_100, .value = 0x02_02, .length = 7 },
    .{ .code = 0b0000_0010_11, .value = 0x02_03, .length = 10 },
    .{ .code = 0b0000_0001_0100, .value = 0x02_04, .length = 12 },
    .{ .code = 0b0000_0000_1010_0, .value = 0x02_05, .length = 13 },
    .{ .code = 0b0011_1, .value = 0x03_01, .length = 5 },
    .{ .code = 0b0010_0100, .value = 0x03_02, .length = 8 },
    .{ .code = 0b0000_0001_1100, .value = 0x03_03, .length = 12 },
    .{ .code = 0b0000_0000_1001_1, .value = 0x03_04, .length = 13 },
    .{ .code = 0b0011_0, .value = 0x04_01, .length = 5 },
    .{ .code = 0b0000_0011_11, .value = 0x04_02, .length = 10 },
    .{ .code = 0b0000_0001_0010, .value = 0x04_03, .length = 12 },
    .{ .code = 0b0001_11, .value = 0x05_01, .length = 6 },
    .{ .code = 0b0000_0010_01, .value = 0x05_02, .length = 10 },
    .{ .code = 0b0000_0000_1001_0, .value = 0x05_03, .length = 13 },
    .{ .code = 0b0001_01, .value = 0x06_01, .length = 6 },
    .{ .code = 0b0000_0001_1110, .value = 0x06_02, .length = 12 },
    .{ .code = 0b0000_0000_0001_0100, .value = 0x06_03, .length = 16 },
    .{ .code = 0b0001_00, .value = 0x07_01, .length = 6 },
    .{ .code = 0b0000_0001_0101, .value = 0x07_02, .length = 12 },
    .{ .code = 0b0000_111, .value = 0x08_01, .length = 7 },
    .{ .code = 0b0000_0001_0001, .value = 0x08_02, .length = 12 },
    .{ .code = 0b0000_101, .value = 0x09_01, .length = 7 },
    .{ .code = 0b0000_0000_1000_1, .value = 0x09_02, .length = 13 },
    .{ .code = 0b0010_0111, .value = 0x0A_01, .length = 8 },
    .{ .code = 0b0000_0000_1000_0, .value = 0x0A_02, .length = 13 },
    .{ .code = 0b0010_0011, .value = 0x0B_01, .length = 8 },
    .{ .code = 0b0000_0000_0001_1010, .value = 0x0B_02, .length = 16 },
    .{ .code = 0b0010_0010, .value = 0x0C_01, .length = 8 },
    .{ .code = 0b0000_0000_0001_1001, .value = 0x0C_02, .length = 16 },
    .{ .code = 0b0010_0000, .value = 0x0D_01, .length = 8 },
    .{ .code = 0b0000_0000_0001_1000, .value = 0x0D_02, .length = 16 },
    .{ .code = 0b0000_0011_10, .value = 0x0E_01, .length = 10 },
    .{ .code = 0b0000_0000_0001_0111, .value = 0x0E_02, .length = 16 },
    .{ .code = 0b0000_0011_01, .value = 0x0F_01, .length = 10 },
    .{ .code = 0b0000_0000_0001_0110, .value = 0x0F_02, .length = 16 },
    .{ .code = 0b0000_0010_00, .value = 0x10_01, .length = 10 },
    .{ .code = 0b0000_0000_0001_0101, .value = 0x10_02, .length = 16 },
    .{ .code = 0b0000_0001_1111, .value = 0x11_01, .length = 12 },
    .{ .code = 0b0000_0001_1010, .value = 0x12_01, .length = 12 },
    .{ .code = 0b0000_0001_1001, .value = 0x13_01, .length = 12 },
    .{ .code = 0b0000_0001_0111, .value = 0x14_01, .length = 12 },
    .{ .code = 0b0000_0001_0110, .value = 0x15_01, .length = 12 },
    .{ .code = 0b0000_0000_1111_1, .value = 0x16_01, .length = 13 },
    .{ .code = 0b0000_0000_1111_0, .value = 0x17_01, .length = 13 },
    .{ .code = 0b0000_0000_1110_1, .value = 0x18_01, .length = 13 },
    .{ .code = 0b0000_0000_1110_0, .value = 0x19_01, .length = 13 },
    .{ .code = 0b0000_0000_1101_1, .value = 0x1A_01, .length = 13 },
    .{ .code = 0b0000_0000_0001_1111, .value = 0x1B_01, .length = 16 },
    .{ .code = 0b0000_0000_0001_1110, .value = 0x1C_01, .length = 16 },
    .{ .code = 0b0000_0000_0001_1101, .value = 0x1D_01, .length = 16 },
    .{ .code = 0b0000_0000_0001_1100, .value = 0x1E_01, .length = 16 },
    .{ .code = 0b0000_0000_0001_1011, .value = 0x1F_01, .length = 16 },
};
const dc_code_y_table_vlc: [9]VariableLengthCode = .{
    .{ .code = 0b100, .value = 0, .length = 3 },
    .{ .code = 0b00, .value = 1, .length = 2 },
    .{ .code = 0b01, .value = 2, .length = 2 },
    .{ .code = 0b101, .value = 3, .length = 3 },
    .{ .code = 0b110, .value = 4, .length = 3 },
    .{ .code = 0b1110, .value = 5, .length = 4 },
    .{ .code = 0b1111_0, .value = 6, .length = 5 },
    .{ .code = 0b1111_10, .value = 7, .length = 6 },
    .{ .code = 0b1111_110, .value = 8, .length = 7 },
};

const dc_code_c_table_vlc: [9]VariableLengthCode = .{
    .{ .code = 0b00, .value = 0, .length = 2 },
    .{ .code = 0b01, .value = 1, .length = 2 },
    .{ .code = 0b10, .value = 2, .length = 2 },
    .{ .code = 0b110, .value = 3, .length = 3 },
    .{ .code = 0b1110, .value = 4, .length = 4 },
    .{ .code = 0b1111_0, .value = 5, .length = 5 },
    .{ .code = 0b1111_10, .value = 6, .length = 6 },
    .{ .code = 0b1111_110, .value = 7, .length = 7 },
    .{ .code = 0b1111_1110, .value = 8, .length = 8 },
};

const dc_code_y_tables = generateLookupTables(&dc_code_y_table_vlc, getMaxLength(&dc_code_y_table_vlc));
const dc_code_c_table_tables = generateLookupTables(&dc_code_c_table_vlc, getMaxLength(&dc_code_c_table_vlc));

pub const dc_code_y_lookup: CodeLookup = .{
    .bit_length = dc_code_y_tables.bit_length,
    .table = &dc_code_y_tables.table,
    .lengths = &dc_code_y_tables.lengths,
};

pub const dc_code_c_lookup: CodeLookup = .{
    .bit_length = dc_code_c_table_tables.bit_length,
    .table = &dc_code_c_table_tables.table,
    .lengths = &dc_code_c_table_tables.lengths,
};

const mb_motion_vector_vlc: [33]VariableLengthCode = .{
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
    .{ .code = 0b011, .value = @bitCast(@as(i16, -1)), .length = 3 },
    .{ .code = 0b0011, .value = @bitCast(@as(i16, -2)), .length = 4 },
    .{ .code = 0b0001_1, .value = @bitCast(@as(i16, -3)), .length = 5 },
    .{ .code = 0b0000_111, .value = @bitCast(@as(i16, -4)), .length = 7 },
    .{ .code = 0b0000_1011, .value = @bitCast(@as(i16, -5)), .length = 8 },
    .{ .code = 0b0000_1001, .value = @bitCast(@as(i16, -6)), .length = 8 },
    .{ .code = 0b0000_0111, .value = @bitCast(@as(i16, -7)), .length = 8 },
    .{ .code = 0b0000_0101_11, .value = @bitCast(@as(i16, -8)), .length = 10 },
    .{ .code = 0b0000_0101_01, .value = @bitCast(@as(i16, -9)), .length = 10 },
    .{ .code = 0b0000_0100_11, .value = @bitCast(@as(i16, -10)), .length = 10 },
    .{ .code = 0b0000_0100_011, .value = @bitCast(@as(i16, -11)), .length = 11 },
    .{ .code = 0b0000_0100_001, .value = @bitCast(@as(i16, -12)), .length = 11 },
    .{ .code = 0b0000_0011_111, .value = @bitCast(@as(i16, -13)), .length = 11 },
    .{ .code = 0b0000_0011_101, .value = @bitCast(@as(i16, -14)), .length = 11 },
    .{ .code = 0b0000_0011_011, .value = @bitCast(@as(i16, -15)), .length = 11 },
    .{ .code = 0b0000_0011_001, .value = @bitCast(@as(i16, -16)), .length = 11 },
};

const mb_motion_vector_tables = generateLookupTables(&mb_motion_vector_vlc, getMaxLength(&mb_motion_vector_vlc));

pub const mb_motion_vector_lookup: CodeLookup = .{
    .bit_length = mb_motion_vector_tables.bit_length,
    .table = &mb_motion_vector_tables.table,
    .lengths = &mb_motion_vector_tables.lengths,
};

const mb_type_I_vlc: [2]VariableLengthCode = .{
    .{ .code = 0b1, .value = 0b10000, .length = 1 },
    .{ .code = 0b01, .value = 0b10001, .length = 2 },
};
const mb_type_I_tables = generateLookupTables(&mb_type_I_vlc, getMaxLength(&mb_type_I_vlc));

pub const mb_type_I_lookup: CodeLookup = .{
    .bit_length = mb_type_I_tables.bit_length,
    .table = &mb_type_I_tables.table,
    .lengths = &mb_type_I_tables.lengths,
};

// @todo I need to check all of these.... ai is useless
const mb_type_P_vlc: [7]VariableLengthCode = .{
    .{ .code = 0b001, .value = 0b00010, .length = 3 },
    .{ .code = 0b01, .value = 0b01000, .length = 2 },
    .{ .code = 0b0000_1, .value = 0b01001, .length = 5 },
    .{ .code = 0b1, .value = 0b01010, .length = 1 },
    .{ .code = 0b0001_0, .value = 0b01011, .length = 5 },
    .{ .code = 0b0001_1, .value = 0b10000, .length = 5 },
    .{ .code = 0b0000_01, .value = 0b10001, .length = 6 },
};

const mb_type_P_tables = generateLookupTables(&mb_type_P_vlc, getMaxLength(&mb_type_P_vlc));

pub const mb_type_P_lookup: CodeLookup = .{
    .bit_length = mb_type_P_tables.bit_length,
    .table = &mb_type_P_tables.table,
    .lengths = &mb_type_P_tables.lengths,
};

const mb_type_B_vlc: [10]VariableLengthCode = .{
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

pub const mb_type_B_lookup: CodeLookup = .{
    .bit_length = mb_type_B_tables.bit_length,
    .table = &mb_type_B_tables.table,
    .lengths = &mb_type_B_tables.lengths,
};

// let's not support this...
// pub const mb_type_D_vlc: [1]VariableLengthCode = .{
//     .{ .code = 0b1, .value = 0b10000, .length = 1 },
// };

const mb_address_increment_vlc: [35]VariableLengthCode = .{
    .{ .code = 0b0000_0001_000, .value = 35, .length = 11 },
    .{ .code = 0b0000_0001_111, .value = 34, .length = 11 },
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

const mb_coded_block_pattern_vlc: [31]VariableLengthCode = .{
    .{ .code = 0b0101_1, .value = 1, .length = 5 },
    .{ .code = 0b0100_1, .value = 2, .length = 5 },
    .{ .code = 0b0011_01, .value = 3, .length = 6 },
    .{ .code = 0b1101, .value = 4, .length = 4 },
    .{ .code = 0b0010_111, .value = 5, .length = 7 },
    .{ .code = 0b0010_011, .value = 6, .length = 7 },
    .{ .code = 0b0001_1111, .value = 7, .length = 8 },
    .{ .code = 0b1100, .value = 8, .length = 4 },
    .{ .code = 0b0010_110, .value = 9, .length = 7 },
    .{ .code = 0b0010_010, .value = 10, .length = 7 },
    .{ .code = 0b0001_1110, .value = 11, .length = 8 },
    .{ .code = 0b1001_1, .value = 12, .length = 5 },
    .{ .code = 0b0001_1011, .value = 13, .length = 8 },
    .{ .code = 0b0001_0111, .value = 14, .length = 8 },
    .{ .code = 0b0001_0011, .value = 15, .length = 8 },
    .{ .code = 0b1011, .value = 16, .length = 4 },
    .{ .code = 0b0010_101, .value = 17, .length = 7 },
    .{ .code = 0b0010_001, .value = 18, .length = 7 },
    .{ .code = 0b0001_1101, .value = 19, .length = 8 },
    .{ .code = 0b1000_1, .value = 20, .length = 5 },
    .{ .code = 0b0001_1001, .value = 21, .length = 8 },
    .{ .code = 0b0001_0101, .value = 22, .length = 8 },
    .{ .code = 0b0001_0001, .value = 23, .length = 8 },
    .{ .code = 0b0011_11, .value = 24, .length = 6 },
    .{ .code = 0b0000_1111, .value = 25, .length = 8 },
    .{ .code = 0b0000_1101, .value = 26, .length = 8 },
    .{ .code = 0b0000_0001_1, .value = 27, .length = 9 },
    .{ .code = 0b0111_1, .value = 28, .length = 5 },
    .{ .code = 0b0000_1011, .value = 29, .length = 8 },
    .{ .code = 0b0000_0111, .value = 30, .length = 8 },
    .{ .code = 0b0000_0011_1, .value = 31, .length = 9 },
};

const mb_coded_block_pattern_tables = generateLookupTables(&mb_coded_block_pattern_vlc, getMaxLength(&mb_coded_block_pattern_vlc));

pub const mb_coded_block_pattern_lookup: CodeLookup = .{
    .bit_length = mb_coded_block_pattern_tables.bit_length,
    .table = &mb_coded_block_pattern_tables.table,
    .lengths = &mb_coded_block_pattern_tables.lengths,
};

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
pub fn generateLookupTables(vlc_table: []const VariableLengthCode, comptime bits: usize) struct { bit_length: u8, table: [1 << bits]VLCType, lengths: [1 << bits]u8 } {
    var table: [1 << bits]VLCType = @splat(255);
    var lengths: [1 << bits]u8 = @splat(0);
    var max_bit_length: u8 = 0;

    @setEvalBranchQuota(5000);
    for (0..vlc_table.len) |i| {
        const entry = vlc_table[i];
        const code = entry.code;
        const value = entry.value;
        const bit_length = entry.length;

        if (bit_length > FAST_BITS) continue;

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
