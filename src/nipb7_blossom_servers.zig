const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const blossom_server_list_kind: u32 = 10063;
pub const blob_sha256_hex_length: u8 = 64;

pub const BlossomError = error{
    InvalidServerListKind,
    MissingServerTag,
    InvalidServerTag,
    InvalidServerUrl,
    InvalidBlobUrl,
    InvalidBlobHash,
    InvalidBlobExtension,
    BufferTooSmall,
};

pub const BlossomServerListInfo = struct {
    server_urls: [][]const u8,
};

pub const BlobReference = struct {
    sha256: [32]u8,
    extension: ?[]const u8 = null,
};

pub const BuiltTag = struct {
    items: [2][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Extracts ordered Blossom servers from a kind-10063 event.
pub fn blossom_servers_extract(
    event: *const nip01_event.Event,
    out_server_urls: [][]const u8,
) BlossomError!BlossomServerListInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_server_urls.len <= limits.tags_max);

    if (event.kind != blossom_server_list_kind) return error.InvalidServerListKind;

    var server_count: u16 = 0;
    for (event.tags) |tag| {
        if (tag.items.len == 0) continue;
        if (!std.mem.eql(u8, tag.items[0], "server")) continue;
        try parse_server_tag(tag, out_server_urls, &server_count);
    }
    if (server_count == 0) return error.MissingServerTag;
    return .{ .server_urls = out_server_urls[0..server_count] };
}

/// Builds a canonical Blossom `server` tag.
pub fn blossom_build_server_tag(
    output: *BuiltTag,
    server_url: []const u8,
) BlossomError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);

    if (server_url.len > limits.tag_item_bytes_max) return error.InvalidServerUrl;
    std.debug.assert(server_url.len <= limits.tag_item_bytes_max);
    output.items[0] = "server";
    output.items[1] = write_canonical_server_url(
        output.text_storage[0..],
        server_url,
    ) catch |err| switch (err) {
        error.InvalidUrl => return error.InvalidServerUrl,
        error.NoSpaceLeft => return error.BufferTooSmall,
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Extracts a deterministic blob hash and optional extension from a blob URL.
pub fn blossom_extract_blob_reference(blob_url: []const u8) BlossomError!BlobReference {
    if (blob_url.len > limits.content_bytes_max) return error.InvalidBlobUrl;
    std.debug.assert(blob_url.len <= limits.content_bytes_max);
    std.debug.assert(blob_sha256_hex_length == limits.id_hex_length);
    const parsed = parse_blob_url(blob_url) catch return error.InvalidBlobUrl;

    const path = blob_url[parsed.path_start..];
    const match = find_last_hash(path) orelse return error.InvalidBlobHash;
    const extension = try parse_blob_extension(path, match.end);
    return .{
        .sha256 = parse_hex_32(path[match.start..match.end]) catch return error.InvalidBlobHash,
        .extension = extension,
    };
}

/// Builds `<sha256>[.<ext>]` from a parsed blob reference.
pub fn blossom_build_fallback_path(
    output: []u8,
    reference: BlobReference,
) BlossomError![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(u16));
    std.debug.assert(reference.extension == null or reference.extension.?.len > 0);

    return write_blob_path(output, reference) catch return error.BufferTooSmall;
}

/// Builds a fallback blob URL on a Blossom server from a blob reference.
pub fn blossom_build_fallback_url(
    output: []u8,
    server_url: []const u8,
    reference: BlobReference,
) BlossomError![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(u16));

    if (server_url.len > limits.tag_item_bytes_max) return error.InvalidServerUrl;
    std.debug.assert(server_url.len <= limits.tag_item_bytes_max);
    const canonical = write_canonical_server_url(output, server_url) catch |err| switch (err) {
        error.InvalidUrl => return error.InvalidServerUrl,
        error.NoSpaceLeft => return error.BufferTooSmall,
    };
    var used = canonical.len;
    if (used >= output.len) return error.BufferTooSmall;
    output[used] = '/';
    used += 1;
    const path = write_blob_path(output[used..], reference) catch return error.BufferTooSmall;
    return output[0 .. used + path.len];
}

/// Builds a fallback blob URL by extracting the blob reference from a broken blob URL first.
pub fn blossom_build_fallback_url_for_blob(
    output: []u8,
    server_url: []const u8,
    blob_url: []const u8,
) BlossomError![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(u16));

    if (server_url.len > limits.tag_item_bytes_max) return error.InvalidServerUrl;
    std.debug.assert(server_url.len <= limits.tag_item_bytes_max);
    const reference = try blossom_extract_blob_reference(blob_url);
    return blossom_build_fallback_url(output, server_url, reference);
}

const HashRange = struct {
    start: usize,
    end: usize,
};

fn parse_server_tag(
    tag: nip01_event.EventTag,
    out_server_urls: [][]const u8,
    server_count: *u16,
) BlossomError!void {
    std.debug.assert(@intFromPtr(server_count) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len != 2) return error.InvalidServerTag;
    _ = parse_server_url(tag.items[1]) catch return error.InvalidServerTag;
    if (server_count.* >= out_server_urls.len) return error.BufferTooSmall;
    out_server_urls[server_count.*] = tag.items[1];
    server_count.* += 1;
}

fn parse_server_url(url: []const u8) error{InvalidUrl}!void {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (url.len > limits.tag_item_bytes_max) return error.InvalidUrl;
    std.debug.assert(url.len <= limits.tag_item_bytes_max);
    const parsed = parse_http_url(url, limits.tag_item_bytes_max) catch return error.InvalidUrl;
    if (parsed.path_start == url.len) return;
    const path = url[parsed.path_start..];
    if (!server_path_is_valid(path)) return error.InvalidUrl;
}

fn parse_blob_url(url: []const u8) error{InvalidUrl}!ParsedHttpUrl {
    std.debug.assert(limits.content_bytes_max >= limits.tag_item_bytes_max);

    if (url.len > limits.content_bytes_max) return error.InvalidUrl;
    std.debug.assert(url.len <= limits.content_bytes_max);
    const parsed = parse_http_url(url, limits.content_bytes_max) catch return error.InvalidUrl;
    if (parsed.path_start == url.len) return error.InvalidUrl;
    if (!path_is_valid(url[parsed.path_start..])) return error.InvalidUrl;
    return parsed;
}

const ParsedHttpUrl = struct {
    path_start: usize,
};

fn parse_http_url(url: []const u8, max_len: usize) error{InvalidUrl}!ParsedHttpUrl {
    std.debug.assert(max_len > 0);
    std.debug.assert(url.len <= max_len);

    if (url.len == 0) return error.InvalidUrl;
    const parsed = std.Uri.parse(url) catch return error.InvalidUrl;
    if (!scheme_is_http(parsed.scheme)) return error.InvalidUrl;
    if (parsed.user != null or parsed.password != null) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
    if (parsed.query != null or parsed.fragment != null) return error.InvalidUrl;
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return error.InvalidUrl;
    const authority_start = scheme_end + 3;
    if (authority_start >= url.len) return error.InvalidUrl;
    const authority_end = find_authority_end(url, authority_start);
    if (authority_end == authority_start) return error.InvalidUrl;
    if (std.mem.indexOfScalar(u8, url[authority_start..authority_end], '@') != null) {
        return error.InvalidUrl;
    }
    return .{ .path_start = authority_end };
}

fn write_canonical_server_url(
    output: []u8,
    server_url: []const u8,
) error{ InvalidUrl, NoSpaceLeft }![]const u8 {
    std.debug.assert(server_url.len <= limits.tag_item_bytes_max);
    std.debug.assert(output.len <= limits.tag_item_bytes_max);

    try parse_server_url(server_url);
    const canonical = trim_trailing_slash(server_url);
    if (canonical.len > output.len) return error.NoSpaceLeft;
    @memcpy(output[0..canonical.len], canonical);
    return output[0..canonical.len];
}

fn trim_trailing_slash(url: []const u8) []const u8 {
    std.debug.assert(url.len > 0);
    std.debug.assert(url.len <= limits.tag_item_bytes_max);

    const scheme_end = std.mem.indexOf(u8, url, "://").?;
    const authority_end = find_authority_end(url, scheme_end + 3);
    var end = url.len;
    while (end > authority_end and url[end - 1] == '/') : (end -= 1) {}
    return url[0..end];
}

fn find_authority_end(url: []const u8, authority_start: usize) usize {
    std.debug.assert(authority_start < url.len);
    std.debug.assert(url.len > 0);

    var index: usize = authority_start;
    while (index < url.len) : (index += 1) {
        const byte = url[index];
        if (byte == '/' or byte == '?' or byte == '#') return index;
    }
    return url.len;
}

fn path_is_valid(path: []const u8) bool {
    std.debug.assert(path.len > 0);
    std.debug.assert(path[0] == '/');

    var saw_segment = false;
    for (path) |byte| {
        if (byte == '?' or byte == '#') return false;
        if (byte != '/') saw_segment = true;
    }
    return saw_segment;
}

fn server_path_is_valid(path: []const u8) bool {
    std.debug.assert(path.len > 0);
    std.debug.assert(path[0] == '/');

    if (std.mem.eql(u8, path, "/")) return true;
    return path_is_valid(path);
}

fn scheme_is_http(scheme: []const u8) bool {
    std.debug.assert(scheme.len > 0);
    std.debug.assert(scheme.len <= 8);

    if (std.ascii.eqlIgnoreCase(scheme, "http")) return true;
    if (std.ascii.eqlIgnoreCase(scheme, "https")) return true;
    return false;
}

fn find_last_hash(url: []const u8) ?HashRange {
    std.debug.assert(url.len > 0);
    std.debug.assert(url.len <= limits.content_bytes_max);

    var result: ?HashRange = null;
    var index: usize = 0;
    while (index + blob_sha256_hex_length <= url.len) : (index += 1) {
        if (!hash_candidate_is_bounded(url, index)) continue;
        const end = index + blob_sha256_hex_length;
        if (end != url.len and url[end] != '.') continue;
        result = .{ .start = index, .end = end };
    }
    return result;
}

fn hash_candidate_is_bounded(url: []const u8, start: usize) bool {
    std.debug.assert(start + blob_sha256_hex_length <= url.len);
    std.debug.assert(blob_sha256_hex_length == 64);

    if (start > 0 and std.ascii.isHex(url[start - 1])) return false;
    for (url[start .. start + blob_sha256_hex_length]) |byte| {
        if (!std.ascii.isHex(byte)) return false;
    }
    if (start + blob_sha256_hex_length == url.len) return true;
    return !std.ascii.isHex(url[start + blob_sha256_hex_length]);
}

fn parse_blob_extension(url: []const u8, hash_end: usize) BlossomError!?[]const u8 {
    std.debug.assert(hash_end <= url.len);
    std.debug.assert(hash_end >= blob_sha256_hex_length);

    if (hash_end == url.len) return null;
    if (url[hash_end] != '.') return error.InvalidBlobHash;
    if (hash_end + 1 >= url.len) return error.InvalidBlobExtension;
    const extension = url[hash_end + 1 ..];
    if (!blob_extension_is_valid(extension)) return error.InvalidBlobExtension;
    return extension;
}

fn blob_extension_is_valid(extension: []const u8) bool {
    std.debug.assert(extension.len > 0);
    std.debug.assert(extension.len <= limits.content_bytes_max);

    if (extension.len > limits.tag_item_bytes_max) return false;
    if (!std.ascii.isAlphanumeric(extension[0])) return false;
    for (extension) |byte| {
        if (std.ascii.isAlphanumeric(byte)) continue;
        if (byte == '-' or byte == '_' or byte == '.') continue;
        return false;
    }
    return true;
}

fn parse_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(blob_sha256_hex_length == limits.id_hex_length);
    std.debug.assert(text.len <= limits.id_hex_length);

    var output: [32]u8 = undefined;
    if (text.len != blob_sha256_hex_length) return error.InvalidHex;
    _ = std.fmt.hexToBytes(output[0..], text) catch return error.InvalidHex;
    return output;
}

fn write_blob_path(
    output: []u8,
    reference: BlobReference,
) error{NoSpaceLeft}![]const u8 {
    std.debug.assert(output.len <= std.math.maxInt(u16));
    std.debug.assert(reference.extension == null or reference.extension.?.len > 0);

    const hash_hex = std.fmt.bytesToHex(reference.sha256, .lower);
    if (hash_hex.len > output.len) return error.NoSpaceLeft;
    @memcpy(output[0..hash_hex.len], hash_hex[0..]);
    var used = hash_hex.len;
    if (reference.extension) |extension| {
        if (used + 1 + extension.len > output.len) return error.NoSpaceLeft;
        output[used] = '.';
        used += 1;
        @memcpy(output[used .. used + extension.len], extension);
        used += extension.len;
    }
    return output[0..used];
}

fn test_event(tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(blossom_server_list_kind <= limits.kind_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0xb7} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = blossom_server_list_kind,
        .created_at = 1_700_000_000,
        .content = "",
        .tags = tags,
    };
}

test "blossom server extract preserves ordered server tags" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "server", "https://cdn.self.hosted" } },
        .{ .items = &.{ "t", "ignored" } },
        .{ .items = &.{ "server", "http://127.0.0.1:24242/cache" } },
    };
    var servers: [2][]const u8 = undefined;

    const parsed = try blossom_servers_extract(&test_event(tags[0..]), servers[0..]);

    try std.testing.expectEqual(@as(usize, 2), parsed.server_urls.len);
    try std.testing.expectEqualStrings("https://cdn.self.hosted", parsed.server_urls[0]);
    try std.testing.expectEqualStrings("http://127.0.0.1:24242/cache", parsed.server_urls[1]);
}

test "blossom server extract rejects malformed server list boundaries" {
    const invalid_tag_items = [_]nip01_event.EventTag{
        .{ .items = &.{ "server", "https://cdn.example.com", "extra" } },
    };
    const invalid_url = [_]nip01_event.EventTag{
        .{ .items = &.{ "server", "wss://relay.example.com" } },
    };
    const missing_server = [_]nip01_event.EventTag{
        .{ .items = &.{ "t", "ignored" } },
    };
    var servers: [1][]const u8 = undefined;
    var wrong_kind = test_event(invalid_url[0..]);
    wrong_kind.kind = 1;

    try std.testing.expectError(
        error.InvalidServerTag,
        blossom_servers_extract(&test_event(invalid_tag_items[0..]), servers[0..]),
    );
    try std.testing.expectError(
        error.InvalidServerTag,
        blossom_servers_extract(&test_event(invalid_url[0..]), servers[0..]),
    );
    try std.testing.expectError(
        error.MissingServerTag,
        blossom_servers_extract(&test_event(missing_server[0..]), servers[0..]),
    );
    try std.testing.expectError(
        error.InvalidServerListKind,
        blossom_servers_extract(&wrong_kind, servers[0..]),
    );
}

test "blossom server extract reports output capacity separately from invalid input" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "server", "https://cdn.one.example" } },
        .{ .items = &.{ "server", "https://cdn.two.example" } },
    };
    var servers: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.BufferTooSmall,
        blossom_servers_extract(&test_event(tags[0..]), servers[0..]),
    );
}

test "blossom server builder canonicalizes and round-trips" {
    var built_tag: BuiltTag = .{};
    var servers: [1][]const u8 = undefined;
    const tag = try blossom_build_server_tag(&built_tag, "https://cdn.example.com/base/");
    const tags = [_]nip01_event.EventTag{tag};

    const parsed = try blossom_servers_extract(&test_event(tags[0..]), servers[0..]);

    try std.testing.expectEqualStrings("server", tag.items[0]);
    try std.testing.expectEqualStrings("https://cdn.example.com/base", tag.items[1]);
    try std.testing.expectEqualStrings("https://cdn.example.com/base", parsed.server_urls[0]);
}

test "blossom blob reference uses the last bounded hash occurrence" {
    const reference = try blossom_extract_blob_reference(
        "https://cdn.example.com/user/" ++ "ec4425ff5e9446080d2f70440188e3ca5d6da8713db7bdeef73d0ed54d9093f0/media/" ++ "B1674191A88EC5CDD733E4240A81803105DC412D6C6708D53AB94FC248F4F553.PDF",
    );
    var path_output: [96]u8 = undefined;
    const path = try blossom_build_fallback_path(path_output[0..], reference);

    try std.testing.expectEqualStrings("PDF", reference.extension.?);
    try std.testing.expectEqualStrings(
        "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553.PDF",
        path,
    );
}

test "blossom fallback url builder joins canonical server and blob path" {
    const reference = try blossom_extract_blob_reference(
        "http://download.example.com/downloads/" ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553",
    );
    var url_output: [160]u8 = undefined;
    const fallback = try blossom_build_fallback_url(
        url_output[0..],
        "https://blossom.self.hosted/",
        reference,
    );

    try std.testing.expectEqualStrings(
        "https://blossom.self.hosted/" ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553",
        fallback,
    );
}

test "blossom fallback rejects malformed blob references and server urls" {
    var url_output: [96]u8 = undefined;

    try std.testing.expectError(
        error.InvalidBlobHash,
        blossom_extract_blob_reference("https://cdn.example.com/path/no-hash-here"),
    );
    try std.testing.expectError(
        error.InvalidBlobExtension,
        blossom_extract_blob_reference(
            "https://cdn.example.com/" ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553.",
        ),
    );
    try std.testing.expectError(
        error.InvalidBlobUrl,
        blossom_extract_blob_reference(
            "https://cdn.example.com/" ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553" ++ "?download=1",
        ),
    );
    try std.testing.expectError(
        error.InvalidServerUrl,
        blossom_build_fallback_url_for_blob(
            url_output[0..],
            "https://blossom.example.com?x=1",
            "https://cdn.example.com/" ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553.pdf",
        ),
    );
}

test "blossom fallback keeps capacity failures typed" {
    const reference = try blossom_extract_blob_reference(
        "https://cdn.example.com/" ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553.pdf",
    );
    var tiny_output: [8]u8 = undefined;

    try std.testing.expectError(
        error.BufferTooSmall,
        blossom_build_fallback_path(tiny_output[0..], reference),
    );
    try std.testing.expectError(
        error.BufferTooSmall,
        blossom_build_fallback_url(
            tiny_output[0..],
            "https://blossom.self.hosted",
            reference,
        ),
    );
}

test "blossom blob reference ignores hash-like host labels" {
    try std.testing.expectError(
        error.InvalidBlobHash,
        blossom_extract_blob_reference(
            "https://b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553" ++ ".example.com/file.pdf",
        ),
    );
}

test "blossom public boundaries keep oversized inputs typed" {
    var overlong_server: [limits.tag_item_bytes_max + 8]u8 = undefined;
    var overlong_blob: [limits.content_bytes_max + 8]u8 = undefined;
    @memset(overlong_server[0..], 'a');
    @memset(overlong_blob[0..], 'a');
    @memcpy(overlong_server[0..8], "https://");
    @memcpy(overlong_blob[0..8], "https://");

    var built_tag: BuiltTag = .{};
    var output: [96]u8 = undefined;

    try std.testing.expectError(
        error.InvalidServerUrl,
        blossom_build_server_tag(&built_tag, overlong_server[0..]),
    );
    try std.testing.expectError(
        error.InvalidBlobUrl,
        blossom_extract_blob_reference(overlong_blob[0..]),
    );
    try std.testing.expectError(
        error.InvalidServerUrl,
        blossom_build_fallback_url_for_blob(
            output[0..],
            overlong_server[0..],
            "https://cdn.example.com/" ++ "b1674191a88ec5cdd733e4240a81803105dc412d6c6708d53ab94fc248f4f553.pdf",
        ),
    );
}
