const std = @import("std");
const vlc = @import("variable_length_codes.zig");

pub const Channel = struct {
    width: u32 = 0,
    height: u32 = 0,
    data: []i32 = undefined,
};

pub const Frame = struct {
    width: u32 = 0,
    height: u32 = 0,
    y: Channel = .{},
    cr: Channel = .{},
    cb: Channel = .{},
};

pub const Packet = struct {
    // packet
    packet_stream_id: u8,
    packet_length: u16,
    std_buffer_scale: u1,
    std_buffer_size: u13,
    presentation_time_stamp: u33,
    decoding_time_stamp: u33,
    data: []u8,
};

pub const mpeg = struct {
    frame: Frame = .{},
    allocator: std.mem.Allocator = undefined,

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

    video_packets: [1024]Packet,
    current_packet: u16,
    video_buffer: [2048 * 277]u8,
    current_byte: u32,

    current_macroblock: u32,
    dc_prev: [3]i32,

    // sequence header

    horizontal_size: u32,
    vertical_size: u32,
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
    mb_intra: u16,

    // stream
    stream: *std.io.StreamSource,

    map: vlc.CodeMap,
};
