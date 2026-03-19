const std = @import("std");
const noztr = @import("noztr");

test "adversarial NIP-89 example: malformed client coordinate stays typed" {
    var built: noztr.nip89_handlers.BuiltTag = .{};

    try std.testing.expectError(
        error.InvalidClientTag,
        noztr.nip89_handlers.client_build_tag(&built, "My Client", "31990:broken", null),
    );
}
