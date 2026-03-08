use std::fs;
use std::process;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use nostr::nips::nip44::v2::{decrypt_to_bytes, encrypt_to_bytes_with_rng, ConversationKey};
use rand::{CryptoRng, RngCore};
use serde::Deserialize;

#[derive(Deserialize)]
struct FixtureSet {
    set_id: String,
    fixtures: Vec<Fixture>,
}

#[derive(Deserialize)]
struct Fixture {
    id: String,
    conversation_key_hex: String,
    nonce_hex: String,
    plaintext: String,
    payload_expectation_base64: String,
}

struct FixedNonceRng {
    nonce: [u8; 32],
    offset: usize,
}

impl FixedNonceRng {
    fn new(nonce: [u8; 32]) -> Self {
        Self { nonce, offset: 0 }
    }

    fn fill_from_nonce(&mut self, dest: &mut [u8]) {
        let mut index = 0;
        while index < dest.len() {
            let remaining = self.nonce.len() - self.offset;
            let take = (dest.len() - index).min(remaining);
            let next = index + take;
            let offset_next = self.offset + take;
            dest[index..next].copy_from_slice(&self.nonce[self.offset..offset_next]);
            index = next;
            self.offset = offset_next % self.nonce.len();
        }
    }
}

impl RngCore for FixedNonceRng {
    fn next_u32(&mut self) -> u32 {
        let mut bytes = [0_u8; 4];
        self.fill_from_nonce(&mut bytes);
        u32::from_le_bytes(bytes)
    }

    fn next_u64(&mut self) -> u64 {
        let mut bytes = [0_u8; 8];
        self.fill_from_nonce(&mut bytes);
        u64::from_le_bytes(bytes)
    }

    fn fill_bytes(&mut self, dest: &mut [u8]) {
        self.fill_from_nonce(dest);
    }

    fn try_fill_bytes(&mut self, dest: &mut [u8]) -> Result<(), rand::Error> {
        self.fill_from_nonce(dest);
        Ok(())
    }
}

impl CryptoRng for FixedNonceRng {}

fn parse_array_32(name: &str, value_hex: &str) -> Result<[u8; 32], String> {
    let bytes = hex::decode(value_hex).map_err(|e| format!("{name} hex decode: {e}"))?;
    let arr: [u8; 32] = bytes
        .as_slice()
        .try_into()
        .map_err(|_| format!("{name} length: got {} want 32", bytes.len()))?;
    Ok(arr)
}

fn main() {
    let fixture_path = "../fixtures/nip44_ut_e_003.json";
    let input = match fs::read_to_string(fixture_path) {
        Ok(s) => s,
        Err(e) => {
            println!("RESULT FAIL: fixture load error: {e}");
            process::exit(1);
        }
    };

    let set: FixtureSet = match serde_json::from_str(&input) {
        Ok(v) => v,
        Err(e) => {
            println!("RESULT FAIL: fixture parse error: {e}");
            process::exit(1);
        }
    };

    println!("rust-nostr/nip44 replay set: {}", set.set_id);

    let mut failures: usize = 0;
    let total = set.fixtures.len();

    for fx in set.fixtures {
        let conversation_key =
            match parse_array_32("key", &fx.conversation_key_hex).map(ConversationKey::new) {
                Ok(v) => v,
                Err(e) => {
                    failures += 1;
                    println!("{} FAIL {}", fx.id, e);
                    continue;
                }
            };

        let nonce: [u8; 32] = match parse_array_32("nonce", &fx.nonce_hex) {
            Ok(v) => v,
            Err(e) => {
                failures += 1;
                println!("{} FAIL {}", fx.id, e);
                continue;
            }
        };

        let payload_bytes = match STANDARD.decode(&fx.payload_expectation_base64) {
            Ok(v) => v,
            Err(e) => {
                failures += 1;
                println!("{} FAIL payload base64 decode: {}", fx.id, e);
                continue;
            }
        };

        let decrypted = match decrypt_to_bytes(&conversation_key, &payload_bytes) {
            Ok(v) => v,
            Err(e) => {
                failures += 1;
                println!("{} FAIL decrypt error: {}", fx.id, e);
                continue;
            }
        };

        let decrypted_text = match String::from_utf8(decrypted) {
            Ok(v) => v,
            Err(e) => {
                failures += 1;
                println!("{} FAIL decrypt utf8: {}", fx.id, e);
                continue;
            }
        };

        if decrypted_text != fx.plaintext {
            failures += 1;
            println!("{} FAIL decrypt mismatch", fx.id);
            println!("  got : {:?}", decrypted_text);
            println!("  want: {:?}", fx.plaintext);
            continue;
        }

        let mut rng = FixedNonceRng::new(nonce);
        let encrypted =
            match encrypt_to_bytes_with_rng(&mut rng, &conversation_key, fx.plaintext.as_bytes()) {
                Ok(v) => v,
                Err(e) => {
                    failures += 1;
                    println!("{} FAIL encrypt error: {}", fx.id, e);
                    continue;
                }
            };

        let encoded = STANDARD.encode(encrypted);
        if encoded != fx.payload_expectation_base64 {
            failures += 1;
            println!("{} FAIL encrypt mismatch", fx.id);
            println!("  got : {}", encoded);
            println!("  want: {}", fx.payload_expectation_base64);
            continue;
        }

        println!("{} PASS decrypt+encrypt parity", fx.id);
    }

    let passed = total - failures;
    if failures > 0 {
        println!("RESULT FAIL: {}/{} fixtures passed", passed, total);
        process::exit(1);
    }

    println!("RESULT PASS: {}/{} fixtures", passed, total);
}
