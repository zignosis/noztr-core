const std = @import("std");

pub const WebsocketOrigin = struct {
    scheme: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,
};

pub fn parse_websocket_origin(url: []const u8) ?WebsocketOrigin {
    std.debug.assert(url.len <= std.math.maxInt(u32));
    std.debug.assert(@sizeOf(WebsocketOrigin) > 0);

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

pub fn websocket_origins_equal(left: WebsocketOrigin, right: WebsocketOrigin) bool {
    std.debug.assert(left.scheme.len > 0);
    std.debug.assert(right.scheme.len > 0);

    if (!std.ascii.eqlIgnoreCase(left.scheme, right.scheme)) {
        return false;
    }
    if (!std.ascii.eqlIgnoreCase(left.host, right.host)) {
        return false;
    }
    if (left.port != right.port) {
        return false;
    }
    if (!std.mem.eql(u8, left.path, right.path)) {
        return false;
    }
    return true;
}

const HostPort = struct {
    host: []const u8,
    port: u16,
};

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

fn parse_host_port(authority: []const u8, scheme: []const u8) ?HostPort {
    std.debug.assert(authority.len > 0);
    std.debug.assert(scheme.len > 0);

    if (authority[0] == '[') {
        return parse_bracketed_host_port(authority, scheme);
    }

    const first_colon = std.mem.indexOfScalar(u8, authority, ':');
    if (first_colon == null) {
        const default_port = default_port_for_scheme(scheme) orelse return null;
        return .{ .host = authority, .port = default_port };
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
        const default_port = default_port_for_scheme(scheme) orelse return null;
        return .{ .host = host, .port = default_port };
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
