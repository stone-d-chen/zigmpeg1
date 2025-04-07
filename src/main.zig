const std = @import("std");
const bitReader = @import("bitReader.zig").bitReader;
const vlc = @import("variable_length_codes.zig");
const Channel = @import("types.zig").Channel;
const Frame = @import("types.zig").Frame;
const mpeg = @import("types.zig").mpeg;
const Packet = @import("types.zig").Packet;
const assert = std.debug.assert;

// @todo how do functions look up vs methods
pub fn findNextStartCode(bit_reader: *bitReader, T: type) !T {
    // @todo assert of type somehow or just implement an interface of sorts
    assert(bit_reader.bit_count == 0);
    var reader = bit_reader.source.reader();
    var byte0 = try reader.readByte();
    var byte1 = try reader.readByte();
    var byte2 = try reader.readByte();

    while (true) {
        if (byte0 == 0x00 and byte1 == 0x00 and byte2 == 0x01) {
            const start_code = try reader.readByte();
            return @as(T, @enumFromInt(start_code));
        } else {
            byte0 = byte1;
            byte1 = byte2;
            byte2 = try reader.readByte();
        }
    }
}

const VideoStartCodes = enum(u8) {
    const Self = @This();

    picture_start = 0x00,
    slice_start_1 = 0x01,
    slice_start_175 = 0xAF,

    user_data = 0xB2,
    sequence_header = 0xB3,
    sequence_error = 0xB4,
    extension_start = 0xB5,
    sequence_end = 0xB7,
    group_start = 0xB8,

    pub fn isSliceCode(self: Self) bool {
        const slice_start_1: u8 = @intFromEnum(Self.slice_start_1);
        const slice_start_175: u8 = @intFromEnum(Self.slice_start_175);
        const current_code: u8 = @intFromEnum(self);
        const result = slice_start_1 <= current_code and current_code <= slice_start_175;
        return result;
    }
};
const SystemStartCodes = enum(u8) {
    const Self = @This();

    // system
    ios_11172_end = 0xB9,
    pack_start = 0xBA,
    system_header_start = 0xBB,

    // packet
    private_stream_1 = 0xBD,
    padding_stream = 0xBE,
    private_stream_2 = 0xBF,
    audio_stream_0 = 0xC0,
    audio_stream_31 = 0xDF,

    video_stream_0 = 0xE0,
    video_stream_15 = 0xEF,
};

const picture_types = enum(u8) {
    forbidden = 0,
    I = 1,
    P = 2,
    B = 3,
    D = 4,
};

const stream_ids = enum(u8) {
    video = 0b1110_0000,
    audio = 0b1100_0000,
    padding = 0b1011_1110,
    // incomplete
};

fn processPack(data: *mpeg, bit_reader: *bitReader) !void {
    const debug = true;
    if (debug) std.log.debug("Processing Pack", .{});
    _ = try bit_reader.readBits(4); // pack  bits

    data.system_clock_reference = try bit_reader.readBits31515();
    if (debug) std.debug.print("system_clock_reference {} || ", .{data.system_clock_reference});

    _ = try bit_reader.readBits(1);
    data.mux_rate = @intCast(try bit_reader.readBits(22));
    if (debug) std.log.debug("mux_rate {}", .{data.mux_rate});

    _ = try bit_reader.readBits(1);

    // should be byte aligned now
    std.debug.assert(bit_reader.bit_buffer == 0 and bit_reader.bit_count == 0);
}

fn processSystemHeader(data: *mpeg, bit_reader: *bitReader) !void {
    // system header flags

    const debug = true;

    var header_length = try bit_reader.readBits(16);
    if (debug) std.log.debug("Length {}", .{header_length});
    assert(header_length >= 6 and header_length <= 165);

    _ = try bit_reader.readBits(1);

    data.rate_bound = @intCast(try bit_reader.readBits(22));
    _ = try bit_reader.readBits(1);

    data.audio_bound = @intCast(try bit_reader.readBits(6));
    assert(data.audio_bound <= 32);

    data.fixed_flag = @intCast(try bit_reader.readBits(1));

    data.csps_flag = @intCast(try bit_reader.readBits(1));

    data.system_audio_lock_flag = @intCast(try bit_reader.readBits(1));
    data.system_video_lock_flag = @intCast(try bit_reader.readBits(1));

    _ = try bit_reader.readBits(1);

    data.video_bound = @intCast(try bit_reader.readBits(5));

    _ = try bit_reader.readBits(8);

    header_length -= 6;

    while (header_length != 0) : (header_length -= 3) {
        data.stream_id = @intCast(try bit_reader.readBits(8));
        if (debug) std.log.debug("stream_id {b}", .{data.stream_id});

        if (@as(stream_ids, @enumFromInt(data.stream_id & 0xF0)) == stream_ids.video) {
            if (debug) std.log.debug("video stream {}", .{data.stream_id & 0x0F});
        }

        _ = try bit_reader.readBits(2);
        data.std_buffer_bound_scale = @intCast(try bit_reader.readBits(1));
        data.std_buffer_size_bound = @intCast(try bit_reader.readBits(13));
    }
    if (debug) std.log.debug("rate_bound {}\n, audio_bound {}\n, stream_id = {}", .{ data.rate_bound, data.audio_bound, data.stream_id });
    std.debug.assert(bit_reader.bit_count == 0);
}

pub fn processPacket(context: *mpeg, bit_reader: *bitReader) !void {
    var data: *Packet = &context.video_packets[context.current_packet];
    context.current_packet += 1;

    data.packet_length = @intCast(try bit_reader.readBits(16));

    var total_bits: u8 = 0;

    std.log.debug("stream {b} packet_length {}", .{ data.packet_stream_id, data.packet_length });

    while (try bit_reader.peekBits(8) == 0xFF) {
        bit_reader.consumeBits(8);
        total_bits += 8;
    }

    const signal_bits = try bit_reader.peekBits(4);

    if (signal_bits == 0b0001) {
        bit_reader.consumeBits(2);
        data.std_buffer_scale = @intCast(try bit_reader.readBits(1));
        data.std_buffer_size = @intCast(try bit_reader.readBits(13));
        total_bits += 1 + 13;
    } else if (signal_bits == 0b0010) {
        bit_reader.consumeBits(4);
        data.presentation_time_stamp = try bit_reader.readBits31515();
        total_bits += 4 + 33;
        std.log.debug("pts/dts {}\n", .{data.presentation_time_stamp});
    } else if (signal_bits == 0b0011) {
        bit_reader.consumeBits(4);

        data.presentation_time_stamp = try bit_reader.readBits31515();

        _ = try bit_reader.readBits(4);
        data.decoding_time_stamp = try bit_reader.readBits31515();

        total_bits += 4 + 33 + 4 + 33;
        std.log.debug("pts/dts {} {}\n", .{ data.presentation_time_stamp, data.decoding_time_stamp });
    } else {
        const expected_bits = try bit_reader.readBits(8);
        assert(expected_bits == 0b0000_1111);
        total_bits += 8;
        std.log.debug("no pts", .{});
    }

    assert(bit_reader.bit_count == 0);

    const bytes_to_read = data.packet_length - total_bits / 8 - 1;

    std.log.debug(
        \\--- Process Packet ---
        \\ packet number {}
        \\
    , .{
        context.current_packet - 1,
    });

    data.data = try context.allocator.alloc(u8, bytes_to_read);

    for (0..bytes_to_read) |index| {
        data.data[index] = try bit_reader.source.reader().readByte();
        context.video_buffer[context.current_byte] = data.data[index];
        context.current_byte += 1;
    }

    //const bytes_read = try bit_reader.source.reader().readAtLeast(data.data, bytes_to_read);
    // assert(bytes_read == bytes_to_read);
}

// zig fmt: off
const intra_quant: [64]u8 = .{
     8, 16, 19, 22, 26, 27, 29, 34,
    16, 16, 22, 24, 27, 29, 34, 37,
    19, 22, 26, 27, 29, 34, 34, 38,
    22, 22, 26, 27, 29, 34, 37, 40,
    22, 26, 27, 29, 32, 35, 40, 48,
    26, 27, 29, 32, 35, 40, 48, 58,
    26, 27, 29, 34, 38, 46, 56, 69,
    27, 29, 35, 38, 46, 56, 69, 83
};
const zig_zag: [64]u8 = .{
     0,  1,  8, 16,  9,  2,  3, 10,
    17, 24, 32, 25, 18, 11,  4,  5,
    12, 19, 26, 33, 40, 48, 41, 34,
    27, 20, 13,  6,  7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36,
    29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46,
    53, 60, 61, 54, 47, 55, 62, 63
};
// zig fmt: on

pub fn processSequenceHeader(data: *mpeg, bit_reader: *bitReader) !void {
    data.horizontal_size = @intCast(try bit_reader.readBits(12));
    data.vertical_size = @intCast(try bit_reader.readBits(12));

    const channel_width = @divTrunc(data.horizontal_size + 15, 16);

    const channel_height = @divTrunc(data.vertical_size + 15, 16);

    data.frame.y.width = channel_width;
    data.frame.y.height = channel_height;
    data.frame.y.data = try data.allocator.alloc(i32, channel_width * channel_height);
    data.frame.cr.data = try data.allocator.alloc(i32, channel_width * channel_height);
    data.frame.cb.data = try data.allocator.alloc(i32, channel_width * channel_height);

    data.pel_aspect_ratio = @intCast(try bit_reader.readBits(4));
    data.picture_rate = @intCast(try bit_reader.readBits(4));
    data.bit_rate = @intCast(try bit_reader.readBits(18));

    _ = try bit_reader.readBits(1);

    data.vbv_buffer_size = @intCast(try bit_reader.readBits(10));

    data.constrained_parameters_flag = @intCast(try bit_reader.readBits(1));
    data.load_intra_quantizer_matrix = @intCast(try bit_reader.readBits(1));

    if (data.load_intra_quantizer_matrix == 1) {
        for (0..64) |i| {
            data.intra_quantizer_matrix[i] = @intCast(try bit_reader.readBits(8));
        }
    } else {
        for (0..64) |i| {
            data.intra_quantizer_matrix[i] = intra_quant[i];
        }
    }

    data.load_non_intra_quantizer_matrix = @intCast(try bit_reader.readBits(1));

    if (data.load_non_intra_quantizer_matrix == 1) {
        for (0..64) |i| {
            data.intra_quantizer_matrix[i] = @intCast(try bit_reader.readBits(8));
        }
    }

    std.log.debug(
        \\--- Sequence Header ---
        \\  {} x {}
        \\  pel_aspect_ratio: {}
        \\  bit_rate: {x}
        \\  vbv_buffer_size: {}
        \\  constrained_parameter_flag: {}
        \\  load_intra_quantizer_matrix: {}
        \\  load_non_intra_quantizer_matrix: {}
        \\
    , .{
        data.horizontal_size,
        data.vertical_size,
        data.pel_aspect_ratio,
        data.bit_rate,
        data.vbv_buffer_size,
        data.constrained_parameters_flag,
        data.load_intra_quantizer_matrix,
        data.load_non_intra_quantizer_matrix,
    });

    assert(bit_reader.bit_count == 0);
}

pub fn processGroupOfPictures(data: *mpeg, bit_reader: *bitReader) !void {
    data.time_code = @intCast(try bit_reader.readBits(25));
    data.closed_gop = @intCast(try bit_reader.readBits(1));
    data.broken_link = @intCast(try bit_reader.readBits(1));

    std.log.debug(
        \\--- Group of Pictures ---
        \\  time_code: {b}
        \\  closed_gop: {}
        \\  broken_link: {}
        \\
    , .{
        data.time_code,
        data.closed_gop,
        data.broken_link,
    });

    assert(bit_reader.bit_count == 5); // 5 marker bits left
    bit_reader.flushBits();
}

pub fn processPicture(data: *mpeg, bit_reader: *bitReader) !void {
    data.temporal_reference = @intCast(try bit_reader.readBits(10));
    data.picture_coding_type = @intCast(try bit_reader.readBits(3));
    assert(1 <= data.picture_coding_type and data.picture_coding_type <= 4);
    data.vbv_delay = @intCast(try bit_reader.readBits(16));

    if (data.picture_coding_type == 2 or data.picture_coding_type == 3) {
        data.full_pel_forward_vector = @intCast(try bit_reader.readBits(1));
        data.forward_f_code = @intCast(try bit_reader.readBits(3));
    }

    if (data.picture_coding_type == 3) {
        data.full_pel_backward_vector = @intCast(try bit_reader.readBits(3));
        data.backward_f_code = @intCast(try bit_reader.readBits(3));
    }

    while (try bit_reader.peekBits(1) == 1) {
        data.extra_bit_picture = @intCast(try bit_reader.readBits(1));
        data.extra_information_picture = @intCast(try bit_reader.readBits(8));
    }
    // end extra info = 0;
    data.extra_bit_picture = @intCast(try bit_reader.readBits(1));

    // @todo extension
    // @todo user data

    std.log.debug(
        \\--- Picture Header ---
        \\  temporal_reference: {}
        \\  picture_coding_type: {}
        \\  vbv_delay: {x}
        \\  extra_bit_picture: {}
        \\
    , .{
        data.temporal_reference,
        @as(picture_types, @enumFromInt(data.picture_coding_type)),
        data.vbv_delay,
        data.extra_bit_picture,
    });
    // std.debug.assert(bit_reader.bit_count == 2);
    bit_reader.flushBits();
}

pub fn processSlice(data: *mpeg, bit_reader: *bitReader) !void {
    data.dc_prev = @splat(128);
    data.quantizer_scale = @intCast(try bit_reader.readBits(5));

    // @todo: init to 0 somewhere else
    data.extra_information_slice = 0;
    while (try bit_reader.peekBits(1) == 1) {
        _ = try bit_reader.readBits(1);
        data.extra_information_slice = @intCast(try bit_reader.readBits(5));
    }
    _ = try bit_reader.readBits(1);

    std.log.debug(
        \\--- Slice Header ---
        \\  quantizer_scale: {}
        \\  extra_information_slice: {}
        \\
    , .{
        data.quantizer_scale,
        data.extra_information_slice,
    });

    data.current_packet += 1;
    std.log.debug("current slice {}", .{data.current_packet});

    try processMacroblocks(data, bit_reader);

    // we might have junk because processMacroblock isn't fully implemented
    bit_reader.flushBits();
}

pub fn readVLCBits(lookup: vlc.CodeLookup, bits: anytype) !u8 {
    return lookup.table[bits];
}

pub fn readVLC(lookup: vlc.CodeLookup, bit_reader: *bitReader) !u16 {
    const bits = try bit_reader.peekBits(@intCast(lookup.bit_length));
    bit_reader.consumeBits(@intCast(lookup.lengths[bits]));
    const result = lookup.table[bits];
    return result;
}

pub fn processMacroblocks(data: *mpeg, bit_reader: *bitReader) !void {
    // 11 bit mb stuffing
    // mb address is index of macroblock in the picture
    // index are in raster scan order starting from 0 in top left
    // at start, initialized to -1
    // mb address increment horizontal position of the first macroblock
    // for other macroblocks in same slice, inc > 1 means skips
    // if > 33 increment address by 33 + appropriate code

    // const total_macroblocks = data.vertical_size * data.horizontal_size / (16 * 16);

    const mb_count_x = data.frame.y.width / 16;
    const mb_count_y = data.frame.y.height / 16;
    // const mb_count = mb_count_x * mb_count_y;

    var mb_index: u32 = 0;
    for (0..mb_count_y) |mb_y| {
        for (0..mb_count_x) |mb_x| {
            mb_index += 1;
            _ = mb_y;
            _ = mb_x;
            while (try bit_reader.peekBits(11) == 0x1111) {
                bit_reader.consumeBits(11);
            }

            var increment: u32 = 0;

            while (try bit_reader.peekBits(11) == 0x1000) {
                bit_reader.consumeBits(11);
                increment += 33;
            }
            increment += @intCast(try readVLC(vlc.mb_address_increment_lookup, bit_reader));

            const picture_type: picture_types = @enumFromInt(data.picture_coding_type);
            var mb_type_vlc: vlc.CodeLookup = undefined;
            switch (picture_type) {
                .I => mb_type_vlc = vlc.mb_type_I_lookup,
                .P => mb_type_vlc = vlc.mb_type_P_lookup,
                .B => mb_type_vlc = vlc.mb_type_B_lookup,
                .forbidden, .D => unreachable,
            }

            const mb_type: u16 = try readVLC(mb_type_vlc, bit_reader);

            const mb_quant = mb_type & 0b00001;
            const mb_motion_forward = mb_type & 0b00010;
            const mb_motion_backward = mb_type & 0b00100;
            const mb_block_pattern = mb_type & 0b01000;
            data.mb_intra = mb_type >> 4;

            if (mb_quant != 0) {
                data.quantizer_scale = @intCast(try bit_reader.readBits(5));
            }

            var mb_horizontal_forward_code: u16 = undefined;
            var mb_horizontal_forward_r: u16 = undefined;
            var mb_vertical_forward_code: u16 = undefined;
            var mb_vertical_forward_r: u16 = undefined;

            if (mb_motion_forward != 0) {
                mb_horizontal_forward_code = try readVLC(vlc.mb_motion_vector_lookup, bit_reader);
                // @todo need to check if this is set, what are the possible values?
                if (data.forward_f_code > 1 and mb_horizontal_forward_code != 0) {
                    mb_horizontal_forward_r = try readVLC(vlc.mb_motion_vector_lookup, bit_reader);
                }

                mb_vertical_forward_code = try readVLC(vlc.mb_motion_vector_lookup, bit_reader);

                if (data.forward_f_code > 1 and mb_vertical_forward_code != 0) {
                    mb_vertical_forward_r = try readVLC(vlc.mb_motion_vector_lookup, bit_reader);
                }
            }

            // @todo change these to appropriate types and then @intCast instead
            // these were changed to u16 because of the VLC table change
            var mb_horizontal_backward_code: u16 = undefined;
            var mb_horizontal_backward_r: u16 = undefined;
            var mb_vertical_backward_code: u16 = undefined;
            var mb_vertical_backward_r: u16 = undefined;

            if (mb_motion_backward != 0) {
                mb_horizontal_backward_code = try readVLC(vlc.mb_motion_vector_lookup, bit_reader);
                // @todo need to check if this is set, what are the possible values?
                if (data.backward_f_code > 1 and mb_horizontal_backward_code != 0) {
                    mb_horizontal_backward_r = try readVLC(vlc.mb_motion_vector_lookup, bit_reader);
                }

                mb_vertical_backward_code = try readVLC(vlc.mb_motion_vector_lookup, bit_reader);

                if (data.backward_f_code > 1 and mb_vertical_backward_code != 0) {
                    mb_vertical_backward_r = try readVLC(vlc.mb_motion_vector_lookup, bit_reader);
                }
            }

            // @todo don't really understand the block pattern stuff
            if (mb_block_pattern != 0) {
                data.block_pattern = @intCast(try readVLC(vlc.mb_coded_block_pattern_lookup, bit_reader));
            } else if (data.mb_intra != 0) {
                data.block_pattern = 0b1111_11;
            }

            std.log.debug(
                \\--- Macroblock Header {} ---
                \\  increment: {}
                \\  mb_type: {b:05}
                \\  picture_type: {}
                \\  mb_quant: {b}
                \\      quantizer_scale: {}
                \\  mb_motion_forward: {b}
                \\  mb_motion_backward: {b}
                \\  mb_block_intra: {}
                \\  mb_coded_block_pattern: {b:06}
                \\      mb_block_pattern: {b}
                \\
            , .{
                mb_index,
                increment,
                mb_type,
                picture_type,
                mb_quant,
                data.quantizer_scale,
                mb_motion_forward,
                mb_motion_backward,
                data.mb_intra,
                mb_block_pattern,
                data.block_pattern,
            });

            if (mb_index == 326) {
                std.log.debug("break", .{});
            }
            try processBlocks(data, bit_reader);
        }
    }
    if (bit_reader.bit_count > 8) {
        const bytes_remaining: i32 = @intCast(bit_reader.bit_count / 8);
        try data.stream.seekBy(-1 * bytes_remaining);
    }
    // bit_reader.flushBits();
}

fn processBlocks(data: *mpeg, bit_reader: *bitReader) !void {
    std.log.debug("--- processBlocks ---", .{});
    std.log.debug("  Intra {}", .{data.mb_intra});

    // 0, 0,0
    // 1, 0,4
    // 2, 0,8
    for (0..6) |block_idx| {
        const block_coded: u8 = data.block_pattern & (@as(u8, 1) << @as(u3, @intCast(block_idx)));
        if (block_coded == 0) continue;

        var block_data: [64]i32 = @splat(0);

        const mb_row = 0;
        const mb_col = 0;
        const pixel_y = mb_row * (data.frame.y.width * 16) + mb_col * 16;

        var mb_pointer_y: *i32 = undefined;
        if (block_idx < 4) {
            mb_pointer_y = &data.frame.y.data[pixel_y];
        } else if (block_idx == 4) {
            mb_pointer_y = &data.frame.cr.data[pixel_y];
        } else {
            mb_pointer_y = &data.frame.cb.data[pixel_y];
        }

        std.log.debug("Decoding Block {}", .{block_idx});
        if (data.mb_intra != 0) {
            if (block_idx < 4) {
                const mag_maybe = try readVLC(vlc.dc_code_y_lookup, bit_reader);
                assert(mag_maybe != 255);
                const magnitude = @as(u5, @intCast(mag_maybe));

                const dc_prev = &data.dc_prev[0];
                var diff: u8 = 0;
                if (magnitude != 0) {
                    diff = @intCast(try bit_reader.readBits(magnitude));
                    if (@as(usize, 1) << (magnitude - 1) != 0) {
                        block_data[0] = dc_prev.* + diff;
                    } else {
                        block_data[0] = dc_prev.* + (-1 * (@as(i32, 1) << magnitude)) | (diff + 1);
                    }
                } else {
                    block_data[0] = dc_prev.*;
                }

                std.log.debug(" Y diff {}", .{diff});

                dc_prev.* = block_data[0];
            } else { // chroma
                const magnitude = @as(u6, @intCast(try readVLC(vlc.dc_code_c_lookup, bit_reader)));

                var diff: u8 = 0;
                if (magnitude != 0) {
                    diff = @intCast(try bit_reader.readBits(magnitude));
                }
                std.log.debug("Cr/Cb magnitude {}", .{magnitude});

                data.frame.cr.data[block_idx] = diff;
            }
        } else {
            std.log.debug(" Non Intra", .{});
            // dct coeff first
            assert(false);
        }

        var n: usize = 1;
        while (true) {
            if (try bit_reader.peekBits(2) == 0b10) {
                break;
            }
            var run: usize = 0;
            var mag: i16 = 0;
            for (1..17) |length| {
                const bits = try bit_reader.peekBits(@intCast(length));
                if (length == 6 and bits == 0b0000_01) {
                    _ = try bit_reader.readBits(6);
                    run = try bit_reader.readBits(6);
                    mag = @intCast(try bit_reader.readBits(8));
                    //std.log.debug("escape run {}, mag {}", .{ run, mag });
                    if (mag == 0) {
                        mag = @intCast(try bit_reader.readBits(8));
                    } else if (mag == 128) {
                        mag = @intCast(try bit_reader.readBits(8));
                        mag -= 256;
                    } else if (mag > 128) {
                        mag = mag - 256;
                    }
                    //std.log.debug("escape run {}, mag {}", .{ run, mag });
                    break;
                }

                const value_maybe = data.map.get(.{ .code = @intCast(bits), .length = @intCast(length) });
                if (value_maybe) |value| {
                    _ = try bit_reader.readBits(@intCast(length));
                    run = value >> 8;
                    mag = @intCast(value & 0x00FF);
                    const sign = try bit_reader.readBits(1);
                    if (sign != 0) {
                        mag *= -1;
                    }
                    break;
                }

                if (length == 16) {
                    unreachable;
                }
            }

            std.log.debug(" run {}, mag {}", .{ run, mag });
            n += run;

            const i = zig_zag[n];
            std.log.debug("quant {}", .{mag});
            block_data[i] = (2 * mag * data.quantizer_scale * data.intra_quantizer_matrix[i]) >> 4;
            if (block_data[i] & 1 == 0) {
                block_data[i] -= if (block_data[i] > 0) 1 else -1;
            }
            std.log.debug("quant {}", .{block_data[i]});
            n += 1;
        }

        const bits = try bit_reader.readBits(2);
        assert(bits == 0b10);
    }
}

pub fn sendPacketToDecoder(stream: *std.io.StreamSource) !void {
    var global_mpeg: mpeg = undefined;
    global_mpeg.audio_bound = 0;
    global_mpeg.stream = stream;
    global_mpeg.current_byte = 0;
    global_mpeg.current_packet = 0;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    global_mpeg.allocator = gpa.allocator();

    var map = try vlc.initCodeMap(global_mpeg.allocator);

    global_mpeg.map = map;
    const out = map.get(.{ .code = 0b0000_0000_0110_00, .length = 14 });

    assert(out == 0x00_17);

    var bit_reader: bitReader = .{ .source = stream };

    while (true) {
        const system_start_code = try findNextStartCode(&bit_reader, SystemStartCodes);
        switch (system_start_code) {
            .pack_start => try processPack(&global_mpeg, &bit_reader),
            .system_header_start => try processSystemHeader(&global_mpeg, &bit_reader),
            .video_stream_0 => {
                global_mpeg.packet_stream_id = @intFromEnum(system_start_code);
                try processPacket(&global_mpeg, &bit_reader);
            },
            .padding_stream => {
                std.log.debug("padding stream, breaking loop", .{});
                break;
            },
            else => unreachable,
        }
    }

    std.log.debug("Bytes written {}", .{global_mpeg.current_byte});
    const v_buffer = std.io.fixedBufferStream(&global_mpeg.video_buffer);
    var video_source = std.io.StreamSource{ .buffer = v_buffer };
    var video_buffer_reader = bitReader{ .source = &video_source };

    while (true) {
        const vid_start_code = findNextStartCode(&video_buffer_reader, VideoStartCodes) catch |err| {
            std.log.debug("error is {}", .{err});
            break;
        };
        std.log.debug("start code is {}", .{vid_start_code});

        switch (vid_start_code) {
            .picture_start => try processPicture(&global_mpeg, &video_buffer_reader),
            .sequence_header => try processSequenceHeader(&global_mpeg, &video_buffer_reader),
            .group_start => try processGroupOfPictures(&global_mpeg, &video_buffer_reader),
            .sequence_end => {
                std.log.debug("Sequence End", .{});
                // global_mpeg.allocator.free(global_mpeg.frame.y.data);
                // global_mpeg.allocator.free(global_mpeg.frame.cb.data);
                // global_mpeg.allocator.free(global_mpeg.frame.cr.data);
                return;
            },
            else => {
                if (vid_start_code.isSliceCode()) {
                    std.log.debug(" Slice {} ", .{vid_start_code});
                    try processSlice(&global_mpeg, &video_buffer_reader);
                } else {
                    unreachable;
                }
            },
        }
    }
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)

    const buffer: [46]u8 = .{
        0x00, 0x00, 0x01, 0xB3, 0x02, 0x00, 0x10, 0x14, 0xFF, 0xFF, 0xE0, 0xA0, 0x00, 0x00, 0x01, 0xB8,
        0x80, 0x08, 0x00, 0x40, 0x00, 0x00, 0x01, 0x00, 0x00, 0x0F, 0xFF, 0xF8, 0x00, 0x00, 0x01, 0x01,
        0xFA, 0x96, 0x52, 0x94, 0x88, 0xAA, 0x25, 0x29, 0x48, 0x88, 0x00, 0x00, 0x01, 0xB7,
    };
    const fixed_buffer = std.io.fixedBufferStream(&buffer);
    var stream = std.io.StreamSource{ .const_buffer = fixed_buffer };

    // try decodeVideo(&stream);
    std.log.debug("----------------", .{});
    const file = try std.fs.cwd().openFile("samples/sample_640x360.mpeg", .{});
    defer file.close();

    stream = std.io.StreamSource{ .file = file };

    try sendPacketToDecoder(&stream);
}
