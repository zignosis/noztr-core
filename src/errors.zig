const std = @import("std");

/// Shared typed boundary errors for strict default I0/I1 modules.
pub const EncodeError = error{ BufferTooSmall, ValueOutOfRange };

/// Phase D contract-aligned parse errors for NIP-01 events.
pub const EventParseError = error{
    InputTooShort,
    InputTooLong,
    InvalidJson,
    InvalidField,
    InvalidHex,
    InvalidUtf8,
    DuplicateField,
    TooManyTags,
    TooManyTagItems,
    TagItemTooLong,
};

/// Phase D contract-aligned verify errors for NIP-01 events.
pub const EventVerifyError = error{ InvalidId, InvalidSignature, InvalidPubkey };

/// Phase D contract-aligned parse errors for NIP-01 filters.
pub const FilterParseError = error{
    InputTooLong,
    InvalidFilter,
    InvalidHex,
    InvalidTagKey,
    TooManyIds,
    TooManyAuthors,
    TooManyKinds,
    TooManyTagValues,
    InvalidTimeWindow,
    ValueOutOfRange,
};

fn force_event_verify_error(fail: bool) EventVerifyError!void {
    std.debug.assert(fail);
    std.debug.assert(!@inComptime());

    if (fail) {
        return error.InvalidSignature;
    }

    return;
}

fn force_filter_parse_error(fail: bool) FilterParseError!void {
    std.debug.assert(fail);
    std.debug.assert(!@inComptime());

    if (fail) {
        return error.InvalidTagKey;
    }

    return;
}

test "typed event verify errors are forceable" {
    try std.testing.expectError(error.InvalidSignature, force_event_verify_error(true));
}

test "typed filter parse errors are forceable" {
    try std.testing.expectError(error.InvalidTagKey, force_filter_parse_error(true));
}

test "encode error variants stay explicit" {
    try std.testing.expect(@typeInfo(EncodeError).error_set != null);
    try std.testing.expect(@typeInfo(EventParseError).error_set != null);
}
