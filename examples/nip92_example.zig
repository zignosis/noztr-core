const std = @import("std");
const noztr = @import("noztr");

test "NIP-92 example: extract imeta and match it against content" {
    var url_field: noztr.nip92_media_attachments.BuiltField = .{};
    var mime_field: noztr.nip92_media_attachments.BuiltField = .{};
    var hash_field: noztr.nip92_media_attachments.BuiltField = .{};
    var built_tag_storage: noztr.nip92_media_attachments.BuiltTag = .{};
    const built_tag = try noztr.nip92_media_attachments.imeta_build_tag(
        &built_tag_storage,
        &.{
            try noztr.nip92_media_attachments.imeta_build_field(
                &url_field,
                "url",
                "https://example.com/cat.jpg",
            ),
            try noztr.nip92_media_attachments.imeta_build_field(&mime_field, "m", "image/jpeg"),
            try noztr.nip92_media_attachments.imeta_build_field(
                &hash_field,
                "x",
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            ),
        },
    );
    const tag = noztr.nip01_event.EventTag{
        .items = &.{
            "imeta",
            "url https://example.com/cat.jpg",
            "m image/jpeg",
            "x aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "alt cat on a wall",
        },
    };
    var fallbacks: [0][]const u8 = .{};

    const parsed = try noztr.nip92_media_attachments.imeta_extract(tag, fallbacks[0..]);
    const matches = noztr.nip92_media_attachments.imeta_matches_content(
        "see https://example.com/cat.jpg now",
        &parsed,
    );

    try std.testing.expectEqualStrings("imeta", built_tag.items[0]);
    try std.testing.expectEqualStrings("url https://example.com/cat.jpg", built_tag.items[1]);
    try std.testing.expectEqualStrings("https://example.com/cat.jpg", parsed.url);
    try std.testing.expectEqualStrings("image/jpeg", parsed.mime_type.?);
    try std.testing.expect(matches);
}
