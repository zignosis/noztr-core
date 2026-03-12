use std::borrow::Cow;
use std::fs;
use std::process;
use std::str::FromStr;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use nostr::filter::MatchEventOptions;
use nostr::nips::nip01::Coordinate;
use nostr::nips::nip02::Contact;
use nostr::nips::nip06::FromMnemonic;
use nostr::nips::nip09::EventDeletionRequest;
use nostr::nips::nip10::Marker as Nip10Marker;
use nostr::nips::nip11::RelayInformationDocument;
use nostr::nips::nip19::{FromBech32, ToBech32};
use nostr::nips::nip21::{Nip21, ToNostrUri};
use nostr::nips::nip22::{self, CommentTarget as Nip22CommentTarget};
use nostr::nips::nip42;
use nostr::nips::nip44::v2::{decrypt_to_bytes, encrypt_to_bytes_with_rng, ConversationKey};
use nostr::nips::nip46::{NostrConnectMessage, NostrConnectMethod, NostrConnectURI};
use nostr::nips::nip51::{ArticlesCuration, Bookmarks, Emojis, Interests, MuteList};
use nostr::nips::nip59::{self, UnwrappedGift};
use nostr::nips::nip65::{self, RelayMetadata};
use nostr::nips::nip73::ExternalContentId;
use nostr::parser::{NostrParser, Token};
use nostr::{
    ClientMessage, Event, EventBuilder, EventId, Filter, JsonUtil, Keys, Kind, PublicKey,
    RelayMessage, RelayUrl, SecretKey, SubscriptionId, Tag, TagStandard, Timestamp, Url,
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
#[allow(dead_code)]
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
    malformed_fixtures: Option<Vec<MalformedFixture>>,
}

#[derive(Deserialize)]
struct Fixture {
    conversation_key_hex: String,
    nonce_hex: String,
    plaintext: String,
    payload_expectation_base64: String,
}

#[derive(Deserialize)]
struct MalformedFixture {
    id: String,
    conversation_key_hex: String,
    payload_base64: String,
    expectation: String,
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

fn parse_alt_keys() -> Result<Keys, String> {
    Keys::parse("7a350bc1469e1a5b1244625fdbec8b23dc4af192e11cdb296cf9d567a90d3812")
        .map_err(|e| format!("alt keys parse: {e}"))
}

fn event_has_identifier(event: &Event, expected: &str) -> bool {
    event.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Identifier(identifier)) if identifier == expected
        )
    })
}

fn event_has_event_id(event: &Event, expected: EventId) -> bool {
    event.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Event { event_id, .. }) if *event_id == expected
        )
    })
}

fn event_has_public_key(event: &Event, expected: PublicKey) -> bool {
    event.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::PublicKey { public_key, .. }) if *public_key == expected
        )
    })
}

fn event_has_coordinate(event: &Event, expected: &Coordinate) -> bool {
    event.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Coordinate { coordinate, .. }) if coordinate == expected
        )
    })
}

fn event_has_relay(event: &Event, expected: &RelayUrl) -> bool {
    event.tags.iter().any(|tag| {
        matches!(tag.as_standardized(), Some(TagStandard::Relay(url)) if url == expected)
    })
}

fn event_has_hashtag(event: &Event, expected: &str) -> bool {
    event.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Hashtag(hashtag)) if hashtag == expected
        )
    })
}

fn event_has_word(event: &Event, expected: &str) -> bool {
    event.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Word(word)) if word == expected
        )
    })
}

fn event_has_url(event: &Event, expected: &Url) -> bool {
    event.tags.iter().any(|tag| {
        matches!(tag.as_standardized(), Some(TagStandard::Url(url)) if url == expected)
    })
}

fn event_has_emoji(event: &Event, shortcode: &str, expected_url: &Url) -> bool {
    event.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Emoji { shortcode: found, url })
                if found == shortcode && url == expected_url
        )
    })
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

    let mut tampered_content_value: serde_json::Value =
        serde_json::from_str(&json).map_err(|e| format!("tampered content json parse: {e}"))?;
    tampered_content_value["content"] = serde_json::Value::String("tampered-content".to_string());
    let tampered_content = Event::from_json(tampered_content_value.to_string())
        .map_err(|e| format!("tampered content event parse: {e}"))?;
    if tampered_content.verify().is_ok() {
        return Err("tampered content accepted".to_string());
    }

    let uppercase_filter = Filter::from_json(r##"{"#P":["target-author"]}"##)
        .map_err(|e| format!("uppercase filter parse: {e}"))?;
    let tagged_event = EventBuilder::new(Kind::TextNote, "nip01 uppercase tag")
        .tags([Tag::parse(vec!["P", "target-author"])
            .map_err(|e| format!("uppercase tag parse: {e}"))?])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign uppercase tag event: {e}"))?;
    if !uppercase_filter.match_event(&tagged_event, MatchEventOptions::new()) {
        return Err("uppercase tag filter did not match uppercase event tag".to_string());
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

    let malformed_contact = EventBuilder::new(Kind::ContactList, "")
        .tags([Tag::parse(vec!["p", "not-hex-pubkey"])
            .map_err(|e| format!("malformed p tag parse failed: {e}"))?])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign malformed contact event: {e}"))?;
    if malformed_contact.tags.public_keys().next().is_some() {
        return Err("malformed contact p tag unexpectedly parsed as public key".to_string());
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

    let malformed_delete = EventBuilder::new(Kind::EventDeletion, "")
        .tags([Tag::parse(vec!["e", "not-hex-event-id"])
            .map_err(|e| format!("malformed e tag parse failed: {e}"))?])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign malformed delete event: {e}"))?;
    if malformed_delete.tags.event_ids().next().is_some() {
        return Err("malformed delete e tag unexpectedly parsed as event id".to_string());
    }

    let invalid_coordinate = Coordinate::parse(
        "20500:aa4fc8665f5696e33db7e1a572e3b0f5b3d615837b0f362dcb1c8068b098c7b4:",
    )
    .map_err(|e| format!("invalid coordinate parse: {e}"))?;
    if invalid_coordinate.verify().is_ok() {
        return Err("ephemeral delete coordinate unexpectedly verified".to_string());
    }

    Ok(())
}

fn check_nip10() -> Result<(), String> {
    let root = Nip10Marker::from_str("root").map_err(|e| format!("root marker parse: {e}"))?;
    if root.to_string() != "root" {
        return Err("root marker display mismatch".to_string());
    }
    let reply = Nip10Marker::from_str("reply").map_err(|e| format!("reply marker parse: {e}"))?;
    if reply.to_string() != "reply" {
        return Err("reply marker display mismatch".to_string());
    }
    if Nip10Marker::from_str("mention").is_ok() {
        return Err("removed mention marker was accepted".to_string());
    }

    let widened_pubkey =
        PublicKey::from_hex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
            .map_err(|e| format!("widened pubkey parse: {e}"))?;
    let widened = Tag::parse(vec![
        "e",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    ])
    .map_err(|e| format!("4-slot e tag parse: {e}"))?;
    match widened.as_standardized() {
        Some(TagStandard::Event {
            marker, public_key, ..
        }) => {
            if marker.is_some() {
                return Err("4-slot e tag unexpectedly carried a marker".to_string());
            }
            if *public_key != Some(widened_pubkey) {
                return Err("4-slot e tag pubkey fallback mismatch".to_string());
            }
        }
        _ => return Err("4-slot e tag did not parse as standardized event tag".to_string()),
    }

    let marked = Tag::parse(vec![
        "e",
        "2222222222222222222222222222222222222222222222222222222222222222",
        "wss://relay.example",
        "reply",
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    ])
    .map_err(|e| format!("marked e tag parse: {e}"))?;
    if !marked.is_reply() {
        return Err("reply marker tag did not report reply".to_string());
    }

    Ok(())
}

fn check_nip18() -> Result<(), String> {
    let repost_keys = parse_keys()?;
    let target_keys = parse_alt_keys()?;
    let relay = RelayUrl::parse("wss://relay.example").map_err(|e| format!("relay parse: {e}"))?;

    let text_note = EventBuilder::text_note("nip18 text note")
        .sign_with_keys(&target_keys)
        .map_err(|e| format!("sign text note: {e}"))?;
    let repost = EventBuilder::repost(&text_note, Some(relay.clone()))
        .sign_with_keys(&repost_keys)
        .map_err(|e| format!("sign repost: {e}"))?;
    if repost.kind != Kind::Repost {
        return Err("text note repost did not use kind 6".to_string());
    }
    if repost.content != text_note.as_json() {
        return Err("text note repost content mismatch".to_string());
    }
    if repost.tags.event_ids().copied().next() != Some(text_note.id) {
        return Err("text note repost missing target event id".to_string());
    }
    if repost.tags.public_keys().copied().next() != Some(text_note.pubkey) {
        return Err("text note repost missing target public key".to_string());
    }

    let generic_target = EventBuilder::new(Kind::Custom(42), "generic target")
        .sign_with_keys(&target_keys)
        .map_err(|e| format!("sign generic target: {e}"))?;
    let generic_repost = EventBuilder::repost(&generic_target, None)
        .sign_with_keys(&repost_keys)
        .map_err(|e| format!("sign generic repost: {e}"))?;
    if generic_repost.kind != Kind::GenericRepost {
        return Err("generic target repost did not use kind 16".to_string());
    }
    let found_kind = generic_repost.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Kind { kind, .. }) if *kind == generic_target.kind
        )
    });
    if !found_kind {
        return Err("generic repost missing k tag".to_string());
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

    let unknown_field = r#"{"name":"Parity Relay","supported_nips":[1,9,11],"x-extra":"ok"}"#;
    let unknown_doc = RelayInformationDocument::from_json(unknown_field)
        .map_err(|e| format!("relay info unknown-field parse: {e}"))?;
    if unknown_doc.name.as_deref() != Some("Parity Relay") {
        return Err("relay info unknown-field parse changed known fields".to_string());
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
        return Err(format!(
            "leading-zero bits mismatch: got {no_zero_bits} want 0"
        ));
    }

    let empty_bits = nostr::nips::nip13::get_leading_zero_bits(Vec::new());
    if empty_bits != 0 {
        return Err(format!(
            "empty input leading-zero bits mismatch: got {empty_bits} want 0"
        ));
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

    let mut mixed_case = npub.clone();
    mixed_case.replace_range(4..5, "A");
    if PublicKey::from_bech32(&mixed_case).is_ok() {
        return Err("mixed-case bech32 pubkey decode accepted".to_string());
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

    let replaceable = Coordinate::new(Kind::MuteList, pubkey);
    let replaceable_naddr = replaceable
        .to_bech32()
        .map_err(|e| format!("replaceable naddr encode: {e}"))?;
    let replaceable_back =
        Coordinate::from_bech32(&replaceable_naddr).map_err(|e| format!("naddr decode: {e}"))?;
    if replaceable_back != replaceable {
        return Err("replaceable naddr roundtrip mismatch".to_string());
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

    if Nip21::parse("nostr:npub1invalid").is_ok() {
        return Err("malformed npub nostr uri accepted".to_string());
    }

    let replaceable = Coordinate::new(Kind::MuteList, pubkey);
    let replaceable_uri = replaceable
        .to_nostr_uri()
        .map_err(|e| format!("replaceable to nostr uri: {e}"))?;
    let replaceable_parsed =
        Nip21::parse(&replaceable_uri).map_err(|e| format!("replaceable parse: {e}"))?;
    let replaceable_roundtrip = replaceable_parsed
        .to_nostr_uri()
        .map_err(|e| format!("replaceable uri roundtrip: {e}"))?;
    if replaceable_roundtrip != replaceable_uri {
        return Err("replaceable naddr uri roundtrip mismatch".to_string());
    }
    Ok(())
}

fn check_nip22() -> Result<(), String> {
    let keys = parse_keys()?;
    let target_keys = parse_alt_keys()?;

    let target = EventBuilder::new(Kind::FileMetadata, "file target")
        .sign_with_keys(&target_keys)
        .map_err(|e| format!("sign comment target: {e}"))?;
    let event_comment = EventBuilder::comment("nice file", &target, Some(&target))
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign event comment: {e}"))?;
    let event_root =
        nip22::extract_root(&event_comment).ok_or("event comment missing root target")?;
    let event_parent =
        nip22::extract_parent(&event_comment).ok_or("event comment missing parent target")?;
    match event_root {
        Nip22CommentTarget::Event {
            id,
            pubkey_hint,
            kind,
            ..
        } => {
            if id != target.id {
                return Err("event comment root id mismatch".to_string());
            }
            if pubkey_hint != Some(target.pubkey) {
                return Err("event comment root pubkey mismatch".to_string());
            }
            if kind != Some(target.kind) {
                return Err("event comment root kind mismatch".to_string());
            }
        }
        _ => return Err("event comment root target kind mismatch".to_string()),
    }
    match event_parent {
        Nip22CommentTarget::Event {
            id,
            pubkey_hint,
            kind,
            ..
        } => {
            if id != target.id {
                return Err("event comment parent id mismatch".to_string());
            }
            if pubkey_hint != Some(target.pubkey) {
                return Err("event comment parent pubkey mismatch".to_string());
            }
            if kind != Some(target.kind) {
                return Err("event comment parent kind mismatch".to_string());
            }
        }
        _ => return Err("event comment parent target kind mismatch".to_string()),
    }

    let coordinate = Coordinate::new(Kind::LongFormTextNote, target.pubkey);
    let coordinate_root = Nip22CommentTarget::coordinate(Cow::Owned(coordinate.clone()), None);
    let coordinate_parent = Nip22CommentTarget::coordinate(Cow::Owned(coordinate.clone()), None);
    let coordinate_comment =
        EventBuilder::comment("nice article", coordinate_parent, Some(coordinate_root))
            .sign_with_keys(&keys)
            .map_err(|e| format!("sign coordinate comment: {e}"))?;
    let found_coordinate_root_kind = coordinate_comment.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Kind {
                kind,
                uppercase: true,
                ..
            }) if *kind == coordinate.kind
        )
    });
    if !found_coordinate_root_kind {
        return Err("coordinate comment missing uppercase root kind".to_string());
    }

    let external_content = ExternalContentId::Url(
        "https://example.com/article"
            .parse()
            .map_err(|e| format!("external url parse: {e}"))?,
    );
    let external_root = Nip22CommentTarget::external(Cow::Owned(external_content.clone()), None);
    let external_parent = Nip22CommentTarget::external(Cow::Owned(external_content.clone()), None);
    let external_comment = EventBuilder::comment("nice link", external_parent, Some(external_root))
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign external comment: {e}"))?;
    let external_root_target =
        nip22::extract_root(&external_comment).ok_or("external comment missing root target")?;
    let external_parent_target =
        nip22::extract_parent(&external_comment).ok_or("external comment missing parent target")?;
    match external_root_target {
        Nip22CommentTarget::External { content, .. } => {
            if content != Cow::Borrowed(&external_content) {
                return Err("external comment root content mismatch".to_string());
            }
        }
        _ => return Err("external comment root target kind mismatch".to_string()),
    }
    match external_parent_target {
        Nip22CommentTarget::External { content, .. } => {
            if content != Cow::Borrowed(&external_content) {
                return Err("external comment parent content mismatch".to_string());
            }
        }
        _ => return Err("external comment parent target kind mismatch".to_string()),
    }

    let parent_only_comment = EventBuilder::comment("parent only", &target, None::<&Event>)
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign parent-only comment: {e}"))?;
    if nip22::extract_root(&parent_only_comment).is_some() {
        return Err("parent-only comment unexpectedly produced a root target".to_string());
    }
    let parent_only_target =
        nip22::extract_parent(&parent_only_comment).ok_or("parent-only comment missing parent")?;
    match parent_only_target {
        Nip22CommentTarget::Event {
            id,
            pubkey_hint,
            kind,
            ..
        } => {
            if id != target.id {
                return Err("parent-only comment parent id mismatch".to_string());
            }
            if pubkey_hint != Some(target.pubkey) {
                return Err("parent-only comment parent pubkey mismatch".to_string());
            }
            if kind != Some(target.kind) {
                return Err("parent-only comment parent kind mismatch".to_string());
            }
        }
        _ => return Err("parent-only comment target kind mismatch".to_string()),
    }

    Ok(())
}

fn check_nip25() -> Result<(), String> {
    let keys = parse_keys()?;
    let target_keys = parse_alt_keys()?;
    let target = EventBuilder::text_note("nip25 target")
        .sign_with_keys(&target_keys)
        .map_err(|e| format!("sign reaction target: {e}"))?;
    let reaction = EventBuilder::reaction(&target, "+")
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign reaction event: {e}"))?;
    if reaction.kind != Kind::Reaction {
        return Err("reaction builder produced wrong kind".to_string());
    }
    if reaction.content != "+" {
        return Err("reaction builder content mismatch".to_string());
    }
    if reaction.tags.event_ids().copied().next() != Some(target.id) {
        return Err("reaction builder missing target event id".to_string());
    }
    if reaction.tags.public_keys().copied().next() != Some(target.pubkey) {
        return Err("reaction builder missing target public key".to_string());
    }
    let found_kind = reaction.tags.iter().any(|tag| {
        matches!(
            tag.as_standardized(),
            Some(TagStandard::Kind { kind, .. }) if *kind == target.kind
        )
    });
    if !found_kind {
        return Err("reaction builder missing target kind tag".to_string());
    }

    let emoji = Tag::parse(vec!["emoji", "soapbox", "https://cdn.example/soapbox.png"])
        .map_err(|e| format!("emoji tag parse: {e}"))?;
    match emoji.as_standardized() {
        Some(TagStandard::Emoji { shortcode, .. }) if shortcode == "soapbox" => {}
        _ => return Err("emoji tag did not parse as standardized emoji".to_string()),
    }

    let invalid_url = Tag::parse(vec!["emoji", "soapbox", "not a url"])
        .map_err(|e| format!("invalid-url emoji raw parse: {e}"))?;
    if matches!(
        invalid_url.as_standardized(),
        Some(TagStandard::Emoji { .. })
    ) {
        return Err("emoji tag standardized invalid url".to_string());
    }

    let widened_shortcode =
        Tag::parse(vec!["emoji", "soap-box", "https://cdn.example/soapbox.png"])
            .map_err(|e| format!("widened shortcode parse: {e}"))?;
    match widened_shortcode.as_standardized() {
        Some(TagStandard::Emoji { shortcode, .. }) if shortcode == "soap-box" => {}
        _ => return Err("emoji shortcode permissive parse changed unexpectedly".to_string()),
    }

    Ok(())
}

fn check_nip27() -> Result<(), String> {
    let keys = parse_keys()?;
    let target_keys = parse_alt_keys()?;
    let npub_uri = keys
        .public_key()
        .to_nostr_uri()
        .map_err(|e| format!("npub uri encode: {e}"))?;
    let note = EventBuilder::text_note("nip27 target")
        .sign_with_keys(&target_keys)
        .map_err(|e| format!("sign nip27 target: {e}"))?;
    let note_uri = note
        .id
        .to_nostr_uri()
        .map_err(|e| format!("note uri encode: {e}"))?;
    let content = format!(
        "Look at [{npub_uri}] and {note_uri}. Broken nostr:npub1broken Uppercase nostr:npub1DRVpZev3"
    );

    let nostr_tokens: Vec<_> = NostrParser::new()
        .parse(&content)
        .filter_map(|token| match token {
            Token::Nostr(uri) => Some(uri),
            _ => None,
        })
        .collect();
    if nostr_tokens.len() != 2 {
        return Err(format!(
            "unexpected NIP-27 token count: {}",
            nostr_tokens.len()
        ));
    }
    match &nostr_tokens[0] {
        Nip21::Pubkey(pubkey) if *pubkey == keys.public_key() => {}
        _ => return Err("first NIP-27 token mismatch".to_string()),
    }
    match &nostr_tokens[1] {
        Nip21::EventId(event_id) if *event_id == note.id => {}
        _ => return Err("second NIP-27 token mismatch".to_string()),
    }

    let duplicate_text = format!("{npub_uri}, {npub_uri}");
    let duplicate_count = NostrParser::new()
        .parse(&duplicate_text)
        .filter(|token| matches!(token, Token::Nostr(_)))
        .count();
    if duplicate_count != 2 {
        return Err("duplicate NIP-27 references were not preserved".to_string());
    }

    Ok(())
}

fn check_nip51() -> Result<(), String> {
    let keys = parse_keys()?;
    let target_keys = parse_alt_keys()?;
    let target = EventBuilder::text_note("nip51 target")
        .sign_with_keys(&target_keys)
        .map_err(|e| format!("sign nip51 target: {e}"))?;
    let article = Coordinate::new(Kind::LongFormTextNote, target.pubkey).identifier("yak");
    let community = Coordinate::new(Kind::Custom(34550), target.pubkey).identifier("garden");
    let interests_coordinate =
        Coordinate::new(Kind::InterestSet, target.pubkey).identifier("systems");
    let emoji_coordinate = Coordinate::new(Kind::EmojiSet, target.pubkey).identifier("icons");
    let relay = RelayUrl::parse("wss://relay.example").map_err(|e| format!("relay parse: {e}"))?;
    let emoji_url =
        Url::parse("https://cdn.example/soapbox.png").map_err(|e| format!("emoji url parse: {e}"))?;
    let bookmark_url =
        Url::parse("https://example.com/post").map_err(|e| format!("bookmark url parse: {e}"))?;

    let mute = EventBuilder::mute_list(MuteList {
        public_keys: vec![target.pubkey],
        hashtags: vec!["nostr".to_string()],
        event_ids: vec![target.id],
        words: vec!["spam phrase".to_string()],
    })
    .sign_with_keys(&keys)
    .map_err(|e| format!("sign mute list: {e}"))?;
    if mute.kind != Kind::MuteList {
        return Err("mute list builder produced wrong kind".to_string());
    }
    if mute.tags.len() != 4
        || !event_has_public_key(&mute, target.pubkey)
        || !event_has_hashtag(&mute, "nostr")
        || !event_has_event_id(&mute, target.id)
        || !event_has_word(&mute, "spam phrase")
    {
        return Err("mute list deep parity mismatch".to_string());
    }

    let pinned_notes = EventBuilder::pinned_notes([target.id])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign pinned notes: {e}"))?;
    if pinned_notes.kind != Kind::PinList
        || pinned_notes.tags.len() != 1
        || !event_has_event_id(&pinned_notes, target.id)
    {
        return Err("pinned notes deep parity mismatch".to_string());
    }

    let bookmarks = EventBuilder::bookmarks(Bookmarks {
        event_ids: vec![target.id],
        coordinate: vec![article.clone()],
        hashtags: Vec::new(),
        urls: Vec::new(),
    })
    .sign_with_keys(&keys)
    .map_err(|e| format!("sign bookmarks: {e}"))?;
    if bookmarks.kind != Kind::Bookmarks
        || bookmarks.tags.len() != 2
        || !event_has_event_id(&bookmarks, target.id)
        || !event_has_coordinate(&bookmarks, &article)
    {
        return Err("bookmarks deep parity mismatch".to_string());
    }

    let broad_bookmarks = EventBuilder::bookmarks(Bookmarks {
        event_ids: vec![target.id],
        coordinate: vec![article.clone()],
        hashtags: vec!["nostr".to_string()],
        urls: vec![bookmark_url.clone()],
    })
    .sign_with_keys(&keys)
    .map_err(|e| format!("sign broad bookmarks: {e}"))?;
    if !event_has_hashtag(&broad_bookmarks, "nostr")
        || !event_has_url(&broad_bookmarks, &bookmark_url)
    {
        return Err("rust bookmark breadth mismatch".to_string());
    }

    let communities = EventBuilder::communities([community.clone()])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign communities: {e}"))?;
    if communities.kind != Kind::Communities
        || communities.tags.len() != 1
        || !event_has_coordinate(&communities, &community)
    {
        return Err("communities deep parity mismatch".to_string());
    }

    let public_chats = EventBuilder::public_chats([target.id])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign public chats: {e}"))?;
    if public_chats.kind != Kind::PublicChats
        || public_chats.tags.len() != 1
        || !event_has_event_id(&public_chats, target.id)
    {
        return Err("public chats deep parity mismatch".to_string());
    }

    let blocked_relays = EventBuilder::blocked_relays([relay.clone()])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign blocked relays: {e}"))?;
    if blocked_relays.kind != Kind::BlockedRelays
        || blocked_relays.tags.len() != 1
        || !event_has_relay(&blocked_relays, &relay)
    {
        return Err("blocked relays deep parity mismatch".to_string());
    }

    let search_relays = EventBuilder::search_relays([relay.clone()])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign search relays: {e}"))?;
    if search_relays.kind != Kind::SearchRelays
        || search_relays.tags.len() != 1
        || !event_has_relay(&search_relays, &relay)
    {
        return Err("search relays deep parity mismatch".to_string());
    }

    let interests = EventBuilder::interests(Interests {
        hashtags: vec!["zig".to_string()],
        coordinate: vec![interests_coordinate.clone()],
    })
    .sign_with_keys(&keys)
    .map_err(|e| format!("sign interests: {e}"))?;
    if interests.kind != Kind::Interests
        || interests.tags.len() != 2
        || !event_has_hashtag(&interests, "zig")
        || !event_has_coordinate(&interests, &interests_coordinate)
    {
        return Err("interests deep parity mismatch".to_string());
    }

    let emojis = EventBuilder::emojis(Emojis {
        emojis: vec![("soapbox".to_string(), emoji_url.clone())],
        coordinate: vec![emoji_coordinate.clone()],
    })
    .sign_with_keys(&keys)
    .map_err(|e| format!("sign emojis: {e}"))?;
    if emojis.kind != Kind::Emojis
        || emojis.tags.len() != 2
        || !event_has_emoji(&emojis, "soapbox", &emoji_url)
        || !event_has_coordinate(&emojis, &emoji_coordinate)
    {
        return Err("emojis deep parity mismatch".to_string());
    }

    let follow_set = EventBuilder::follow_set("team", [target.pubkey])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign follow set: {e}"))?;
    if follow_set.kind != Kind::FollowSet
        || follow_set.tags.len() != 2
        || !event_has_identifier(&follow_set, "team")
        || !event_has_public_key(&follow_set, target.pubkey)
    {
        return Err("follow set deep parity mismatch".to_string());
    }

    let relay_set = EventBuilder::relay_set("search", [relay.clone()])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign relay set: {e}"))?;
    if relay_set.kind != Kind::RelaySet
        || relay_set.tags.len() != 2
        || !event_has_identifier(&relay_set, "search")
        || !event_has_relay(&relay_set, &relay)
    {
        return Err("relay set deep parity mismatch".to_string());
    }

    let bookmark_set = EventBuilder::bookmarks_set(
        "saved",
        Bookmarks {
            event_ids: vec![target.id],
            coordinate: vec![article.clone()],
            hashtags: Vec::new(),
            urls: Vec::new(),
        },
    )
    .sign_with_keys(&keys)
    .map_err(|e| format!("sign bookmark set: {e}"))?;
    if bookmark_set.kind != Kind::BookmarkSet
        || !event_has_identifier(&bookmark_set, "saved")
        || !event_has_event_id(&bookmark_set, target.id)
        || !event_has_coordinate(&bookmark_set, &article)
    {
        return Err("bookmark set deep parity mismatch".to_string());
    }

    let articles_curation_set = EventBuilder::articles_curation_set(
        "essays",
        ArticlesCuration {
            coordinate: vec![article.clone()],
            event_ids: vec![target.id],
        },
    )
    .sign_with_keys(&keys)
    .map_err(|e| format!("sign articles curation set: {e}"))?;
    if articles_curation_set.kind != Kind::ArticlesCurationSet
        || !event_has_identifier(&articles_curation_set, "essays")
        || !event_has_event_id(&articles_curation_set, target.id)
        || !event_has_coordinate(&articles_curation_set, &article)
    {
        return Err("articles curation set deep parity mismatch".to_string());
    }

    let interest_set = EventBuilder::interest_set("topics", ["zig", "nostr"])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign interest set: {e}"))?;
    if interest_set.kind != Kind::InterestSet
        || !event_has_identifier(&interest_set, "topics")
        || !event_has_hashtag(&interest_set, "zig")
        || !event_has_hashtag(&interest_set, "nostr")
    {
        return Err("interest set deep parity mismatch".to_string());
    }

    let emoji_set = EventBuilder::emoji_set("icons", [("soapbox".to_string(), emoji_url.clone())])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign emoji set: {e}"))?;
    if emoji_set.kind != Kind::EmojiSet
        || !event_has_identifier(&emoji_set, "icons")
        || !event_has_emoji(&emoji_set, "soapbox", &emoji_url)
    {
        return Err("emoji set deep parity mismatch".to_string());
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

    let auth_json = event.as_json();
    let mut auth_value: serde_json::Value =
        serde_json::from_str(&auth_json).map_err(|e| format!("auth json parse: {e}"))?;
    let tags = auth_value
        .get_mut("tags")
        .and_then(|value| value.as_array_mut())
        .ok_or_else(|| "auth event missing tags array".to_string())?;
    tags.retain(|tag| {
        tag.get(0)
            .and_then(|value| value.as_str())
            .map(|name| name != "challenge")
            .unwrap_or(true)
    });
    let missing_challenge = Event::from_json(auth_value.to_string())
        .map_err(|e| format!("missing challenge auth parse: {e}"))?;
    if nip42::is_valid_auth_event(&missing_challenge, &relay_url, challenge) {
        return Err("auth event missing challenge tag accepted".to_string());
    }

    let long_challenge = "x".repeat(128);
    let long_event = EventBuilder::auth(long_challenge.clone(), relay_url.clone())
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign long auth event: {e}"))?;
    if !nip42::is_valid_auth_event(&long_event, &relay_url, &long_challenge) {
        return Err("long auth challenge rejected".to_string());
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

        if !payload.is_empty() {
            let mut malformed_mac = payload.clone();
            let last_index = malformed_mac.len() - 1;
            malformed_mac[last_index] ^= 0x01;
            if decrypt_to_bytes(&conversation_key, &malformed_mac).is_ok() {
                return Err("tampered-mac payload accepted".to_string());
            }
        }
    }

    if let Some(malformed_fixtures) = set.malformed_fixtures {
        for fixture in malformed_fixtures {
            if fixture.expectation != "decrypt_reject" {
                return Err(format!(
                    "malformed fixture {} expectation mismatch",
                    fixture.id
                ));
            }

            let conversation_key = parse_array_32("key", &fixture.conversation_key_hex)
                .map(ConversationKey::new)
                .map_err(|e| format!("malformed fixture key parse: {e}"))?;
            let payload = STANDARD
                .decode(&fixture.payload_base64)
                .map_err(|e| format!("malformed fixture payload decode: {e}"))?;

            if decrypt_to_bytes(&conversation_key, &payload).is_ok() {
                return Err(format!("malformed fixture {} decrypt accepted", fixture.id));
            }
        }
    }

    Ok(())
}

fn check_nip46() -> Result<(), String> {
    let bunker_uri = NostrConnectURI::parse(
        "bunker://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?relay=wss://relay.damus.io&secret=abcd",
    )
    .map_err(|e| format!("nip46 bunker uri parse: {e}"))?;
    if bunker_uri.to_string() != "bunker://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?relay=wss://relay.damus.io&secret=abcd" {
        return Err("nip46 bunker uri roundtrip mismatch".to_string());
    }

    let client_uri = NostrConnectURI::parse(
        r#"nostrconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?metadata={"name":"Example"}&relay=wss://relay.damus.io&secret=mysecret"#,
    )
    .map_err(|e| format!("nip46 client uri parse: {e}"))?;
    let client_uri_text = client_uri.to_string();
    if !client_uri_text.starts_with("nostrconnect://b889ff5b1513b641e2a139f661a661364979c5beee91842f8f0ef42ab558e9d4?metadata=") {
        return Err("nip46 client uri missing rust metadata field".to_string());
    }
    if !client_uri_text.contains("&relay=wss://relay.damus.io") {
        return Err("nip46 client uri missing relay query".to_string());
    }

    let request = NostrConnectMessage::Request {
        id: String::from("3047714669"),
        method: NostrConnectMethod::SignEvent,
        params: vec![String::from(
            "{\"id\":\"236ad3390704e1bf435f40143fb3de163723aeaa8f25c3bf12a0ac4d9a4b56a7\",\"pubkey\":\"79dff8f82963424e0bb02708a22e44b4980893e3a4be0fa3cb60a43b946764e3\",\"created_at\":1710854115,\"kind\":1,\"tags\":[],\"content\":\"Testing rust-nostr NIP46 signer [bunker]\"}",
        )],
    };
    let request_json = request.as_json();
    let request_back =
        NostrConnectMessage::from_json(&request_json).map_err(|e| format!("nip46 request parse: {e}"))?;
    if request_back != request {
        return Err("nip46 request message roundtrip mismatch".to_string());
    }

    let response_json = r#"{"id":"2581081643","result":"pong","error":null}"#;
    let response = NostrConnectMessage::from_json(response_json)
        .map_err(|e| format!("nip46 response parse: {e}"))?;
    match response {
        NostrConnectMessage::Response { id, result, error } => {
            if id != "2581081643" {
                return Err("nip46 response id mismatch".to_string());
            }
            if result.as_deref() != Some("pong") {
                return Err("nip46 response result mismatch".to_string());
            }
            if error.is_some() {
                return Err("nip46 response error mismatch".to_string());
            }
        }
        _ => return Err("nip46 response parsed as request".to_string()),
    }

    if NostrConnectMethod::from_str("switch_relays").is_ok() {
        return Err("nip46 rust method set unexpectedly includes switch_relays".to_string());
    }

    Ok(())
}

async fn check_nip59() -> Result<(), String> {
    let sender = Keys::parse("6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e")
        .map_err(|e| format!("sender key parse: {e}"))?;
    let receiver = Keys::parse("7b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e")
        .map_err(|e| format!("receiver key parse: {e}"))?;
    let impersonated =
        Keys::parse("5b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e")
            .map_err(|e| format!("impersonated key parse: {e}"))?;

    // 1) valid wrap/unwrap baseline
    let rumor = EventBuilder::text_note("nip59 baseline").build(sender.public_key());
    let gift_wrap = EventBuilder::gift_wrap(&sender, &receiver.public_key(), rumor, [])
        .await
        .map_err(|e| format!("gift_wrap compose: {e}"))?;
    let unwrapped_first = UnwrappedGift::from_gift_wrap(&receiver, &gift_wrap)
        .await
        .map_err(|e| format!("gift_wrap unwrap: {e}"))?;
    if unwrapped_first.sender != sender.public_key() {
        return Err("sender mismatch after unwrap".to_string());
    }
    if unwrapped_first.rumor.kind != Kind::TextNote {
        return Err("rumor kind mismatch".to_string());
    }
    if unwrapped_first.rumor.content != "nip59 baseline" {
        return Err("rumor content mismatch".to_string());
    }

    // 2) wrong recipient rejection
    if UnwrappedGift::from_gift_wrap(&sender, &gift_wrap)
        .await
        .is_ok()
    {
        return Err("gift_wrap unwrap accepted wrong recipient".to_string());
    }

    // 3) non-giftwrap event rejection
    let non_gift_wrap = EventBuilder::text_note("nip59 not giftwrap")
        .sign_with_keys(&sender)
        .map_err(|e| format!("non-giftwrap compose: {e}"))?;
    match UnwrappedGift::from_gift_wrap(&receiver, &non_gift_wrap).await {
        Err(nip59::Error::NotGiftWrap) => {}
        Err(other) => {
            return Err(format!("non-giftwrap returned unexpected error: {other}"));
        }
        Ok(_) => {
            return Err("non-giftwrap event accepted".to_string());
        }
    }

    // 4) sender-mismatch rejection (spoofed rumor pubkey)
    let spoofed_rumor =
        EventBuilder::text_note("nip59 spoofed sender").build(impersonated.public_key());
    let spoofed_wrap = EventBuilder::gift_wrap(&sender, &receiver.public_key(), spoofed_rumor, [])
        .await
        .map_err(|e| format!("spoofed gift_wrap compose: {e}"))?;
    match UnwrappedGift::from_gift_wrap(&receiver, &spoofed_wrap).await {
        Err(nip59::Error::SenderMismatch) => {}
        Err(other) => {
            return Err(format!(
                "sender mismatch returned unexpected error: {other}"
            ));
        }
        Ok(_) => {
            return Err("sender mismatch spoof accepted".to_string());
        }
    }

    // 5) deterministic repeated unwrap consistency
    let unwrapped_second = UnwrappedGift::from_gift_wrap(&receiver, &gift_wrap)
        .await
        .map_err(|e| format!("gift_wrap second unwrap: {e}"))?;
    if unwrapped_second.sender != unwrapped_first.sender {
        return Err("repeated unwrap sender mismatch".to_string());
    }
    if unwrapped_second.rumor != unwrapped_first.rumor {
        return Err("repeated unwrap rumor mismatch".to_string());
    }

    // 6) malformed payload rejection on gift_wrap content
    let gift_wrap_json = gift_wrap.as_json();
    let mut malformed_content_value: serde_json::Value =
        serde_json::from_str(&gift_wrap_json).map_err(|e| format!("gift_wrap json parse: {e}"))?;
    malformed_content_value["content"] =
        serde_json::Value::String("not-a-valid-giftwrap".to_string());
    let malformed_content_event = Event::from_json(malformed_content_value.to_string())
        .map_err(|e| format!("gift_wrap malformed content parse: {e}"))?;
    if UnwrappedGift::from_gift_wrap(&receiver, &malformed_content_event)
        .await
        .is_ok()
    {
        return Err("gift_wrap malformed payload accepted".to_string());
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

    let non_relay_event = EventBuilder::text_note("nip65 negative")
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign non-relay event: {e}"))?;
    if nip65::extract_relay_list(&non_relay_event).next().is_some() {
        return Err("non-relay event unexpectedly produced relay metadata".to_string());
    }

    let malformed_url_event = EventBuilder::new(Kind::RelayList, "")
        .tags([Tag::parse(vec!["r", "not-a-url"])
            .map_err(|e| format!("malformed r tag parse: {e}"))?])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign malformed relay event: {e}"))?;
    if nip65::extract_relay_list(&malformed_url_event)
        .next()
        .is_some()
    {
        return Err("relay list extracted malformed relay url".to_string());
    }

    let mixed_tag_event = EventBuilder::new(Kind::RelayList, "")
        .tags([
            Tag::parse(vec!["x", "ignored"])
                .map_err(|e| format!("foreign tag parse: {e}"))?,
            Tag::parse(vec!["r", relay_a.as_str(), "read"])
                .map_err(|e| format!("mixed relay tag parse: {e}"))?,
        ])
        .sign_with_keys(&keys)
        .map_err(|e| format!("sign mixed relay event: {e}"))?;
    let mixed_extracted: Vec<(String, Option<RelayMetadata>)> =
        nip65::extract_relay_list(&mixed_tag_event)
            .map(|(url, metadata)| (url.as_str().to_string(), *metadata))
            .collect();
    if mixed_extracted.len() != 1 {
        return Err("foreign tags should not poison relay extraction".to_string());
    }
    let mixed_matches = mixed_extracted
        .iter()
        .any(|(url, metadata)| url == relay_a.as_str() && *metadata == Some(RelayMetadata::Read));
    if !mixed_matches {
        return Err("foreign-tag relay extraction mismatch".to_string());
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

    let malformed_expiration_event = EventBuilder::text_note("nip40 malformed expiration")
        .tags([Tag::parse(vec!["expiration", "not-a-number"])
            .map_err(|e| format!("malformed expiration tag parse failed: {e}"))?])
        .sign_with_keys(&keys)
        .map_err(|e| format!("malformed expiration event build failed: {e}"))?;
    if malformed_expiration_event.is_expired_at(&Timestamp::from(9_999_u64)) {
        return Err("malformed expiration value unexpectedly marked event expired".to_string());
    }

    let missing_expiration_value_event = EventBuilder::text_note("nip40 missing expiration value")
        .tags([Tag::parse(vec!["expiration"])
            .map_err(|e| format!("missing expiration value tag parse failed: {e}"))?])
        .sign_with_keys(&keys)
        .map_err(|e| format!("missing expiration value event build failed: {e}"))?;
    if missing_expiration_value_event.is_expired_at(&Timestamp::from(9_999_u64)) {
        return Err("expiration tag without value unexpectedly marked event expired".to_string());
    }

    Ok(())
}

fn check_nip45() -> Result<(), String> {
    let message = ClientMessage::from_json(r#"["COUNT","sub-a",{"kinds":[1]}]"#)
        .map_err(|e| format!("COUNT parse failed unexpectedly: {e}"))?;
    if !matches!(message, ClientMessage::Count { .. }) {
        return Err("COUNT parse did not return Count variant".to_string());
    }
    let roundtrip = message.as_json();
    if !roundtrip.contains("\"COUNT\"") {
        return Err("COUNT serialization missing command".to_string());
    }

    let relay_count = RelayMessage::from_json(r#"["COUNT","sub-a",{"count":7}]"#)
        .map_err(|e| format!("relay COUNT parse failed unexpectedly: {e}"))?;
    if !matches!(relay_count, RelayMessage::Count { .. }) {
        return Err("relay COUNT parse did not return Count variant".to_string());
    }

    let relay_count_with_unknown =
        RelayMessage::from_json(r#"["COUNT","sub-a",{"count":7,"future":1}]"#)
            .map_err(|e| format!("relay COUNT unknown-field parse failed unexpectedly: {e}"))?;
    if !matches!(relay_count_with_unknown, RelayMessage::Count { .. }) {
        return Err("relay COUNT unknown-field parse did not return Count variant".to_string());
    }

    let uppercase_hll = "A1".repeat(256);
    let relay_count_with_uppercase_hll = RelayMessage::from_json(&format!(
        "[\"COUNT\",\"sub-a\",{{\"count\":7,\"hll\":\"{}\"}}]",
        uppercase_hll
    ))
    .map_err(|e| format!("relay COUNT uppercase hll parse failed unexpectedly: {e}"))?;
    if !matches!(relay_count_with_uppercase_hll, RelayMessage::Count { .. }) {
        return Err("relay COUNT uppercase hll parse did not return Count variant".to_string());
    }

    if ClientMessage::from_json(r#"["COUNT","sub-a"]"#).is_ok() {
        return Err("COUNT malformed client shape was accepted".to_string());
    }
    if RelayMessage::from_json(r#"["COUNT","sub-a",{"count":"bad"}]"#).is_ok() {
        return Err("COUNT malformed relay payload was accepted".to_string());
    }
    if RelayMessage::from_json(r#"{"type":"COUNT"}"#).is_ok() {
        return Err("COUNT malformed relay top-level object was accepted".to_string());
    }

    Ok(())
}

fn check_nip50() -> Result<(), String> {
    let filter = Filter::new().search("nostr parity");
    let parsed = Filter::from_json(r#"{"search":"nostr parity","kinds":[1]}"#)
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
    if Filter::from_json(r#"{"search":["bad"]}"#).is_ok() {
        return Err("array search field type accepted".to_string());
    }

    let malformed_extension_filter = Filter::new().search("include: language:en:us");
    let malformed_extension_event = EventBuilder::text_note("include: language:en:us")
        .sign_with_keys(&keys)
        .map_err(|e| format!("search malformed-extension event build failed: {e}"))?;
    if !malformed_extension_filter.match_event(
        &malformed_extension_event,
        MatchEventOptions::new().nip50(true),
    ) {
        return Err("malformed extension-like search text was not treated as raw search text".to_string());
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

    let close_variant_event = EventBuilder::text_note("nip70 close variant")
        .tags([Tag::parse(vec!["--"])
            .map_err(|e| format!("close-variant protected tag parse failed: {e}"))?])
        .sign_with_keys(&keys)
        .map_err(|e| format!("close-variant event build failed: {e}"))?;
    if close_variant_event.is_protected() {
        return Err("close-variant protected tag was treated as protected".to_string());
    }

    let malformed_dash_key_event = EventBuilder::text_note("nip70 malformed dash key")
        .tags([Tag::parse(vec![" -"])
            .map_err(|e| format!("malformed-dash protected tag parse failed: {e}"))?])
        .sign_with_keys(&keys)
        .map_err(|e| format!("malformed-dash event build failed: {e}"))?;
    if malformed_dash_key_event.is_protected() {
        return Err("malformed dash key tag was treated as protected".to_string());
    }

    Ok(())
}

fn check_nip77() -> Result<(), String> {
    let message = ClientMessage::from_json(r#"["NEG-OPEN","sub-b",{},"00"]"#)
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
    let relay_neg_err_no_space = RelayMessage::from_json(r#"["NEG-ERR","sub-b","blocked:retry"]"#)
        .map_err(|e| format!("relay NEG-ERR no-space parse failed unexpectedly: {e}"))?;
    if !matches!(relay_neg_err_no_space, RelayMessage::NegErr { .. }) {
        return Err("relay NEG-ERR no-space parse did not return NegErr variant".to_string());
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
    if ClientMessage::from_json(r#"["NEG-MSG",123,"0102"]"#).is_ok() {
        return Err("malformed NEG-MSG subscription id type was accepted".to_string());
    }

    Ok(())
}

fn check_nip06() -> Result<(), String> {
    let mnemonic = "equal dragon fabric refuse stable cherry smoke allow alley easy never medal \
attend together lumber movie what sad siege weather matrix buffalo state shoot";
    let account_zero = Keys::from_mnemonic(mnemonic, None)
        .map_err(|e| format!("NIP-06 account 0 derivation failed: {e}"))?;
    if account_zero.secret_key().display_secret().to_string()
        != "06992419a8fe821dd8de03d4c300614e8feefb5ea936b76f89976dcace8aebee"
    {
        return Err("NIP-06 account 0 secret key mismatch".to_string());
    }

    let account_one = Keys::from_mnemonic_with_account(mnemonic, None, Some(1))
        .map_err(|e| format!("NIP-06 account 1 derivation failed: {e}"))?;
    if account_one.secret_key().display_secret().to_string()
        != "5735ecd7389ba3dcc0c4464d6c9328867821560c3923acff14aeeb4b6cd5c775"
    {
        return Err("NIP-06 account 1 secret key mismatch".to_string());
    }

    let null_passphrase = Keys::from_mnemonic(
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
        None,
    )
    .map_err(|e| format!("NIP-06 null passphrase derivation failed: {e}"))?;
    let empty_passphrase = Keys::from_mnemonic(
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
        Some(""),
    )
    .map_err(|e| format!("NIP-06 empty passphrase derivation failed: {e}"))?;
    if null_passphrase.secret_key() != empty_passphrase.secret_key() {
        return Err("NIP-06 null and empty passphrase derivations diverged".to_string());
    }

    if Keys::from_mnemonic(
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon",
        None,
    )
    .is_ok()
    {
        return Err("NIP-06 invalid mnemonic length was accepted".to_string());
    }

    Ok(())
}

#[tokio::main]
async fn main() {
    let mut results: Vec<NipResult> = Vec::new();

    push_harness_covered(&mut results, "NIP-01", Depth::Deep, check_nip01());
    push_harness_covered(&mut results, "NIP-02", Depth::Deep, check_nip02());
    push_harness_covered(&mut results, "NIP-10", Depth::Deep, check_nip10());
    push_harness_covered(&mut results, "NIP-18", Depth::Deep, check_nip18());
    push_harness_covered(&mut results, "NIP-09", Depth::Deep, check_nip09());
    push_harness_covered(&mut results, "NIP-11", Depth::Deep, check_nip11());
    push_harness_covered(&mut results, "NIP-13", Depth::Deep, check_nip13());
    push_harness_covered(&mut results, "NIP-19", Depth::Deep, check_nip19());
    push_harness_covered(&mut results, "NIP-21", Depth::Deep, check_nip21());
    push_harness_covered(&mut results, "NIP-22", Depth::Deep, check_nip22());
    push_harness_covered(&mut results, "NIP-27", Depth::Deep, check_nip27());
    push_harness_covered(&mut results, "NIP-25", Depth::Deep, check_nip25());
    push_harness_covered(&mut results, "NIP-51", Depth::Deep, check_nip51());
    push_harness_covered(&mut results, "NIP-42", Depth::Deep, check_nip42());
    push_harness_covered(&mut results, "NIP-44", Depth::Deep, check_nip44());
    push_harness_covered(&mut results, "NIP-46", Depth::Baseline, check_nip46());
    push_harness_covered(&mut results, "NIP-59", Depth::Deep, check_nip59().await);
    push_harness_covered(&mut results, "NIP-65", Depth::Deep, check_nip65());
    push_harness_covered(&mut results, "NIP-06", Depth::Edge, check_nip06());

    push_harness_covered(&mut results, "NIP-40", Depth::Deep, check_nip40());
    push_harness_covered(&mut results, "NIP-45", Depth::Deep, check_nip45());
    push_harness_covered(&mut results, "NIP-50", Depth::Deep, check_nip50());
    push_harness_covered(&mut results, "NIP-70", Depth::Deep, check_nip70());
    push_harness_covered(&mut results, "NIP-77", Depth::Deep, check_nip77());

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
