const std = @import("std");
const noztr = @import("noztr");

test "NIP-73 example: parse external ids and build canonical i tags" {
    const external_id = try noztr.nip73_external_ids.external_id_parse(
        "https://example.com/article",
        null,
    );
    var built: noztr.nip73_external_ids.BuiltTag = .{};
    const tag = try noztr.nip73_external_ids.external_id_build_i_tag(&built, &external_id);

    try std.testing.expect(external_id.kind == .web);
    try std.testing.expectEqualStrings("i", tag.items[0]);
}
