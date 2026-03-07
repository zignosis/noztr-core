const std = @import("std");
const nip01_event = @import("nip01_event.zig");

pub const AuthError = error{
    ChallengeEmpty,
    ChallengeTooLong,
    RelayUrlMismatch,
    ChallengeMismatch,
    InvalidAuthEventKind,
    MissingRelayTag,
    MissingChallengeTag,
    DuplicateRequiredTag,
    FutureTimestamp,
    StaleTimestamp,
    InvalidSignature,
    BackendUnavailable,
    PubkeySetFull,
};

pub const auth_event_kind: u32 = 22242;
pub const challenge_max_bytes: u8 = 64;
pub const authenticated_pubkeys_max: u16 = 64;

pub const AuthState = struct {
    challenge: [challenge_max_bytes]u8 = [_]u8{0} ** challenge_max_bytes,
    challenge_len: u8 = 0,
    authenticated_pubkeys: [authenticated_pubkeys_max][32]u8 = [_][32]u8{[_]u8{0} ** 32} **
        authenticated_pubkeys_max,
    authenticated_count: u16 = 0,
};

pub fn auth_state_init(state: *AuthState) void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(authenticated_pubkeys_max > 0);

    state.* = AuthState{};
}

pub fn auth_state_set_challenge(
    state: *AuthState,
    challenge: []const u8,
) error{ ChallengeEmpty, ChallengeTooLong }!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(challenge_max_bytes == 64);

    if (challenge.len == 0) {
        return error.ChallengeEmpty;
    }
    if (challenge.len > challenge_max_bytes) {
        return error.ChallengeTooLong;
    }

    state.challenge_len = @intCast(challenge.len);
    @memset(state.challenge[0..], 0);
    @memcpy(state.challenge[0..challenge.len], challenge);
    @memset(state.authenticated_pubkeys[0..], [_]u8{0} ** 32);
    state.authenticated_count = 0;
}

pub fn auth_validate_event(
    auth_event: *const nip01_event.Event,
    expected_relay: []const u8,
    expected_challenge: []const u8,
    now_unix_seconds: u64,
    window_seconds: u32,
) AuthError!void {
    std.debug.assert(auth_event.created_at <= std.math.maxInt(u64));
    std.debug.assert(window_seconds <= std.math.maxInt(u32));

    if (auth_event.kind != auth_event_kind) {
        return error.InvalidAuthEventKind;
    }
    const relay_value = try find_required_tag_value_unique(auth_event, "relay") orelse {
        return error.MissingRelayTag;
    };
    const challenge_value = try find_required_tag_value_unique(auth_event, "challenge") orelse {
        return error.MissingChallengeTag;
    };
    if (!relay_urls_match(relay_value, expected_relay)) {
        return error.RelayUrlMismatch;
    }
    if (!std.mem.eql(u8, challenge_value, expected_challenge)) {
        return error.ChallengeMismatch;
    }
    try validate_timestamp_window(auth_event.created_at, now_unix_seconds, window_seconds);
    nip01_event.event_verify(auth_event) catch |verify_error| {
        return map_event_verify_error(verify_error);
    };
}

pub fn auth_state_accept_event(
    state: *AuthState,
    auth_event: *const nip01_event.Event,
    expected_relay: []const u8,
    now_unix_seconds: u64,
    window_seconds: u32,
) AuthError!void {
    std.debug.assert(@intFromPtr(state) != 0);
    std.debug.assert(state.authenticated_count <= authenticated_pubkeys_max);

    if (state.challenge_len == 0) {
        return error.ChallengeMismatch;
    }
    const challenge = state.challenge[0..state.challenge_len];
    try auth_validate_event(
        auth_event,
        expected_relay,
        challenge,
        now_unix_seconds,
        window_seconds,
    );
    if (auth_state_is_pubkey_authenticated(state, &auth_event.pubkey)) {
        return;
    }
    if (state.authenticated_count == authenticated_pubkeys_max) {
        return error.PubkeySetFull;
    }

    state.authenticated_pubkeys[state.authenticated_count] = auth_event.pubkey;
    state.authenticated_count += 1;
}

pub fn auth_state_is_pubkey_authenticated(state: *const AuthState, pubkey: *const [32]u8) bool {
    std.debug.assert(state.authenticated_count <= authenticated_pubkeys_max);
    std.debug.assert(pubkey[0] <= 255);

    var index: usize = 0;
    while (index < state.authenticated_count) : (index += 1) {
        if (std.mem.eql(u8, &state.authenticated_pubkeys[index], pubkey)) {
            return true;
        }
    }
    return false;
}

fn find_required_tag_value_unique(
    event: *const nip01_event.Event,
    key: []const u8,
) error{DuplicateRequiredTag}!?[]const u8 {
    std.debug.assert(key.len > 0);
    std.debug.assert(event.tags.len <= std.math.maxInt(u16));

    var matched_value: ?[]const u8 = null;
    var tag_index: usize = 0;
    while (tag_index < event.tags.len) : (tag_index += 1) {
        const tag = event.tags[tag_index];
        if (tag.items.len < 2) {
            continue;
        }
        if (!std.mem.eql(u8, tag.items[0], key)) {
            continue;
        }
        if (matched_value == null) {
            matched_value = tag.items[1];
            continue;
        }
        return error.DuplicateRequiredTag;
    }
    return matched_value;
}

fn validate_timestamp_window(
    created_at: u64,
    now_unix_seconds: u64,
    window_seconds: u32,
) AuthError!void {
    std.debug.assert(created_at <= std.math.maxInt(u64));
    std.debug.assert(window_seconds <= std.math.maxInt(u32));

    if (created_at > now_unix_seconds) {
        return error.FutureTimestamp;
    }

    const diff = now_unix_seconds - created_at;
    if (diff > window_seconds) {
        return error.StaleTimestamp;
    }
}

fn map_event_verify_error(verify_error: nip01_event.EventVerifyError) AuthError {
    std.debug.assert(@intFromError(verify_error) >= 0);
    std.debug.assert(!@inComptime());

    return switch (verify_error) {
        error.InvalidId => error.InvalidSignature,
        error.InvalidSignature => error.InvalidSignature,
        error.InvalidPubkey => error.InvalidSignature,
        error.BackendUnavailable => error.BackendUnavailable,
    };
}

fn force_auth_verify_mapping(verify_error: nip01_event.EventVerifyError) AuthError!void {
    std.debug.assert(@intFromError(verify_error) >= 0);
    std.debug.assert(!@inComptime());

    return map_event_verify_error(verify_error);
}

const RelayOrigin = struct {
    scheme: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,
};

fn relay_urls_match(left: []const u8, right: []const u8) bool {
    std.debug.assert(left.len <= std.math.maxInt(u32));
    std.debug.assert(right.len <= std.math.maxInt(u32));

    if (left.len == 0) {
        return false;
    }
    if (right.len == 0) {
        return false;
    }

    const left_origin = parse_relay_origin(left) orelse return false;
    const right_origin = parse_relay_origin(right) orelse return false;
    if (!std.ascii.eqlIgnoreCase(left_origin.scheme, right_origin.scheme)) {
        return false;
    }
    if (!std.ascii.eqlIgnoreCase(left_origin.host, right_origin.host)) {
        return false;
    }
    if (left_origin.port != right_origin.port) {
        return false;
    }
    if (!std.mem.eql(u8, left_origin.path, right_origin.path)) {
        return false;
    }
    return true;
}

fn parse_relay_origin(url: []const u8) ?RelayOrigin {
    std.debug.assert(url.len <= std.math.maxInt(u32));
    std.debug.assert(challenge_max_bytes == 64);

    if (url.len == 0) {
        return null;
    }

    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;
    if (scheme_end == 0) {
        return null;
    }
    const scheme = url[0..scheme_end];
    if (!scheme_is_websocket(scheme)) {
        return null;
    }
    const authority_start = scheme_end + 3;
    if (authority_start >= url.len) {
        return null;
    }

    const authority_end = find_authority_end(url, authority_start);
    const authority = url[authority_start..authority_end];
    if (authority.len == 0) {
        return null;
    }
    const host_port = parse_host_port(authority, scheme) orelse return null;
    const path = parse_url_path(url, authority_end);
    return .{ .scheme = scheme, .host = host_port.host, .port = host_port.port, .path = path };
}

fn find_authority_end(url: []const u8, authority_start: usize) usize {
    std.debug.assert(authority_start < url.len);
    std.debug.assert(url.len > 0);

    var index: usize = authority_start;
    while (index < url.len) : (index += 1) {
        const byte = url[index];
        if (byte == '/') {
            return index;
        }
        if (byte == '?') {
            return index;
        }
        if (byte == '#') {
            return index;
        }
    }
    return url.len;
}

fn parse_url_path(url: []const u8, authority_end: usize) []const u8 {
    std.debug.assert(authority_end <= url.len);
    std.debug.assert(url.len > 0);

    if (authority_end == url.len) {
        return "/";
    }
    const first_after_authority = url[authority_end];
    if (first_after_authority != '/') {
        return "/";
    }

    const path_end = find_path_end(url, authority_end);
    return url[authority_end..path_end];
}

fn find_path_end(url: []const u8, path_start: usize) usize {
    std.debug.assert(path_start < url.len);
    std.debug.assert(url[path_start] == '/');

    var index: usize = path_start;
    while (index < url.len) : (index += 1) {
        const byte = url[index];
        if (byte == '?') {
            return index;
        }
        if (byte == '#') {
            return index;
        }
    }
    return url.len;
}

const HostPort = struct {
    host: []const u8,
    port: u16,
};

fn parse_host_port(authority: []const u8, scheme: []const u8) ?HostPort {
    std.debug.assert(authority.len > 0);
    std.debug.assert(scheme.len > 0);

    if (authority[0] == '[') {
        return parse_bracketed_host_port(authority, scheme);
    }

    const first_colon = std.mem.indexOfScalar(u8, authority, ':');
    if (first_colon == null) {
        const port_default = default_port_for_scheme(scheme) orelse return null;
        return .{ .host = authority, .port = port_default };
    }

    if (find_second_colon(authority, first_colon.?) != null) {
        return null;
    }

    const colon_index = first_colon.?;
    if (colon_index == 0) {
        return null;
    }
    if (colon_index + 1 >= authority.len) {
        return null;
    }

    const host = authority[0..colon_index];
    const port_text = authority[colon_index + 1 ..];
    const port = std.fmt.parseUnsigned(u16, port_text, 10) catch return null;
    return .{ .host = host, .port = port };
}

fn find_second_colon(authority: []const u8, first_colon: usize) ?usize {
    std.debug.assert(authority.len > 0);
    std.debug.assert(first_colon < authority.len);

    var index: usize = first_colon + 1;
    while (index < authority.len) : (index += 1) {
        if (authority[index] == ':') {
            return index;
        }
    }
    return null;
}

fn parse_bracketed_host_port(authority: []const u8, scheme: []const u8) ?HostPort {
    std.debug.assert(authority.len > 0);
    std.debug.assert(authority[0] == '[');

    const closing_bracket = std.mem.indexOfScalar(u8, authority, ']') orelse return null;
    if (closing_bracket == 1) {
        return null;
    }

    const host = authority[0 .. closing_bracket + 1];
    if (closing_bracket + 1 == authority.len) {
        const port_default = default_port_for_scheme(scheme) orelse return null;
        return .{ .host = host, .port = port_default };
    }
    if (authority[closing_bracket + 1] != ':') {
        return null;
    }
    if (closing_bracket + 2 >= authority.len) {
        return null;
    }

    const port_text = authority[closing_bracket + 2 ..];
    const port = std.fmt.parseUnsigned(u16, port_text, 10) catch return null;
    return .{ .host = host, .port = port };
}

fn scheme_is_websocket(scheme: []const u8) bool {
    std.debug.assert(scheme.len > 0);
    std.debug.assert(scheme.len <= std.math.maxInt(u16));

    if (std.ascii.eqlIgnoreCase(scheme, "ws")) {
        return true;
    }
    if (std.ascii.eqlIgnoreCase(scheme, "wss")) {
        return true;
    }
    return false;
}

fn default_port_for_scheme(scheme: []const u8) ?u16 {
    std.debug.assert(scheme.len > 0);
    std.debug.assert(@sizeOf(u16) == 2);

    if (std.ascii.eqlIgnoreCase(scheme, "ws")) {
        return 80;
    }
    if (std.ascii.eqlIgnoreCase(scheme, "wss")) {
        return 443;
    }
    return null;
}

const AuthTagFixture = struct {
    relay_items: [2][]const u8,
    challenge_items: [2][]const u8,
    tags: [2]nip01_event.EventTag,
};

fn auth_tag_fixture_init(
    fixture: *AuthTagFixture,
    relay: []const u8,
    challenge: []const u8,
) void {
    std.debug.assert(@intFromPtr(fixture) != 0);
    std.debug.assert(relay.len > 0);

    fixture.* = .{
        .relay_items = .{ "relay", relay },
        .challenge_items = .{ "challenge", challenge },
        .tags = undefined,
    };
    fixture.tags[0] = .{ .items = fixture.relay_items[0..] };
    fixture.tags[1] = .{ .items = fixture.challenge_items[0..] };
    std.debug.assert(challenge.len > 0);
}

test "auth validates event and accepts state" {
    var state = AuthState{};
    auth_state_init(&state);
    try auth_state_set_challenge(&state, "challenge-1");

    var fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture, "wss://relay.example.com/path", "challenge-1");
    var event = build_signed_auth_event(fixture.tags[0..], 10_000);

    try auth_validate_event(&event, "wss://relay.example.com/path", "challenge-1", 10_010, 60);
    try auth_state_accept_event(&state, &event, "wss://relay.example.com/path", 10_010, 60);
    try std.testing.expect(auth_state_is_pubkey_authenticated(&state, &event.pubkey));
    try std.testing.expectEqual(@as(u16, 1), state.authenticated_count);
}

test "auth accepts relay normalization and duplicate pubkey" {
    var state = AuthState{};
    auth_state_init(&state);
    try auth_state_set_challenge(&state, "challenge-1");

    var fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(
        &fixture,
        "WSS://RELAY.EXAMPLE.COM:443/path/Exact?x=1#frag",
        "challenge-1",
    );
    var event = build_signed_auth_event(fixture.tags[0..], 2_000);
    try auth_state_accept_event(&state, &event, "wss://relay.example.com/path/Exact", 2_001, 60);
    try auth_state_accept_event(&state, &event, "wss://relay.example.com/path/Exact", 2_001, 60);

    try std.testing.expect(auth_state_is_pubkey_authenticated(&state, &event.pubkey));
    try std.testing.expectEqual(@as(u16, 1), state.authenticated_count);
}

test "auth accepts bracketed ipv6 relay authorities" {
    var state = AuthState{};
    auth_state_init(&state);
    try auth_state_set_challenge(&state, "challenge-ipv6");

    var fixture_explicit: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture_explicit, "wss://[2001:db8::1]:443/path", "challenge-ipv6");
    var event_explicit = build_signed_auth_event(fixture_explicit.tags[0..], 4_000);
    try auth_validate_event(
        &event_explicit,
        "wss://[2001:db8::1]/path?ignored=1#fragment",
        "challenge-ipv6",
        4_001,
        60,
    );
    try auth_state_accept_event(&state, &event_explicit, "wss://[2001:db8::1]/path", 4_001, 60);

    var fixture_default: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture_default, "ws://[::1]", "challenge-ipv6");
    var event_default = build_signed_auth_event(fixture_default.tags[0..], 4_100);
    try auth_validate_event(&event_default, "ws://[::1]:80", "challenge-ipv6", 4_101, 60);
    try std.testing.expectError(
        error.RelayUrlMismatch,
        auth_validate_event(&event_default, "ws://[::1]:81", "challenge-ipv6", 4_101, 60),
    );
}

test "auth rejects same origin with different relay path" {
    var fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture, "wss://relay.example.com/alpha", "challenge-1");
    const event = build_signed_auth_event(fixture.tags[0..], 2_300);

    try std.testing.expectError(
        error.RelayUrlMismatch,
        auth_validate_event(&event, "wss://relay.example.com/beta", "challenge-1", 2_301, 60),
    );
}

test "auth treats missing relay path and slash as equivalent" {
    var fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture, "wss://relay.example.com", "challenge-1");
    const event_missing = build_signed_auth_event(fixture.tags[0..], 2_320);

    try auth_validate_event(&event_missing, "wss://relay.example.com/", "challenge-1", 2_321, 60);

    auth_tag_fixture_init(&fixture, "wss://relay.example.com/", "challenge-1");
    const event_slash = build_signed_auth_event(fixture.tags[0..], 2_330);
    try auth_validate_event(&event_slash, "wss://relay.example.com", "challenge-1", 2_331, 60);
}

test "relay origin rejects empty authority segment" {
    try std.testing.expect(parse_relay_origin("wss:///path") == null);
}

test "relay origin rejects non-websocket schemes" {
    try std.testing.expect(parse_relay_origin("http://relay.example.com") == null);
    try std.testing.expect(parse_relay_origin("https://relay.example.com") == null);
}

test "relay origin rejects unbracketed ipv6 authority" {
    try std.testing.expect(parse_relay_origin("ws://2001:db8::1") == null);

    var fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture, "ws://2001:db8::1", "challenge-ipv6-unbracketed");
    const event = build_signed_auth_event(fixture.tags[0..], 4_200);
    try std.testing.expectError(
        error.RelayUrlMismatch,
        auth_validate_event(&event, "ws://2001:db8::1", "challenge-ipv6-unbracketed", 4_201, 60),
    );
}

test "auth empty relay tag value returns relay mismatch" {
    const relay_items = [_][]const u8{ "relay", "" };
    const challenge_items = [_][]const u8{ "challenge", "challenge-1" };
    const tags = [_]nip01_event.EventTag{
        .{ .items = relay_items[0..] },
        .{ .items = challenge_items[0..] },
    };
    const event = build_signed_auth_event(tags[0..], 2_200);

    try std.testing.expectError(
        error.RelayUrlMismatch,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 2_201, 60),
    );
}

test "auth rejects http and https relay origins as relay mismatch" {
    var fixture_http: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture_http, "http://relay.example.com", "challenge-1");
    const event_http = build_signed_auth_event(fixture_http.tags[0..], 2_210);
    try std.testing.expectError(
        error.RelayUrlMismatch,
        auth_validate_event(&event_http, "http://relay.example.com", "challenge-1", 2_211, 60),
    );

    var fixture_https: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture_https, "https://relay.example.com", "challenge-1");
    const event_https = build_signed_auth_event(fixture_https.tags[0..], 2_220);
    try std.testing.expectError(
        error.RelayUrlMismatch,
        auth_validate_event(&event_https, "https://relay.example.com", "challenge-1", 2_221, 60),
    );
}

test "auth challenge rotation clears authenticated identities" {
    var state = AuthState{};
    auth_state_init(&state);
    try auth_state_set_challenge(&state, "challenge-old");

    var old_fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&old_fixture, "wss://relay.example.com", "challenge-old");
    var old_event = build_signed_auth_event(old_fixture.tags[0..], 3_000);
    try auth_state_accept_event(&state, &old_event, "wss://relay.example.com", 3_001, 60);
    try std.testing.expect(auth_state_is_pubkey_authenticated(&state, &old_event.pubkey));
    try std.testing.expectEqual(@as(u16, 1), state.authenticated_count);

    try auth_state_set_challenge(&state, "challenge-new");
    try std.testing.expect(!auth_state_is_pubkey_authenticated(&state, &old_event.pubkey));
    try std.testing.expectEqual(@as(u16, 0), state.authenticated_count);
    try std.testing.expect(std.mem.allEqual(u8, state.authenticated_pubkeys[0][0..], 0));

    try std.testing.expectError(
        error.ChallengeMismatch,
        auth_state_accept_event(&state, &old_event, "wss://relay.example.com", 3_000, 60),
    );

    var new_fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&new_fixture, "wss://relay.example.com", "challenge-new");
    var new_event = build_signed_auth_event(new_fixture.tags[0..], 3_000);
    try auth_state_accept_event(&state, &new_event, "wss://relay.example.com", 3_001, 60);
    try std.testing.expect(auth_state_is_pubkey_authenticated(&state, &new_event.pubkey));
}

test "auth forcing errors for kind, missing tags, relay mismatch, duplicate tags" {
    var fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture, "wss://relay.example.com", "challenge-1");
    var event = build_signed_auth_event(fixture.tags[0..], 1_000);

    event.kind = 1;
    try std.testing.expectError(
        error.InvalidAuthEventKind,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 1_000, 60),
    );

    event = build_signed_auth_event(fixture.tags[0..], 1_000);
    const only_challenge_items = [_][]const u8{ "challenge", "challenge-1" };
    const only_challenge_tags = [_]nip01_event.EventTag{
        .{ .items = only_challenge_items[0..] },
    };
    event.tags = only_challenge_tags[0..];
    try std.testing.expectError(
        error.MissingRelayTag,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 1_000, 60),
    );

    event = build_signed_auth_event(fixture.tags[0..], 1_000);
    const only_relay_items = [_][]const u8{ "relay", "wss://relay.example.com" };
    const only_relay_tags = [_]nip01_event.EventTag{.{ .items = only_relay_items[0..] }};
    event.tags = only_relay_tags[0..];
    try std.testing.expectError(
        error.MissingChallengeTag,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 1_000, 60),
    );

    event = build_signed_auth_event(fixture.tags[0..], 1_000);
    try std.testing.expectError(
        error.RelayUrlMismatch,
        auth_validate_event(&event, "wss://other.example.com", "challenge-1", 1_000, 60),
    );

    const duplicate_relay_first = [_][]const u8{ "relay", "wss://relay.example.com" };
    const duplicate_relay_second = [_][]const u8{ "relay", "wss://relay.example.com" };
    const duplicate_relay_challenge = [_][]const u8{ "challenge", "challenge-1" };
    const duplicate_relay_tags = [_]nip01_event.EventTag{
        .{ .items = duplicate_relay_first[0..] },
        .{ .items = duplicate_relay_second[0..] },
        .{ .items = duplicate_relay_challenge[0..] },
    };
    event = build_signed_auth_event(duplicate_relay_tags[0..], 1_000);
    try std.testing.expectError(
        error.DuplicateRequiredTag,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 1_000, 60),
    );

    const duplicate_challenge_relay = [_][]const u8{ "relay", "wss://relay.example.com" };
    const duplicate_challenge_first = [_][]const u8{ "challenge", "challenge-1" };
    const duplicate_challenge_second = [_][]const u8{ "challenge", "challenge-1" };
    const duplicate_challenge_tags = [_]nip01_event.EventTag{
        .{ .items = duplicate_challenge_relay[0..] },
        .{ .items = duplicate_challenge_first[0..] },
        .{ .items = duplicate_challenge_second[0..] },
    };
    event = build_signed_auth_event(duplicate_challenge_tags[0..], 1_000);
    try std.testing.expectError(
        error.DuplicateRequiredTag,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 1_000, 60),
    );
}

test "auth forcing timestamp and verification mapping errors" {
    var fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture, "wss://relay.example.com", "challenge-1");
    var event = build_signed_auth_event(fixture.tags[0..], 1_000);

    try std.testing.expectError(
        error.FutureTimestamp,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 999, 60),
    );

    try std.testing.expectError(
        error.StaleTimestamp,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 1_200, 60),
    );

    event.sig[0] ^= 1;
    try std.testing.expectError(
        error.InvalidSignature,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-1", 1_000, 60),
    );

    try std.testing.expectError(
        error.BackendUnavailable,
        force_auth_verify_mapping(error.BackendUnavailable),
    );
    try std.testing.expect(
        map_event_verify_error(error.BackendUnavailable) != error.InvalidSignature,
    );
}

test "auth forcing errors for challenge, challenge bounds, pubkey set" {
    var fixture: AuthTagFixture = undefined;
    auth_tag_fixture_init(&fixture, "wss://relay.example.com", "challenge-1");
    var event = build_signed_auth_event(fixture.tags[0..], 1_000);

    try std.testing.expectError(
        error.ChallengeMismatch,
        auth_validate_event(&event, "wss://relay.example.com", "challenge-2", 1_000, 60),
    );

    var state = AuthState{};
    auth_state_init(&state);
    try std.testing.expectError(error.ChallengeEmpty, auth_state_set_challenge(&state, ""));
    const oversized = [_]u8{'a'} ** (challenge_max_bytes + 1);
    try std.testing.expectError(
        error.ChallengeTooLong,
        auth_state_set_challenge(&state, oversized[0..]),
    );

    try auth_state_set_challenge(&state, "challenge-1");
    event = build_signed_auth_event(fixture.tags[0..], 1_000);
    @memset(state.authenticated_pubkeys[0..], [_]u8{0xFF} ** 32);
    state.authenticated_count = authenticated_pubkeys_max;
    try std.testing.expectError(
        error.PubkeySetFull,
        auth_state_accept_event(&state, &event, "wss://relay.example.com", 1_001, 60),
    );
}

fn build_signed_auth_event(
    tags: []const nip01_event.EventTag,
    created_at: u64,
) nip01_event.Event {
    std.debug.assert(tags.len >= 2);
    std.debug.assert(created_at <= std.math.maxInt(u64));

    var secret_key: [32]u8 = [_]u8{0} ** 32;
    secret_key[31] = 3;
    var pubkey: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(
        &pubkey,
        "F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9",
    ) catch unreachable;

    var event = nip01_event.Event{
        .id = [_]u8{0} ** 32,
        .pubkey = pubkey,
        .sig = [_]u8{0} ** 64,
        .kind = auth_event_kind,
        .created_at = created_at,
        .content = "",
        .tags = tags,
    };
    event.id = nip01_event.event_compute_id(&event);
    @import("crypto/secp256k1_backend.zig").sign_schnorr_signature(
        &secret_key,
        &event.id,
        &event.sig,
    ) catch unreachable;
    return event;
}
