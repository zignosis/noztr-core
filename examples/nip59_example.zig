const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-59 example: invalid outer kind is a typed boundary failure" {
    var event = common.simple_event(1, [_]u8{0x59} ** 32, "payload", &.{});
    try common.finalize_event_id(&event);

    try std.testing.expectError(
        error.InvalidWrapKind,
        noztr.nip59_wrap.validate_wrap_structure(&event),
    );
}
