const std = @import("std");
const bitReader = @import("bitReader.zig").bitReader;

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
    // read for bit fixed
    // ...
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

    // this causes an annoying issue where we get an extra byte
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
    std.log.debug("sequence header", .{});

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

    std.log.debug("{} x {}", .{ data.horizontal_size, data.vertical_size });

    assert(bit_reader.bit_count == 0);
}

pub fn processGroupOfPictures(data: *mpeg, bit_reader: *bitReader) !void {
    data.time_code = @intCast(try bit_reader.readBits(25));
    data.closed_gop = @intCast(try bit_reader.readBits(1));
    data.broken_link = @intCast(try bit_reader.readBits(1));
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
    bit_reader.flushBits();
}

pub fn processSlice(data: *mpeg, bit_reader: *bitReader) !void {
    data.quantizer_scale = @intCast(try bit_reader.readBits(5));
    while (try bit_reader.peekBits(1) == 1) {
        _ = try bit_reader.readBits(1);
        data.extra_information_slice = @intCast(try bit_reader.readBits(5));
    }
    _ = try bit_reader.readBits(1);
    // macroblock

    bit_reader.flushBits();
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

    //
    quantizer_scale: u5,
    extra_information_slice: u8,
};

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)

    const file = try std.fs.cwd().openFile("sample_640x360.mpeg", .{});
    defer file.close();

    var stream = std.io.StreamSource{ .file = file };
    var reader = stream.reader();

    var bit_reader: bitReader = .{ .source = stream };

    var byte0 = try reader.readByte();
    var byte1 = try reader.readByte();
    var byte2 = try reader.readByte();

    var global_mpeg: mpeg = undefined;
    global_mpeg.audio_bound = 0;

    while (true) {
        if (byte0 == 0x00 and byte1 == 0x00 and byte2 == 0x01) {
            if (false) std.log.debug("Found a start code", .{});

            const code = try reader.readByte();
            const codeenum = toCode(code);

            switch (codeenum) {
                .pack_start => try processPack(&global_mpeg, &bit_reader),
                .system_header_start => try processSystemHeader(&global_mpeg, &bit_reader),
                .video_stream_0 => {
                    global_mpeg.packet_stream_id = code;
                    try processPacket(&global_mpeg, &bit_reader);
                },
                .sequence_header => try processSequenceHeader(&global_mpeg, &bit_reader),
                .group_start => try processGroupOfPictures(&global_mpeg, &bit_reader),
                .slice_start_1 => {},

                .padding_stream => {
                    std.log.debug("padding stream, breaking loop", .{});
                    break;
                },
                else => {},
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
