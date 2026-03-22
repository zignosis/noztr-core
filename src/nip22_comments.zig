const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");
const nip73_external_ids = @import("nip73_external_ids.zig");
const lower_hex_32 = @import("internal/lower_hex_32.zig");

pub const comment_event_kind: u32 = 1111;

pub const CommentError = error{
    InvalidCommentKind,
    MissingRootTarget,
    MissingParentTarget,
    DuplicateRootTarget,
    DuplicateParentTarget,
    MissingRootKind,
    MissingParentKind,
    DuplicateRootKind,
    DuplicateParentKind,
    InvalidRootTarget,
    InvalidParentTarget,
    InvalidRootKind,
    InvalidParentKind,
    MissingRootAuthor,
    MissingParentAuthor,
    InvalidRootAuthor,
    InvalidParentAuthor,
    RootAuthorMismatch,
    ParentAuthorMismatch,
    RootKindMismatch,
    ParentKindMismatch,
    RootTextNoteUnsupported,
    ParentTextNoteUnsupported,
};

pub const EventTarget = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
    event_author_pubkey: ?[32]u8 = null,
    author_pubkey: [32]u8,
    author_hint: ?[]const u8 = null,
    kind: u32,
};

pub const CoordinateTarget = struct {
    kind: u32,
    pubkey: [32]u8,
    identifier: []const u8,
    relay_hint: ?[]const u8 = null,
    event_id: ?[32]u8 = null,
    event_hint: ?[]const u8 = null,
    author_hint: ?[]const u8 = null,
};

pub const ExternalTarget = struct {
    value: []const u8,
    hint: ?[]const u8 = null,
    external_kind: []const u8,
};

pub const CommentTarget = union(enum) {
    event: EventTarget,
    coordinate: CoordinateTarget,
    external: ExternalTarget,
};

pub const CommentInfo = struct {
    root: CommentTarget,
    parent: CommentTarget,
};

const ParsedEventTarget = struct {
    event_id: [32]u8,
    relay_hint: ?[]const u8 = null,
    event_author_pubkey: ?[32]u8 = null,
};

const ParsedExternalTarget = struct {
    value: []const u8,
    hint: ?[]const u8 = null,
};

const ParsedTarget = union(enum) {
    event: ParsedEventTarget,
    coordinate: CoordinateTarget,
    external: ParsedExternalTarget,
};

const ParsedAuthor = struct {
    pubkey: [32]u8,
    hint: ?[]const u8 = null,
};

const ParsedState = struct {
    root_target: ?ParsedTarget = null,
    root_companion_event: ?ParsedEventTarget = null,
    root_kind: ?[]const u8 = null,
    root_author: ?ParsedAuthor = null,
    parent_target: ?ParsedTarget = null,
    parent_companion_event: ?ParsedEventTarget = null,
    parent_kind: ?[]const u8 = null,
    parent_author: ?ParsedAuthor = null,
};

/// Returns whether the event is a native NIP-22 comment event.
pub fn comment_is_comment(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= std.math.maxInt(u32));

    return event.kind == comment_event_kind;
}

/// Parses strict NIP-22 root and parent linkage from a kind-1111 comment event.
pub fn comment_parse(event: *const nip01_event.Event) CommentError!CommentInfo {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (!comment_is_comment(event)) {
        return error.InvalidCommentKind;
    }

    var parsed = ParsedState{};
    for (event.tags) |tag| {
        try parse_comment_tag(tag, &parsed);
    }

    const root_target = parsed.root_target orelse return error.MissingRootTarget;
    const root_kind = parsed.root_kind orelse return error.MissingRootKind;
    const parent_target = parsed.parent_target orelse return error.MissingParentTarget;
    const parent_kind = parsed.parent_kind orelse return error.MissingParentKind;

    return .{
        .root = try finalize_root_target(
            event.tags,
            root_target,
            parsed.root_companion_event,
            root_kind,
        ),
        .parent = try finalize_parent_target(
            event.tags,
            parent_target,
            parsed.parent_companion_event,
            parent_kind,
        ),
    };
}

fn parse_comment_tag(tag: nip01_event.EventTag, parsed: *ParsedState) CommentError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (tag.items.len == 0) {
        return error.InvalidParentTarget;
    }

    const tag_name = tag.items[0];
    if (try parse_root_tag(tag_name, tag, parsed)) {
        return;
    }
    if (try parse_parent_tag(tag_name, tag, parsed)) {
        return;
    }
}

fn parse_root_tag(
    tag_name: []const u8,
    tag: nip01_event.EventTag,
    parsed: *ParsedState,
) CommentError!bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (std.mem.eql(u8, tag_name, "E")) {
        try apply_root_event_tag(tag, parsed);
        return true;
    }
    if (std.mem.eql(u8, tag_name, "A")) {
        if (parsed.root_target != null and parsed.root_target.? != .event) {
            return error.DuplicateRootTarget;
        }
        const coordinate = try parse_coordinate_target(tag, error.InvalidRootTarget);
        if (parsed.root_target != null and parsed.root_target.? == .event) {
            parsed.root_companion_event = parsed.root_target.?.event;
        }
        parsed.root_target = .{ .coordinate = coordinate };
        return true;
    }
    if (std.mem.eql(u8, tag_name, "I")) {
        if (parsed.root_target != null) {
            return error.DuplicateRootTarget;
        }
        parsed.root_target = .{
            .external = try parse_external_target(tag, error.InvalidRootTarget),
        };
        return true;
    }
    if (std.mem.eql(u8, tag_name, "K")) {
        if (parsed.root_kind != null) {
            return error.DuplicateRootKind;
        }
        parsed.root_kind = try parse_kind_token(tag, error.InvalidRootKind);
        return true;
    }
    if (std.mem.eql(u8, tag_name, "P") and parsed.root_author == null) {
        parsed.root_author = try parse_author_tag(tag, error.InvalidRootAuthor);
        return true;
    }
    return false;
}

fn parse_parent_tag(
    tag_name: []const u8,
    tag: nip01_event.EventTag,
    parsed: *ParsedState,
) CommentError!bool {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    if (std.mem.eql(u8, tag_name, "e")) {
        try apply_parent_event_tag(tag, parsed);
        return true;
    }
    if (std.mem.eql(u8, tag_name, "a")) {
        if (parsed.parent_target != null and parsed.parent_target.? != .event) {
            return error.DuplicateParentTarget;
        }
        const coordinate = try parse_coordinate_target(tag, error.InvalidParentTarget);
        if (parsed.parent_target != null and parsed.parent_target.? == .event) {
            parsed.parent_companion_event = parsed.parent_target.?.event;
        }
        parsed.parent_target = .{ .coordinate = coordinate };
        return true;
    }
    if (std.mem.eql(u8, tag_name, "i")) {
        if (parsed.parent_target != null) {
            return error.DuplicateParentTarget;
        }
        parsed.parent_target = .{
            .external = try parse_external_target(tag, error.InvalidParentTarget),
        };
        return true;
    }
    if (std.mem.eql(u8, tag_name, "k")) {
        if (parsed.parent_kind != null) {
            return error.DuplicateParentKind;
        }
        parsed.parent_kind = try parse_kind_token(tag, error.InvalidParentKind);
        return true;
    }
    if (std.mem.eql(u8, tag_name, "p") and parsed.parent_author == null) {
        parsed.parent_author = try parse_author_tag(tag, error.InvalidParentAuthor);
        return true;
    }
    return false;
}

fn apply_root_event_tag(tag: nip01_event.EventTag, parsed: *ParsedState) CommentError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    const event_target = try parse_event_target(tag, error.InvalidRootTarget);
    if (parsed.root_target == null and parsed.root_companion_event == null) {
        parsed.root_target = .{ .event = event_target };
        return;
    }
    if (parsed.root_target != null and parsed.root_target.? == .coordinate and parsed.root_companion_event == null) {
        parsed.root_companion_event = event_target;
        return;
    }
    if (parsed.root_target != null and parsed.root_target.? == .event and parsed.root_companion_event == null) {
        return error.DuplicateRootTarget;
    }
    return error.DuplicateRootTarget;
}

fn apply_parent_event_tag(tag: nip01_event.EventTag, parsed: *ParsedState) CommentError!void {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(@intFromPtr(parsed) != 0);

    const event_target = try parse_event_target(tag, error.InvalidParentTarget);
    if (parsed.parent_target == null and parsed.parent_companion_event == null) {
        parsed.parent_target = .{ .event = event_target };
        return;
    }
    if (parsed.parent_target != null and parsed.parent_target.? == .coordinate and parsed.parent_companion_event == null) {
        parsed.parent_companion_event = event_target;
        return;
    }
    if (parsed.parent_target != null and parsed.parent_target.? == .event and parsed.parent_companion_event == null) {
        return error.DuplicateParentTarget;
    }
    return error.DuplicateParentTarget;
}

fn parse_event_target(
    tag: nip01_event.EventTag,
    invalid_error: CommentError,
) CommentError!ParsedEventTarget {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len >= 1);

    if (tag.items.len < 2) {
        return invalid_error;
    }
    if (tag.items.len > 4) {
        return invalid_error;
    }

    var parsed = ParsedEventTarget{
        .event_id = parse_lower_hex_32(tag.items[1]) catch return invalid_error,
    };
    if (tag.items.len >= 3) {
        parsed.relay_hint = parse_optional_hint(tag.items[2]) catch return invalid_error;
    }
    if (tag.items.len >= 4) {
        parsed.event_author_pubkey = parse_lower_hex_32(tag.items[3]) catch return invalid_error;
    }
    return parsed;
}

fn parse_coordinate_target(
    tag: nip01_event.EventTag,
    invalid_error: CommentError,
) CommentError!CoordinateTarget {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len >= 1);

    if (tag.items.len < 2) {
        return invalid_error;
    }
    if (tag.items.len > 3) {
        return invalid_error;
    }

    var parsed = parse_address_coordinate(tag.items[1]) catch return invalid_error;
    if (tag.items.len >= 3) {
        parsed.relay_hint = parse_optional_hint(tag.items[2]) catch return invalid_error;
    }
    return parsed;
}

fn parse_external_target(
    tag: nip01_event.EventTag,
    invalid_error: CommentError,
) CommentError!ParsedExternalTarget {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len >= 1);

    if (tag.items.len < 2) {
        return invalid_error;
    }
    if (tag.items.len > 3) {
        return invalid_error;
    }

    var parsed = ParsedExternalTarget{
        .value = parse_nonempty_utf8(tag.items[1]) catch return invalid_error,
    };
    if (tag.items.len >= 3) {
        parsed.hint = parse_optional_hint(tag.items[2]) catch return invalid_error;
    }
    return parsed;
}

fn parse_kind_token(
    tag: nip01_event.EventTag,
    invalid_error: CommentError,
) CommentError![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len >= 1);

    if (tag.items.len < 2) {
        return invalid_error;
    }
    if (tag.items.len > 2) {
        return invalid_error;
    }
    return parse_nonempty_utf8(tag.items[1]) catch return invalid_error;
}

fn parse_author_tag(
    tag: nip01_event.EventTag,
    invalid_error: CommentError,
) CommentError!ParsedAuthor {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(tag.items.len >= 1);

    if (tag.items.len < 2) {
        return invalid_error;
    }
    if (tag.items.len > 3) {
        return invalid_error;
    }

    var parsed = ParsedAuthor{
        .pubkey = parse_lower_hex_32(tag.items[1]) catch return invalid_error,
    };
    if (tag.items.len >= 3) {
        parsed.hint = parse_optional_hint(tag.items[2]) catch return invalid_error;
    }
    return parsed;
}

fn finalize_root_target(
    tags: []const nip01_event.EventTag,
    parsed_target: ParsedTarget,
    companion_event: ?ParsedEventTarget,
    kind_token: []const u8,
) CommentError!CommentTarget {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(kind_token.len > 0);
    std.debug.assert(std.unicode.utf8ValidateSlice(kind_token));

    return finalize_target(
        tags,
        parsed_target,
        companion_event,
        kind_token,
        true,
        error.InvalidRootKind,
        error.MissingRootAuthor,
        error.RootAuthorMismatch,
        error.RootKindMismatch,
        error.RootTextNoteUnsupported,
    );
}

fn finalize_parent_target(
    tags: []const nip01_event.EventTag,
    parsed_target: ParsedTarget,
    companion_event: ?ParsedEventTarget,
    kind_token: []const u8,
) CommentError!CommentTarget {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(kind_token.len > 0);
    std.debug.assert(std.unicode.utf8ValidateSlice(kind_token));

    return finalize_target(
        tags,
        parsed_target,
        companion_event,
        kind_token,
        false,
        error.InvalidParentKind,
        error.MissingParentAuthor,
        error.ParentAuthorMismatch,
        error.ParentKindMismatch,
        error.ParentTextNoteUnsupported,
    );
}

fn finalize_target(
    tags: []const nip01_event.EventTag,
    parsed_target: ParsedTarget,
    companion_event: ?ParsedEventTarget,
    kind_token: []const u8,
    uppercase_author: bool,
    invalid_kind_error: CommentError,
    missing_author_error: CommentError,
    author_mismatch_error: CommentError,
    kind_mismatch_error: CommentError,
    text_note_error: CommentError,
) CommentError!CommentTarget {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(kind_token.len > 0);
    std.debug.assert(std.unicode.utf8ValidateSlice(kind_token));

    switch (parsed_target) {
        .event => |event_target| return finalize_event_target(
            tags,
            event_target,
            companion_event,
            kind_token,
            uppercase_author,
            invalid_kind_error,
            missing_author_error,
            author_mismatch_error,
            kind_mismatch_error,
            text_note_error,
        ),
        .coordinate => |coordinate| return finalize_coordinate_target(
            tags,
            coordinate,
            companion_event,
            kind_token,
            uppercase_author,
            invalid_kind_error,
            missing_author_error,
            author_mismatch_error,
            kind_mismatch_error,
            text_note_error,
        ),
        .external => |external_target| return finalize_external_target(
            external_target,
            kind_token,
            kind_mismatch_error,
        ),
    }
}

fn finalize_event_target(
    tags: []const nip01_event.EventTag,
    event_target: ParsedEventTarget,
    companion_event: ?ParsedEventTarget,
    kind_token: []const u8,
    uppercase_author: bool,
    invalid_kind_error: CommentError,
    missing_author_error: CommentError,
    author_mismatch_error: CommentError,
    kind_mismatch_error: CommentError,
    text_note_error: CommentError,
) CommentError!CommentTarget {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(kind_token.len > 0);

    const kind = parse_non_text_note_kind(
        kind_token,
        invalid_kind_error,
        text_note_error,
    ) catch |err| return err;
    if (companion_event != null) return kind_mismatch_error;

    const parsed_author = try select_author(
        tags,
        uppercase_author,
        event_target.event_author_pubkey,
        missing_author_error,
        author_mismatch_error,
        uppercase_author,
    );
    try require_matching_optional_author(
        event_target.event_author_pubkey,
        parsed_author.pubkey,
        author_mismatch_error,
    );
    return .{
        .event = .{
            .event_id = event_target.event_id,
            .relay_hint = event_target.relay_hint,
            .event_author_pubkey = event_target.event_author_pubkey,
            .author_pubkey = parsed_author.pubkey,
            .author_hint = parsed_author.hint,
            .kind = kind,
        },
    };
}

fn finalize_coordinate_target(
    tags: []const nip01_event.EventTag,
    coordinate: CoordinateTarget,
    companion_event: ?ParsedEventTarget,
    kind_token: []const u8,
    uppercase_author: bool,
    invalid_kind_error: CommentError,
    missing_author_error: CommentError,
    author_mismatch_error: CommentError,
    kind_mismatch_error: CommentError,
    text_note_error: CommentError,
) CommentError!CommentTarget {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(kind_token.len > 0);

    const kind = parse_non_text_note_kind(
        kind_token,
        invalid_kind_error,
        text_note_error,
    ) catch |err| return err;
    if (kind != coordinate.kind) return kind_mismatch_error;

    const parsed_author = try select_author(
        tags,
        uppercase_author,
        coordinate.pubkey,
        missing_author_error,
        author_mismatch_error,
        false,
    );
    if (!std.mem.eql(u8, &coordinate.pubkey, &parsed_author.pubkey)) {
        return author_mismatch_error;
    }

    var finalized = coordinate;
    try apply_coordinate_companion_event(
        &finalized,
        companion_event,
        author_mismatch_error,
    );
    finalized.author_hint = parsed_author.hint;
    return .{ .coordinate = finalized };
}

fn finalize_external_target(
    external_target: ParsedExternalTarget,
    kind_token: []const u8,
    kind_mismatch_error: CommentError,
) CommentError!CommentTarget {
    std.debug.assert(kind_token.len > 0);
    std.debug.assert(std.unicode.utf8ValidateSlice(kind_token));

    if (!external_kind_matches_value(kind_token, external_target.value)) {
        return kind_mismatch_error;
    }
    return .{
        .external = .{
            .value = external_target.value,
            .hint = external_target.hint,
            .external_kind = kind_token,
        },
    };
}

fn parse_non_text_note_kind(
    kind_token: []const u8,
    invalid_kind_error: CommentError,
    text_note_error: CommentError,
) CommentError!u32 {
    std.debug.assert(kind_token.len > 0);
    std.debug.assert(std.unicode.utf8ValidateSlice(kind_token));

    const kind = parse_nostr_kind(kind_token) catch return invalid_kind_error;
    if (kind == 1) return text_note_error;
    return kind;
}

fn require_matching_optional_author(
    expected: ?[32]u8,
    actual: [32]u8,
    author_mismatch_error: CommentError,
) CommentError!void {
    std.debug.assert(@typeInfo(CommentError) == .error_set);
    std.debug.assert(limits.pubkey_hex_length == 64);

    if (expected) |tag_pubkey| {
        if (!std.mem.eql(u8, &tag_pubkey, &actual)) {
            return author_mismatch_error;
        }
    }
}

fn apply_coordinate_companion_event(
    coordinate: *CoordinateTarget,
    companion_event: ?ParsedEventTarget,
    author_mismatch_error: CommentError,
) CommentError!void {
    std.debug.assert(@intFromPtr(coordinate) != 0);
    std.debug.assert(@typeInfo(CommentError) == .error_set);

    if (companion_event) |event_target| {
        coordinate.event_id = event_target.event_id;
        coordinate.event_hint = event_target.relay_hint;
        try require_matching_optional_author(
            event_target.event_author_pubkey,
            coordinate.pubkey,
            author_mismatch_error,
        );
    }
}

fn select_author(
    tags: []const nip01_event.EventTag,
    uppercase_author: bool,
    required_pubkey: ?[32]u8,
    missing_author_error: CommentError,
    author_mismatch_error: CommentError,
    allow_ambiguous_single: bool,
) CommentError!ParsedAuthor {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(@typeInfo(CommentError) == .error_set);

    const tag_name = if (uppercase_author) "P" else "p";
    var first_author: ?ParsedAuthor = null;
    var match_count: u16 = 0;
    var saw_author = false;

    for (tags) |tag| {
        if (tag.items.len == 0) {
            continue;
        }
        if (!std.mem.eql(u8, tag.items[0], tag_name)) {
            continue;
        }

        const parsed = parse_author_tag(tag, author_mismatch_error) catch {
            return author_mismatch_error;
        };
        saw_author = true;
        if (first_author == null) {
            first_author = parsed;
        }
        if (required_pubkey) |pubkey| {
            if (std.mem.eql(u8, &pubkey, &parsed.pubkey)) {
                match_count += 1;
                first_author = parsed;
            }
        } else {
            match_count += 1;
        }
    }

    if (required_pubkey) |_| {
        if (match_count == 1) {
            return first_author.?;
        }
        if (match_count > 1) {
            return first_author.?;
        }
        if (saw_author) {
            return author_mismatch_error;
        }
        return missing_author_error;
    }
    if (match_count == 1 and allow_ambiguous_single) {
        return first_author.?;
    }
    if (match_count == 1) {
        return first_author.?;
    }
    if (saw_author) {
        return author_mismatch_error;
    }
    return missing_author_error;
}

fn external_kind_matches_value(kind_token: []const u8, value: []const u8) bool {
    std.debug.assert(kind_token.len > 0);
    std.debug.assert(std.unicode.utf8ValidateSlice(kind_token));

    return nip73_external_ids.external_id_matches_kind(kind_token, value);
}

fn parse_nostr_kind(text: []const u8) error{InvalidKind}!u32 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.kind_max <= std.math.maxInt(u32));

    const kind = std.fmt.parseUnsigned(u32, text, 10) catch {
        return error.InvalidKind;
    };
    if (kind > limits.kind_max) {
        return error.InvalidKind;
    }
    return kind;
}

fn parse_address_coordinate(text: []const u8) error{InvalidCoordinate}!CoordinateTarget {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.pubkey_hex_length == 64);

    const first_colon = std.mem.indexOfScalar(u8, text, ':') orelse {
        return error.InvalidCoordinate;
    };
    if (first_colon == 0) {
        return error.InvalidCoordinate;
    }

    const second_rel = std.mem.indexOfScalar(u8, text[first_colon + 1 ..], ':') orelse {
        return error.InvalidCoordinate;
    };
    const second_colon = first_colon + second_rel + 1;
    if (second_colon == first_colon + 1) {
        return error.InvalidCoordinate;
    }

    const kind = parse_nostr_kind(text[0..first_colon]) catch {
        return error.InvalidCoordinate;
    };
    const pubkey = parse_lower_hex_32(text[first_colon + 1 .. second_colon]) catch {
        return error.InvalidCoordinate;
    };
    const identifier = text[second_colon + 1 ..];
    if (!std.unicode.utf8ValidateSlice(identifier)) {
        return error.InvalidCoordinate;
    }
    return .{
        .kind = kind,
        .pubkey = pubkey,
        .identifier = identifier,
    };
}

fn parse_optional_hint(text: []const u8) error{InvalidHint}!?[]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    if (text.len == 0) {
        return null;
    }
    if (!std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidHint;
    }
    return text;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidText}![]const u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(text.len >= 0);

    if (text.len == 0) {
        return error.InvalidText;
    }
    if (!std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidText;
    }
    return text;
}

fn parse_lower_hex_32(text: []const u8) error{InvalidHex}![32]u8 {
    std.debug.assert(text.len <= limits.tag_item_bytes_max);
    std.debug.assert(limits.id_hex_length == 64);

    return lower_hex_32.parse(text);
}

fn comment_event(tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(tags.len <= limits.tags_max);
    std.debug.assert(comment_event_kind == 1111);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = comment_event_kind,
        .created_at = 0,
        .content = "hello",
        .tags = tags,
    };
}

test "comment kind helper detects kind 1111" {
    const event = comment_event(&.{});
    const other = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 0,
        .content = "",
        .tags = &.{},
    };

    try std.testing.expect(comment_is_comment(&event));
    try std.testing.expect(!comment_is_comment(&other));
}

test "comment parse valid event root and parent targets" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "E",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "wss://root.example",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{
            "K",
            "1063",
        } },
        .{ .items = &[_][]const u8{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "wss://root.example",
        } },
        .{ .items = &[_][]const u8{
            "e",
            "2222222222222222222222222222222222222222222222222222222222222222",
            "wss://parent.example",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
        .{ .items = &[_][]const u8{
            "k",
            "1111",
        } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            "wss://parent.example",
        } },
    };

    const parsed = try comment_parse(&comment_event(tags[0..]));

    switch (parsed.root) {
        .event => |root| {
            try std.testing.expect(root.event_id[0] == 0x11);
            try std.testing.expect(root.author_pubkey[0] == 0xaa);
            try std.testing.expectEqual(@as(u32, 1063), root.kind);
            try std.testing.expectEqualStrings("wss://root.example", root.relay_hint.?);
        },
        else => return error.UnexpectedError,
    }
    switch (parsed.parent) {
        .event => |parent| {
            try std.testing.expect(parent.event_id[0] == 0x22);
            try std.testing.expect(parent.author_pubkey[0] == 0xbb);
            try std.testing.expectEqual(@as(u32, 1111), parent.kind);
            try std.testing.expectEqualStrings("wss://parent.example", parent.author_hint.?);
        },
        else => return error.UnexpectedError,
    }
}

test "comment parse valid coordinate and external targets" {
    const coordinate_tags = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "A",
            "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:article",
            "wss://root.example",
        } },
        .{ .items = &[_][]const u8{ "K", "30023" } },
        .{ .items = &[_][]const u8{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{
            "a",
            "30023:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:",
            "wss://parent.example",
        } },
        .{ .items = &[_][]const u8{
            "e",
            "3333333333333333333333333333333333333333333333333333333333333333",
            "wss://parent.example",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
        .{ .items = &[_][]const u8{ "k", "30023" } },
        .{ .items = &[_][]const u8{
            "p",
            "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
        } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };
    const coordinate_comment = try comment_parse(&comment_event(coordinate_tags[0..]));
    switch (coordinate_comment.root) {
        .coordinate => |root| {
            try std.testing.expectEqual(@as(u32, 30023), root.kind);
            try std.testing.expect(root.pubkey[0] == 0xaa);
            try std.testing.expectEqualStrings("article", root.identifier);
        },
        else => return error.UnexpectedError,
    }
    switch (coordinate_comment.parent) {
        .coordinate => |parent| {
            try std.testing.expectEqual(@as(u32, 30023), parent.kind);
            try std.testing.expect(parent.pubkey[0] == 0xbb);
            try std.testing.expect(parent.identifier.len == 0);
            try std.testing.expect(parent.event_id.?[0] == 0x33);
            try std.testing.expectEqualStrings("wss://parent.example", parent.event_hint.?);
        },
        else => return error.UnexpectedError,
    }

    const external_tags = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "I",
            "https://example.com/article",
        } },
        .{ .items = &[_][]const u8{ "K", "web" } },
        .{ .items = &[_][]const u8{
            "i",
            "https://example.com/article",
            "https://example.com/article",
        } },
        .{ .items = &[_][]const u8{ "k", "web" } },
    };
    const external_comment = try comment_parse(&comment_event(external_tags[0..]));
    switch (external_comment.root) {
        .external => |root| {
            try std.testing.expectEqualStrings("https://example.com/article", root.value);
            try std.testing.expectEqualStrings("web", root.external_kind);
        },
        else => return error.UnexpectedError,
    }
    switch (external_comment.parent) {
        .external => |parent| {
            try std.testing.expectEqualStrings("https://example.com/article", parent.value);
            try std.testing.expectEqualStrings("web", parent.external_kind);
        },
        else => return error.UnexpectedError,
    }
}

test "comment parse rejects missing required linkage" {
    const missing_root_tags = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "e",
            "1111111111111111111111111111111111111111111111111111111111111111",
        } },
        .{ .items = &[_][]const u8{ "k", "1111" } },
        .{ .items = &[_][]const u8{
            "p",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
    };
    const missing_parent_tags = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "E",
            "1111111111111111111111111111111111111111111111111111111111111111",
        } },
        .{ .items = &[_][]const u8{ "K", "1063" } },
        .{ .items = &[_][]const u8{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
    };
    const wrong_kind = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 7,
        .created_at = 0,
        .content = "hello",
        .tags = missing_root_tags[0..],
    };

    try std.testing.expectError(error.InvalidCommentKind, comment_parse(&wrong_kind));
    try std.testing.expectError(
        error.MissingRootTarget,
        comment_parse(&comment_event(missing_root_tags[0..])),
    );
    try std.testing.expectError(
        error.MissingParentTarget,
        comment_parse(&comment_event(missing_parent_tags[0..])),
    );
}

test "comment parse rejects duplicate root targets" {
    const duplicate_root = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "E",
            "1111111111111111111111111111111111111111111111111111111111111111",
        } },
        .{ .items = &[_][]const u8{
            "A",
            "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:article",
        } },
        .{ .items = &[_][]const u8{
            "I",
            "https://example.com/article",
        } },
        .{ .items = &[_][]const u8{ "K", "30023" } },
        .{ .items = &[_][]const u8{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{
            "e",
            "2222222222222222222222222222222222222222222222222222222222222222",
        } },
        .{ .items = &[_][]const u8{ "k", "1111" } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };

    try std.testing.expectError(
        error.DuplicateRootTarget,
        comment_parse(&comment_event(duplicate_root[0..])),
    );
}

test "comment parse rejects author mismatches for nostr targets" {
    const missing_root_author = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "E",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{ "K", "1063" } },
        .{ .items = &[_][]const u8{
            "e",
            "2222222222222222222222222222222222222222222222222222222222222222",
        } },
        .{ .items = &[_][]const u8{ "k", "1111" } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };
    const root_author_mismatch = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "E",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{ "K", "1063" } },
        .{ .items = &[_][]const u8{
            "P",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
        .{ .items = &[_][]const u8{
            "e",
            "2222222222222222222222222222222222222222222222222222222222222222",
        } },
        .{ .items = &[_][]const u8{ "k", "1111" } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };

    try std.testing.expectError(
        error.MissingRootAuthor,
        comment_parse(&comment_event(missing_root_author[0..])),
    );
    try std.testing.expectError(
        error.RootAuthorMismatch,
        comment_parse(&comment_event(root_author_mismatch[0..])),
    );
}

test "comment parse rejects kind mismatches and text note targets" {
    const coordinate_kind_mismatch = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "A",
            "30023:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:article",
        } },
        .{ .items = &[_][]const u8{ "K", "30024" } },
        .{ .items = &[_][]const u8{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{
            "i",
            "https://example.com/article",
        } },
        .{ .items = &[_][]const u8{ "k", "web" } },
    };
    const kind1_root = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "E",
            "1111111111111111111111111111111111111111111111111111111111111111",
        } },
        .{ .items = &[_][]const u8{ "K", "1" } },
        .{ .items = &[_][]const u8{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{
            "e",
            "2222222222222222222222222222222222222222222222222222222222222222",
        } },
        .{ .items = &[_][]const u8{ "k", "1111" } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };

    try std.testing.expectError(
        error.RootKindMismatch,
        comment_parse(&comment_event(coordinate_kind_mismatch[0..])),
    );
    try std.testing.expectError(
        error.RootTextNoteUnsupported,
        comment_parse(&comment_event(kind1_root[0..])),
    );
}

test "comment parse rejects malformed external kinds and malformed trailing fields" {
    const invalid_external = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "I",
            "https://example.com/article",
        } },
        .{ .items = &[_][]const u8{ "K", "isbn" } },
        .{ .items = &[_][]const u8{
            "i",
            "https://example.com/article",
        } },
        .{ .items = &[_][]const u8{ "k", "web" } },
    };
    const trailing_junk = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "E",
            "1111111111111111111111111111111111111111111111111111111111111111",
            "",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "reply",
        } },
        .{ .items = &[_][]const u8{ "K", "1063", "junk" } },
        .{ .items = &[_][]const u8{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{
            "e",
            "2222222222222222222222222222222222222222222222222222222222222222",
        } },
        .{ .items = &[_][]const u8{ "k", "1111" } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };

    try std.testing.expectError(
        error.RootKindMismatch,
        comment_parse(&comment_event(invalid_external[0..])),
    );
    try std.testing.expectError(
        error.InvalidRootTarget,
        comment_parse(&comment_event(trailing_junk[0..])),
    );
}

test "comment parse ignores mention pubkeys for external targets" {
    const external_with_mentions = [_]nip01_event.EventTag{
        .{ .items = &[_][]const u8{
            "I",
            "https://example.com/article",
        } },
        .{ .items = &[_][]const u8{ "K", "web" } },
        .{ .items = &[_][]const u8{
            "P",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        } },
        .{ .items = &[_][]const u8{
            "i",
            "https://example.com/article",
        } },
        .{ .items = &[_][]const u8{ "k", "web" } },
        .{ .items = &[_][]const u8{
            "p",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        } },
    };

    const parsed = try comment_parse(&comment_event(external_with_mentions[0..]));
    switch (parsed.parent) {
        .external => |parent| {
            try std.testing.expectEqualStrings("https://example.com/article", parent.value);
            try std.testing.expectEqualStrings("web", parent.external_kind);
        },
        else => return error.UnexpectedError,
    }
}
