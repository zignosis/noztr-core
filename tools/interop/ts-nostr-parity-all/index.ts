import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import {
    finalizeEvent,
    getEventHash,
    type EventTemplate,
    type UnsignedEvent,
    verifyEvent,
} from "nostr-tools/pure";
import { getPow } from "nostr-tools/nip13";
import { decode, noteEncode, npubEncode } from "nostr-tools/nip19";
import { makeAuthEvent } from "nostr-tools/nip42";
import { decrypt, encrypt } from "nostr-tools/nip44";
import { parse as parseNostrUri } from "nostr-tools/nip21";

type NipStatus = "PASS" | "FAIL" | "UNSUPPORTED";

type NipResult = {
    nip: string;
    status: NipStatus;
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

function push_supported(results: NipResult[], nip: string, check: () => void): void {
    try {
        check();
        results.push({ nip, status: "PASS" });
    } catch (error) {
        const detail = error instanceof Error ? error.message : String(error);
        results.push({ nip, status: "FAIL", detail });
    }
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
}

function check_nip13(): void {
    const sample_id = "0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    const pow_bits = getPow(sample_id);
    ensure(pow_bits === 4, `getPow mismatch: got ${pow_bits}, want 4`);
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
}

function check_nip21(): void {
    const pubkey_hex =
        "aa4fc8665f5696e33db7e1a572e3b0f5b3d615837b0f362dcb1c8068b098c7b4";
    const uri = `nostr:${npubEncode(pubkey_hex)}`;
    const parsed = parseNostrUri(uri);

    ensure(parsed.uri === uri, "NIP-21 uri mismatch after parse");
    ensure(parsed.decoded.type === "npub", "NIP-21 decoded type mismatch");
    ensure(parsed.decoded.data === pubkey_hex, "NIP-21 decoded pubkey mismatch");
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
}

function check_nip44(): void {
    const local_file = fileURLToPath(import.meta.url);
    const local_dir = dirname(local_file);
    const fixture_path = join(local_dir, "..", "fixtures", "nip44_ut_e_003.json");
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
    }
}

function main(): void {
    const results: NipResult[] = [];

    push_supported(results, "NIP-01", check_nip01);
    push_supported(results, "NIP-13", check_nip13);
    push_supported(results, "NIP-19", check_nip19);
    push_supported(results, "NIP-21", check_nip21);
    push_supported(results, "NIP-42", check_nip42);
    push_supported(results, "NIP-44", check_nip44);

    for (const nip of [
        "NIP-02",
        "NIP-09",
        "NIP-11",
        "NIP-40",
        "NIP-45",
        "NIP-50",
        "NIP-59",
        "NIP-65",
        "NIP-70",
        "NIP-77",
    ]) {
        results.push({
            nip,
            status: "UNSUPPORTED",
            detail: "no nostr-tools overlap helper in this pass",
        });
    }

    let pass_count = 0;
    let fail_count = 0;
    let unsupported_count = 0;

    for (const result of results) {
        if (result.status === "PASS") {
            pass_count += 1;
            console.log(`${result.nip} PASS`);
            continue;
        }

        if (result.status === "FAIL") {
            fail_count += 1;
            console.log(`${result.nip} FAIL`);
            if (result.detail !== undefined) {
                console.log(`  detail: ${result.detail}`);
            }
            continue;
        }

        unsupported_count += 1;
        console.log(`${result.nip} UNSUPPORTED`);
    }

    console.log(
        `SUMMARY pass=${pass_count} fail=${fail_count} unsupported=${unsupported_count} total=${results.length}`,
    );

    if (fail_count > 0) {
        process.exit(1);
    }
}

main();
