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
import { decode, noteEncode, npubEncode } from "nostr-tools/nip19";
import { makeAuthEvent } from "nostr-tools/nip42";
import { decrypt, encrypt } from "nostr-tools/nip44";
import * as nip10 from "nostr-tools/nip10";
import { parse as parseNostrUri } from "nostr-tools/nip21";
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
}

function check_nip13(): void {
    const sample_id = "0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    const pow_bits = getPow(sample_id);
    ensure(pow_bits === 4, `getPow mismatch: got ${pow_bits}, want 4`);

    const no_pow_bits = getPow("ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
    ensure(no_pow_bits === 0, `getPow mismatch: got ${no_pow_bits}, want 0`);
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

async function main(): Promise<void> {
    const results: NipResult[] = [];

    await push_harness_covered(results, "NIP-01", "EDGE", check_nip01);
    await push_harness_covered(results, "NIP-02", "BASELINE", check_nip02);
    await push_harness_covered(results, "NIP-09", "BASELINE", check_nip09);
    await push_harness_covered(results, "NIP-10", "EDGE", check_nip10);
    await push_harness_covered(results, "NIP-11", "EDGE", check_nip11);
    await push_harness_covered(results, "NIP-13", "EDGE", check_nip13);
    await push_harness_covered(results, "NIP-19", "EDGE", check_nip19);
    await push_harness_covered(results, "NIP-21", "EDGE", check_nip21);
    await push_harness_covered(results, "NIP-42", "EDGE", check_nip42);
    await push_harness_covered(results, "NIP-44", "DEEP", check_nip44);
    await push_harness_covered(results, "NIP-59", "EDGE", check_nip59);
    await push_harness_covered(results, "NIP-65", "BASELINE", check_nip65);
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
