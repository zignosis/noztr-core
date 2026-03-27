const std = @import("std");
const limits = @import("limits.zig");
const nip01_event = @import("nip01_event.zig");

pub const chess_pgn_kind: u32 = 64;

pub const ChessPgnError = error{
    UnsupportedKind,
    DuplicateAltTag,
    InvalidAltTag,
    InvalidContent,
    InvalidPgn,
};

pub const Pgn = struct {
    content: []const u8,
    alt: ?[]const u8 = null,
    game_count: u16 = 0,
};

pub const TagBuilder = struct {
    items: [2][]const u8 = undefined,
    item_count: u8 = 0,

    pub fn as_event_tag(self: *const TagBuilder) nip01_event.EventTag {
        std.debug.assert(self.item_count > 0);
        std.debug.assert(self.item_count <= self.items.len);

        return .{ .items = self.items[0..self.item_count] };
    }
};

const Scanner = struct {
    content: []const u8,
    index: u32 = 0,

    fn done(self: *const Scanner) bool {
        std.debug.assert(self.index <= self.content.len);
        std.debug.assert(self.content.len <= limits.content_bytes_max);

        return self.index == self.content.len;
    }

    fn peek(self: *const Scanner) ?u8 {
        std.debug.assert(self.index <= self.content.len);
        std.debug.assert(self.content.len <= limits.content_bytes_max);

        if (self.done()) return null;
        return self.content[self.index];
    }

    fn advance(self: *Scanner) void {
        std.debug.assert(!self.done());
        std.debug.assert(self.index < self.content.len);

        self.index += 1;
    }
};

/// Returns whether the event kind is supported by the strict NIP-64 helper.
pub fn is_supported(event: *const nip01_event.Event) bool {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.kind <= limits.kind_max);

    return event.kind == chess_pgn_kind;
}

/// Extracts bounded NIP-64 metadata and validates the PGN database content.
pub fn extract(event: *const nip01_event.Event) ChessPgnError!Pgn {
    std.debug.assert(@intFromPtr(event) != 0);
    std.debug.assert(event.tags.len <= limits.tags_max);

    if (event.kind != chess_pgn_kind) return error.UnsupportedKind;
    const game_count = try validate(event.content);

    var info = Pgn{
        .content = event.content,
        .game_count = game_count,
    };
    for (event.tags) |tag| {
        try apply_tag(tag, &info);
    }
    return info;
}

/// Validates the provided PGN database content and returns the bounded game count.
pub fn validate(content: []const u8) ChessPgnError!u16 {
    try validate_content_text(content);

    var scanner = Scanner{ .content = content };
    var game_count: u16 = 0;
    skip_ascii_whitespace(&scanner);
    if (scanner.done()) return error.InvalidPgn;

    while (!scanner.done()) {
        try parse_game(&scanner);
        game_count += 1;
        skip_ascii_whitespace(&scanner);
    }
    return game_count;
}

/// Builds a canonical optional `alt` tag for chess PGN notes.
pub fn build_alt_tag(
    output: *TagBuilder,
    alt: []const u8,
) ChessPgnError!nip01_event.EventTag {
    std.debug.assert(@intFromPtr(output) != 0);
    std.debug.assert(output.items.len == 2);

    output.items[0] = "alt";
    output.items[1] = parse_nonempty_utf8(alt) catch return error.InvalidAltTag;
    output.item_count = 2;
    return output.as_event_tag();
}

fn apply_tag(tag: nip01_event.EventTag, info: *Pgn) ChessPgnError!void {
    std.debug.assert(@intFromPtr(info) != 0);
    std.debug.assert(tag.items.len <= limits.tag_items_max);

    if (tag.items.len == 0) return;
    if (!std.mem.eql(u8, tag.items[0], "alt")) return;
    if (info.alt != null) return error.DuplicateAltTag;
    info.alt = parse_alt_tag(tag) catch return error.InvalidAltTag;
}

fn parse_alt_tag(tag: nip01_event.EventTag) error{InvalidValue}![]const u8 {
    std.debug.assert(tag.items.len <= limits.tag_items_max);
    std.debug.assert(limits.tag_items_max >= 2);

    if (tag.items.len != 2) return error.InvalidValue;
    return parse_nonempty_utf8(tag.items[1]) catch return error.InvalidValue;
}

fn parse_game(scanner: *Scanner) ChessPgnError!void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.content.len <= limits.content_bytes_max);

    while (scanner.peek()) |byte| {
        if (byte != '[') break;
        try parse_tag_pair(scanner);
        skip_ascii_whitespace(scanner);
    }
    try parse_movetext(scanner);
}

fn parse_tag_pair(scanner: *Scanner) ChessPgnError!void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.peek().? == '[');

    scanner.advance();
    skip_horizontal_whitespace(scanner);
    try parse_symbol(scanner);
    try require_horizontal_whitespace(scanner);
    try parse_quoted_value(scanner);
    skip_horizontal_whitespace(scanner);
    if (scanner.peek() != ']') return error.InvalidPgn;
    scanner.advance();
    if (scanner.peek()) |byte| {
        if (!std.ascii.isWhitespace(byte)) return error.InvalidPgn;
    }
}

fn parse_movetext(scanner: *Scanner) ChessPgnError!void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.content.len <= limits.content_bytes_max);

    var variation_depth: u16 = 0;
    while (scanner.peek()) |byte| {
        if (std.ascii.isWhitespace(byte)) {
            skip_ascii_whitespace(scanner);
            continue;
        }
        if (byte == '{') {
            try consume_brace_comment(scanner);
            continue;
        }
        if (byte == ';') {
            consume_line_comment(scanner);
            continue;
        }
        if (byte == '(') {
            variation_depth += 1;
            scanner.advance();
            continue;
        }
        if (byte == ')') {
            if (variation_depth == 0) return error.InvalidPgn;
            variation_depth -= 1;
            scanner.advance();
            continue;
        }
        if (byte == '[' or byte == ']' or byte == '"') return error.InvalidPgn;
        const token = try parse_movetext_token(scanner);
        if (!is_valid_movetext_token(token)) return error.InvalidPgn;
        if (variation_depth == 0 and is_termination_marker(token)) return;
    }
    return error.InvalidPgn;
}

fn parse_symbol(scanner: *Scanner) ChessPgnError!void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.content.len <= limits.content_bytes_max);

    const first = scanner.peek() orelse return error.InvalidPgn;
    if (!is_symbol_start(first)) return error.InvalidPgn;
    scanner.advance();
    while (scanner.peek()) |byte| {
        if (!is_symbol_continue(byte)) break;
        scanner.advance();
    }
}

fn parse_quoted_value(scanner: *Scanner) ChessPgnError!void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.content.len <= limits.content_bytes_max);

    if (scanner.peek() != '"') return error.InvalidPgn;
    scanner.advance();
    while (scanner.peek()) |byte| {
        if (byte == '"') {
            scanner.advance();
            return;
        }
        if (byte == '\\') {
            scanner.advance();
            if (scanner.done()) return error.InvalidPgn;
        }
        scanner.advance();
    }
    return error.InvalidPgn;
}

fn parse_movetext_token(scanner: *Scanner) ChessPgnError![]const u8 {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.content.len <= limits.content_bytes_max);

    const start = scanner.index;
    while (scanner.peek()) |byte| {
        if (is_movetext_delimiter(byte)) break;
        scanner.advance();
    }
    if (scanner.index == start) return error.InvalidPgn;
    return scanner.content[start..scanner.index];
}

fn consume_brace_comment(scanner: *Scanner) ChessPgnError!void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.peek().? == '{');

    scanner.advance();
    while (scanner.peek()) |byte| {
        scanner.advance();
        if (byte == '}') return;
    }
    return error.InvalidPgn;
}

fn consume_line_comment(scanner: *Scanner) void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.peek().? == ';');

    while (scanner.peek()) |byte| {
        scanner.advance();
        if (byte == '\n') return;
    }
}

fn require_horizontal_whitespace(scanner: *Scanner) ChessPgnError!void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.content.len <= limits.content_bytes_max);

    const byte = scanner.peek() orelse return error.InvalidPgn;
    if (!is_horizontal_whitespace(byte)) return error.InvalidPgn;
    skip_horizontal_whitespace(scanner);
}

fn skip_horizontal_whitespace(scanner: *Scanner) void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.content.len <= limits.content_bytes_max);

    while (scanner.peek()) |byte| {
        if (!is_horizontal_whitespace(byte)) break;
        scanner.advance();
    }
}

fn skip_ascii_whitespace(scanner: *Scanner) void {
    std.debug.assert(@intFromPtr(scanner) != 0);
    std.debug.assert(scanner.content.len <= limits.content_bytes_max);

    while (scanner.peek()) |byte| {
        if (!std.ascii.isWhitespace(byte)) break;
        scanner.advance();
    }
}

fn validate_content_text(content: []const u8) ChessPgnError!void {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (content.len > limits.content_bytes_max) return error.InvalidContent;
    if (content.len == 0) return error.InvalidContent;
    if (!std.unicode.utf8ValidateSlice(content)) return error.InvalidContent;
}

fn parse_nonempty_utf8(text: []const u8) error{InvalidUtf8}![]const u8 {
    std.debug.assert(limits.tag_item_bytes_max <= limits.content_bytes_max);

    if (text.len > limits.tag_item_bytes_max) return error.InvalidUtf8;
    if (text.len == 0) return error.InvalidUtf8;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
    return text;
}

fn is_horizontal_whitespace(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(@sizeOf(u8) == 1);

    return byte == ' ' or byte == '\t' or byte == '\r';
}

fn is_symbol_start(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(@sizeOf(u8) == 1);

    return std.ascii.isAlphabetic(byte);
}

fn is_symbol_continue(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(@sizeOf(u8) == 1);

    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn is_movetext_delimiter(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(@sizeOf(u8) == 1);

    return std.ascii.isWhitespace(byte) or
        byte == '{' or byte == '}' or
        byte == ';' or byte == '(' or
        byte == ')' or byte == '[' or
        byte == ']' or byte == '"';
}

fn is_termination_marker(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (std.mem.eql(u8, token, "*")) return true;
    if (std.mem.eql(u8, token, "1-0")) return true;
    if (std.mem.eql(u8, token, "0-1")) return true;
    return std.mem.eql(u8, token, "1/2-1/2");
}

fn is_valid_movetext_token(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (is_termination_marker(token)) return true;
    if (is_move_number_token(token)) return true;
    if (is_annotation_token(token)) return true;
    if (is_numeric_annotation_glyph(token)) return true;
    if (is_castling_token(token)) return true;
    return is_san_token(token);
}

fn is_move_number_token(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (std.mem.eql(u8, token, "...")) return true;
    if (!std.ascii.isDigit(token[0])) return false;
    var index: u32 = 0;
    while (index < token.len and std.ascii.isDigit(token[index])) {
        index += 1;
    }
    if (index == token.len) return false;
    while (index < token.len and token[index] == '.') {
        index += 1;
    }
    return index == token.len;
}

fn is_annotation_token(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (token.len == 0 or token.len > 2) return false;
    for (token) |byte| {
        if (byte != '!' and byte != '?') return false;
    }
    return true;
}

fn is_numeric_annotation_glyph(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (token.len < 2 or token[0] != '$') return false;
    for (token[1..]) |byte| {
        if (!std.ascii.isDigit(byte)) return false;
    }
    return true;
}

fn is_castling_token(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (token.len < 3) return false;
    const core = trim_suffix_markers(token);
    if (std.mem.eql(u8, core, "O-O")) return true;
    return std.mem.eql(u8, core, "O-O-O");
}

fn is_san_token(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (token.len == 0) return false;
    if (std.mem.eql(u8, token, "--")) return true;

    const core = trim_suffix_markers(token);
    if (core.len == 0) return false;
    if (is_piece_move(core)) return true;
    return is_pawn_move(core);
}

fn trim_suffix_markers(token: []const u8) []const u8 {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    var end = token.len;
    while (end > 0) {
        const byte = token[end - 1];
        if (byte != '+' and byte != '#' and byte != '!' and byte != '?') break;
        end -= 1;
    }
    return token[0..end];
}

fn is_piece_move(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (token.len < 3) return false;
    if (!is_piece_letter(token[0])) return false;
    if (!is_square(token[token.len - 2 ..])) return false;

    var middle = token[1 .. token.len - 2];
    if (middle.len > 0 and middle[middle.len - 1] == 'x') {
        middle = middle[0 .. middle.len - 1];
    }
    if (middle.len > 2) return false;
    if (middle.len == 2) {
        if (!is_file(middle[0]) and !is_rank(middle[0])) return false;
        if (!is_file(middle[1]) and !is_rank(middle[1])) return false;
        if (is_file(middle[0]) == is_file(middle[1])) return false;
    }
    if (middle.len == 1) {
        if (!is_file(middle[0]) and !is_rank(middle[0])) return false;
    }
    return true;
}

fn is_pawn_move(token: []const u8) bool {
    std.debug.assert(token.len <= limits.content_bytes_max);
    std.debug.assert(limits.content_bytes_max > 0);

    if (token.len < 2) return false;
    if (!is_file(token[0])) return false;
    if (token.len == 2) return is_square(token);
    if (token.len == 4 and is_square(token[0..2]) and token[2] == '=') {
        return is_promotion_piece(token[3]);
    }
    if (token.len < 4 or token[1] != 'x') return false;
    if (!is_square(token[2..4])) return false;
    if (token.len == 4) return true;
    if (token.len != 6 or token[4] != '=') return false;
    return is_promotion_piece(token[5]);
}

fn is_square(text: []const u8) bool {
    std.debug.assert(text.len <= 2);
    std.debug.assert(@sizeOf(u8) == 1);

    if (text.len != 2) return false;
    if (!is_file(text[0])) return false;
    return is_rank(text[1]);
}

fn is_file(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(@sizeOf(u8) == 1);

    return byte >= 'a' and byte <= 'h';
}

fn is_rank(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(@sizeOf(u8) == 1);

    return byte >= '1' and byte <= '8';
}

fn is_piece_letter(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(@sizeOf(u8) == 1);

    return byte == 'K' or byte == 'Q' or byte == 'R' or byte == 'B' or byte == 'N';
}

fn is_promotion_piece(byte: u8) bool {
    std.debug.assert(byte <= std.math.maxInt(u8));
    std.debug.assert(@sizeOf(u8) == 1);

    return byte == 'Q' or byte == 'R' or byte == 'B' or byte == 'N';
}

fn test_event(content: []const u8, tags: []const nip01_event.EventTag) nip01_event.Event {
    std.debug.assert(content.len <= limits.content_bytes_max);
    std.debug.assert(tags.len <= limits.tags_max);

    return .{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = chess_pgn_kind,
        .created_at = 1_700_000_000,
        .content = content,
        .tags = tags,
    };
}

test "chess PGN extract parses valid PGN note with optional alt tag" {
    const tags = [_]nip01_event.EventTag{
        .{ .items = &.{ "alt", "Fischer vs. Spassky" } },
        .{ .items = &.{ "t", "ignored" } },
    };
    const content =
        "[White \"Fischer, Robert J.\"]\n" ++
        "[Black \"Spassky, Boris V.\"]\n\n" ++
        "1. e4 e5 2. Nf3 Nc6 3. Bb5 *";
    const parsed = try extract(&test_event(content, tags[0..]));

    try std.testing.expectEqualStrings(content, parsed.content);
    try std.testing.expectEqualStrings("Fischer vs. Spassky", parsed.alt.?);
    try std.testing.expectEqual(@as(u16, 1), parsed.game_count);
    try std.testing.expect(parsed.game_count != 0);
}

test "chess PGN validate accepts minimal single and multi game databases" {
    const single = try validate("1. e4 *");
    const minimal = try validate("*");
    const multi = try validate(
        "[Event \"One\"]\n\n1. e4 1-0\n\n[Event \"Two\"]\n\n1. d4 d5 1/2-1/2",
    );

    try std.testing.expectEqual(@as(u16, 1), single);
    try std.testing.expectEqual(@as(u16, 1), minimal);
    try std.testing.expectEqual(@as(u16, 2), multi);
}

test "chess PGN validate accepts comments and variations in import format" {
    const content =
        "[Event \"Arena\"]\n\n" ++
        "1. e4 {King pawn} e5 (1... c5) 2. Nf3 $1 Nc6 ; note\n" ++
        "3. Bb5 a6 *";
    const game_count = try validate(content);

    try std.testing.expectEqual(@as(u16, 1), game_count);
    try std.testing.expect(game_count <= 1);
}

test "chess PGN builder emits canonical alt tag" {
    var alt_tag: TagBuilder = .{};
    const built = try build_alt_tag(&alt_tag, "Fischer vs. Spassky");

    try std.testing.expectEqualStrings("alt", built.items[0]);
    try std.testing.expectEqualStrings("Fischer vs. Spassky", built.items[1]);
    try std.testing.expectEqual(@as(usize, 2), built.items.len);
}

test "chess PGN builder and parser stay symmetric for canonical alt metadata" {
    var alt_tag: TagBuilder = .{};
    const tags = [_]nip01_event.EventTag{
        try build_alt_tag(&alt_tag, "friendly match"),
    };
    const parsed = try extract(&test_event("1. e4 *", tags[0..]));

    try std.testing.expectEqualStrings("friendly match", parsed.alt.?);
    try std.testing.expectEqual(@as(u16, 1), parsed.game_count);
}

test "chess PGN extract rejects malformed alt and malformed PGN content" {
    const duplicate_alt = [_]nip01_event.EventTag{
        .{ .items = &.{ "alt", "first" } },
        .{ .items = &.{ "alt", "second" } },
    };
    const invalid_alt = [_]nip01_event.EventTag{
        .{ .items = &.{ "alt", "" } },
    };

    try std.testing.expectError(
        error.DuplicateAltTag,
        extract(&test_event("1. e4 *", duplicate_alt[0..])),
    );
    try std.testing.expectError(
        error.InvalidAltTag,
        extract(&test_event("1. e4 *", invalid_alt[0..])),
    );
    try std.testing.expectError(error.InvalidPgn, validate("[Event \"One\"]\n\n1. e4"));
    try std.testing.expectError(error.InvalidPgn, validate("1. e4 {open *"));
    try std.testing.expectError(error.InvalidPgn, validate("1. e4 (1... c5 *"));
    try std.testing.expectError(error.InvalidPgn, validate("hello world *"));
    try std.testing.expectError(error.InvalidPgn, validate("not-pgn 1-0"));
}

test "chess PGN extract rejects unsupported kind invalid content and broken tag pairs" {
    const invalid_utf8 = [_]u8{0xff};
    const unsupported = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = [_]u8{0} ** 32,
        .sig = [_]u8{0} ** 64,
        .kind = 1,
        .created_at = 1_700_000_000,
        .content = "1. e4 *",
        .tags = &.{},
    };

    try std.testing.expectError(error.UnsupportedKind, extract(&unsupported));
    try std.testing.expectError(error.InvalidContent, validate(""));
    try std.testing.expectError(error.InvalidContent, validate(invalid_utf8[0..]));
    try std.testing.expectError(
        error.InvalidPgn,
        validate("[White Fischer]\n\n1. e4 *"),
    );
    try std.testing.expectError(
        error.InvalidPgn,
        validate("[White \"Fischer\"]\n\n] 1. e4 *"),
    );
    try std.testing.expectError(
        error.InvalidPgn,
        validate("[White \"Fischer\"]1. e4 *"),
    );
    try std.testing.expectError(
        error.InvalidPgn,
        validate("[White \"Fischer\"]junk *"),
    );
}
