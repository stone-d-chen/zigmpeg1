const std = @import("std");

pub const bitReader = struct {
    const Self = @This();
    bit_buffer: u64 = 0,
    bit_count: u6 = 0,
    source: std.io.StreamSource, // this is kind of annoying, probably want an internal type?

    pub fn peekBits(self: *Self, num_bits: u6) !u64 {
        try self.fillBits(num_bits);

        return (self.bit_buffer >> 1) >> (63 - num_bits);
    }

    pub fn fillBits(self: *Self, num_bits: u6) !void {
        // std.debug.assert(num_bits <= 24);
        var reader = self.source.reader();

        while (self.bit_count < num_bits) {
            const byte_curr: u64 = try reader.readByte();

            self.bit_buffer |= byte_curr << (56 - self.bit_count);
            self.bit_count += 8;
        }
    }

    pub fn consumeBits(self: *Self, num_bits: u6) void {
        std.debug.assert(num_bits <= self.bit_count);

        self.bit_buffer <<= num_bits;
        self.bit_count -= num_bits;
    }

    pub fn readBits(self: *Self, num_bits: u6) !u64 {
        const bits: u64 = try peekBits(self, num_bits);
        consumeBits(self, num_bits);
        return bits;
    }

    pub fn flushBits(self: *Self) void {
        self.bit_buffer = 0;
        self.bit_count = 0;
    }

    pub fn readBits31515(self: *Self) !u33 {
        var result: u33 = 0;

        result |= @intCast(try self.readBits(3) << (33 - 3));
        _ = try self.readBits(1);

        result |= @intCast((try self.readBits(15)) << (33 - 3 - 15));
        _ = try self.readBits(1);

        result |= @intCast(try self.readBits(15));
        _ = try self.readBits(1);

        return result;
    }
};
