const std = @import("std");
const noztr = @import("noztr");
const common = @import("common.zig");

test "NIP-99 example: extract classified listing metadata" {
    var price_tag: noztr.nip99_classified_listings.TagBuilder = .{};
    var status_tag: noztr.nip99_classified_listings.TagBuilder = .{};
    const built_price = try noztr.nip99_classified_listings.build_price_tag(
        &price_tag,
        &.{ .amount = "500", .currency = "EUR", .frequency = null },
    );
    const built_status = try noztr.nip99_classified_listings.build_status_tag(
        &status_tag,
        .active,
    );
    const tags = [_]noztr.nip01_event.EventTag{
        .{ .items = &.{ "d", "alice.blog/post" } },
        .{ .items = &.{ "title", "Road bike" } },
        .{ .items = &.{ "price", "500", "EUR" } },
        .{ .items = &.{ "image", "https://example.com/bike.jpg", "800x600" } },
    };
    const event = common.simple_event(30402, [_]u8{0x99} ** 32, "bike details", tags[0..]);
    var images: [2]noztr.nip99_classified_listings.Image = undefined;
    var hashtags: [1][]const u8 = undefined;

    const parsed = try noztr.nip99_classified_listings.extract(
        &event,
        images[0..],
        hashtags[0..],
    );

    try std.testing.expectEqualStrings("price", built_price.items[0]);
    try std.testing.expectEqualStrings("status", built_status.items[0]);
    try std.testing.expectEqualStrings("alice.blog/post", parsed.identifier);
    try std.testing.expectEqualStrings("Road bike", parsed.title.?);
    try std.testing.expectEqualStrings("500", parsed.price.?.amount);
    try std.testing.expectEqualStrings("https://example.com/bike.jpg", images[0].url);
}
