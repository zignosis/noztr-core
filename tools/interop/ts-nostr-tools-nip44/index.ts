import { readFileSync } from "node:fs";
import { decrypt, encrypt } from "nostr-tools/nip44";

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

function hex_to_bytes(value_hex: string): Uint8Array {
    if (value_hex.length !== 64) {
        throw new Error(`expected 32-byte hex, got ${value_hex.length / 2} bytes`);
    }
    return Uint8Array.from(Buffer.from(value_hex, "hex"));
}

function main(): void {
    const input = readFileSync("../fixtures/nip44_ut_e_003.json", "utf8");
    const set = JSON.parse(input) as FixtureSet;

    let failures = 0;
    console.log(`nostr-tools/nip44 replay set: ${set.set_id}`);

    for (const fx of set.fixtures) {
        try {
            const key = hex_to_bytes(fx.conversation_key_hex);
            const nonce = hex_to_bytes(fx.nonce_hex);

            const decrypted = decrypt(fx.payload_expectation_base64, key);
            if (decrypted !== fx.plaintext) {
                failures += 1;
                console.log(`${fx.id} FAIL decrypt mismatch`);
                console.log(`  got : ${JSON.stringify(decrypted)}`);
                console.log(`  want: ${JSON.stringify(fx.plaintext)}`);
                continue;
            }

            const encrypted = encrypt(fx.plaintext, key, nonce);
            if (encrypted !== fx.payload_expectation_base64) {
                failures += 1;
                console.log(`${fx.id} FAIL encrypt mismatch`);
                console.log(`  got : ${encrypted}`);
                console.log(`  want: ${fx.payload_expectation_base64}`);
                continue;
            }

            console.log(`${fx.id} PASS decrypt+encrypt parity`);
        } catch (error) {
            failures += 1;
            const message = error instanceof Error ? error.message : String(error);
            console.log(`${fx.id} FAIL ${message}`);
        }
    }

    const total = set.fixtures.length;
    const passed = total - failures;
    if (failures > 0) {
        console.log(`RESULT FAIL: ${passed}/${total} fixtures passed`);
        process.exit(1);
    }

    console.log(`RESULT PASS: ${passed}/${total} fixtures`);
}

main();
