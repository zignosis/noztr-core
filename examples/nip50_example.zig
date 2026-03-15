const std = @import("std");
const noztr = @import("noztr");

test "NIP-50 example: extract supported strict extension tokens" {
    var tokens: [2]noztr.nip50_search.SearchToken = undefined;
    const count = try noztr.nip50_search.search_tokens_parse(
        "hello include:spam domain:nostr.com",
        tokens[0..],
    );

    try std.testing.expectEqual(@as(u16, 2), count);
    try std.testing.expect(tokens[0].key == .include);
}
