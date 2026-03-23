const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-54 example: extract wiki article metadata and normalize identifiers" {
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "nostr-wiki" } },
        .{ .items = &.{ "title", "Nostr Wiki" } },
        .{ .items = &.{ "summary", "shared notes" } },
        .{ .items = &.{
            "a",
            "30818:1111111111111111111111111111111111111111111111111111111111111111:nostr-wiki",
            "wss://relay.example.com",
            "fork",
        } },
    };
    const event = common.simple_event(
        noztr.nip54_wiki.wiki_article_kind,
        [_]u8{0x54} ** 32,
        "article body",
        tags[0..],
    );
    var forks: [1]noztr.nip54_wiki.ArticleRef = undefined;
    var defers: [0]noztr.nip54_wiki.ArticleRef = .{};
    var normalized_storage: [64]u8 = undefined;

    const info = try noztr.nip54_wiki.wiki_article_extract(&event, forks[0..], defers[0..]);
    const normalized = try noztr.nip54_wiki.wiki_normalize_identifier_ascii(
        normalized_storage[0..],
        "Nostr Wiki Start",
    );

    try std.testing.expectEqualStrings("nostr-wiki", info.identifier);
    try std.testing.expectEqualStrings("Nostr Wiki", info.title.?);
    try std.testing.expectEqual(@as(u16, 1), info.fork_count);
    try std.testing.expectEqualStrings("nostr-wiki-start", normalized);
}
