const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const code_snippet_kind: u32 = 1337;
pub const repo_announcement_kind: u32 = 30617;

pub const CodeSnippetError = error{
    UnsupportedKind,
    DuplicateLanguageTag,
    InvalidLanguageTag,
    DuplicateNameTag,
    InvalidNameTag,
    DuplicateExtensionTag,
    InvalidExtensionTag,
    DuplicateDescriptionTag,
    InvalidDescriptionTag,
    DuplicateRuntimeTag,
    InvalidRuntimeTag,
    DuplicateRepoTag,
    InvalidRepoTag,
    InvalidLicenseTag,
    InvalidDependencyTag,
    InvalidContent,
    BufferTooSmall,
};

pub const LicenseInfo = struct {
    identifier: []const u8,
    text_reference: ?[]const u8 = null,
};

pub const RepoCoordinate = struct {
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
};

pub const RepoReference = union(enum) {
    url: []const u8,
    coordinate: RepoCoordinate,
};

pub const CodeSnippetInfo = struct {
    content: []const u8,
    language: ?[]const u8 = null,
    name: ?[]const u8 = null,
    extension: ?[]const u8 = null,
    description: ?[]const u8 = null,
    runtime: ?[]const u8 = null,
    repo: ?RepoReference = null,
    license_count: u16 = 0,
    dependency_count: u16 = 0,
};

pub const BuiltTag = struct {
    items: [3][]const u8 = undefined,
    text_storage: [limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    /// Returns the built tag backed by this buffer.
    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

/// Returns whether the event kind is supported by the strict NIP-C0 helper.
pub fn code_snippet_is_supported(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= limits.kind_max);

    return event.kind == code_snippet_kind;
}

/// Extracts bounded NIP-C0 metadata plus ordered licenses and dependencies.
pub fn code_snippet_extract(
    event: *const nip01_event.Event,
    out_licenses: []LicenseInfo,
    out_dependencies: [][]const u8,
) CodeSnippetError!CodeSnippetInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_licenses.len <= std.math.maxInt(u16));
    std.debug.assert(out_dependencies.len <= std.math.maxInt(u16));

    if (event.kind != code_snippet_kind) return error.UnsupportedKind;
    try validate_content(event.content);

    var info = CodeSnippetInfo{ .content = event.content };
    for (event.tags) |tag| {
        try apply_tag(tag, &info, out_licenses, out_dependencies);
    }
    return info;
}

/// Builds a canonical `l` language tag.
pub fn code_snippet_build_language_tag(
    output: *BuiltTag,
    language: []const u8,
) CodeSnippetError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.text_storage.len == limits.tag_item_bytes_max);

    output.items[0] = "l";
    output.items[1] = lowercase_language(output.text_storage[0..], language) catch {
        return error.InvalidLanguageTag;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

/// Builds a canonical `name` tag.
pub fn code_snippet_build_name_tag(
    output: *BuiltTag,
    name: []const u8,
) CodeSnippetError!nip01_event.EventTag {
    return build_text_tag(output, "name", name, error.InvalidNameTag);
}

/// Builds a canonical `extension` tag.
pub fn code_snippet_build_extension_tag(
    output: *BuiltTag,
    extension: []const u8,
) CodeSnippetError!nip01_event.EventTag {
    return build_text_tag(output, "extension", extension, error.InvalidExtensionTag);
}

/// Builds a canonical `description` tag.
pub fn code_snippet_build_description_tag(
    output: *BuiltTag,
    description: []const u8,
) CodeSnippetError!nip01_event.EventTag {
    return build_text_tag(output, "description", description, error.InvalidDescriptionTag);
}

/// Builds a canonical `runtime` tag.
pub fn code_snippet_build_runtime_tag(
    output: *BuiltTag,
    runtime: []const u8,
) CodeSnippetError!nip01_event.EventTag {
    return build_text_tag(output, "runtime", runtime, error.InvalidRuntimeTag);
}

/// Builds a canonical `license` tag with an optional reference.
pub fn code_snippet_build_license_tag(
    output: *BuiltTag,
    license: LicenseInfo,
) CodeSnippetError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len >= 3);

    output.items[0] = "license";
    output.items[1] = parse_nonempty_utf8(license.identifier) catch return error.InvalidLicenseTag;
    output.item_count = 2;
    if (license.text_reference) |text_reference| {
        output.items[2] = parse_nonempty_utf8(text_reference) catch {
            return error.InvalidLicenseTag;
        };
        output.item_count = 3;
    }
    return output.as_event_tag();
}

/// Builds a canonical `dep` tag.
pub fn code_snippet_build_dependency_tag(
    output: *BuiltTag,
    dependency: []const u8,
) CodeSnippetError!nip01_event.EventTag {
    return build_text_tag(output, "dep", dependency, error.InvalidDependencyTag);
}

/// Builds a canonical `repo` tag from either a URL or a NIP-34 repository coordinate.
pub fn code_snippet_build_repo_tag(
    output: *BuiltTag,
    repo: RepoReference,
) CodeSnippetError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(@sizeOf(RepoReference) > 0);

    output.items[0] = "repo";
    output.item_count = 2;
    switch (repo) {
        .url => |url| {
            output.items[1] = parse_url(url) catch return error.InvalidRepoTag;
        },
        .coordinate => |coordinate| {
            validate_repo_coordinate(coordinate) catch return error.InvalidRepoTag;
            output.items[1] = format_repo_coordinate(output.text_storage[0..], coordinate) catch {
                return error.BufferTooSmall;
            };
            if (coordinate.relay_hint) |relay_hint| {
                output.items[2] = parse_url(relay_hint) catch return error.InvalidRepoTag;
                output.item_count = 3;
            }
        },
    }
    return output.as_event_tag();
}

fn apply_tag(
    tag: nip01_event.EventTag,
    info: *CodeSnippetInfo,
    out_licenses: []LicenseInfo,
    out_dependencies: [][]const u8,
) CodeSnippetError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(out_licenses.len <= std.math.maxInt(u16));

    if (tag.items.len == 0) return;
    const name = tag.items[0];
    if (std.mem.eql(u8, name, "l")) {
        return apply_optional_text_tag(
            tag,
            &info.language,
            error.DuplicateLanguageTag,
            error.InvalidLanguageTag,
        );
    }
    if (std.mem.eql(u8, name, "name")) {
        return apply_optional_text_tag(
            tag,
            &info.name,
            error.DuplicateNameTag,
            error.InvalidNameTag,
        );
    }
    if (std.mem.eql(u8, name, "extension")) {
        return apply_optional_text_tag(
            tag,
            &info.extension,
            error.DuplicateExtensionTag,
            error.InvalidExtensionTag,
        );
    }
    if (std.mem.eql(u8, name, "description")) {
        return apply_optional_text_tag(
            tag,
            &info.description,
            error.DuplicateDescriptionTag,
            error.InvalidDescriptionTag,
        );
    }
    if (std.mem.eql(u8, name, "runtime")) {
        return apply_optional_text_tag(
            tag,
            &info.runtime,
            error.DuplicateRuntimeTag,
            error.InvalidRuntimeTag,
        );
    }
    if (std.mem.eql(u8, name, "repo")) return apply_repo_tag(tag, info);
    if (std.mem.eql(u8, name, "license")) return apply_license_tag(tag, info, out_licenses);
    if (std.mem.eql(u8, name, "dep")) return apply_dependency_tag(tag, info, out_dependencies);
}

fn apply_optional_text_tag(
    tag: nip01_event.EventTag,
    field: *?[]const u8,
    duplicate_error: CodeSnippetError,
    invalid_error: CodeSnippetError,
) CodeSnippetError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return duplicate_error;
    field.* = parse_single_utf8_value(tag) catch return invalid_error;
}

fn apply_repo_tag(tag: nip01_event.EventTag, info: *CodeSnippetInfo) CodeSnippetError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.repo != null) return error.DuplicateRepoTag;
    info.repo = parse_repo_tag(tag) catch return error.InvalidRepoTag;
}

fn apply_license_tag(
    tag: nip01_event.EventTag,
    info: *CodeSnippetInfo,
    out_licenses: []LicenseInfo,
) CodeSnippetError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    const license = parse_license_tag(tag) catch return error.InvalidLicenseTag;
    if (info.license_count == out_licenses.len) return error.BufferTooSmall;
    out_licenses[info.license_count] = license;
    info.license_count += 1;
}

fn apply_dependency_tag(
    tag: nip01_event.EventTag,
    info: *CodeSnippetInfo,
    out_dependencies: [][]const u8,
) CodeSnippetError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    const dependency = parse_single_utf8_value(tag) catch return error.InvalidDependencyTag;
    if (info.dependency_count == out_dependencies.len) return error.BufferTooSmall;
    out_dependencies[info.dependency_count] = dependency;
    info.dependency_count += 1;
}

fn build_text_tag(
    output: *BuiltTag,
    name: []const u8,
    value: []const u8,
    invalid_error: CodeSnippetError,
) CodeSnippetError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(name.len > 0);

    output.items[0] = name;
    output.items[1] = parse_nonempty_utf8(value) catch return invalid_error;
    output.item_count = 2;
    return output.as_event_tag();
}

fn lowercase_language(output: []u8, language: []const u8) error{InvalidLanguage}![]const u8 {
    std.debug.assert(output.len >= limits.tag_item_bytes_max);
    std.debug.assert(output.len <= limits.content_bytes_max);

    const parsed = parse_nonempty_utf8(language) catch return error.InvalidLanguage;
    if (parsed.len > output.len) return error.InvalidLanguage;
    for (parsed, 0..) |byte, index| {
        output[index] = std.ascii.toLower(byte);
    }
    return output[0..parsed.len];
}

fn parse_single_utf8_value(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_nonempty_utf8(tag.items[1]) catch return error.InvalidValue;
}

fn parse_license_tag(tag: nip01_event.EventTag) error{InvalidValue}!LicenseInfo {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 3);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidValue;
    const identifier = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidValue;
    var license = LicenseInfo{ .identifier = identifier };
    if (tag.items.len == 3) {
        license.text_reference = parse_nonempty_utf8(tag.items[2]) catch {
            return error.InvalidValue;
        };
    }
    return license;
}

fn parse_repo_tag(tag: nip01_event.EventTag) error{InvalidValue}!RepoReference {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 3);

    if (tag.items.len != 2 and tag.items.len != 3) return error.InvalidValue;
    const hint = if (tag.items.len == 3)
        parse_url(tag.items[2]) catch return error.InvalidValue
    else
        null;
    return parse_repo_reference(tag.items[1], hint) catch return error.InvalidValue;
}

fn parse_repo_reference(
    text: []const u8,
    relay_hint: ?[]const u8,
) error{InvalidValue}!RepoReference {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.content_bytes_max) return error.InvalidValue;
    if (parse_url(text)) |url| {
        if (relay_hint != null) return error.InvalidValue;
        return .{ .url = url };
    } else |_| {}
    var coordinate = parse_repo_coordinate(text) catch return error.InvalidValue;
    coordinate.relay_hint = relay_hint;
    return .{ .coordinate = coordinate };
}

fn parse_repo_coordinate(text: []const u8) error{InvalidCoordinate}!RepoCoordinate {
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (text.len > limits.content_bytes_max) return error.InvalidCoordinate;
    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse return error.InvalidCoordinate;
    if (first_colon == 0) return error.InvalidCoordinate;
    const second_search = text[first_colon + 1 ..];
    const second_rel = std.mem.indexOfScalar(u8, second_search, ':') orelse {
        return error.InvalidCoordinate;
    };
    const second_colon = first_colon + 1 + second_rel;
    if (second_colon == first_colon + 1) return error.InvalidCoordinate;
    if (std.mem.indexOfScalar(u8, text[second_colon + 1 ..], ':') != null) {
        return error.InvalidCoordinate;
    }
    const kind = std.fmt.parseUnsigned(u32, text[0..first_colon], 10) catch {
        return error.InvalidCoordinate;
    };
    const pubkey = parse_lower_hex_32(text[first_colon + 1 .. second_colon]) catch {
        return error.InvalidCoordinate;
    };
    const identifier = parse_nonempty_utf8(text[second_colon + 1 ..]) catch {
        return error.InvalidCoordinate;
    };
    if (kind != repo_announcement_kind) return error.InvalidCoordinate;
    return .{ .pubkey = pubkey, .identifier = identifier };
}

fn validate_repo_coordinate(coordinate: RepoCoordinate) error{InvalidCoordinate}!void {
    std.debug.assert(@sizeOf(RepoCoordinate) > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (coordinate.identifier.len == 0) return error.InvalidCoordinate;
    _ = parse_nonempty_utf8(coordinate.identifier) catch return error.InvalidCoordinate;
    if (coordinate.relay_hint) |relay_hint| {
        _ = parse_url(relay_hint) catch return error.InvalidCoordinate;
    }
}

fn format_repo_coordinate(
    output: []u8,
    coordinate: RepoCoordinate,
) error{BufferTooSmall}![]const u8 {
    std.debug.assert(output.len >= limits.pubkey_hex_length + 8);
    std.debug.assert(coordinate.identifier.len <= limits.tag_item_bytes_max);

    const pubkey_hex = std.fmt.bytesToHex(coordinate.pubkey, .lower);
    return std.fmt.bufPrint(
        output,
        "{d}:{s}:{s}",
        .{ repo_announcement_kind, pubkey_hex[0..], coordinate.identifier },
    ) catch return error.BufferTooSmall;
}

fn validate_content(content: []const u8) CodeSnippetError!void {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (content.len > limits.content_bytes_max) return error.InvalidContent;
    if (content.len == 0) return error.InvalidContent;
    if (!std.unicode.utf8ValidateSlice(content)) return error.InvalidContent;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.content_bytes_max) return error.InvalidUtf8;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.content_bytes_max) return error.InvalidUrl;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUrl;
    if (text.len == 0) return error.InvalidUrl;
    const parsed = std.Uri.parse(text) catch return error.InvalidUrl;
    if (parsed.scheme.len == 0) return error.InvalidUrl;
    if (parsed.host == null) return error.InvalidUrl;
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(limits.id_hex_length == 64);
    std.debug.assert(limits.pubkey_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn test_event(
    kind: u32,
    content: []const u8,
    tags: []const nip01_event.EventTag,
) nip01_event.Event {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = kind,
        .created_at = 1_700_000_000,
        .content = content,
        .tags = tags,
    };
}

test "code snippet extract parses metadata with repo url licenses and dependencies" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "l", "rust" } },
        .{ .items = &.{ "name", "hello.rs" } },
        .{ .items = &.{ "extension", "rs" } },
        .{ .items = &.{ "description", "prints hello" } },
        .{ .items = &.{ "runtime", "stable" } },
        .{ .items = &.{ "license", "MIT", "https://spdx.org/licenses/MIT.html" } },
        .{ .items = &.{ "license", "Apache-2.0" } },
        .{ .items = &.{ "dep", "std" } },
        .{ .items = &.{ "dep", "serde" } },
        .{ .items = &.{ "repo", "https://github.com/nostr-protocol/nips" } },
        .{ .items = &.{ "t", "ignored" } },
    };
    const event = test_event(code_snippet_kind, "pub fn main() void {}", tags[0..]);
    var licenses: [2]LicenseInfo = undefined;
    var dependencies: [2][]const u8 = undefined;

    const parsed = try code_snippet_extract(&event, licenses[0..], dependencies[0..]);

    try std.testing.expectEqualStrings("pub fn main() void {}", parsed.content);
    try std.testing.expectEqualStrings("rust", parsed.language.?);
    try std.testing.expectEqualStrings("hello.rs", parsed.name.?);
    try std.testing.expectEqualStrings("rs", parsed.extension.?);
    try std.testing.expectEqualStrings("prints hello", parsed.description.?);
    try std.testing.expectEqualStrings("stable", parsed.runtime.?);
    try std.testing.expectEqual(@as(u16, 2), parsed.license_count);
    try std.testing.expectEqual(@as(u16, 2), parsed.dependency_count);
    try std.testing.expectEqualStrings("MIT", licenses[0].identifier);
    try std.testing.expectEqualStrings(
        "https://spdx.org/licenses/MIT.html",
        licenses[0].text_reference.?,
    );
    try std.testing.expectEqualStrings("Apache-2.0", licenses[1].identifier);
    try std.testing.expect(licenses[1].text_reference == null);
    try std.testing.expectEqualStrings("std", dependencies[0]);
    try std.testing.expectEqualStrings("serde", dependencies[1]);
    switch (parsed.repo.?) {
        .url => |url| try std.testing.expectEqualStrings(
            "https://github.com/nostr-protocol/nips",
            url,
        ),
        .coordinate => unreachable,
    }
}

test "code snippet extract parses coordinate repo with optional relay hint" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{
            "repo",
            "30617:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:nostr",
            "wss://relay.example.com",
        } },
    };
    const event = test_event(code_snippet_kind, "fn main() {}", tags[0..]);
    var licenses: [1]LicenseInfo = undefined;
    var dependencies: [1][]const u8 = undefined;

    const parsed = try code_snippet_extract(&event, licenses[0..], dependencies[0..]);

    switch (parsed.repo.?) {
        .url => unreachable,
        .coordinate => |repo| {
            try std.testing.expectEqualStrings("nostr", repo.identifier);
            try std.testing.expectEqualStrings("wss://relay.example.com", repo.relay_hint.?);
            try std.testing.expect(repo.pubkey[0] == 0xaa);
        },
    }
}

test "code snippet builders emit canonical tag shapes" {
    var language_tag: BuiltTag = .{};
    var license_tag: BuiltTag = .{};
    var dependency_tag: BuiltTag = .{};
    var repo_tag: BuiltTag = .{};
    const repo = RepoReference{ .coordinate = .{
        .pubkey = [_]u8{0xbb} ** 32,
        .identifier = "nostr",
        .relay_hint = "wss://relay.example.com",
    } };

    const built_language = try code_snippet_build_language_tag(&language_tag, "zig");
    const built_license = try code_snippet_build_license_tag(&license_tag, .{
        .identifier = "MIT",
        .text_reference = "https://spdx.org/licenses/MIT.html",
    });
    const built_dependency = try code_snippet_build_dependency_tag(&dependency_tag, "std");
    const built_repo = try code_snippet_build_repo_tag(&repo_tag, repo);

    try std.testing.expectEqualStrings("l", built_language.items[0]);
    try std.testing.expectEqualStrings("zig", built_language.items[1]);
    try std.testing.expectEqualStrings("license", built_license.items[0]);
    try std.testing.expectEqualStrings("MIT", built_license.items[1]);
    try std.testing.expectEqualStrings("dep", built_dependency.items[0]);
    try std.testing.expectEqualStrings("std", built_dependency.items[1]);
    try std.testing.expectEqual(@as(usize, 3), built_repo.items.len);
    try std.testing.expectEqualStrings("repo", built_repo.items[0]);
    try std.testing.expectEqualStrings(
        "30617:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:nostr",
        built_repo.items[1],
    );
    try std.testing.expectEqualStrings("wss://relay.example.com", built_repo.items[2]);
}

test "code snippet language builder canonicalizes ascii uppercase" {
    var language_tag: BuiltTag = .{};

    const built_language = try code_snippet_build_language_tag(&language_tag, "Rust");

    try std.testing.expectEqualStrings("rust", built_language.items[1]);
    try std.testing.expect(!std.mem.eql(u8, built_language.items[1], "Rust"));
}

test "code snippet builder and parser stay symmetric for canonical metadata" {
    var name_tag: BuiltTag = .{};
    var license_tag: BuiltTag = .{};
    var repo_tag: BuiltTag = .{};
    const tags = [_]nip01_event.EventTag{
        try code_snippet_build_name_tag(&name_tag, "hello.zig"),
        try code_snippet_build_license_tag(&license_tag, .{ .identifier = "MIT" }),
        try code_snippet_build_repo_tag(&repo_tag, .{
            .url = "https://github.com/nostr-protocol/nips",
        }),
    };
    const event = test_event(code_snippet_kind, "const x = 1;", tags[0..]);
    var licenses: [1]LicenseInfo = undefined;
    var dependencies: [0][]const u8 = .{};

    const parsed = try code_snippet_extract(&event, licenses[0..], dependencies[0..]);

    try std.testing.expectEqualStrings("hello.zig", parsed.name.?);
    try std.testing.expectEqual(@as(u16, 1), parsed.license_count);
    try std.testing.expectEqualStrings("MIT", licenses[0].identifier);
    switch (parsed.repo.?) {
        .url => |url| try std.testing.expectEqualStrings(
            "https://github.com/nostr-protocol/nips",
            url,
        ),
        .coordinate => unreachable,
    }
}

test "code snippet extract rejects invalid and contradictory tag shapes" {
    var licenses: [1]LicenseInfo = undefined;
    var dependencies: [1][]const u8 = undefined;
    const duplicate_language = [_]nip01_event.EventTag{
        .{ .items = &.{ "l", "rust" } },
        .{ .items = &.{ "l", "zig" } },
    };
    const invalid_repo_kind = [_]nip01_event.EventTag{
        .{ .items = &.{
            "repo",
            "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:nostr",
        } },
    };
    const invalid_repo_hint = [_]nip01_event.EventTag{
        .{ .items = &.{
            "repo",
            "30617:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:nostr",
            "not a url",
        } },
    };
    const invalid_license = [_]nip01_event.EventTag{
        .{ .items = &.{ "license", "" } },
    };
    const invalid_dependency = [_]nip01_event.EventTag{
        .{ .items = &.{ "dep", "" } },
    };

    try std.testing.expectError(
        error.DuplicateLanguageTag,
        code_snippet_extract(
            &test_event(code_snippet_kind, "const x = 1;", duplicate_language[0..]),
            licenses[0..],
            dependencies[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidRepoTag,
        code_snippet_extract(
            &test_event(code_snippet_kind, "const x = 1;", invalid_repo_kind[0..]),
            licenses[0..],
            dependencies[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidRepoTag,
        code_snippet_extract(
            &test_event(code_snippet_kind, "const x = 1;", invalid_repo_hint[0..]),
            licenses[0..],
            dependencies[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidLicenseTag,
        code_snippet_extract(
            &test_event(code_snippet_kind, "const x = 1;", invalid_license[0..]),
            licenses[0..],
            dependencies[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidDependencyTag,
        code_snippet_extract(
            &test_event(code_snippet_kind, "const x = 1;", invalid_dependency[0..]),
            licenses[0..],
            dependencies[0..],
        ),
    );
}

test "code snippet extract separates invalid input from capacity failures" {
    var no_licenses: [0]LicenseInfo = .{};
    var no_dependencies: [0][]const u8 = .{};
    const license_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "license", "MIT" } },
    };
    const dependency_tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "dep", "std" } },
    };
    const invalid_content = [_]u8{0xff};

    try std.testing.expectError(
        error.BufferTooSmall,
        code_snippet_extract(
            &test_event(code_snippet_kind, "const x = 1;", license_tags[0..]),
            no_licenses[0..],
            no_dependencies[0..],
        ),
    );
    try std.testing.expectError(
        error.BufferTooSmall,
        code_snippet_extract(
            &test_event(code_snippet_kind, "const x = 1;", dependency_tags[0..]),
            no_licenses[0..],
            no_dependencies[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidContent,
        code_snippet_extract(
            &test_event(code_snippet_kind, invalid_content[0..], dependency_tags[0..]),
            no_licenses[0..],
            no_dependencies[0..],
        ),
    );
}

test "code snippet builders reject overlong metadata as invalid input" {
    var name_tag: BuiltTag = .{};
    var dependency_tag: BuiltTag = .{};
    var repo_tag: BuiltTag = .{};
    var long_storage: [limits.tag_item_bytes_max + 1]u8 = undefined;
    @memset(long_storage[0..], 'a');

    try std.testing.expectError(
        error.InvalidNameTag,
        code_snippet_build_name_tag(&name_tag, long_storage[0..]),
    );
    try std.testing.expectError(
        error.InvalidDependencyTag,
        code_snippet_build_dependency_tag(&dependency_tag, long_storage[0..]),
    );
    try std.testing.expectError(
        error.InvalidRepoTag,
        code_snippet_build_repo_tag(&repo_tag, .{
            .coordinate = .{
                .pubkey = [_]u8{0} ** 32,
                .identifier = long_storage[0..],
            },
        }),
    );
}

test "code snippet extract rejects unsupported kind and empty content" {
    var licenses: [1]LicenseInfo = undefined;
    var dependencies: [1][]const u8 = undefined;

    try std.testing.expectError(
        error.UnsupportedKind,
        code_snippet_extract(
            &test_event(1, "const x = 1;", &.{}),
            licenses[0..],
            dependencies[0..],
        ),
    );
    try std.testing.expectError(
        error.InvalidContent,
        code_snippet_extract(
            &test_event(code_snippet_kind, "", &.{}),
            licenses[0..],
            dependencies[0..],
        ),
    );
}
