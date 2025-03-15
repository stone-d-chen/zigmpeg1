const std = @import("std");
const bitReader = @import("bitReader.zig").bitReader;
const vlc = @import("variable_length_codes.zig");

const assert = std.debug.assert;

const start_codes = enum(u8) {
    // video
    picture_start = 0x00,
    slice_start_1 = 0x01,
    slice_start_175 = 0xAF,

    user_data = 0xB2,
    sequence_header = 0xB3,
    sequence_error = 0xB4,
    extension_start = 0xB5,
    sequence_end = 0xB7,
    group_start = 0xB8,

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

    pub fn isSliceCode(self: @This()) bool {
        const slice_start_1: u8 = @intFromEnum(start_codes.slice_start_1);
        const slice_start_175: u8 = @intFromEnum(start_codes.slice_start_175);
        const current_code: u8 = @intFromEnum(self);
        const result = slice_start_1 <= current_code and current_code <= slice_start_175;
        return result;
    }
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

fn toCode(code: u8) start_codes {
    return @as(start_codes, @enumFromInt(code));
}

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

pub fn processPacket(data: *mpeg, bit_reader: *bitReader) !void {
    data.packet_length = @intCast(try bit_reader.readBits(16));

    std.log.debug("stream {b} packet_length {}", .{ data.packet_stream_id, data.packet_length });

    while (try bit_reader.peekBits(8) == 0xFF) {
        bit_reader.consumeBits(8);
    }

    const signal_bits = try bit_reader.peekBits(4);

    if (signal_bits == 0b0001) {
        bit_reader.consumeBits(2);
        data.std_buffer_scale = @intCast(try bit_reader.readBits(1));
        data.std_buffer_size = @intCast(try bit_reader.readBits(13));
    } else if (signal_bits == 0b0010) {
        bit_reader.consumeBits(4);
        data.presentation_time_stamp = try bit_reader.readBits31515();
    } else if (signal_bits == 0b0011) {
        bit_reader.consumeBits(4);

        data.presentation_time_stamp = try bit_reader.readBits31515();

        _ = try bit_reader.readBits(4);
        data.decoding_time_stamp = try bit_reader.readBits31515();

        std.log.debug("pts/dts {} {}", .{ data.presentation_time_stamp, data.decoding_time_stamp });
    } else {
        const expected_bits = try bit_reader.readBits(8);
        assert(expected_bits == 0b0000_1111);
    }

    assert(bit_reader.bit_count == 0);
}

pub fn processSequenceHeader(data: *mpeg, bit_reader: *bitReader) !void {
    data.horizontal_size = @intCast(try bit_reader.readBits(12));
    data.vertical_size = @intCast(try bit_reader.readBits(12));

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

    try processMacroblocks(data, bit_reader);

    // we might have junk because processMacroblock isn't fully implemented
    bit_reader.flushBits();
}

pub fn readVLCBits(lookup: vlc.CodeLookup, bits: anytype) !u8 {
    return lookup.table[bits];
}

pub fn readVLC(lookup: vlc.CodeLookup, bit_reader: *bitReader) !u8 {
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

    const mb_type: u8 = try readVLC(mb_type_vlc, bit_reader);

    const mb_quant = mb_type & 0b00001;
    const mb_motion_forward = mb_type & 0b00010;
    const mb_motion_backward = mb_type & 0b00100;
    const mb_block_pattern = mb_type & 0b01000;
    data.mb_intra = mb_type & 0b10000;

    if (mb_quant != 0) {
        data.quantizer_scale = @intCast(try bit_reader.readBits(5));
    }

    var mb_horizontal_forward_code: u8 = undefined;
    var mb_horizontal_forward_r: u8 = undefined;
    var mb_vertical_forward_code: u8 = undefined;
    var mb_vertical_forward_r: u8 = undefined;

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

    var mb_horizontal_backward_code: u8 = undefined;
    var mb_horizontal_backward_r: u8 = undefined;
    var mb_vertical_backward_code: u8 = undefined;
    var mb_vertical_backward_r: u8 = undefined;

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
        data.block_pattern = try readVLC(vlc.mb_coded_block_pattern_lookup, bit_reader);
    } else if (data.mb_intra != 0) {
        data.block_pattern = 0b1111_11;
    }

    std.log.debug(
        \\--- Macroblock Header ---
        \\  increment: {}
        \\  mb_type: {b:05}
        \\  picture_type: {}
        \\  mb_quant: {b}
        \\      quantizer_scale: {}
        \\  mb_motion_forward: {b}
        \\  mb_motion_backward: {b}
        \\  mb_block_intra: {b}
        \\  mb_coded_block_pattern: {b:06}
        \\      mb_block_pattern: {b}
        \\
    , .{
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

    try processBlocks(data, bit_reader);
    bit_reader.flushBits();
}

fn processBlocks(data: *mpeg, bit_reader: *bitReader) !void {
    const coded_block_pattern = data.block_pattern;
    for (0..6) |block_idx| {
        const block_coded: u8 = coded_block_pattern & (@as(u8, 1) << @as(u3, @intCast(block_idx)));
        if (block_coded != 0) {
            std.log.debug("coded {}", .{block_idx});
        }
    }
    _ = bit_reader;
}

pub const mpeg = struct {
    system_clock_reference: u33 = 0,
    mux_rate: u32 = 0,

    // system header
    // header length
    rate_bound: u32,
    audio_bound: u6,
    fixed_flag: u1,
    csps_flag: u1,
    system_audio_lock_flag: u1,
    system_video_lock_flag: u1,

    video_bound: u5,
    stream_id: u8,
    std_buffer_bound_scale: u1,
    std_buffer_size_bound: u13,

    // packet
    packet_stream_id: u8,
    packet_length: u16,
    std_buffer_scale: u1,
    std_buffer_size: u13,
    presentation_time_stamp: u33,
    decoding_time_stamp: u33,

    // sequence header

    horizontal_size: u12,
    vertical_size: u12,
    pel_aspect_ratio: u4,
    picture_rate: u4,
    bit_rate: u18,
    vbv_buffer_size: u10,
    constrained_parameters_flag: u1,
    load_intra_quantizer_matrix: u1,

    intra_quantizer_matrix: [64]u8,

    load_non_intra_quantizer_matrix: u1,

    non_intra_quantizer_matrix: [64]u8,
    // extension_start_code signals mpeg2
    // user_data

    // group of pictures
    time_code: u25,
    // drop_frame_flag: u1,
    // time_code_hours: u5,
    // time_code_minutes: u6,
    // time_code_seconds: u6,
    // time_code_pictures: u6
    closed_gop: u1,
    broken_link: u1,

    // picture layer
    temporal_reference: u10,
    picture_coding_type: u3,
    vbv_delay: u16,
    full_pel_forward_vector: u1,
    forward_f_code: u3,
    full_pel_backward_vector: u1,
    backward_f_code: u3,
    extra_bit_picture: u1,
    extra_information_picture: u8,
    extra_bit_picture2: u1,
    // extension etc

    // slice
    quantizer_scale: u5,
    extra_information_slice: u8,

    // macroblock
    block_pattern: u8,
    mb_intra: u8,
};

pub fn decodeVideo(stream: *std.io.StreamSource) !void {
    var reader = stream.reader();

    var bit_reader: bitReader = .{ .source = stream };

    var byte0 = try reader.readByte();
    var byte1 = try reader.readByte();
    var byte2 = try reader.readByte();

    var global_mpeg: mpeg = undefined;
    global_mpeg.audio_bound = 0;

    while (true) {
        if (byte0 == 0x00 and byte1 == 0x00 and byte2 == 0x01) {
            const code = try reader.readByte();
            const codeenum = toCode(code);
            if (false) std.log.debug("Found a start code {x}", .{code});

            switch (codeenum) {
                .pack_start => try processPack(&global_mpeg, &bit_reader),
                .system_header_start => try processSystemHeader(&global_mpeg, &bit_reader),
                .picture_start => try processPicture(&global_mpeg, &bit_reader),
                .video_stream_0 => {
                    global_mpeg.packet_stream_id = code;
                    try processPacket(&global_mpeg, &bit_reader);
                },
                .sequence_header => try processSequenceHeader(&global_mpeg, &bit_reader),
                .group_start => try processGroupOfPictures(&global_mpeg, &bit_reader),
                .sequence_end => {
                    std.log.debug("Sequence End", .{});
                    return;
                },
                .padding_stream => {
                    std.log.debug("padding stream, breaking loop", .{});
                    break;
                },
                else => {
                    if (codeenum.isSliceCode()) {
                        try processSlice(&global_mpeg, &bit_reader);
                    } else {
                        unreachable;
                    }
                },
            }

            byte0 = try reader.readByte();
            byte1 = try reader.readByte();
            byte2 = try reader.readByte();
        } else {
            byte0 = byte1;
            byte1 = byte2;
            byte2 = try reader.readByte();
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

    try decodeVideo(&stream);

    // const file = try std.fs.cwd().openFile("sample_640x360.mpeg", .{});
    // defer file.close();

    // stream = std.io.StreamSource{ .file = file };

    // try decodeVideo(&stream);
}
