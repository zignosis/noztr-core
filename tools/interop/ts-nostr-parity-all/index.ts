import { readFileSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";
import {
    finalizeEvent,
    getEventHash,
    getPublicKey,
    type EventTemplate,
    type UnsignedEvent,
    verifyEvent,
} from "nostr-tools/pure";
import * as nostr_tools from "nostr-tools";
import { getPow } from "nostr-tools/nip13";
import { decode, naddrEncode, noteEncode, nsecEncode, npubEncode } from "nostr-tools/nip19";
import * as nip25 from "nostr-tools/nip25";
import * as nip30 from "nostr-tools/nip30";
import { makeAuthEvent } from "nostr-tools/nip42";
import { decrypt, encrypt, getConversationKey } from "nostr-tools/nip44";
import * as nip46 from "nostr-tools/nip46";
import * as nip10 from "nostr-tools/nip10";
import * as nip06 from "nostr-tools/nip06";
import * as nip17 from "nostr-tools/nip17";
import * as nip29 from "nostr-tools/nip29";
import * as nip39 from "nostr-tools/nip39";
import { parse as parseNostrUri } from "nostr-tools/nip21";
import * as nip27 from "nostr-tools/nip27";
import * as kinds from "nostr-tools/kinds";
import { Relay, useWebSocketImplementation } from "nostr-tools/relay";

type Taxonomy =
    | "LIB_SUPPORTED"
    | "HARNESS_COVERED"
    | "NOT_COVERED_IN_THIS_PASS"
    | "LIB_UNSUPPORTED";

type Depth = "BASELINE" | "EDGE" | "DEEP";

type CheckResult = "PASS" | "FAIL" | "NOT_RUN";

type NipResult = {
    nip: string;
    taxonomy: Taxonomy;
    depth: Depth;
    result: CheckResult;
    detail?: string;
};

type Fixture = {
    id: string;
    conversation_key_hex: string;
    nonce_hex: string;
    plaintext: string;
    payload_expectation_base64: string;
};

type FixtureSet = {
    set_id: string;
    fixtures: Fixture[];
};

const FIXED_SECRET_KEY_HEX =
    "6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e";
const LOCAL_FILE = fileURLToPath(import.meta.url);
const LOCAL_DIR = dirname(LOCAL_FILE);
const NIP40_FILE_URL = pathToFileURL(
    join(LOCAL_DIR, "node_modules", "nostr-tools", "lib", "esm", "nip40.js"),
).href;

function to_bytes(value_hex: string): Uint8Array {
    if (value_hex.length % 2 !== 0) {
        throw new Error("hex input must have even length");
    }
    return Uint8Array.from(Buffer.from(value_hex, "hex"));
}

function to_bytes_32(value_hex: string): Uint8Array {
    if (value_hex.length !== 64) {
        throw new Error(`expected 32-byte hex, got ${value_hex.length / 2} bytes`);
    }
    return to_bytes(value_hex);
}

function ensure(condition: boolean, detail: string): void {
    if (!condition) {
        throw new Error(detail);
    }
}

async function push_harness_covered(
    results: NipResult[],
    nip: string,
    depth: Depth,
    check: () => void | Promise<void>,
): Promise<void> {
    try {
        await check();
        results.push({ nip, taxonomy: "HARNESS_COVERED", depth, result: "PASS" });
    } catch (error) {
        const detail = error instanceof Error ? error.message : String(error);
        results.push({
            nip,
            taxonomy: "HARNESS_COVERED",
            depth,
            result: "FAIL",
            detail,
        });
    }
}

async function import_nip40_module(): Promise<{ getExpiration: (event: unknown) => Date | undefined; isEventExpired: (event: unknown) => boolean }> {
    try {
        return await import("nostr-tools/nip40");
    } catch {
        return await import(NIP40_FILE_URL);
    }
}

async function check_nip40(): Promise<void> {
    const nip40 = await import_nip40_module();
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const expiration_seconds = 1_708_000_350;
    const event = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_050,
            tags: [["expiration", `${expiration_seconds}`]],
            content: "nip40 baseline",
        },
        secret_key,
    );

    const expiration = nip40.getExpiration(event);
    ensure(expiration !== undefined, "NIP-40 getExpiration returned undefined for expiration tag");
    ensure(
        expiration.getTime() === expiration_seconds * 1000,
        "NIP-40 expiration timestamp mismatch",
    );

    const date_now_original = Date.now;
    try {
        Date.now = () => (expiration_seconds - 1) * 1000;
        ensure(!nip40.isEventExpired(event), "NIP-40 event expired before boundary");
        Date.now = () => expiration_seconds * 1000;
        ensure(!nip40.isEventExpired(event), "NIP-40 event expired at exact boundary second");
        Date.now = () => (expiration_seconds + 1) * 1000;
        ensure(nip40.isEventExpired(event), "NIP-40 event not expired after boundary");
    } finally {
        Date.now = date_now_original;
    }

    const non_expiring_event = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_051,
            tags: [],
            content: "nip40 negative",
        },
        secret_key,
    );
    ensure(!nip40.isEventExpired(non_expiring_event), "NIP-40 non-expiring event marked expired");

    const malformed_expiration_event = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_052,
            tags: [["expiration", "not-a-number"]],
            content: "nip40 malformed expiration",
        },
        secret_key,
    );
    const malformed_expiration = nip40.getExpiration(malformed_expiration_event);
    ensure(malformed_expiration !== undefined, "NIP-40 malformed expiration should return Date object");
    ensure(
        Number.isNaN(malformed_expiration.getTime()),
        "NIP-40 malformed expiration should produce invalid Date time value",
    );
    ensure(
        !nip40.isEventExpired(malformed_expiration_event),
        "NIP-40 malformed expiration event marked expired",
    );
}

function check_nip03(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const event = finalizeEvent(
        {
            kind: kinds.OpenTimestamps,
            created_at: 1_708_000_040,
            tags: [
                [
                    "e",
                    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
                    "wss://relay.example",
                ],
                ["k", "1"],
            ],
            content: "AQIDBA==",
        },
        secret_key,
    );
    ensure(event.kind === kinds.OpenTimestamps, "NIP-03 event kind mismatch");
    ensure(verifyEvent(event), "NIP-03 signature verification failed");
    ensure(event.content === "AQIDBA==", "NIP-03 proof content mismatch");
    ensure(event.tags.some((tag) => tag[0] === "e" && tag[2] === "wss://relay.example"), "NIP-03 event missing target event tag");
    ensure(event.tags.some((tag) => tag[0] === "k" && tag[1] === "1"), "NIP-03 event missing target kind tag");
}

class MockCountWebSocket {
    static OPEN = 1;
    static CLOSED = 3;

    readyState = MockCountWebSocket.OPEN;
    url: string;
    onopen?: () => void;
    onclose?: () => void;
    onerror?: (error: Error) => void;
    onmessage?: (event: { data: string }) => void;

    constructor(url: string) {
        this.url = url;
        queueMicrotask(() => this.onopen?.());
    }

    close(): void {
        this.readyState = MockCountWebSocket.CLOSED;
        this.onclose?.({ message: "mock websocket closed" } as never);
    }

    send(message: string): void {
        const payload = JSON.parse(message) as unknown[];
        if (payload[0] !== "COUNT") {
            return;
        }
        const subscription_id = String(payload[1]);
        const filter_payload = payload[2] as Record<string, unknown>;
        const has_expected_kind = Array.isArray(filter_payload?.kinds) && filter_payload.kinds[0] === 1;
        if (!has_expected_kind) {
            this.onerror?.(new Error("COUNT request missing expected kinds filter"));
            return;
        }

        if (subscription_id === "count-baseline") {
            this.onmessage?.({ data: `["COUNT","${subscription_id}",{"count":2}]` });
            return;
        }
        if (subscription_id === "count-future") {
            this.onmessage?.({ data: `["COUNT","${subscription_id}",{"count":2,"future":1}]` });
            return;
        }
        if (subscription_id === "count-edge") {
            this.onmessage?.({ data: `["COUNT","${subscription_id}",{}]` });
        }
    }
}

async function check_nip45(): Promise<void> {
    const native_websocket = (globalThis as { WebSocket?: unknown }).WebSocket;
    useWebSocketImplementation(MockCountWebSocket as unknown as typeof WebSocket);

    const relay = await Relay.connect("wss://relay.mock");
    try {
        const count = await relay.count([{ kinds: [1], search: "nostr parity" }], {
            id: "count-baseline",
        });
        ensure(count === 2, `NIP-45 baseline count mismatch: got ${String(count)}`);

        const malformed_count = await relay.count([{ kinds: [1] }], { id: "count-edge" });
        ensure(
            malformed_count === undefined,
            "NIP-45 malformed COUNT payload should resolve undefined",
        );

        const future_count = await relay.count([{ kinds: [1] }], { id: "count-future" });
        ensure(future_count === 2, `NIP-45 future metadata count mismatch: got ${String(future_count)}`);
    } finally {
        relay.close();
        useWebSocketImplementation(native_websocket as typeof WebSocket);
    }
}

function check_nip50(): void {
    const event = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_055,
            tags: [],
            content: "nostr parity",
        },
        to_bytes_32(FIXED_SECRET_KEY_HEX),
    );
    const matched = nostr_tools.matchFilter({ search: "nostr parity", ids: [event.id] }, event);
    ensure(matched, "NIP-50 search filter baseline did not match event");

    const unmatched = nostr_tools.matchFilter(
        {
            search: "nostr parity",
            ids: ["ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"],
        },
        event,
    );
    ensure(!unmatched, "NIP-50 negative filter unexpectedly matched event");

    const malformed_extension_event = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_056,
            tags: [],
            content: "include: language:en:us",
        },
        to_bytes_32(FIXED_SECRET_KEY_HEX),
    );
    const malformed_extension_matched = nostr_tools.matchFilter(
        { search: "include: language:en:us" },
        malformed_extension_event,
    );
    ensure(
        malformed_extension_matched,
        "NIP-50 malformed extension-like text was not treated as raw search text",
    );
}

function check_nip70(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const event = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_060,
            tags: [["-"]],
            content: "nip70 baseline",
        },
        secret_key,
    );
    ensure(verifyEvent(event), "NIP-70 protected event verify failed");
    const has_protected_tag = event.tags.some(tag => tag.length === 1 && tag[0] === "-");
    ensure(has_protected_tag, "NIP-70 protected event missing '-' tag");

    const regular = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_061,
            tags: [],
            content: "nip70 negative",
        },
        secret_key,
    );
    const regular_has_protected = regular.tags.some(tag => tag.length >= 1 && tag[0] === "-");
    ensure(!regular_has_protected, "NIP-70 regular event unexpectedly has '-' tag");

    const malformed_shape = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_062,
            tags: [["-", "extra"]],
            content: "nip70 malformed protected shape",
        },
        secret_key,
    );
    const malformed_shape_has_canonical = malformed_shape.tags.some(
        tag => tag.length === 1 && tag[0] === "-",
    );
    ensure(
        !malformed_shape_has_canonical,
        "NIP-70 malformed protected-tag shape matched canonical '-' semantics",
    );
}

function check_nip02(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const contact_pubkey =
        "f831caf722214748c72db4829986bd0cbb2bb8b3aeade1c959624a52a9629046";
    const contact_list = finalizeEvent(
        {
            kind: kinds.Contacts,
            created_at: 1_708_000_010,
            tags: [["p", contact_pubkey, "wss://relay.example"]],
            content: "",
        },
        secret_key,
    );
    ensure(contact_list.kind === kinds.Contacts, "NIP-02 contact-list kind mismatch");
    ensure(verifyEvent(contact_list), "NIP-02 contact-list verify failed");
    const has_p_tag = contact_list.tags.some(
        tag => tag.length >= 2 && tag[0] === "p" && tag[1] === contact_pubkey,
    );
    ensure(has_p_tag, "NIP-02 contact-list missing expected p tag");

    const non_contact = finalizeEvent(
        {
            kind: kinds.ShortTextNote,
            created_at: 1_708_000_011,
            tags: [],
            content: "nip02 negative",
        },
        secret_key,
    );
    const non_contact_has_p_tag = non_contact.tags.some(
        tag => tag.length >= 2 && tag[0] === "p" && tag[1] === contact_pubkey,
    );
    ensure(!non_contact_has_p_tag, "non-contact event unexpectedly contains contact p tag");
}

function check_nip09(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const target_event_id =
        "7469af3be8c8e06e1b50ef1caceba30392ddc0b6614507398b7d7daa4c218e96";
    const delete_event = finalizeEvent(
        {
            kind: kinds.EventDeletion,
            created_at: 1_708_000_020,
            tags: [["e", target_event_id]],
            content: "cleanup baseline",
        },
        secret_key,
    );
    ensure(delete_event.kind === kinds.EventDeletion, "NIP-09 delete event kind mismatch");
    ensure(verifyEvent(delete_event), "NIP-09 delete event verify failed");
    const has_e_tag = delete_event.tags.some(
        tag => tag.length >= 2 && tag[0] === "e" && tag[1] === target_event_id,
    );
    ensure(has_e_tag, "NIP-09 delete event missing expected e tag");

    const non_delete = finalizeEvent(
        {
            kind: kinds.ShortTextNote,
            created_at: 1_708_000_021,
            tags: [],
            content: "nip09 negative",
        },
        secret_key,
    );
    const non_delete_has_e_tag = non_delete.tags.some(
        tag => tag.length >= 2 && tag[0] === "e" && tag[1] === target_event_id,
    );
    ensure(!non_delete_has_e_tag, "non-delete event unexpectedly contains delete e tag");
}

function check_nip65(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const relay_list = finalizeEvent(
        {
            kind: kinds.RelayList,
            created_at: 1_708_000_030,
            tags: [
                ["r", "wss://relay-a.example", "read"],
                ["r", "wss://relay-b.example", "write"],
            ],
            content: "",
        },
        secret_key,
    );
    ensure(relay_list.kind === kinds.RelayList, "NIP-65 relay-list kind mismatch");
    ensure(verifyEvent(relay_list), "NIP-65 relay-list verify failed");
    const has_read_tag = relay_list.tags.some(
        tag => tag.length >= 3 && tag[0] === "r" && tag[1] === "wss://relay-a.example" &&
            tag[2] === "read",
    );
    ensure(has_read_tag, "NIP-65 relay-list missing read relay tag");
    const has_write_tag = relay_list.tags.some(
        tag => tag.length >= 3 && tag[0] === "r" && tag[1] === "wss://relay-b.example" &&
            tag[2] === "write",
    );
    ensure(has_write_tag, "NIP-65 relay-list missing write relay tag");

    const non_relay_list = finalizeEvent(
        {
            kind: kinds.ShortTextNote,
            created_at: 1_708_000_031,
            tags: [],
            content: "nip65 negative",
        },
        secret_key,
    );
    const non_relay_has_r_tag = non_relay_list.tags.some(tag => tag.length >= 1 && tag[0] === "r");
    ensure(!non_relay_has_r_tag, "non-relay-list event unexpectedly contains relay tag");
}

function check_nip01(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const event_template: EventTemplate = {
        kind: 1,
        created_at: 1_708_000_000,
        tags: [],
        content: "nip01 baseline",
    };

    const event = finalizeEvent(event_template, secret_key);
    const verified = verifyEvent(event);
    ensure(verified, "verifyEvent rejected finalized event");

    const unsigned_event: UnsignedEvent = {
        pubkey: event.pubkey,
        created_at: event.created_at,
        kind: event.kind,
        tags: event.tags,
        content: event.content,
    };
    const computed_id = getEventHash(unsigned_event);
    ensure(computed_id === event.id, "event id mismatch against getEventHash");

    const tampered_event = {
        id: event.id,
        sig: event.sig,
        pubkey: event.pubkey,
        created_at: event.created_at,
        kind: event.kind,
        tags: event.tags,
        content: `${event.content}-tampered`,
    };
    ensure(!verifyEvent(tampered_event), "verifyEvent accepted tampered event payload");

    const uppercase_tag_event = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_001,
            tags: [["P", "target-author"]],
            content: "nip01 uppercase tag",
        },
        secret_key,
    );
    ensure(
        nostr_tools.matchFilter({ "#P": ["target-author"] }, uppercase_tag_event),
        "NIP-01 uppercase tag filter did not match uppercase event tag",
    );
}

function check_nip13(): void {
    const sample_id = "0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    const pow_bits = getPow(sample_id);
    ensure(pow_bits === 4, `getPow mismatch: got ${pow_bits}, want 4`);

    const no_pow_bits = getPow("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
    ensure(no_pow_bits === 0, `getPow mismatch: got ${no_pow_bits}, want 0`);

    const max_pow_bits = getPow("0000000000000000000000000000000000000000000000000000000000000000");
    ensure(max_pow_bits === 256, `getPow mismatch: got ${max_pow_bits}, want 256`);
}

function check_nip19(): void {
    const pubkey_hex =
        "aa4fc8665f5696e33db7e1a572e3b0f5b3d615837b0f362dcb1c8068b098c7b4";
    const event_id_hex =
        "d94a3f4dd87b9a3b0bed183b32e916fa29c8020107845d1752d72697fe5309a5";

    const npub = npubEncode(pubkey_hex);
    const npub_decoded = decode(npub);
    ensure(npub_decoded.type === "npub", "npub decode type mismatch");
    ensure(npub_decoded.data === pubkey_hex, "npub decode payload mismatch");

    const note = noteEncode(event_id_hex);
    const note_decoded = decode(note);
    ensure(note_decoded.type === "note", "note decode type mismatch");
    ensure(note_decoded.data === event_id_hex, "note decode payload mismatch");

    const replaceable_addr = naddrEncode({
        identifier: "",
        pubkey: pubkey_hex,
        kind: 10002,
        relays: ["wss://relay.replaceable"],
    });
    const replaceable_addr_decoded = decode(replaceable_addr);
    ensure(replaceable_addr_decoded.type === "naddr", "naddr decode type mismatch");
    ensure(
        typeof replaceable_addr_decoded.data === "object" &&
            replaceable_addr_decoded.data !== null &&
            "identifier" in replaceable_addr_decoded.data &&
            replaceable_addr_decoded.data.identifier === "",
        "replaceable naddr identifier mismatch",
    );

    let invalid_decode_rejected = false;
    try {
        decode("npub1invalid");
    } catch {
        invalid_decode_rejected = true;
    }
    ensure(invalid_decode_rejected, "invalid bech32 value unexpectedly decoded");
}

function check_nip21(): void {
    const pubkey_hex =
        "aa4fc8665f5696e33db7e1a572e3b0f5b3d615837b0f362dcb1c8068b098c7b4";
    const uri = `nostr:${npubEncode(pubkey_hex)}`;
    const parsed = parseNostrUri(uri);

    ensure(parsed.uri === uri, "NIP-21 uri mismatch after parse");
    ensure(parsed.decoded.type === "npub", "NIP-21 decoded type mismatch");
    ensure(parsed.decoded.data === pubkey_hex, "NIP-21 decoded pubkey mismatch");

    const replaceable_uri = `nostr:${naddrEncode({
        identifier: "",
        pubkey: pubkey_hex,
        kind: 10002,
        relays: ["wss://relay.replaceable"],
    })}`;
    const replaceable_parsed = parseNostrUri(replaceable_uri);
    ensure(replaceable_parsed.uri === replaceable_uri, "replaceable NIP-21 uri mismatch");
    ensure(replaceable_parsed.decoded.type === "naddr", "replaceable NIP-21 type mismatch");
    ensure(
        typeof replaceable_parsed.decoded.data === "object" &&
            replaceable_parsed.decoded.data !== null &&
            "identifier" in replaceable_parsed.decoded.data &&
            replaceable_parsed.decoded.data.identifier === "",
        "replaceable NIP-21 identifier mismatch",
    );

    let invalid_uri_rejected = false;
    try {
        parseNostrUri("https://relay.damus.io");
    } catch {
        invalid_uri_rejected = true;
    }
    ensure(invalid_uri_rejected, "non-nostr URI unexpectedly parsed");
}

function check_nip42(): void {
    const relay_url = "wss://relay.damus.io";
    const challenge = "parity-challenge";
    const auth_template = makeAuthEvent(relay_url, challenge);

    ensure(auth_template.kind === 22242, "auth event kind mismatch");
    ensure(Array.isArray(auth_template.tags), "auth event tags are not an array");

    const has_relay_tag = auth_template.tags.some(
        tag => tag.length >= 2 && tag[0] === "relay" && tag[1] === relay_url,
    );
    ensure(has_relay_tag, "auth event missing relay tag");

    const has_challenge_tag = auth_template.tags.some(
        tag => tag.length >= 2 && tag[0] === "challenge" && tag[1] === challenge,
    );
    ensure(has_challenge_tag, "auth event missing challenge tag");

    ensure(auth_template.content === "", "auth event content should be empty");

    const wrong_challenge_tag = auth_template.tags.some(
        tag => tag.length >= 2 && tag[0] === "challenge" && tag[1] === "mismatch",
    );
    ensure(!wrong_challenge_tag, "auth event unexpectedly contains mismatched challenge tag");

    const long_challenge = "x".repeat(128);
    const long_auth_template = makeAuthEvent(relay_url, long_challenge);
    const has_long_challenge_tag = long_auth_template.tags.some(
        tag => tag.length >= 2 && tag[0] === "challenge" && tag[1] === long_challenge,
    );
    ensure(has_long_challenge_tag, "auth event long challenge tag mismatch");
}

async function check_nip11(): Promise<void> {
    const original_fetch = globalThis.fetch;
    const mock_fetch = async (url: string, init?: { headers?: Record<string, string> }) => {
        ensure(url === "https://relay.example", `unexpected NIP-11 URL: ${url}`);
        const accept = init?.headers?.Accept;
        ensure(accept === "application/nostr+json", "NIP-11 Accept header mismatch");
        return {
            async json() {
                return {
                    name: "Parity Relay",
                    supported_nips: [1, 11, 59, 77],
                    software: "https://example.com/relay",
                };
            },
        };
    };

    (globalThis as { fetch?: typeof globalThis.fetch }).fetch = mock_fetch as never;
    nostr_tools.nip11.useFetchImplementation(mock_fetch);
    try {
        const info = await nostr_tools.nip11.fetchRelayInformation("wss://relay.example");
        ensure(info.name === "Parity Relay", "NIP-11 relay name mismatch");
        ensure(Array.isArray(info.supported_nips), "NIP-11 supported_nips missing");
        ensure(info.supported_nips.includes(77), "NIP-11 supported_nips missing expected NIP");
    } finally {
        (globalThis as { fetch?: typeof globalThis.fetch }).fetch = original_fetch;
    }
}

function check_nip44(): void {
    const fixture_path = join(LOCAL_DIR, "..", "fixtures", "nip44_ut_e_003.json");
    const fixture_text = readFileSync(fixture_path, "utf8");
    const fixture_set = JSON.parse(fixture_text) as FixtureSet;

    for (const fixture of fixture_set.fixtures) {
        const key = to_bytes_32(fixture.conversation_key_hex);
        const nonce = to_bytes_32(fixture.nonce_hex);

        const decrypted = decrypt(fixture.payload_expectation_base64, key);
        ensure(decrypted === fixture.plaintext, `${fixture.id} decrypt mismatch`);

        const encrypted = encrypt(fixture.plaintext, key, nonce);
        ensure(
            encrypted === fixture.payload_expectation_base64,
            `${fixture.id} encrypt mismatch`,
        );

        const malformed = fixture.payload_expectation_base64.slice(0, -1);
        let malformed_rejected = false;
        try {
            decrypt(malformed, key);
        } catch {
            malformed_rejected = true;
        }
        ensure(malformed_rejected, `${fixture.id} malformed payload unexpectedly decrypted`);
    }
}

function check_nip51(): void {
    const author_private_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const author_pubkey = getPublicKey(author_private_key);
    const conversation_key = getConversationKey(author_private_key, author_pubkey);
    const nonce = new Uint8Array(32);
    nonce[31] = 7;
    const private_tags = [
        ["t", "nostr"],
        ["url", "https://example.com/post"],
    ];
    const plaintext = JSON.stringify(private_tags);
    const payload = encrypt(plaintext, conversation_key, nonce);
    const decrypted = decrypt(payload, conversation_key);

    ensure(decrypted === plaintext, "NIP-51 private-list nip44 json roundtrip mismatch");
    const parsed = JSON.parse(decrypted) as unknown;
    ensure(Array.isArray(parsed), "NIP-51 private-list decrypted payload is not an array");
    ensure(parsed.length === 2, "NIP-51 private-list decrypted tag count mismatch");
    ensure(
        Array.isArray(parsed[0]) && parsed[0][0] === "t" && parsed[0][1] === "nostr",
        "NIP-51 private-list hashtag tag mismatch",
    );
    ensure(
        Array.isArray(parsed[1]) && parsed[1][0] === "url" &&
            parsed[1][1] === "https://example.com/post",
        "NIP-51 private-list url tag mismatch",
    );
}

function check_nip23(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const article = finalizeEvent(
        {
            kind: kinds.LongFormArticle,
            created_at: 1_708_000_056,
            tags: [
                ["d", "lorem-ipsum"],
                ["title", "Lorem Ipsum"],
                ["image", "https://example.com/image.png", "800x600"],
                ["summary", "Article summary"],
                ["published_at", "1296962229"],
                ["t", "placeholder"],
            ],
            content: "NIP-23 article",
        },
        secret_key,
    );
    ensure(article.kind === kinds.LongFormArticle, "NIP-23 article kind mismatch");
    ensure(verifyEvent(article), "NIP-23 article signature verification failed");
    ensure(article.tags.some((tag) => tag[0] === "d" && tag[1] === "lorem-ipsum"), "NIP-23 article missing identifier");
    ensure(article.tags.some((tag) => tag[0] === "title" && tag[1] === "Lorem Ipsum"), "NIP-23 article missing title");
    ensure(article.tags.some((tag) => tag[0] === "image" && tag[2] === "800x600"), "NIP-23 article missing image dimensions");
    ensure(article.tags.some((tag) => tag[0] === "summary" && tag[1] === "Article summary"), "NIP-23 article missing summary");
    ensure(article.tags.some((tag) => tag[0] === "published_at" && tag[1] === "1296962229"), "NIP-23 article missing published_at");
    ensure(article.tags.some((tag) => tag[0] === "t" && tag[1] === "placeholder"), "NIP-23 article missing hashtag");

    const draft = finalizeEvent(
        {
            kind: kinds.DraftLong,
            created_at: 1_708_000_057,
            tags: [["d", "draft-id"]],
            content: "NIP-23 draft",
        },
        secret_key,
    );
    ensure(draft.kind === kinds.DraftLong, "NIP-23 draft kind mismatch");
    ensure(verifyEvent(draft), "NIP-23 draft signature verification failed");
    ensure(draft.tags.some((tag) => tag[0] === "d" && tag[1] === "draft-id"), "NIP-23 draft missing identifier");
}

function check_nip24(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const metadata_content = JSON.stringify({
        display_name: "Display",
        website: "https://example.com",
        banner: "https://example.com/banner.png",
        bot: true,
        birthday: { year: 1984, month: 1, day: 24 },
    });
    const parsed = JSON.parse(metadata_content) as {
        display_name?: string;
        website?: string;
        banner?: string;
        bot?: boolean;
        birthday?: { year?: number; month?: number; day?: number };
    };
    ensure(parsed.display_name === "Display", "NIP-24 metadata display_name mismatch");
    ensure(parsed.website === "https://example.com", "NIP-24 metadata website mismatch");
    ensure(parsed.banner === "https://example.com/banner.png", "NIP-24 metadata banner mismatch");
    ensure(parsed.bot === true, "NIP-24 metadata bot mismatch");
    ensure(parsed.birthday?.year === 1984, "NIP-24 metadata birthday year mismatch");
    ensure(parsed.birthday?.month === 1, "NIP-24 metadata birthday month mismatch");
    ensure(parsed.birthday?.day === 24, "NIP-24 metadata birthday day mismatch");

    const event = finalizeEvent(
        {
            kind: 0,
            created_at: 1_708_000_058,
            tags: [
                ["r", "https://example.com/profile"],
                ["title", "Display title"],
                ["t", "nostr"],
            ],
            content: metadata_content,
        },
        secret_key,
    );
    ensure(event.kind === 0, "NIP-24 event kind mismatch");
    ensure(verifyEvent(event), "NIP-24 event signature verification failed");
    ensure(event.tags.some((tag) => tag[0] === "r" && tag[1] === "https://example.com/profile"), "NIP-24 event missing reference");
    ensure(event.tags.some((tag) => tag[0] === "title" && tag[1] === "Display title"), "NIP-24 event missing title");
    ensure(event.tags.some((tag) => tag[0] === "t" && tag[1] === "nostr"), "NIP-24 event missing hashtag");
}

function check_nip17(): void {
    const sender_secret = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const recipient_secret = to_bytes_32(
        "7a350bc1469e1a5b1244625fdbec8b23dc4af192e11cdb296cf9d567a90d3812",
    );
    const recipient_public_key = getPublicKey(recipient_secret);
    const wrap = nip17.wrapEvent(
        sender_secret,
        { publicKey: recipient_public_key, relayUrl: "wss://relay.example" },
        "hello",
        "Topic",
        {
            eventId:
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            relayUrl: "wss://relay.example",
        },
    );
    ensure(wrap.kind === kinds.GiftWrap, "NIP-17 wrap kind mismatch");
    ensure(verifyEvent(wrap), "NIP-17 wrap signature verification failed");

    const rumor = nip17.unwrapEvent(wrap, recipient_secret);
    ensure(rumor.kind === kinds.PrivateDirectMessage, "NIP-17 rumor kind mismatch");
    ensure(rumor.content === "hello", "NIP-17 rumor content mismatch");
    ensure(
        rumor.tags.some((tag) => tag[0] === "p" && tag[1] === recipient_public_key),
        "NIP-17 rumor missing recipient",
    );
    ensure(
        rumor.tags.some((tag) => tag[0] === "subject" && tag[1] === "Topic"),
        "NIP-17 rumor missing subject",
    );
    ensure(
        rumor.tags.some(
            (tag) =>
                tag[0] === "e" &&
                tag[1] ===
                    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" &&
                tag[tag.length - 1] === "reply",
        ),
        "NIP-17 rumor missing reply tag",
    );

    const relay_event = finalizeEvent(
        {
            kind: kinds.DirectMessageRelaysList,
            created_at: 1_708_000_059,
            tags: [
                ["relay", "wss://relay.one"],
                ["name", "ignored"],
                ["relay", "wss://relay.two"],
            ],
            content: "",
        },
        sender_secret,
    );
    ensure(
        relay_event.kind === kinds.DirectMessageRelaysList,
        "NIP-17 relay-list kind mismatch",
    );
    ensure(
        verifyEvent(relay_event),
        "NIP-17 relay-list signature verification failed",
    );
    const relay_tags = relay_event.tags.filter((tag) => tag[0] === "relay");
    ensure(relay_tags.length === 2, "NIP-17 relay-list count mismatch");
    ensure(relay_tags[0][1] === "wss://relay.one", "NIP-17 first relay mismatch");
    ensure(relay_tags[1][1] === "wss://relay.two", "NIP-17 second relay mismatch");
}

async function check_nip39(): Promise<void> {
    const pubkey =
        "b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4";
    const npub = npubEncode(pubkey);
    let requested_url = "";

    nip39.useFetchImplementation(async (url: string) => {
        requested_url = url;
        return {
            text: async () =>
                `Verifying that I control the following Nostr public key: ${npub}`,
        };
    });
    const github_ok = await nip39.validateGithub(
        npub,
        "semisol",
        "9721ce4ee4fceb91c9711ca2a6c9a5ab",
    );
    ensure(github_ok, "NIP-39 github validation returned false");
    ensure(
        requested_url ===
            "https://gist.github.com/semisol/9721ce4ee4fceb91c9711ca2a6c9a5ab/raw",
        "NIP-39 github proof URL mismatch",
    );

    nip39.useFetchImplementation(async () => {
        return { text: async () => "bad proof text" };
    });
    const github_bad = await nip39.validateGithub(npub, "semisol", "bad-proof");
    ensure(!github_bad, "NIP-39 github validation accepted wrong proof text");
}

function check_nip29(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const group = {
        relay: "wss://groups.example",
        metadata: {
            id: "pizza-lovers",
            pubkey: getPublicKey(secret_key),
            name: "Pizza Lovers",
            picture: "https://pizza.example/pizza.png",
            about: "a group for people who love pizza",
            isPublic: true,
            isOpen: true,
        },
        reference: { id: "pizza-lovers", host: "groups.example" },
    };
    const metadata_template = nip29.generateGroupMetadataEventTemplate(group);
    const metadata_event = finalizeEvent(metadata_template, secret_key);
    ensure(nip29.validateGroupMetadataEvent(metadata_event), "NIP-29 metadata validation failed");
    const metadata = nip29.parseGroupMetadataEvent(metadata_event);
    ensure(metadata.id === "pizza-lovers", "NIP-29 metadata id mismatch");
    ensure(metadata.name === "Pizza Lovers", "NIP-29 metadata name mismatch");
    ensure(metadata.isPublic === true, "NIP-29 metadata public mismatch");
    ensure(metadata.isOpen === true, "NIP-29 metadata open mismatch");

    const admins_template = nip29.generateGroupAdminsEventTemplate(group, [
        {
            pubkey:
                "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            label: "ceo",
            permissions: [
                nip29.GroupAdminPermission.PutUser,
                nip29.GroupAdminPermission.DeleteEvent,
            ],
        },
    ]);
    const admins_event = finalizeEvent(admins_template, secret_key);
    ensure(nip29.validateGroupAdminsEvent(admins_event), "NIP-29 admins validation failed");
    const admins = nip29.parseGroupAdminsEvent(admins_event);
    ensure(admins.length === 1, "NIP-29 admins count mismatch");
    ensure(admins[0].label === "ceo", "NIP-29 admin label mismatch");
    ensure(
        admins[0].permissions.includes(nip29.GroupAdminPermission.PutUser),
        "NIP-29 admin permission mismatch",
    );

    const members_template = nip29.generateGroupMembersEventTemplate(group, [
        {
            pubkey:
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            label: "vip",
        },
    ]);
    const members_event = finalizeEvent(members_template, secret_key);
    ensure(nip29.validateGroupMembersEvent(members_event), "NIP-29 members validation failed");
    const members = nip29.parseGroupMembersEvent(members_event);
    ensure(members.length === 1, "NIP-29 members count mismatch");
    ensure(members[0].label === "vip", "NIP-29 member label mismatch");

    ensure(
        nip29.encodeGroupReference(group.reference) === "groups.example'pizza-lovers",
        "NIP-29 group reference encoding mismatch",
    );
    ensure(
        nip29.parseGroupCode("groups.example'pizza-lovers")?.id === "pizza-lovers",
        "NIP-29 group reference parsing mismatch",
    );
}

async function check_nip46(): Promise<void> {
    const pubkey =
        "b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4";
    const bunker = nip46.toBunkerURL({
        pubkey,
        relays: ["wss://relay.one", "wss://relay.two"],
        secret: "abcd",
    });
    ensure(
        bunker ===
            "bunker://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4" +
                "?relay=wss%3A%2F%2Frelay.one&relay=wss%3A%2F%2Frelay.two&secret=abcd",
        "NIP-46 bunker URL serialization mismatch",
    );

    const parsed_bunker = await nip46.parseBunkerInput(bunker);
    ensure(parsed_bunker !== null, "NIP-46 bunker URL parse returned null");
    ensure(parsed_bunker?.pubkey === pubkey, "NIP-46 bunker pubkey mismatch");
    ensure(
        JSON.stringify(parsed_bunker?.relays) === JSON.stringify(["wss://relay.one", "wss://relay.two"]),
        "NIP-46 bunker relay list mismatch",
    );
    ensure(parsed_bunker?.secret === "abcd", "NIP-46 bunker secret mismatch");

    const client_uri = nip46.createNostrConnectURI({
        clientPubkey: pubkey,
        relays: ["wss://relay.one", "wss://relay.two"],
        secret: "mysecret",
        perms: ["sign_event:1", "ping"],
        name: "My Client",
        url: "https://client.example",
        image: "https://client.example/app.png",
    });
    ensure(
        client_uri.startsWith(`nostrconnect://${pubkey}?relay=wss%3A%2F%2Frelay.one`),
        "NIP-46 client URI relay prefix mismatch",
    );
    ensure(
        client_uri.includes("&relay=wss%3A%2F%2Frelay.two"),
        "NIP-46 client URI missing second relay",
    );
    ensure(
        client_uri.includes("&secret=mysecret"),
        "NIP-46 client URI missing secret",
    );
    ensure(
        client_uri.includes("&perms=sign_event%3A1%2Cping"),
        "NIP-46 client URI missing perms",
    );
    ensure(client_uri.includes("&name=My+Client"), "NIP-46 client URI missing name");
    ensure(
        client_uri.includes("&url=https%3A%2F%2Fclient.example"),
        "NIP-46 client URI missing url",
    );
    ensure(
        client_uri.includes("&image=https%3A%2F%2Fclient.example%2Fapp.png"),
        "NIP-46 client URI missing image",
    );

    ensure(
        typeof nip46.BunkerSigner.prototype.switchRelays === "function",
        "NIP-46 BunkerSigner missing switchRelays method",
    );
}

function check_nip59(): void {
    const sender_private = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const receiver_private = to_bytes_32(
        "7b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e",
    );
    const wrong_receiver_private = to_bytes_32(
        "8b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e",
    );
    const receiver_pubkey = getPublicKey(receiver_private);

    const rumor = nostr_tools.nip59.createRumor(
        {
            kind: 1,
            created_at: 1_708_000_100,
            tags: [],
            content: "nip59 baseline",
        },
        sender_private,
    );
    ensure(rumor.kind === 1, "NIP-59 rumor kind mismatch");
    ensure(rumor.content === "nip59 baseline", "NIP-59 rumor content mismatch");

    const seal = nostr_tools.nip59.createSeal(rumor, sender_private, receiver_pubkey);
    const wrap = nostr_tools.nip59.createWrap(seal, receiver_pubkey);
    const unwrapped = nostr_tools.nip59.unwrapEvent(wrap, receiver_private);
    ensure(unwrapped.id === rumor.id, "NIP-59 rumor id mismatch after unwrap");
    ensure(unwrapped.content === rumor.content, "NIP-59 rumor content mismatch after unwrap");

    let wrong_recipient_rejected = false;
    try {
        nostr_tools.nip59.unwrapEvent(wrap, wrong_receiver_private);
    } catch {
        wrong_recipient_rejected = true;
    }
    ensure(wrong_recipient_rejected, "NIP-59 unwrap accepted wrong recipient key");
}

function check_nip10(): void {
    const root_id = "1111111111111111111111111111111111111111111111111111111111111111";
    const reply_id = "2222222222222222222222222222222222222222222222222222222222222222";
    const mention_id = "3333333333333333333333333333333333333333333333333333333333333333";
    const reply_author =
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    const mention_author =
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";

    const parsed_marked = nip10.parse({
        tags: [
            ["e", root_id, "", "root"],
            ["e", mention_id, "", "mention", mention_author],
            ["e", reply_id, "wss://relay.example", "reply", reply_author],
        ],
    });
    ensure(parsed_marked.root?.id === root_id, "NIP-10 root marker parse mismatch");
    ensure(parsed_marked.reply?.id === reply_id, "NIP-10 reply marker parse mismatch");
    ensure(
        parsed_marked.reply?.author === reply_author,
        "NIP-10 reply marker author mismatch",
    );
    ensure(parsed_marked.mentions.length === 1, "NIP-10 mention marker count mismatch");
    ensure(parsed_marked.mentions[0].id === mention_id, "NIP-10 mention marker id mismatch");
    ensure(
        parsed_marked.mentions[0].author === mention_author,
        "NIP-10 mention marker author mismatch",
    );

    const parsed_mention_only = nip10.parse({
        tags: [["e", mention_id, "", "mention"]],
    });
    ensure(parsed_mention_only.root === undefined, "NIP-10 mention-only unexpectedly set root");
    ensure(parsed_mention_only.reply === undefined, "NIP-10 mention-only unexpectedly set reply");
    ensure(
        parsed_mention_only.mentions.length === 1,
        "NIP-10 mention-only mention count mismatch",
    );

    const widened_pubkey =
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const parsed_widened = nip10.parse({
        tags: [["e", root_id, "", widened_pubkey]],
    });
    ensure(parsed_widened.root?.id === root_id, "NIP-10 widened root mismatch");
    ensure(parsed_widened.reply?.id === root_id, "NIP-10 widened reply mismatch");
    ensure(parsed_widened.reply?.author === undefined, "NIP-10 widened author should be absent");
    ensure(parsed_widened.mentions.length === 0, "NIP-10 widened tag produced mentions");
}

function check_nip18(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const target_private = to_bytes_32(
        "7b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e",
    );
    const text_note = finalizeEvent(
        { kind: 1, created_at: 1_708_000_130, tags: [], content: "nip18 note" },
        target_private,
    );
    const repost = nostr_tools.nip18.finishRepostEvent(
        { created_at: 1_708_000_131 },
        text_note,
        "wss://relay.example",
        secret_key,
    );
    const protected_note = finalizeEvent(
        { kind: 1, created_at: 1_708_000_132, tags: [["-"]], content: "nip18 protected" },
        target_private,
    );
    const protected_repost = nostr_tools.nip18.finishRepostEvent(
        { created_at: 1_708_000_133 },
        protected_note,
        "wss://relay.example",
        secret_key,
    );
    const generic_target = finalizeEvent(
        { kind: 10000, created_at: 1_708_000_134, tags: [], content: "nip18 generic" },
        target_private,
    );
    const generic_repost = nostr_tools.nip18.finishRepostEvent(
        { created_at: 1_708_000_135 },
        generic_target,
        "wss://relay.example",
        secret_key,
    );
    const pointer = nostr_tools.nip18.getRepostedEventPointer(repost);
    const embedded = nostr_tools.nip18.getRepostedEvent(repost, { skipVerification: true });

    ensure(repost.kind === kinds.Repost, "NIP-18 text repost kind mismatch");
    ensure(pointer?.id === text_note.id, "NIP-18 repost pointer id mismatch");
    ensure(pointer?.author === text_note.pubkey, "NIP-18 repost pointer author mismatch");
    ensure(pointer?.relays[0] === "wss://relay.example", "NIP-18 repost relay hint mismatch");
    ensure(embedded?.id === text_note.id, "NIP-18 embedded repost extraction mismatch");
    ensure(protected_repost.content === "", "NIP-18 protected repost content mismatch");
    ensure(generic_repost.kind === kinds.GenericRepost, "NIP-18 generic repost kind mismatch");
    ensure(
        generic_repost.tags.some(tag => tag[0] === "k" && tag[1] === "10000"),
        "NIP-18 generic repost missing k tag",
    );
}

function check_nip25(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const target_private = to_bytes_32(
        "7b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e",
    );
    const reacted = finalizeEvent(
        {
            kind: 1,
            created_at: 1_708_000_125,
            tags: [
                ["e", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"],
                ["p", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"],
            ],
            content: "nip25 target",
        },
        target_private,
    );
    const reaction = nip25.finishReactionEvent({ created_at: 1_708_000_126 }, reacted, secret_key);
    const pointer = nip25.getReactedEventPointer(reaction);
    const valid_shortcode = Array.from(nip30.matchAll("x :soapbox: y"));
    const widened_shortcode = Array.from(nip30.matchAll("x :soap-box: y"));

    ensure(reaction.kind === kinds.Reaction, "NIP-25 reaction builder kind mismatch");
    ensure(reaction.content === "+", "NIP-25 reaction builder default content mismatch");
    ensure(pointer !== undefined, "NIP-25 pointer extraction returned undefined");
    ensure(pointer?.id === reacted.id, "NIP-25 pointer target id mismatch");
    ensure(pointer?.author === reacted.pubkey, "NIP-25 pointer author mismatch");
    ensure((pointer?.relays.length ?? 0) === 0, "NIP-25 pointer relay list mismatch");
    ensure(valid_shortcode.length === 1, "NIP-25 nostr-tools shortcode match count mismatch");
    ensure(valid_shortcode[0].name === "soapbox", "NIP-25 shortcode name mismatch");
    ensure(widened_shortcode.length === 0, "NIP-25 widened shortcode unexpectedly matched");
}

function check_nip27(): void {
    const secret_key = to_bytes_32(FIXED_SECRET_KEY_HEX);
    const target_private = to_bytes_32(
        "7b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e",
    );
    const pubkey = getPublicKey(secret_key);
    const npub_uri = npubEncode(pubkey);
    const note = finalizeEvent(
        { kind: 1, created_at: 1_708_000_136, tags: [], content: "nip27 target" },
        target_private,
    );
    const note_uri = noteEncode(note.id);
    const content = `Look at [nostr:${npub_uri}] and nostr:${note_uri}. ` +
        "Broken nostr:npub1broken Uppercase nostr:npub1DRVpZev3";

    const references = Array.from(nip27.parse(content)).filter(
        block => block.type === "reference",
    );
    ensure(references.length === 2, `NIP-27 reference count mismatch: ${references.length}`);
    ensure(
        references[0].type === "reference" && "pubkey" in references[0].pointer,
        "NIP-27 first reference kind mismatch",
    );
    ensure(
        references[0].type === "reference" &&
            "pubkey" in references[0].pointer &&
            references[0].pointer.pubkey === pubkey,
        "NIP-27 first reference pubkey mismatch",
    );
    ensure(
        references[1].type === "reference" && "id" in references[1].pointer,
        "NIP-27 second reference kind mismatch",
    );
    ensure(
        references[1].type === "reference" &&
            "id" in references[1].pointer &&
            references[1].pointer.id === note.id,
        "NIP-27 second reference id mismatch",
    );

    const duplicate_count = Array.from(nip27.parse(`nostr:${npub_uri}, nostr:${npub_uri}`)).filter(
        block => block.type === "reference",
    ).length;
    ensure(duplicate_count === 2, "NIP-27 duplicate references were not preserved");

    const nsec_uri = `nostr:${nsecEncode(secret_key)}`;
    const forbidden_count = Array.from(nip27.parse(`nostr:nsec1broken ${nsec_uri}`)).filter(
        block => block.type === "reference",
    ).length;
    ensure(forbidden_count === 0, "NIP-27 forbidden fragments produced references");
}

function check_nip77(): void {
    const local = new nostr_tools.nip77.NegentropyStorageVector();
    const remote = new nostr_tools.nip77.NegentropyStorageVector();

    const local_only_id = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const shared_id = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    const remote_only_id = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";

    local.insert(1000, local_only_id);
    local.insert(1001, shared_id);
    remote.insert(1001, shared_id);
    remote.insert(1002, remote_only_id);
    local.seal();
    remote.seal();

    const local_neg = new nostr_tools.nip77.Negentropy(local);
    const remote_neg = new nostr_tools.nip77.Negentropy(remote);
    const remote_have: string[] = [];
    const remote_need: string[] = [];

    const query = local_neg.initiate();
    ensure(query.length > 0, "NIP-77 initiate produced empty query");
    const response = remote_neg.reconcile(
        query,
        id => remote_have.push(id),
        id => remote_need.push(id),
    );
    ensure(remote_have.includes(remote_only_id), "NIP-77 missing remote-only id in have callback");
    ensure(remote_need.includes(local_only_id), "NIP-77 missing local-only id in need callback");
    if (response !== null) {
        local_neg.reconcile(response);
    }

    let sealed_insert_rejected = false;
    try {
        local.insert(1003, "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd");
    } catch {
        sealed_insert_rejected = true;
    }
    ensure(sealed_insert_rejected, "NIP-77 storage accepted insert after seal");
}

function check_nip06(): void {
    const mnemonic =
        "equal dragon fabric refuse stable cherry smoke allow alley easy never medal " +
        "attend together lumber movie what sad siege weather matrix buffalo state shoot";
    const account_zero = Buffer.from(
        nip06.privateKeyFromSeedWords(mnemonic, "", 0),
    ).toString("hex");
    ensure(
        account_zero === "06992419a8fe821dd8de03d4c300614e8feefb5ea936b76f89976dcace8aebee",
        "NIP-06 account 0 secret key mismatch",
    );

    const account_one = Buffer.from(
        nip06.privateKeyFromSeedWords(mnemonic, "", 1),
    ).toString("hex");
    ensure(
        account_one === "5735ecd7389ba3dcc0c4464d6c9328867821560c3923acff14aeeb4b6cd5c775",
        "NIP-06 account 1 secret key mismatch",
    );

    const null_passphrase = Buffer.from(
        nip06.privateKeyFromSeedWords(
            "abandon abandon abandon abandon abandon abandon abandon abandon " +
                "abandon abandon abandon about",
            undefined,
            0,
        ),
    ).toString("hex");
    const empty_passphrase = Buffer.from(
        nip06.privateKeyFromSeedWords(
            "abandon abandon abandon abandon abandon abandon abandon abandon " +
                "abandon abandon abandon about",
            "",
            0,
        ),
    ).toString("hex");
    ensure(
        null_passphrase === empty_passphrase,
        "NIP-06 null and empty passphrase derivations diverged",
    );

    ensure(
        nip06.validateWords(
            "leader monkey parrot ring guide accident before fence cannon height naive bean",
        ),
        "NIP-06 validateWords rejected canonical mnemonic",
    );
    ensure(
        !nip06.validateWords(
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon",
        ),
        "NIP-06 validateWords accepted invalid mnemonic length",
    );
}

async function main(): Promise<void> {
    const results: NipResult[] = [];

    await push_harness_covered(results, "NIP-01", "EDGE", check_nip01);
    await push_harness_covered(results, "NIP-02", "BASELINE", check_nip02);
    await push_harness_covered(results, "NIP-03", "BASELINE", check_nip03);
    await push_harness_covered(results, "NIP-09", "BASELINE", check_nip09);
    await push_harness_covered(results, "NIP-10", "EDGE", check_nip10);
    await push_harness_covered(results, "NIP-11", "EDGE", check_nip11);
    await push_harness_covered(results, "NIP-13", "EDGE", check_nip13);
    await push_harness_covered(results, "NIP-18", "EDGE", check_nip18);
    await push_harness_covered(results, "NIP-19", "EDGE", check_nip19);
    await push_harness_covered(results, "NIP-25", "EDGE", check_nip25);
    await push_harness_covered(results, "NIP-27", "EDGE", check_nip27);
    await push_harness_covered(results, "NIP-21", "EDGE", check_nip21);
    await push_harness_covered(results, "NIP-23", "BASELINE", check_nip23);
    await push_harness_covered(results, "NIP-24", "BASELINE", check_nip24);
    await push_harness_covered(results, "NIP-17", "BASELINE", check_nip17);
    await push_harness_covered(results, "NIP-29", "BASELINE", check_nip29);
    await push_harness_covered(results, "NIP-39", "BASELINE", check_nip39);
    await push_harness_covered(results, "NIP-42", "EDGE", check_nip42);
    await push_harness_covered(results, "NIP-44", "DEEP", check_nip44);
    await push_harness_covered(results, "NIP-51", "BASELINE", check_nip51);
    await push_harness_covered(results, "NIP-46", "BASELINE", check_nip46);
    await push_harness_covered(results, "NIP-59", "EDGE", check_nip59);
    await push_harness_covered(results, "NIP-65", "BASELINE", check_nip65);
    await push_harness_covered(results, "NIP-06", "EDGE", check_nip06);
    await push_harness_covered(results, "NIP-77", "EDGE", check_nip77);
    await push_harness_covered(results, "NIP-40", "EDGE", check_nip40);
    await push_harness_covered(results, "NIP-45", "EDGE", check_nip45);
    await push_harness_covered(results, "NIP-50", "EDGE", check_nip50);
    await push_harness_covered(results, "NIP-70", "EDGE", check_nip70);

    let pass_count = 0;
    let fail_count = 0;
    let harness_covered_count = 0;
    let lib_supported_count = 0;
    let not_covered_count = 0;
    let lib_unsupported_count = 0;

    for (const result of results) {
        if (result.taxonomy === "HARNESS_COVERED") {
            harness_covered_count += 1;
            if (result.result === "PASS") {
                pass_count += 1;
            }
            if (result.result === "FAIL") {
                fail_count += 1;
            }
        }
        if (result.taxonomy === "LIB_SUPPORTED") {
            lib_supported_count += 1;
        }
        if (result.taxonomy === "NOT_COVERED_IN_THIS_PASS") {
            not_covered_count += 1;
        }
        if (result.taxonomy === "LIB_UNSUPPORTED") {
            lib_unsupported_count += 1;
        }

        const detail_suffix = result.detail === undefined ? "" : ` | detail=${result.detail}`;
        console.log(
            `${result.nip} | taxonomy=${result.taxonomy} | depth=${result.depth} | result=${result.result}${detail_suffix}`,
        );
    }

    console.log(
        "SUMMARY " +
            `pass=${pass_count} fail=${fail_count} harness_covered=${harness_covered_count} ` +
            `lib_supported=${lib_supported_count} not_covered_in_this_pass=${not_covered_count} ` +
            `lib_unsupported=${lib_unsupported_count} total=${results.length}`,
    );

    if (fail_count > 0) {
        process.exit(1);
    }
}

await main();
