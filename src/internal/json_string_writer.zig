const std = @import("std");

pub const ControlBytes = enum {
    reject,
    escape,
};

pub fn write_string_json(
    writer: anytype,
    value: []const u8,
    control_bytes: ControlBytes,
) error{BufferTooSmall, InvalidControlByte}!void {
    try write_byte(writer, '"');
    for (value) |byte| {
        if (byte == '"' or byte == '\\') {
            try write_escape(writer, byte);
            continue;
        }
        if (byte == '\n') {
            try write_escape(writer, 'n');
            continue;
        }
        if (byte == '\r') {
            try write_escape(writer, 'r');
            continue;
        }
        if (byte == '\t') {
            try write_escape(writer, 't');
            continue;
        }
        if (byte < 0x20) {
            switch (control_bytes) {
                .reject => return error.InvalidControlByte,
                .escape => try write_control_escape(writer, byte),
            }
            continue;
        }
        try write_byte(writer, byte);
    }
    try write_byte(writer, '"');
}

pub fn write_escape(writer: anytype, escape_byte: u8) error{BufferTooSmall}!void {
    try write_byte(writer, '\\');
    try write_byte(writer, escape_byte);
}

pub fn write_control_escape(writer: anytype, byte: u8) error{BufferTooSmall}!void {
    const hex = "0123456789abcdef";

    try write_byte(writer, '\\');
    try write_byte(writer, 'u');
    try write_byte(writer, '0');
    try write_byte(writer, '0');
    try write_byte(writer, hex[byte >> 4]);
    try write_byte(writer, hex[byte & 0x0f]);
}

pub fn write_byte(writer: anytype, byte: u8) error{BufferTooSmall}!void {
    writer.writeByte(byte) catch return error.BufferTooSmall;
}

test "json string writer rejects control bytes when configured" {
    var buffer: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try std.testing.expectError(
        error.InvalidControlByte,
        write_string_json(stream.writer(), &[_]u8{ 0x01 }, .reject),
    );
}

test "json string writer escapes control bytes when configured" {
    var buffer: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try write_string_json(stream.writer(), &[_]u8{ 0x01 }, .escape);
    try std.testing.expectEqualStrings("\"\\u0001\"", buffer[0..stream.pos]);
}
