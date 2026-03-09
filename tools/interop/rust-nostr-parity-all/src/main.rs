use std::fs;
use std::process;
use std::{borrow::Cow};

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
use nostr::filter::MatchEventOptions;
use nostr::{
    ClientMessage, Event, EventBuilder, EventId, Filter, JsonUtil, Keys, Kind, PublicKey,
    RelayMessage, RelayUrl, SecretKey, SubscriptionId, Tag, Timestamp,
};
use rand::{CryptoRng, RngCore};
use serde::Deserialize;

#[derive(Clone, Copy, PartialEq, Eq)]
#[allow(dead_code)]
enum Taxonomy {
    LibSupported,
    HarnessCovered,
    NotCoveredInThisPass,
    LibUnsupported,
}

impl Taxonomy {
    fn as_str(self) -> &'static str {
        match self {
            Taxonomy::LibSupported => "LIB_SUPPORTED",
            Taxonomy::HarnessCovered => "HARNESS_COVERED",
            Taxonomy::NotCoveredInThisPass => "NOT_COVERED_IN_THIS_PASS",
            Taxonomy::LibUnsupported => "LIB_UNSUPPORTED",
        }
    }
}

#[derive(Clone, Copy)]
enum Depth {
    Baseline,
    Edge,
    Deep,
}

impl Depth {
    fn as_str(self) -> &'static str {
        match self {
            Depth::Baseline => "BASELINE",
            Depth::Edge => "EDGE",
            Depth::Deep => "DEEP",
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum CheckResult {
    Pass,
    Fail,
}

impl CheckResult {
    fn as_str(self) -> &'static str {
        match self {
            CheckResult::Pass => "PASS",
            CheckResult::Fail => "FAIL",
        }
    }
}

#[derive(Clone)]
struct NipResult {
    nip: &'static str,
    taxonomy: Taxonomy,
    depth: Depth,
    result: CheckResult,
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

fn push_harness_covered(
    results: &mut Vec<NipResult>,
    nip: &'static str,
    depth: Depth,
    result: Result<(), String>,
) {
    match result {
        Ok(()) => results.push(NipResult {
            nip,
            taxonomy: Taxonomy::HarnessCovered,
            depth,
            result: CheckResult::Pass,
            detail: None,
        }),
        Err(detail) => results.push(NipResult {
            nip,
            taxonomy: Taxonomy::HarnessCovered,
            depth,
            result: CheckResult::Fail,
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

    let mut tampered_value: serde_json::Value =
        serde_json::from_str(&json).map_err(|e| format!("tampered event json parse: {e}"))?;
    tampered_value["sig"] = serde_json::Value::String(
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff".to_string(),
    );
    let tampered = Event::from_json(tampered_value.to_string())
        .map_err(|e| format!("tampered event parse: {e}"))?;
    if tampered.verify().is_ok() {
        return Err("tampered signature accepted".to_string());
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

    let non_contact = EventBuilder::text_note("nip02 negative")
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign non-contact event: {e}"))?;
    if non_contact.tags.public_keys().any(|k| *k == target) {
        return Err("text note unexpectedly exposed contact p tag".to_string());
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

    let empty_request = EventBuilder::delete(EventDeletionRequest::new())
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign empty delete event: {e}"))?;
    if empty_request.tags.event_ids().next().is_some() {
        return Err("empty delete request unexpectedly contains e tag".to_string());
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

    let malformed = r#"{"name":"Parity Relay","supported_nips":"bad"}"#;
    if RelayInformationDocument::from_json(malformed).is_ok() {
        return Err("relay info accepted malformed supported_nips type".to_string());
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
    let no_zero_bits = nostr::nips::nip13::get_leading_zero_bits(vec![0xff]);
    if no_zero_bits != 0 {
        return Err(format!("leading-zero bits mismatch: got {no_zero_bits} want 0"));
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
        let nonce =
            parse_array_32("nonce", &fixture.nonce_hex).map_err(|e| format!("fixture nonce parse: {e}"))?;
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
        let encrypted = encrypt_to_bytes_with_rng(&mut rng, &conversation_key, fixture.plaintext.as_bytes())
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

    if UnwrappedGift::from_gift_wrap(&sender, &gift_wrap).await.is_ok() {
        return Err("gift_wrap unwrap accepted wrong recipient".to_string());
    }

    Ok(())
}

fn check_nip65() -> Result<(), String> {
    let keys = parse_keys()?;
    let relay_a = RelayUrl::parse("wss://relay-a.example").map_err(|e| format!("relay-a parse: {e}"))?;
    let relay_b = RelayUrl::parse("wss://relay-b.example").map_err(|e| format!("relay-b parse: {e}"))?;
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

    let non_relay_event = EventBuilder::text_note("nip65 negative")
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign non-relay event: {e}"))?;
    if nip65::extract_relay_list(&non_relay_event).next().is_some() {
        return Err("non-relay event unexpectedly produced relay metadata".to_string());
    }

    Ok(())
}

fn check_nip40() -> Result<(), String> {
    let keys = parse_keys()?;
    let event = EventBuilder::text_note("nip40 baseline")
        .tags([Tag::expiration(Timestamp::from(2_u64))])
        .sign_with_keys(&keys)
        .map_err(|e| format!("expiration-tag event build failed: {e}"))?;
    if event.is_expired_at(&Timestamp::from(2_u64)) {
        return Err("expiration boundary mismatch at exact second".to_string());
    }
    if !event.is_expired_at(&Timestamp::from(3_u64)) {
        return Err("expiration boundary mismatch after second".to_string());
    }

    let regular_event = EventBuilder::text_note("nip40 negative")
        .sign_with_keys(&keys)
        .map_err(|e| format!("regular event build failed: {e}"))?;
    if regular_event.is_expired_at(&Timestamp::from(9_999_u64)) {
        return Err("event without expiration tag was treated as expired".to_string());
    }

    Ok(())
}

fn check_nip45() -> Result<(), String> {
    let message =
        ClientMessage::from_json(r#"["COUNT","sub-a",{"kinds":[1]}]"#)
            .map_err(|e| format!("COUNT parse failed unexpectedly: {e}"))?;
    if !matches!(message, ClientMessage::Count { .. }) {
        return Err("COUNT parse did not return Count variant".to_string());
    }
    let roundtrip = message.as_json();
    if !roundtrip.contains("\"COUNT\"") {
        return Err("COUNT serialization missing command".to_string());
    }

    let relay_count =
        RelayMessage::from_json(r#"["COUNT","sub-a",{"count":7}]"#)
            .map_err(|e| format!("relay COUNT parse failed unexpectedly: {e}"))?;
    if !matches!(relay_count, RelayMessage::Count { .. }) {
        return Err("relay COUNT parse did not return Count variant".to_string());
    }

    if ClientMessage::from_json(r#"["COUNT","sub-a"]"#).is_ok() {
        return Err("COUNT malformed client shape was accepted".to_string());
    }
    if RelayMessage::from_json(r#"["COUNT","sub-a",{"count":"bad"}]"#).is_ok() {
        return Err("COUNT malformed relay payload was accepted".to_string());
    }

    Ok(())
}

fn check_nip50() -> Result<(), String> {
    let filter = Filter::new().search("nostr parity");
    let parsed =
        Filter::from_json(r#"{"search":"nostr parity","kinds":[1]}"#)
            .map_err(|e| format!("search filter parse failed: {e}"))?;
    if parsed.search.as_deref() != Some("nostr parity") {
        return Err("search field not preserved in parsed filter".to_string());
    }

    let keys = parse_keys()?;
    let event = EventBuilder::text_note("nostr parity baseline")
        .sign_with_keys(&keys)
        .map_err(|e| format!("search baseline event build failed: {e}"))?;
    if !filter.match_event(&event, MatchEventOptions::new()) {
        return Err("search-enabled filter failed baseline event match".to_string());
    }

    let non_match_event = EventBuilder::text_note("different content")
        .sign_with_keys(&keys)
        .map_err(|e| format!("search negative event build failed: {e}"))?;
    let opts_nip50_enabled = MatchEventOptions::new().nip50(true);
    if filter.match_event(&non_match_event, opts_nip50_enabled) {
        return Err("search-enabled match options accepted mismatched content".to_string());
    }

    let opts_nip50_disabled = MatchEventOptions::new().nip50(false);
    if !filter.match_event(&non_match_event, opts_nip50_disabled) {
        return Err("match options with nip50 disabled unexpectedly rejected event".to_string());
    }

    let kind_mismatch_filter = Filter::new().search("nostr parity").kind(Kind::Metadata);
    if kind_mismatch_filter.match_event(&event, MatchEventOptions::new()) {
        return Err("filter accepted event with mismatched kind".to_string());
    }

    if Filter::from_json(r#"{"search":{"q":"bad"}}"#).is_ok() {
        return Err("invalid search field type accepted".to_string());
    }

    Ok(())
}

fn check_nip70() -> Result<(), String> {
    let keys = parse_keys()?;
    let protected_event = EventBuilder::text_note("nip70 baseline")
        .tags([Tag::protected()])
        .sign_with_keys(&keys)
        .map_err(|e| format!("protected-tag event build failed: {e}"))?;
    if !protected_event.is_protected() {
        return Err("protected event was not detected".to_string());
    }
    let has_dash_tag = protected_event
        .tags
        .iter()
        .any(|tag| tag.as_slice().len() == 1 && tag.as_slice()[0] == "-");
    if !has_dash_tag {
        return Err("protected event missing structural '-' tag".to_string());
    }

    let regular_event = EventBuilder::text_note("nip70 regular")
        .sign_with_keys(&keys)
        .map_err(|e| format!("regular event build failed: {e}"))?;
    if regular_event.is_protected() {
        return Err("regular event flagged as protected".to_string());
    }

    Ok(())
}

fn check_nip77() -> Result<(), String> {
    let message =
        ClientMessage::from_json(r#"["NEG-OPEN","sub-b",{},"00"]"#)
            .map_err(|e| format!("NEG-OPEN parse failed unexpectedly: {e}"))?;
    if !matches!(message, ClientMessage::NegOpen { .. }) {
        return Err("NEG-OPEN parse did not return NegOpen variant".to_string());
    }
    let open_serialized = ClientMessage::neg_open(
        SubscriptionId::new("sub-b"),
        Filter::new(),
        "00".to_string(),
    )
    .as_json();
    if !open_serialized.contains("NEG-OPEN") {
        return Err("NEG-OPEN serialization missing command".to_string());
    }

    let neg_msg = ClientMessage::from_json(r#"["NEG-MSG","sub-b","0102"]"#)
        .map_err(|e| format!("NEG-MSG parse failed unexpectedly: {e}"))?;
    if !matches!(neg_msg, ClientMessage::NegMsg { .. }) {
        return Err("NEG-MSG parse did not return NegMsg variant".to_string());
    }
    let neg_close = ClientMessage::from_json(r#"["NEG-CLOSE","sub-b"]"#)
        .map_err(|e| format!("NEG-CLOSE parse failed unexpectedly: {e}"))?;
    if !matches!(neg_close, ClientMessage::NegClose { .. }) {
        return Err("NEG-CLOSE parse did not return NegClose variant".to_string());
    }

    let relay_neg_msg = RelayMessage::from_json(r#"["NEG-MSG","sub-b","0203"]"#)
        .map_err(|e| format!("relay NEG-MSG parse failed unexpectedly: {e}"))?;
    if !matches!(relay_neg_msg, RelayMessage::NegMsg { .. }) {
        return Err("relay NEG-MSG parse did not return NegMsg variant".to_string());
    }
    let relay_neg_err = RelayMessage::from_json(r#"["NEG-ERR","sub-b","bad-frame"]"#)
        .map_err(|e| format!("relay NEG-ERR parse failed unexpectedly: {e}"))?;
    if !matches!(relay_neg_err, RelayMessage::NegErr { .. }) {
        return Err("relay NEG-ERR parse did not return NegErr variant".to_string());
    }

    let msg_serialized = ClientMessage::NegMsg {
        subscription_id: Cow::Owned(SubscriptionId::new("sub-b")),
        message: Cow::Owned("0203".to_string()),
    }
    .as_json();
    if !msg_serialized.contains("NEG-MSG") {
        return Err("NEG-MSG serialization missing command".to_string());
    }
    let close_serialized = ClientMessage::NegClose {
        subscription_id: Cow::Owned(SubscriptionId::new("sub-b")),
    }
    .as_json();
    if !close_serialized.contains("NEG-CLOSE") {
        return Err("NEG-CLOSE serialization missing command".to_string());
    }

    let relay_err_serialized = RelayMessage::NegErr {
        subscription_id: Cow::Owned(SubscriptionId::new("sub-b")),
        message: Cow::Owned("bad-frame".to_string()),
    }
    .as_json();
    if !relay_err_serialized.contains("NEG-ERR") {
        return Err("NEG-ERR serialization missing command".to_string());
    }

    if ClientMessage::from_json(r#"["NEG-OPEN","sub-b",{}]"#).is_ok() {
        return Err("malformed NEG-OPEN shape was accepted".to_string());
    }
    if RelayMessage::from_json(r#"["NEG-ERR","sub-b",{}]"#).is_ok() {
        return Err("malformed NEG-ERR shape was accepted".to_string());
    }

    Ok(())
}

#[tokio::main]
async fn main() {
    let mut results: Vec<NipResult> = Vec::new();

    push_harness_covered(&mut results, "NIP-01", Depth::Baseline, check_nip01());
    push_harness_covered(&mut results, "NIP-02", Depth::Baseline, check_nip02());
    push_harness_covered(&mut results, "NIP-09", Depth::Baseline, check_nip09());
    push_harness_covered(&mut results, "NIP-11", Depth::Baseline, check_nip11());
    push_harness_covered(&mut results, "NIP-13", Depth::Baseline, check_nip13());
    push_harness_covered(&mut results, "NIP-19", Depth::Edge, check_nip19());
    push_harness_covered(&mut results, "NIP-21", Depth::Edge, check_nip21());
    push_harness_covered(&mut results, "NIP-42", Depth::Edge, check_nip42());
    push_harness_covered(&mut results, "NIP-44", Depth::Deep, check_nip44());
    push_harness_covered(&mut results, "NIP-59", Depth::Baseline, check_nip59().await);
    push_harness_covered(&mut results, "NIP-65", Depth::Edge, check_nip65());

    push_harness_covered(&mut results, "NIP-40", Depth::Baseline, check_nip40());
    push_harness_covered(&mut results, "NIP-45", Depth::Edge, check_nip45());
    push_harness_covered(&mut results, "NIP-50", Depth::Edge, check_nip50());
    push_harness_covered(&mut results, "NIP-70", Depth::Baseline, check_nip70());
    push_harness_covered(&mut results, "NIP-77", Depth::Edge, check_nip77());

    let mut pass_count = 0usize;
    let mut fail_count = 0usize;
    let mut harness_covered_count = 0usize;
    let mut lib_supported_count = 0usize;
    let mut not_covered_count = 0usize;
    let mut lib_unsupported_count = 0usize;

    for result in &results {
        match result.taxonomy {
            Taxonomy::HarnessCovered => {
                harness_covered_count += 1;
                if result.result == CheckResult::Pass {
                    pass_count += 1;
                } else if result.result == CheckResult::Fail {
                    fail_count += 1;
                }
            }
            Taxonomy::LibSupported => {
                lib_supported_count += 1;
            }
            Taxonomy::NotCoveredInThisPass => {
                not_covered_count += 1;
            }
            Taxonomy::LibUnsupported => {
                lib_unsupported_count += 1;
            }
        }

        let detail = result
            .detail
            .as_ref()
            .map(|d| format!(" | detail={d}"))
            .unwrap_or_default();
        println!(
            "{} | taxonomy={} | depth={} | result={}{}",
            result.nip,
            result.taxonomy.as_str(),
            result.depth.as_str(),
            result.result.as_str(),
            detail
        );
    }

    println!(
        "SUMMARY pass={} fail={} harness_covered={} lib_supported={} \
not_covered_in_this_pass={} lib_unsupported={} total={}",
        pass_count,
        fail_count,
        harness_covered_count,
        lib_supported_count,
        not_covered_count,
        lib_unsupported_count,
        results.len()
    );

    if fail_count > 0 {
        process::exit(1);
    }
}
