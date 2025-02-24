const std = @import("std");

pub const bitReader = struct {
    const Self = @This();
    bit_buffer: u32 = 0,
    bit_count: u5 = 0,
    source: std.io.StreamSource, // this is kind of annoying, probably want an internal type?

    pub fn peekBits(self: *Self, num_bits: u5) !u32 {
        try self.fillBits(num_bits);

        return (self.bit_buffer >> 1) >> (31 - num_bits);
    }

    pub fn fillBits(self: *Self, num_bits: u5) !void {
        std.debug.assert(num_bits <= 24);
        var reader = self.source.reader();

        while (self.bit_count < num_bits) {
            const byte_curr: u32 = try reader.readByte();

            self.bit_buffer |= byte_curr << (24 - self.bit_count);
            self.bit_count += 8;
        }
    }

    pub fn consumeBits(self: *Self, num_bits: u5) void {
        std.debug.assert(num_bits <= self.bit_count);

        self.bit_buffer <<= num_bits;
        self.bit_count -= num_bits;
    }

    pub fn readBits(self: *Self, num_bits: u5) !u32 {
        const bits: u32 = try peekBits(self, num_bits);
        consumeBits(self, num_bits);
        return bits;
    }

    pub fn flushBits(self: *Self) void {
        self.bit_buffer = 0;
        self.bit_count = 0;
    }
};
