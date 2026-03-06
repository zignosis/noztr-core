const std = @import("std");

/// Strict-by-default shared limits used by v1 module contracts.
pub const limits = @import("limits.zig");

/// Strict-by-default typed errors used by v1 module contracts.
pub const errors = @import("errors.zig");

/// Phase I1 concrete export for the NIP-01 event module.
pub const nip01_event = @import("nip01_event.zig");

/// Phase I1 concrete export for the NIP-01 filter module.
pub const nip01_filter = @import("nip01_filter.zig");

/// Phase I2 concrete export for the NIP-01 message module.
pub const nip01_message = @import("nip01_message.zig");

/// Phase I2 concrete export for the NIP-42 auth module.
pub const nip42_auth = @import("nip42_auth.zig");

/// Phase I2 concrete export for the NIP-70 protected-event module.
pub const nip70_protected = @import("nip70_protected.zig");

/// Phase I2 concrete export for the NIP-11 relay information module.
pub const nip11 = @import("nip11.zig");

/// Phase I3 concrete export for the NIP-09 deletion module.
pub const nip09_delete = @import("nip09_delete.zig");

/// Phase I3 concrete export for the NIP-40 expiration module.
pub const nip40_expire = @import("nip40_expire.zig");

/// Phase I3 concrete export for the NIP-13 proof-of-work module.
pub const nip13_pow = @import("nip13_pow.zig");

fn use_typed_error_for_smoke(fail: bool) errors.EventVerifyError!void {
    std.debug.assert(fail);
    std.debug.assert(!@inComptime());

    if (fail) {
        return error.InvalidId;
    }

    return;
}

test "root exports limits and error namespaces" {
    try std.testing.expect(limits.event_json_max >= limits.content_bytes_max);
    try std.testing.expect(@TypeOf(nip01_event.EventParseError) == type);
    try std.testing.expect(@TypeOf(nip01_filter.FilterParseError) == type);
    try std.testing.expect(@TypeOf(nip01_message.MessageParseError) == type);
    try std.testing.expect(@TypeOf(nip42_auth.AuthError) == type);
    try std.testing.expect(@TypeOf(nip70_protected.ProtectedError) == type);
    try std.testing.expect(@TypeOf(nip11.Nip11Error) == type);
    try std.testing.expect(@TypeOf(nip09_delete.DeleteError) == type);
    try std.testing.expect(@TypeOf(nip40_expire.ExpirationError) == type);
    try std.testing.expect(@TypeOf(nip13_pow.PowError) == type);
}

test "root smoke test uses typed errors" {
    try std.testing.expectError(error.InvalidId, use_typed_error_for_smoke(true));
}
