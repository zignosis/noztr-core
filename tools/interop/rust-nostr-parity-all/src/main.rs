use std::fs;
use std::process;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use nostr::nips::nip02::Contact;
use nostr::nips::nip09::EventDeletionRequest;
use nostr::nips::nip11::RelayInformationDocument;
use nostr::nips::nip19::{FromBech32, ToBech32};
use nostr::nips::nip21::{Nip21, ToNostrUri};
use nostr::nips::nip42;
use nostr::nips::nip44::v2::{decrypt_to_bytes, encrypt_to_bytes_with_rng, ConversationKey};
use nostr::nips::nip59::UnwrappedGift;
use nostr::nips::nip65::{self, RelayMetadata};
use nostr::{Event, EventBuilder, EventId, JsonUtil, Keys, Kind, PublicKey, RelayUrl, SecretKey};
use rand::{CryptoRng, RngCore};
use serde::Deserialize;

#[derive(Clone)]
struct NipResult {
    nip: &'static str,
    status: &'static str,
    detail: Option<String>,
}

#[derive(Deserialize)]
struct FixtureSet {
    fixtures: Vec<Fixture>,
}

#[derive(Deserialize)]
struct Fixture {
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
    bytes
        .as_slice()
        .try_into()
        .map_err(|_| format!("{name} length: got {} want 32", bytes.len()))
}

fn parse_keys() -> Result<Keys, String> {
    Keys::parse("6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e")
        .map_err(|e| format!("keys parse: {e}"))
}

fn push_supported(results: &mut Vec<NipResult>, nip: &'static str, result: Result<(), String>) {
    match result {
        Ok(()) => results.push(NipResult {
            nip,
            status: "PASS",
            detail: None,
        }),
        Err(detail) => results.push(NipResult {
            nip,
            status: "FAIL",
            detail: Some(detail),
        }),
    }
}

fn check_nip01() -> Result<(), String> {
    let keys = parse_keys()?;
    let signed = EventBuilder::text_note("nip01 baseline")
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign event: {e}"))?;
    let json = signed.as_json();
    let parsed = Event::from_json(&json).map_err(|e| format!("parse event: {e}"))?;
    parsed.verify().map_err(|e| format!("verify event: {e}"))?;
    if parsed.id != signed.id {
        return Err("id mismatch after parse".to_string());
    }
    Ok(())
}

fn check_nip02() -> Result<(), String> {
    let keys = parse_keys()?;
    let target =
        PublicKey::from_hex("f831caf722214748c72db4829986bd0cbb2bb8b3aeade1c959624a52a9629046")
            .map_err(|e| format!("target pubkey parse: {e}"))?;
    let event = EventBuilder::contact_list([Contact::new(target)])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign contact list: {e}"))?;
    if event.kind != Kind::ContactList {
        return Err("wrong event kind".to_string());
    }
    let found = event.tags.public_keys().any(|k| *k == target);
    if !found {
        return Err("missing expected p tag".to_string());
    }
    Ok(())
}

fn check_nip09() -> Result<(), String> {
    let keys = parse_keys()?;
    let target_id =
        EventId::from_hex("7469af3be8c8e06e1b50ef1caceba30392ddc0b6614507398b7d7daa4c218e96")
            .map_err(|e| format!("target id parse: {e}"))?;
    let request = EventDeletionRequest::new()
        .id(target_id)
        .reason("cleanup baseline");
    let event = EventBuilder::delete(request)
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign delete event: {e}"))?;
    if event.kind != Kind::EventDeletion {
        return Err("wrong event kind".to_string());
    }
    if event.content != "cleanup baseline" {
        return Err("unexpected deletion content".to_string());
    }
    let found = event.tags.event_ids().any(|id| *id == target_id);
    if !found {
        return Err("missing expected e tag".to_string());
    }
    Ok(())
}

fn check_nip11() -> Result<(), String> {
    let json = r#"{"name":"Parity Relay","supported_nips":[1,9,11]}"#;
    let document =
        RelayInformationDocument::from_json(json).map_err(|e| format!("relay info parse: {e}"))?;
    if document.name.as_deref() != Some("Parity Relay") {
        return Err("relay info name mismatch".to_string());
    }
    let roundtrip = RelayInformationDocument::from_json(&document.as_json())
        .map_err(|e| format!("relay info roundtrip parse: {e}"))?;
    if roundtrip.supported_nips != document.supported_nips {
        return Err("relay info roundtrip mismatch".to_string());
    }
    Ok(())
}

fn check_nip13() -> Result<(), String> {
    let bytes = hex::decode("0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
        .map_err(|e| format!("hex decode: {e}"))?;
    let bits = nostr::nips::nip13::get_leading_zero_bits(bytes);
    if bits != 4 {
        return Err(format!("leading-zero bits mismatch: got {bits} want 4"));
    }
    Ok(())
}

fn check_nip19() -> Result<(), String> {
    let pubkey =
        PublicKey::from_hex("aa4fc8665f5696e33db7e1a572e3b0f5b3d615837b0f362dcb1c8068b098c7b4")
            .map_err(|e| format!("pubkey parse: {e}"))?;
    let npub = pubkey
        .to_bech32()
        .map_err(|e| format!("pubkey to_bech32: {e}"))?;
    let pubkey_back = PublicKey::from_bech32(&npub).map_err(|e| format!("pubkey decode: {e}"))?;
    if pubkey_back != pubkey {
        return Err("pubkey bech32 roundtrip mismatch".to_string());
    }
    if EventId::from_bech32(&npub).is_ok() {
        return Err("invalid prefix accepted for event id decode".to_string());
    }
    if PublicKey::from_bech32("npub1invalid").is_ok() {
        return Err("invalid bech32 pubkey decode accepted".to_string());
    }

    let event_id =
        EventId::from_hex("d94a3f4dd87b9a3b0bed183b32e916fa29c8020107845d1752d72697fe5309a5")
            .map_err(|e| format!("event id parse: {e}"))?;
    let note = event_id
        .to_bech32()
        .map_err(|e| format!("event id to_bech32: {e}"))?;
    let event_id_back = EventId::from_bech32(&note).map_err(|e| format!("event id decode: {e}"))?;
    if event_id_back != event_id {
        return Err("event id bech32 roundtrip mismatch".to_string());
    }
    Ok(())
}

fn check_nip21() -> Result<(), String> {
    let pubkey =
        PublicKey::from_hex("aa4fc8665f5696e33db7e1a572e3b0f5b3d615837b0f362dcb1c8068b098c7b4")
            .map_err(|e| format!("pubkey parse: {e}"))?;
    let uri = pubkey
        .to_nostr_uri()
        .map_err(|e| format!("to nostr uri: {e}"))?;
    let parsed = Nip21::parse(&uri).map_err(|e| format!("parse nostr uri: {e}"))?;
    let roundtrip = parsed
        .to_nostr_uri()
        .map_err(|e| format!("uri roundtrip: {e}"))?;
    if roundtrip != uri {
        return Err("nostr uri roundtrip mismatch".to_string());
    }

    if Nip21::parse("https://relay.damus.io").is_ok() {
        return Err("non-nostr uri accepted".to_string());
    }

    let secret_key =
        SecretKey::from_hex("6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e")
            .map_err(|e| format!("secret key parse: {e}"))?;
    let nsec = secret_key
        .to_bech32()
        .map_err(|e| format!("secret key to_bech32: {e}"))?;
    let forbidden_uri = format!("nostr:{nsec}");
    if Nip21::parse(&forbidden_uri).is_ok() {
        return Err("forbidden nsec uri accepted".to_string());
    }
    Ok(())
}

fn check_nip42() -> Result<(), String> {
    let keys = parse_keys()?;
    let relay_url =
        RelayUrl::parse("wss://relay.damus.io").map_err(|e| format!("relay parse: {e}"))?;
    let other_relay_url =
        RelayUrl::parse("wss://relay.example").map_err(|e| format!("other relay parse: {e}"))?;
    let challenge = "parity-challenge";
    let event = EventBuilder::auth(challenge, relay_url.clone())
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign auth event: {e}"))?;
    if !nip42::is_valid_auth_event(&event, &relay_url, challenge) {
        return Err("valid auth event rejected".to_string());
    }
    if nip42::is_valid_auth_event(&event, &relay_url, "different") {
        return Err("invalid challenge accepted".to_string());
    }
    if nip42::is_valid_auth_event(&event, &other_relay_url, challenge) {
        return Err("invalid relay accepted".to_string());
    }

    let not_auth = EventBuilder::text_note("nip42 negative kind")
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign non-auth event: {e}"))?;
    if nip42::is_valid_auth_event(&not_auth, &relay_url, challenge) {
        return Err("non-auth event accepted".to_string());
    }
    Ok(())
}

fn check_nip44() -> Result<(), String> {
    let fixture_path = "tools/interop/fixtures/nip44_ut_e_003.json";
    let input = fs::read_to_string(fixture_path).map_err(|e| format!("fixture load error: {e}"))?;
    let set: FixtureSet =
        serde_json::from_str(&input).map_err(|e| format!("fixture parse error: {e}"))?;

    for fixture in set.fixtures {
        let conversation_key = parse_array_32("key", &fixture.conversation_key_hex)
            .map(ConversationKey::new)
            .map_err(|e| format!("fixture key parse: {e}"))?;
        let nonce = parse_array_32("nonce", &fixture.nonce_hex)
            .map_err(|e| format!("fixture nonce parse: {e}"))?;
        let payload = STANDARD
            .decode(&fixture.payload_expectation_base64)
            .map_err(|e| format!("fixture payload decode: {e}"))?;

        let decrypted = decrypt_to_bytes(&conversation_key, &payload)
            .map_err(|e| format!("decrypt failure: {e}"))?;
        let decrypted_text =
            String::from_utf8(decrypted).map_err(|e| format!("decrypt utf8 failure: {e}"))?;
        if decrypted_text != fixture.plaintext {
            return Err("fixture decrypt mismatch".to_string());
        }

        let mut rng = FixedNonceRng::new(nonce);
        let encrypted =
            encrypt_to_bytes_with_rng(&mut rng, &conversation_key, fixture.plaintext.as_bytes())
                .map_err(|e| format!("encrypt failure: {e}"))?;
        let encoded = STANDARD.encode(encrypted);
        if encoded != fixture.payload_expectation_base64 {
            return Err("fixture encrypt mismatch".to_string());
        }

        if payload.len() > 1 {
            let mut malformed = payload.clone();
            malformed.truncate(malformed.len() - 1);
            if decrypt_to_bytes(&conversation_key, &malformed).is_ok() {
                return Err("malformed payload accepted".to_string());
            }
        }
    }

    Ok(())
}

async fn check_nip59() -> Result<(), String> {
    let sender = Keys::parse("6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e")
        .map_err(|e| format!("sender key parse: {e}"))?;
    let receiver = Keys::parse("7b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e")
        .map_err(|e| format!("receiver key parse: {e}"))?;
    let rumor = EventBuilder::text_note("nip59 baseline").build(sender.public_key());
    let gift_wrap = EventBuilder::gift_wrap(&sender, &receiver.public_key(), rumor, [])
        .await
        .map_err(|e| format!("gift_wrap compose: {e}"))?;
    let unwrapped = UnwrappedGift::from_gift_wrap(&receiver, &gift_wrap)
        .await
        .map_err(|e| format!("gift_wrap unwrap: {e}"))?;
    if unwrapped.sender != sender.public_key() {
        return Err("sender mismatch after unwrap".to_string());
    }
    if unwrapped.rumor.kind != Kind::TextNote {
        return Err("rumor kind mismatch".to_string());
    }
    if unwrapped.rumor.content != "nip59 baseline" {
        return Err("rumor content mismatch".to_string());
    }
    Ok(())
}

fn check_nip65() -> Result<(), String> {
    let keys = parse_keys()?;
    let relay_a =
        RelayUrl::parse("wss://relay-a.example").map_err(|e| format!("relay-a parse: {e}"))?;
    let relay_b =
        RelayUrl::parse("wss://relay-b.example").map_err(|e| format!("relay-b parse: {e}"))?;
    let event = EventBuilder::relay_list([
        (relay_a.clone(), Some(RelayMetadata::Read)),
        (relay_b.clone(), Some(RelayMetadata::Write)),
    ])
    .sign_with_keys(&keys)
    .map_err(|e| format!("sign relay list: {e}"))?;

    let extracted: Vec<(String, Option<RelayMetadata>)> = nip65::extract_relay_list(&event)
        .map(|(url, metadata)| (url.as_str().to_string(), *metadata))
        .collect();
    if extracted.len() != 2 {
        return Err("unexpected relay metadata count".to_string());
    }
    let has_read = extracted
        .iter()
        .any(|(url, metadata)| url == relay_a.as_str() && *metadata == Some(RelayMetadata::Read));
    let has_write = extracted
        .iter()
        .any(|(url, metadata)| url == relay_b.as_str() && *metadata == Some(RelayMetadata::Write));
    if !has_read || !has_write {
        return Err("relay metadata extraction mismatch".to_string());
    }

    if "invalid".parse::<RelayMetadata>().is_ok() {
        return Err("invalid relay metadata marker accepted".to_string());
    }
    Ok(())
}

#[tokio::main]
async fn main() {
    let mut results: Vec<NipResult> = Vec::new();

    push_supported(&mut results, "NIP-01", check_nip01());
    push_supported(&mut results, "NIP-02", check_nip02());
    push_supported(&mut results, "NIP-09", check_nip09());
    push_supported(&mut results, "NIP-11", check_nip11());
    push_supported(&mut results, "NIP-13", check_nip13());
    push_supported(&mut results, "NIP-19", check_nip19());
    push_supported(&mut results, "NIP-21", check_nip21());
    push_supported(&mut results, "NIP-42", check_nip42());
    push_supported(&mut results, "NIP-44", check_nip44());
    push_supported(&mut results, "NIP-59", check_nip59().await);
    push_supported(&mut results, "NIP-65", check_nip65());

    for nip in ["NIP-40", "NIP-70", "NIP-45", "NIP-50", "NIP-77"] {
        results.push(NipResult {
            nip,
            status: "UNSUPPORTED",
            detail: Some("no rust-nostr overlap helper in this pass".to_string()),
        });
    }

    let mut pass_count = 0usize;
    let mut fail_count = 0usize;
    let mut unsupported_count = 0usize;

    for result in &results {
        match result.status {
            "PASS" => {
                pass_count += 1;
                println!("{} PASS", result.nip);
            }
            "FAIL" => {
                fail_count += 1;
                println!(
                    "{} FAIL{}",
                    result.nip,
                    result
                        .detail
                        .as_ref()
                        .map(|d| format!(": {d}"))
                        .unwrap_or_default()
                );
            }
            _ => {
                unsupported_count += 1;
                println!("{} UNSUPPORTED", result.nip);
            }
        }
    }

    println!(
        "SUMMARY pass={} fail={} unsupported={} total={}",
        pass_count,
        fail_count,
        unsupported_count,
        results.len()
    );

    if fail_count > 0 {
        process::exit(1);
    }
}
