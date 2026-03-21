const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip94_file_metadata = @import("nip94_file_metadata.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");
const url_with_scheme = @import("internal/url_with_scheme.zig");

pub const normal_video_kind: u32 = 21;
pub const short_video_kind: u32 = 22;
pub const addressable_normal_video_kind: u32 = 34235;
pub const addressable_short_video_kind: u32 = 34236;

pub const Nip71Error = error{
    InvalidVideoKind,
    MissingTitleTag,
    DuplicateTitleTag,
    InvalidTitleTag,
    MissingIdentifierTag,
    DuplicateIdentifierTag,
    InvalidIdentifierTag,
    DuplicatePublishedAtTag,
    InvalidPublishedAtTag,
    DuplicateContentWarningTag,
    InvalidContentWarningTag,
    DuplicateAltTag,
    InvalidAltTag,
    InvalidVariantTag,
    MissingVariantUrlField,
    MissingVariantMetadataField,
    DuplicateVariantUrlField,
    DuplicateVariantMimeTypeField,
    DuplicateVariantHashField,
    DuplicateVariantServiceField,
    DuplicateVariantDimensionsField,
    DuplicateVariantDurationField,
    DuplicateVariantBitrateField,
    InvalidVariantUrlField,
    InvalidVariantMimeTypeField,
    InvalidVariantHashField,
    InvalidVariantServiceField,
    InvalidVariantDimensionsField,
    InvalidVariantDurationField,
    InvalidVariantBitrateField,
    InvalidTextTrackTag,
    InvalidSegmentTag,
    InvalidParticipantTag,
    InvalidHashtagTag,
    InvalidReferenceTag,
    InvalidOriginTag,
    BufferTooSmall,
};

pub const VideoFlavor = enum {
    normal,
    short,
};

pub const Dimensions = nip94_file_metadata.Dimensions;

pub const VideoVariant = struct {
    url: []const u8,
    mime_type: ?[]const u8 = null,
    sha256: ?[32]u8 = null,
    dimensions: ?Dimensions = null,
    service: ?[]const u8 = null,
    duration_seconds: ?f64 = null,
    bitrate: ?u64 = null,
    image_offset: u16 = 0,
    image_count: u16 = 0,
    fallback_offset: u16 = 0,
    fallback_count: u16 = 0,
};

pub const TextTrackInfo = struct {
    value: []const u8,
    track_type: ?[]const u8 = null,
    language_code: ?[]const u8 = null,
};

pub const VideoSegment = struct {
    start_text: []const u8,
    end_text: []const u8,
    title: []const u8,
    thumbnail_url: ?[]const u8 = null,
};

pub const VideoParticipant = struct {
    pubkey: [32]u8,
    relay_hint: ?[]const u8 = null,
};

pub const OriginInfo = struct {
    platform: []const u8,
    external_id: []const u8,
    original_url: []const u8,
    metadata: ?[]const u8 = null,
};

pub const VideoInfo = struct {
    flavor: VideoFlavor,
    addressable: bool,
    identifier: ?[]const u8 = null,
    title: []const u8,
    content: []const u8,
    published_at: ?u64 = null,
    content_warning: ?[]const u8 = null,
    alt: ?[]const u8 = null,
    variant_count: u16 = 0,
    text_track_count: u16 = 0,
    segment_count: u16 = 0,
    participant_count: u16 = 0,
    hashtag_count: u16 = 0,
    reference_count: u16 = 0,
    origin_count: u16 = 0,
};

pub const BuiltTag = struct {
    items: [5][]const u8 = undefined,
    text_storage: [3][limits.tag_item_bytes_max]u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const BuiltTag) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

pub const BuiltField = struct {
    storage: [limits.tag_item_bytes_max]u8 = undefined,
};

const VariantState = struct {
    saw_url: bool = false,
    saw_metadata: bool = false,
    saw_mime: bool = false,
    saw_hash: bool = false,
    saw_service: bool = false,
    saw_dimensions: bool = false,
    saw_duration: bool = false,
    saw_bitrate: bool = false,
};

/// Extracts bounded NIP-71 video metadata from one supported video-event kind.
pub fn video_extract(
    event: *const nip01_event.Event,
    out_variants: []VideoVariant,
    out_variant_images: [][]const u8,
    out_variant_fallbacks: [][]const u8,
    out_text_tracks: []TextTrackInfo,
    out_segments: []VideoSegment,
    out_participants: []VideoParticipant,
    out_hashtags: [][]const u8,
    out_references: [][]const u8,
    out_origins: []OriginInfo,
) Nip71Error!VideoInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(out_variants.len <= limits.tags_max);

    var info = VideoInfo{
        .flavor = try parse_video_flavor(event.kind),
        .addressable = is_addressable_kind(event.kind),
        .title = undefined,
        .content = event.content,
    };
    var title: ?[]const u8 = null;
    var identifier: ?[]const u8 = null;
    var image_cursor: u16 = 0;
    var fallback_cursor: u16 = 0;
    for (event.tags) |tag| {
        try apply_video_tag(
            tag,
            &info,
            &title,
            &identifier,
            out_variants,
            out_variant_images,
            out_variant_fallbacks,
            &image_cursor,
            &fallback_cursor,
            out_text_tracks,
            out_segments,
            out_participants,
            out_hashtags,
            out_references,
            out_origins,
        );
    }
    info.title = title orelse return error.MissingTitleTag;
    if (info.addressable) {
        info.identifier = identifier orelse return error.MissingIdentifierTag;
    } else {
        info.identifier = identifier;
    }
    return info;
}

pub fn video_is_video_kind(kind: u32) bool {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(normal_video_kind < addressable_normal_video_kind);

    return is_video_kind(kind);
}

pub fn video_build_identifier_tag(
    output: *BuiltTag,
    identifier: []const u8,
) Nip71Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "d";
    output.items[1] = parse_nonempty_utf8(identifier) catch return error.InvalidIdentifierTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn video_build_title_tag(
    output: *BuiltTag,
    title: []const u8,
) Nip71Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "title";
    output.items[1] = parse_nonempty_utf8(title) catch return error.InvalidTitleTag;
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn video_build_published_at_tag(
    output: *BuiltTag,
    unix_seconds: u64,
) Nip71Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(unix_seconds <= std.math.maxInt(u64));

    output.items[0] = "published_at";
    output.items[1] = std.fmt.bufPrint(output.text_storage[0][0..], "{d}", .{unix_seconds}) catch {
        return error.BufferTooSmall;
    };
    output.item_count = 2;
    return output.as_event_tag();
}

pub fn video_build_text_track_tag(
    output: *BuiltTag,
    value: []const u8,
    track_type: ?[]const u8,
    language_code: ?[]const u8,
) Nip71Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "text-track";
    output.items[1] = parse_nonempty_utf8(value) catch return error.InvalidTextTrackTag;
    output.item_count = 2;
    if (track_type) |text| {
        output.items[2] = parse_nonempty_utf8(text) catch return error.InvalidTextTrackTag;
        output.item_count = 3;
    }
    if (language_code) |text| {
        output.items[output.item_count] = parse_nonempty_utf8(text) catch {
            return error.InvalidTextTrackTag;
        };
        output.item_count += 1;
    }
    return output.as_event_tag();
}

pub fn video_build_segment_tag(
    output: *BuiltTag,
    start_text: []const u8,
    end_text: []const u8,
    title: []const u8,
    thumbnail_url: ?[]const u8,
) Nip71Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    _ = parse_timestamp_text(start_text) catch return error.InvalidSegmentTag;
    _ = parse_timestamp_text(end_text) catch return error.InvalidSegmentTag;
    output.items[0] = "segment";
    output.items[1] = start_text;
    output.items[2] = end_text;
    output.items[3] = parse_nonempty_utf8(title) catch return error.InvalidSegmentTag;
    output.item_count = 4;
    if (thumbnail_url) |url| {
        output.items[4] = parse_url(url) catch return error.InvalidSegmentTag;
        output.item_count = 5;
    }
    return output.as_event_tag();
}

pub fn video_build_participant_tag(
    output: *BuiltTag,
    pubkey_hex: []const u8,
    relay_hint: ?[]const u8,
) Nip71Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    _ = lower_hex_32.parse(pubkey_hex) catch return error.InvalidParticipantTag;
    output.items[0] = "p";
    output.items[1] = pubkey_hex;
    output.item_count = 2;
    if (relay_hint) |url| {
        output.items[2] = parse_url(url) catch return error.InvalidParticipantTag;
        output.item_count = 3;
    }
    return output.as_event_tag();
}

pub fn video_build_origin_tag(
    output: *BuiltTag,
    platform: []const u8,
    external_id: []const u8,
    original_url: []const u8,
    metadata: ?[]const u8,
) Nip71Error!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 5);

    output.items[0] = "origin";
    output.items[1] = parse_nonempty_utf8(platform) catch return error.InvalidOriginTag;
    output.items[2] = parse_nonempty_utf8(external_id) catch return error.InvalidOriginTag;
    output.items[3] = parse_url(original_url) catch return error.InvalidOriginTag;
    output.item_count = 4;
    if (metadata) |text| {
        output.items[4] = parse_nonempty_utf8(text) catch return error.InvalidOriginTag;
        output.item_count = 5;
    }
    return output.as_event_tag();
}

pub fn video_build_duration_field(
    output: *BuiltField,
    duration_seconds: f64,
) Nip71Error![]const u8 {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(duration_seconds >= 0);

    if (!std.math.isFinite(duration_seconds)) return error.InvalidVariantDurationField;
    if (duration_seconds < 0) return error.InvalidVariantDurationField;
    return std.fmt.bufPrint(output.storage[0..], "duration {d}", .{duration_seconds}) catch {
        return error.BufferTooSmall;
    };
}

pub fn video_build_bitrate_field(
    output: *BuiltField,
    bitrate: u64,
) Nip71Error![]const u8 {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(bitrate <= std.math.maxInt(u64));

    return std.fmt.bufPrint(output.storage[0..], "bitrate {d}", .{bitrate}) catch {
        return error.BufferTooSmall;
    };
}

fn apply_video_tag(
    tag: nip01_event.EventTag,
    info: *VideoInfo,
    title: *?[]const u8,
    identifier: *?[]const u8,
    out_variants: []VideoVariant,
    out_variant_images: [][]const u8,
    out_variant_fallbacks: [][]const u8,
    image_cursor: *u16,
    fallback_cursor: *u16,
    out_text_tracks: []TextTrackInfo,
    out_segments: []VideoSegment,
    out_participants: []VideoParticipant,
    out_hashtags: [][]const u8,
    out_references: [][]const u8,
    out_origins: []OriginInfo,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(@intFromPtr(title) != 0);

    if (tag.items.len == 0) return;
    if (std.mem.eql(u8, tag.items[0], "d")) return apply_identifier_tag(tag, identifier);
    if (std.mem.eql(u8, tag.items[0], "title")) return apply_title_tag(tag, title);
    if (std.mem.eql(u8, tag.items[0], "published_at")) return apply_published_at_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "content-warning")) return apply_content_warning_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "alt")) return apply_alt_tag(tag, info);
    if (std.mem.eql(u8, tag.items[0], "imeta")) {
        return append_variant(
            tag,
            info,
            out_variants,
            out_variant_images,
            out_variant_fallbacks,
            image_cursor,
            fallback_cursor,
        );
    }
    if (std.mem.eql(u8, tag.items[0], "text-track")) {
        return append_text_track(tag, info, out_text_tracks);
    }
    if (std.mem.eql(u8, tag.items[0], "segment")) return append_segment(tag, info, out_segments);
    if (std.mem.eql(u8, tag.items[0], "p")) return append_participant(tag, info, out_participants);
    if (std.mem.eql(u8, tag.items[0], "t")) return append_text_tag(tag, &info.hashtag_count, out_hashtags, error.InvalidHashtagTag);
    if (std.mem.eql(u8, tag.items[0], "r")) return append_text_tag(tag, &info.reference_count, out_references, error.InvalidReferenceTag);
    if (std.mem.eql(u8, tag.items[0], "origin")) return append_origin(tag, info, out_origins);
}

fn apply_identifier_tag(tag: nip01_event.EventTag, field: *?[]const u8) Nip71Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return error.DuplicateIdentifierTag;
    if (tag.items.len != 2) return error.InvalidIdentifierTag;
    field.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidIdentifierTag;
}

fn apply_title_tag(tag: nip01_event.EventTag, field: *?[]const u8) Nip71Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(field) != 0);

    if (field.* != null) return error.DuplicateTitleTag;
    if (tag.items.len != 2) return error.InvalidTitleTag;
    field.* = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTitleTag;
}

fn apply_published_at_tag(tag: nip01_event.EventTag, info: *VideoInfo) Nip71Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.published_at != null) return error.DuplicatePublishedAtTag;
    if (tag.items.len != 2) return error.InvalidPublishedAtTag;
    info.published_at = std.fmt.parseUnsigned(u64, tag.items[1], 10) catch {
        return error.InvalidPublishedAtTag;
    };
}

fn apply_content_warning_tag(tag: nip01_event.EventTag, info: *VideoInfo) Nip71Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.content_warning != null) return error.DuplicateContentWarningTag;
    if (tag.items.len > 2) return error.InvalidContentWarningTag;
    const reason = if (tag.items.len == 2) tag.items[1] else "";
    info.content_warning = parse_optional_utf8(reason) catch return error.InvalidContentWarningTag;
}

fn apply_alt_tag(tag: nip01_event.EventTag, info: *VideoInfo) Nip71Error!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(info) != 0);

    if (info.alt != null) return error.DuplicateAltTag;
    if (tag.items.len != 2) return error.InvalidAltTag;
    info.alt = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidAltTag;
}

fn append_variant(
    tag: nip01_event.EventTag,
    info: *VideoInfo,
    out_variants: []VideoVariant,
    out_variant_images: [][]const u8,
    out_variant_fallbacks: [][]const u8,
    image_cursor: *u16,
    fallback_cursor: *u16,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.variant_count <= out_variants.len);

    if (info.variant_count == out_variants.len) return error.BufferTooSmall;
    const index = info.variant_count;
    out_variants[index] = try parse_variant_tag(
        tag,
        out_variant_images,
        out_variant_fallbacks,
        image_cursor,
        fallback_cursor,
    );
    info.variant_count += 1;
}

fn append_text_track(
    tag: nip01_event.EventTag,
    info: *VideoInfo,
    out_text_tracks: []TextTrackInfo,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.text_track_count <= out_text_tracks.len);

    if (info.text_track_count == out_text_tracks.len) return error.BufferTooSmall;
    out_text_tracks[info.text_track_count] = parse_text_track_tag(tag) catch {
        return error.InvalidTextTrackTag;
    };
    info.text_track_count += 1;
}

fn append_segment(
    tag: nip01_event.EventTag,
    info: *VideoInfo,
    out_segments: []VideoSegment,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.segment_count <= out_segments.len);

    if (info.segment_count == out_segments.len) return error.BufferTooSmall;
    out_segments[info.segment_count] = parse_segment_tag(tag) catch return error.InvalidSegmentTag;
    info.segment_count += 1;
}

fn append_participant(
    tag: nip01_event.EventTag,
    info: *VideoInfo,
    out_participants: []VideoParticipant,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.participant_count <= out_participants.len);

    if (info.participant_count == out_participants.len) return error.BufferTooSmall;
    out_participants[info.participant_count] = parse_participant_tag(tag) catch {
        return error.InvalidParticipantTag;
    };
    info.participant_count += 1;
}

fn append_text_tag(
    tag: nip01_event.EventTag,
    count: *u16,
    output: [][]const u8,
    invalid_error: Nip71Error,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(count) != 0);
    std.debug.assert(count.* <= output.len);

    if (tag.items.len != 2) return invalid_error;
    if (count.* == output.len) return error.BufferTooSmall;
    output[count.*] = parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
    count.* += 1;
}

fn append_origin(
    tag: nip01_event.EventTag,
    info: *VideoInfo,
    out_origins: []OriginInfo,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(info.origin_count <= out_origins.len);

    if (info.origin_count == out_origins.len) return error.BufferTooSmall;
    out_origins[info.origin_count] = parse_origin_tag(tag) catch return error.InvalidOriginTag;
    info.origin_count += 1;
}

fn parse_variant_tag(
    tag: nip01_event.EventTag,
    out_variant_images: [][]const u8,
    out_variant_fallbacks: [][]const u8,
    image_cursor: *u16,
    fallback_cursor: *u16,
) Nip71Error!VideoVariant {
    std.debug.assert(@intFromPtr(image_cursor) != 0);
    std.debug.assert(@intFromPtr(fallback_cursor) != 0);

    if (tag.items.len < 2) return error.InvalidVariantTag;
    if (!std.mem.eql(u8, tag.items[0], "imeta")) return error.InvalidVariantTag;

    var state = VariantState{};
    var variant = VideoVariant{
        .url = undefined,
        .image_offset = image_cursor.*,
        .fallback_offset = fallback_cursor.*,
    };
    for (tag.items[1..]) |field_text| {
        try apply_variant_field(
            field_text,
            &state,
            &variant,
            out_variant_images,
            out_variant_fallbacks,
            image_cursor,
            fallback_cursor,
        );
    }
    if (!state.saw_url) return error.MissingVariantUrlField;
    if (!state.saw_metadata) return error.MissingVariantMetadataField;
    return variant;
}

fn apply_variant_field(
    field_text: []const u8,
    state: *VariantState,
    variant: *VideoVariant,
    out_variant_images: [][]const u8,
    out_variant_fallbacks: [][]const u8,
    image_cursor: *u16,
    fallback_cursor: *u16,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(field_text.len <= limits.tag_item_bytes_max);

    const split_at = std.mem.indexOfScalar(u8, field_text, ' ') orelse return error.InvalidVariantTag;
    if (split_at == 0 or split_at + 1 >= field_text.len) return error.InvalidVariantTag;
    const name = field_text[0..split_at];
    const value = field_text[split_at + 1 ..];
    if (std.mem.eql(u8, name, "url")) return parse_variant_url(value, state, variant);
    if (std.mem.eql(u8, name, "m")) return parse_variant_mime(value, state, variant);
    if (std.mem.eql(u8, name, "x")) return parse_variant_hash(value, state, variant);
    if (std.mem.eql(u8, name, "dim")) return parse_variant_dimensions(value, state, variant);
    if (std.mem.eql(u8, name, "service")) return parse_variant_service(value, state, variant);
    if (std.mem.eql(u8, name, "duration")) return parse_variant_duration(value, state, variant);
    if (std.mem.eql(u8, name, "bitrate")) return parse_variant_bitrate(value, state, variant);
    if (std.mem.eql(u8, name, "image")) {
        return append_variant_url(value, out_variant_images, image_cursor, &variant.image_count);
    }
    if (std.mem.eql(u8, name, "fallback")) {
        return append_variant_url(value, out_variant_fallbacks, fallback_cursor, &variant.fallback_count);
    }
}

fn parse_variant_url(
    value: []const u8,
    state: *VariantState,
    variant: *VideoVariant,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(variant) != 0);

    if (state.saw_url) return error.DuplicateVariantUrlField;
    variant.url = parse_url(value) catch return error.InvalidVariantUrlField;
    state.saw_url = true;
}

fn parse_variant_mime(
    value: []const u8,
    state: *VariantState,
    variant: *VideoVariant,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(variant) != 0);

    if (state.saw_mime) return error.DuplicateVariantMimeTypeField;
    variant.mime_type = parse_mime_type(value) catch return error.InvalidVariantMimeTypeField;
    state.saw_mime = true;
    state.saw_metadata = true;
}

fn parse_variant_hash(
    value: []const u8,
    state: *VariantState,
    variant: *VideoVariant,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(variant) != 0);

    if (state.saw_hash) return error.DuplicateVariantHashField;
    variant.sha256 = lower_hex_32.parse(value) catch return error.InvalidVariantHashField;
    state.saw_hash = true;
    state.saw_metadata = true;
}

fn parse_variant_dimensions(
    value: []const u8,
    state: *VariantState,
    variant: *VideoVariant,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(variant) != 0);

    if (state.saw_dimensions) return error.DuplicateVariantDimensionsField;
    variant.dimensions = parse_dimensions(value) catch return error.InvalidVariantDimensionsField;
    state.saw_dimensions = true;
    state.saw_metadata = true;
}

fn parse_variant_service(
    value: []const u8,
    state: *VariantState,
    variant: *VideoVariant,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(variant) != 0);

    if (state.saw_service) return error.DuplicateVariantServiceField;
    variant.service = parse_nonempty_utf8(value) catch return error.InvalidVariantServiceField;
    state.saw_service = true;
}

fn parse_variant_duration(
    value: []const u8,
    state: *VariantState,
    variant: *VideoVariant,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(variant) != 0);

    if (state.saw_duration) return error.DuplicateVariantDurationField;
    const parsed = std.fmt.parseFloat(f64, value) catch return error.InvalidVariantDurationField;
    if (!std.math.isFinite(parsed)) return error.InvalidVariantDurationField;
    if (parsed < 0) return error.InvalidVariantDurationField;
    variant.duration_seconds = parsed;
    state.saw_duration = true;
}

fn parse_variant_bitrate(
    value: []const u8,
    state: *VariantState,
    variant: *VideoVariant,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(@intFromPtr(variant) != 0);

    if (state.saw_bitrate) return error.DuplicateVariantBitrateField;
    variant.bitrate = std.fmt.parseUnsigned(u64, value, 10) catch {
        return error.InvalidVariantBitrateField;
    };
    state.saw_bitrate = true;
}

fn append_variant_url(
    value: []const u8,
    output: [][]const u8,
    cursor: *u16,
    count: *u16,
) Nip71Error!void {
    std.debug.assert(@intFromPtr(cursor) != 0);
    std.debug.assert(@intFromPtr(count) != 0);

    if (cursor.* == output.len) return error.BufferTooSmall;
    output[cursor.*] = parse_url(value) catch return error.InvalidVariantUrlField;
    cursor.* += 1;
    count.* += 1;
}

fn parse_text_track_tag(tag: nip01_event.EventTag) Nip71Error!TextTrackInfo {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 2 or tag.items.len > 4) return error.InvalidTextTrackTag;
    return .{
        .value = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidTextTrackTag,
        .track_type = if (tag.items.len >= 3) parse_nonempty_utf8(tag.items[2]) catch {
            return error.InvalidTextTrackTag;
        } else null,
        .language_code = if (tag.items.len == 4) parse_nonempty_utf8(tag.items[3]) catch {
            return error.InvalidTextTrackTag;
        } else null,
    };
}

fn parse_segment_tag(tag: nip01_event.EventTag) Nip71Error!VideoSegment {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 4 or tag.items.len > 5) return error.InvalidSegmentTag;
    const start_text = parse_timestamp_text(tag.items[1]) catch return error.InvalidSegmentTag;
    const end_text = parse_timestamp_text(tag.items[2]) catch return error.InvalidSegmentTag;
    return .{
        .start_text = start_text,
        .end_text = end_text,
        .title = parse_nonempty_utf8(tag.items[3]) catch return error.InvalidSegmentTag,
        .thumbnail_url = if (tag.items.len == 5) parse_url(tag.items[4]) catch {
            return error.InvalidSegmentTag;
        } else null,
    };
}

fn parse_participant_tag(tag: nip01_event.EventTag) Nip71Error!VideoParticipant {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 2 or tag.items.len > 3) return error.InvalidParticipantTag;
    return .{
        .pubkey = lower_hex_32.parse(tag.items[1]) catch return error.InvalidParticipantTag,
        .relay_hint = if (tag.items.len == 3) parse_url(tag.items[2]) catch {
            return error.InvalidParticipantTag;
        } else null,
    };
}

fn parse_origin_tag(tag: nip01_event.EventTag) Nip71Error!OriginInfo {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len > 0);

    if (tag.items.len < 4 or tag.items.len > 5) return error.InvalidOriginTag;
    return .{
        .platform = parse_nonempty_utf8(tag.items[1]) catch return error.InvalidOriginTag,
        .external_id = parse_nonempty_utf8(tag.items[2]) catch return error.InvalidOriginTag,
        .original_url = parse_url(tag.items[3]) catch return error.InvalidOriginTag,
        .metadata = if (tag.items.len == 5) parse_nonempty_utf8(tag.items[4]) catch {
            return error.InvalidOriginTag;
        } else null,
    };
}

fn parse_video_flavor(kind: u32) Nip71Error!VideoFlavor {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(short_video_kind < addressable_normal_video_kind);

    return switch (kind) {
        normal_video_kind, addressable_normal_video_kind => .normal,
        short_video_kind, addressable_short_video_kind => .short,
        else => error.InvalidVideoKind,
    };
}

fn is_video_kind(kind: u32) bool {
    std.debug.assert(kind <= limits.kind_max);
    std.debug.assert(normal_video_kind == 21);

    return kind == normal_video_kind or
        kind == short_video_kind or
        kind == addressable_normal_video_kind or
        kind == addressable_short_video_kind;
}

fn is_addressable_kind(kind: u32) bool {
    std.debug.assert(is_video_kind(kind));
    std.debug.assert(addressable_normal_video_kind > short_video_kind);

    return kind == addressable_normal_video_kind or kind == addressable_short_video_kind;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidUtf8;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_optional_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn parse_url(text: []const u8) error{InvalidUrl}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    return url_with_scheme.parse_utf8(text, limits.tag_item_bytes_max);
}

fn parse_mime_type(text: []const u8) error{InvalidMimeType}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidMimeType;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidMimeType;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidMimeType;
    if (std.mem.indexOfScalar(u8, text, '/')) |_| return text;
    return error.InvalidMimeType;
}

fn parse_dimensions(text: []const u8) error{InvalidDimensions}!Dimensions {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len == 0) return error.InvalidDimensions;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidDimensions;
    const split_at = std.mem.indexOfScalar(u8, text, 'x') orelse return error.InvalidDimensions;
    const width = std.fmt.parseUnsigned(u32, text[0..split_at], 10) catch {
        return error.InvalidDimensions;
    };
    const height = std.fmt.parseUnsigned(u32, text[split_at + 1 ..], 10) catch {
        return error.InvalidDimensions;
    };
    if (width == 0) return error.InvalidDimensions;
    if (height == 0) return error.InvalidDimensions;
    return .{ .width = width, .height = height };
}

fn parse_timestamp_text(text: []const u8) error{InvalidTimestamp}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max > 0);
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len < 8) return error.InvalidTimestamp;
    if (text.len > limits.tag_item_bytes_max) return error.InvalidTimestamp;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidTimestamp;
    if (text[2] != ':' or text[5] != ':') return error.InvalidTimestamp;
    _ = std.fmt.parseUnsigned(u8, text[0..2], 10) catch return error.InvalidTimestamp;
    _ = std.fmt.parseUnsigned(u8, text[3..5], 10) catch return error.InvalidTimestamp;
    _ = std.fmt.parseUnsigned(u8, text[6..8], 10) catch return error.InvalidTimestamp;
    if (text.len == 8) return text;
    if (text[8] != '.') return error.InvalidTimestamp;
    _ = std.fmt.parseUnsigned(u16, text[9..], 10) catch return error.InvalidTimestamp;
    return text;
}

test "NIP-71 extracts bounded addressable video metadata" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "d", "nostube-123" } },
        .{ .items = &.{ "title", "Nostube episode" } },
        .{ .items = &.{ "published_at", "1700000000" } },
        .{ .items = &.{ "alt", "Episode summary" } },
        .{ .items = &.{
            "imeta",
            "url https://cdn.example/video.mp4",
            "m video/mp4",
            "dim 1280x720",
            "image https://cdn.example/thumb.jpg",
            "fallback https://backup.example/video.mp4",
            "duration 29.223",
            "bitrate 3000000",
        } },
        .{ .items = &.{ "text-track", "https://cdn.example/captions.vtt", "subtitles", "en" } },
        .{ .items = &.{ "segment", "00:00:00.000", "00:00:10.000", "Intro" } },
        .{ .items = &.{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://relay.example.com",
        } },
        .{ .items = &.{ "t", "nostube" } },
        .{ .items = &.{ "r", "https://nostube.example/watch/123" } },
        .{ .items = &.{ "origin", "youtube", "abc123", "https://youtube.example/watch?v=abc123" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x71} ** 32,
        .pubkey = [_]u8{0x11} ** 32,
        .created_at = 1,
        .kind = addressable_short_video_kind,
        .tags = tags[0..],
        .content = "A short-form video.",
        .sig = [_]u8{0x22} ** 64,
    };
    var variants: [1]VideoVariant = undefined;
    var images: [1][]const u8 = undefined;
    var fallbacks: [1][]const u8 = undefined;
    var tracks: [1]TextTrackInfo = undefined;
    var segments: [1]VideoSegment = undefined;
    var participants: [1]VideoParticipant = undefined;
    var hashtags: [1][]const u8 = undefined;
    var references: [1][]const u8 = undefined;
    var origins: [1]OriginInfo = undefined;

    const info = try video_extract(
        &event,
        variants[0..],
        images[0..],
        fallbacks[0..],
        tracks[0..],
        segments[0..],
        participants[0..],
        hashtags[0..],
        references[0..],
        origins[0..],
    );

    try std.testing.expectEqual(VideoFlavor.short, info.flavor);
    try std.testing.expect(info.addressable);
    try std.testing.expectEqualStrings("nostube-123", info.identifier.?);
    try std.testing.expectEqualStrings("Nostube episode", info.title);
    try std.testing.expectEqual(@as(u16, 1), info.variant_count);
    try std.testing.expectEqual(@as(u16, 1), variants[0].image_count);
    try std.testing.expectEqual(@as(u16, 1), variants[0].fallback_count);
    try std.testing.expectEqual(@as(?u64, 3_000_000), variants[0].bitrate);
    try std.testing.expect(variants[0].duration_seconds.? > 29.0);
}

test "NIP-71 rejects duplicate titles" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "title", "first" } },
        .{ .items = &.{ "title", "second" } },
    };
    const event = nip01_event.Event{
        .id = [_]u8{0x72} ** 32,
        .pubkey = [_]u8{0x12} ** 32,
        .created_at = 2,
        .kind = normal_video_kind,
        .tags = tags[0..],
        .content = "",
        .sig = [_]u8{0x23} ** 64,
    };

    try std.testing.expectError(
        error.DuplicateTitleTag,
        video_extract(&event, &.{}, &.{}, &.{}, &.{}, &.{}, &.{}, &.{}, &.{}, &.{}),
    );
}

test "NIP-71 builds title and duration helpers" {
    var title_built: BuiltTag = .{};
    var field_built: BuiltField = .{};

    const title = try video_build_title_tag(&title_built, "Episode");
    const duration = try video_build_duration_field(&field_built, 12.5);

    try std.testing.expectEqualStrings("title", title.items[0]);
    try std.testing.expectEqualStrings("Episode", title.items[1]);
    try std.testing.expectEqualStrings("duration 12.5", duration);
}

test "NIP-71 rejects overlong title builder input with typed error" {
    var built: BuiltTag = .{};
    const overlong = [_]u8{'a'} ** (limits.tag_item_bytes_max + 1);

    try std.testing.expectError(
        error.InvalidTitleTag,
        video_build_title_tag(&built, overlong[0..]),
    );
}
