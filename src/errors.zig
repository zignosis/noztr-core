const std = @import("std");

/// Shared typed boundary errors for strict default I0/I1 modules.
pub const EncodeError = error{ BufferTooSmall, ValueOutOfRange };

/// Phase D contract-aligned parse errors for NIP-01 events.
pub const EventParseError = error{
    InputTooShort,
    InputTooLong,
    OutOfMemory,
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
pub const EventVerifyError = error{
    InvalidId,
    InvalidSignature,
    InvalidPubkey,
    BackendUnavailable,
};

/// Phase D contract-aligned parse errors for NIP-01 filters.
pub const FilterParseError = error{
    InputTooLong,
    OutOfMemory,
    InvalidFilter,
    InvalidHex,
    InvalidTagKey,
    TooManyTagKeys,
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

fn force_event_verify_backend_unavailable(fail: bool) EventVerifyError!void {
    std.debug.assert(fail);
    std.debug.assert(!@inComptime());

    if (fail) {
        return error.BackendUnavailable;
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

fn force_filter_parse_capacity_error(fail: bool) FilterParseError!void {
    std.debug.assert(fail);
    std.debug.assert(!@inComptime());

    if (fail) {
        return error.TooManyTagKeys;
    }

    return;
}

fn force_filter_parse_resource_error(fail: bool) FilterParseError!void {
    std.debug.assert(fail);
    std.debug.assert(!@inComptime());

    if (fail) {
        return error.OutOfMemory;
    }

    return;
}

test "typed event verify errors are forceable" {
    try std.testing.expectError(error.InvalidSignature, force_event_verify_error(true));
    try std.testing.expectError(
        error.BackendUnavailable,
        force_event_verify_backend_unavailable(true),
    );
}

test "typed filter parse errors are forceable" {
    try std.testing.expectError(error.InvalidTagKey, force_filter_parse_error(true));
    try std.testing.expectError(error.TooManyTagKeys, force_filter_parse_capacity_error(true));
    try std.testing.expectError(error.OutOfMemory, force_filter_parse_resource_error(true));
}

test "encode error variants stay explicit" {
    try std.testing.expect(@typeInfo(EncodeError).error_set != null);
    try std.testing.expect(@typeInfo(EventParseError).error_set != null);
}
