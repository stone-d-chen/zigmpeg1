const std = @import("std");
const bitReader = @import("bitReader.zig").bitReader;

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

fn toCode(code: u8) start_codes {
    return @as(start_codes, @enumFromInt(code));
}

fn processPack(data: *mpeg, bit_reader: *bitReader) !void {
    const debug = false;
    // read for bit fixed
    // ...
    if (debug) std.log.debug("Processing Pack", .{});
    _ = try bit_reader.readBits(4); // pack  bits

    data.system_clock_reference = 0;
    data.system_clock_reference |= try bit_reader.readBits(3) << (33 - 3);
    _ = try bit_reader.readBits(1);

    const bits = try bit_reader.readBits(15);

    data.system_clock_reference |= bits << (33 - 3 - 15);
    _ = try bit_reader.readBits(1);

    data.system_clock_reference |= try bit_reader.readBits(15);

    if (debug) std.debug.print("system_clock_reference {} || ", .{data.system_clock_reference});

    _ = try bit_reader.readBits(2);
    data.mux_rate = try bit_reader.readBits(22);
    if (debug) std.log.debug("mux_rate {}", .{data.mux_rate});

    _ = try bit_reader.readBits(1);

    // should be byte aligned now
    std.debug.assert(bit_reader.bit_buffer == 0 and bit_reader.bit_count == 0);
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
            if (codeenum == start_codes.pack_start) {
                // std.log.debug(" {X}", .{code});
                try processPack(&global_mpeg, &bit_reader);
            } else if (codeenum == start_codes.system_header_start) {
                std.log.debug("{X}", .{code});
                try processSystemHeader(&global_mpeg, &bit_reader);
            } else if (codeenum == start_codes.padding_stream) {
                std.log.debug("Padding stream, breaking loop", .{});
                break;
            } else {
                // std.log.debug("Unknown start {X}", .{code});
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
