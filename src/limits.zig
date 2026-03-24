const std = @import("std");

/// Strict-by-default shared limits for core protocol modules.
///
/// All constants are fixed-width and bounded to preserve deterministic behavior.
pub const Limits = struct {
    pub const event_json_max: u32 = 262_144;
    pub const content_bytes_max: u32 = 65_536;
    pub const tags_max: u16 = 2_048;
    pub const tag_items_max: u16 = 16;
    pub const tag_item_bytes_max: u16 = 4_096;

    pub const filter_ids_max: u16 = 1_024;
    pub const filter_authors_max: u16 = 1_024;
    pub const filter_kinds_max: u16 = 128;
    pub const filter_tag_keys_max: u16 = 256;
    pub const filter_tag_values_max: u16 = 2_048;

    pub const relay_message_bytes_max: u32 = 524_288;
    pub const subscription_id_bytes_max: u8 = 64;
    pub const message_filters_max: u8 = 16;
    pub const kind_max: u32 = 65_535;

    pub const nip11_supported_nips_max: u16 = 256;
    pub const nip11_limitation_max_message_length_max: u32 = Limits.relay_message_bytes_max;
    pub const nip11_limitation_max_subscriptions_max: u32 = 65_536;
    pub const nip11_limitation_max_filters_max: u32 = 4_096;
    pub const nip11_limitation_max_limit_max: u32 = 65_536;
    pub const nip11_limitation_max_subid_length_max: u32 = Limits.subscription_id_bytes_max;
    pub const nip11_limitation_max_event_tags_max: u32 = Limits.tags_max;
    pub const nip11_limitation_max_content_length_max: u32 = Limits.content_bytes_max;
    pub const nip11_limitation_min_pow_difficulty_max: u32 = 256;

    pub const id_hex_length: u8 = 64;
    pub const pubkey_hex_length: u8 = 64;
    pub const sig_hex_length: u8 = 128;

    pub const nip19_bech32_identifier_bytes_max: u16 = 2_048;
    pub const nip19_bech32_hrp_bytes_max: u8 = 8;
    pub const nip19_tlv_type_max: u8 = 255;
    pub const nip19_tlv_length_max: u8 = 255;
    pub const nip19_tlv_entries_max: u8 = 64;
    pub const nip19_tlv_scratch_bytes_max: u16 = 16_448;
    pub const nip19_relays_max: u8 = 32;
    pub const nip19_identifier_tlv_bytes_max: u8 = 255;

    pub const nip21_uri_bytes_max: u16 = 2_054;
    pub const nip21_scheme_prefix_bytes: u8 = 6;

    pub const nip02_contacts_max: u16 = Limits.tags_max;
    pub const nip02_contact_tag_items_max: u8 = 4;
    pub const nip02_contact_relay_url_bytes_max: u16 = Limits.tag_item_bytes_max;
    pub const nip02_contact_petname_bytes_max: u16 = Limits.tag_item_bytes_max;

    pub const nip65_relays_max: u16 = Limits.tags_max;
    pub const nip65_relay_tag_items_max: u8 = 3;
    pub const nip65_relay_url_bytes_max: u16 = Limits.tag_item_bytes_max;
    pub const nip65_marker_bytes_max: u8 = 5;

    pub const nip04_shared_secret_bytes: u8 = 32;
    pub const nip04_iv_bytes: u8 = 16;
    pub const nip04_plaintext_max_bytes: u32 = 49_119;
    pub const nip04_ciphertext_min_bytes: u8 = 16;
    pub const nip04_ciphertext_max_bytes: u32 = 49_120;
    pub const nip04_iv_base64_bytes: u8 = 24;
    pub const nip04_payload_min_bytes: u8 = 28 + 24;
    pub const nip04_payload_max_bytes: u32 = 65_524;

    pub const nip44_version: u8 = 2;
    pub const nip44_conversation_key_bytes: u8 = 32;
    pub const nip44_nonce_bytes: u8 = 32;
    pub const nip44_mac_bytes: u8 = 32;
    pub const nip44_message_keys_bytes: u8 = 76;
    pub const nip44_plaintext_min_bytes: u16 = 1;
    pub const nip44_plaintext_max_bytes: u16 = 65_535;
    pub const nip44_ciphertext_min_bytes: u16 = 34;
    pub const nip44_ciphertext_max_bytes: u32 = 65_538;
    pub const nip44_payload_decoded_min_bytes: u16 = 99;
    pub const nip44_payload_decoded_max_bytes: u32 = 65_603;
    pub const nip44_payload_base64_min_bytes: u16 = 132;
    pub const nip44_payload_base64_max_bytes: u32 = 87_472;

    pub const nip45_hll_hex_length: u16 = 512;

    pub const nip46_uri_bytes_max: u16 = 4_096;
    pub const nip46_message_json_bytes_max: u32 = Limits.nip44_plaintext_max_bytes;
    pub const nip46_message_id_bytes_max: u8 = 128;
    pub const nip46_message_params_max: u8 = 8;
    pub const nip46_relays_max: u8 = 32;
    pub const nip46_permissions_max: u8 = 32;
    pub const nip46_secret_bytes_max: u16 = 256;

    pub const nip49_version: u8 = 0x02;
    pub const nip49_key_bytes: u8 = 32;
    pub const nip49_salt_bytes: u8 = 16;
    pub const nip49_nonce_bytes: u8 = 24;
    pub const nip49_ciphertext_bytes: u8 = 48;
    pub const nip49_payload_bytes: u8 = 91;
    pub const nip49_bech32_bytes_max: u16 = 162;
    pub const nip49_password_bytes_max: u16 = 4_096;
    pub const nip49_password_normalized_bytes_max: u16 = 4_096;
    pub const nip49_scrypt_r: u8 = 8;
    pub const nip49_scrypt_p: u8 = 1;

    pub const nipb7_servers_max: u16 = Limits.tags_max;
    pub const nipb7_server_tag_items_max: u8 = 2;
    pub const nipb7_server_url_bytes_max: u16 = Limits.tag_item_bytes_max;
    pub const nipb7_blob_url_bytes_max: u16 = Limits.content_bytes_max;
    pub const nipb7_blob_extension_bytes_max: u16 = Limits.tag_item_bytes_max;

    pub const nip06_mnemonic_bytes_max: u16 = 256;
    pub const nip06_passphrase_bytes_max: u16 = 256;
    pub const nip06_normalized_bytes_max: u16 = 4_096;
    pub const nip06_seed_bytes: u8 = 64;
    pub const nip06_secret_key_bytes: u8 = 32;
    pub const bip85_entropy_bytes_max: u8 = 64;
    pub const bip85_mnemonic_bytes_max: u16 = 256;

    pub const nip05_identifier_bytes_max: u16 = Limits.tag_item_bytes_max;
    pub const nip05_relays_max: u8 = 32;

    pub const nip50_search_field_bytes_max: u16 = Limits.tag_item_bytes_max;

    pub const nip77_negentropy_protocol_version: u8 = 0x61;
    pub const nip77_negentropy_hex_payload_bytes_max: u32 = 262_144;
    pub const nip77_negentropy_session_steps_max: u16 = 1_024;
};

pub const event_json_max: u32 = Limits.event_json_max;
pub const content_bytes_max: u32 = Limits.content_bytes_max;
pub const tags_max: u16 = Limits.tags_max;
pub const tag_items_max: u16 = Limits.tag_items_max;
pub const tag_item_bytes_max: u16 = Limits.tag_item_bytes_max;

pub const filter_ids_max: u16 = Limits.filter_ids_max;
pub const filter_authors_max: u16 = Limits.filter_authors_max;
pub const filter_kinds_max: u16 = Limits.filter_kinds_max;
pub const filter_tag_keys_max: u16 = Limits.filter_tag_keys_max;
pub const filter_tag_values_max: u16 = Limits.filter_tag_values_max;

pub const relay_message_bytes_max: u32 = Limits.relay_message_bytes_max;
pub const subscription_id_bytes_max: u8 = Limits.subscription_id_bytes_max;
pub const message_filters_max: u8 = Limits.message_filters_max;
pub const kind_max: u32 = Limits.kind_max;

pub const nip11_supported_nips_max: u16 = Limits.nip11_supported_nips_max;
pub const nip11_limitation_max_message_length_max: u32 =
    Limits.nip11_limitation_max_message_length_max;
pub const nip11_limitation_max_subscriptions_max: u32 =
    Limits.nip11_limitation_max_subscriptions_max;
pub const nip11_limitation_max_filters_max: u32 = Limits.nip11_limitation_max_filters_max;
pub const nip11_limitation_max_limit_max: u32 = Limits.nip11_limitation_max_limit_max;
pub const nip11_limitation_max_subid_length_max: u32 = Limits.nip11_limitation_max_subid_length_max;
pub const nip11_limitation_max_event_tags_max: u32 = Limits.nip11_limitation_max_event_tags_max;
pub const nip11_limitation_max_content_length_max: u32 =
    Limits.nip11_limitation_max_content_length_max;
pub const nip11_limitation_min_pow_difficulty_max: u32 =
    Limits.nip11_limitation_min_pow_difficulty_max;

pub const id_hex_length: u8 = Limits.id_hex_length;
pub const pubkey_hex_length: u8 = Limits.pubkey_hex_length;
pub const sig_hex_length: u8 = Limits.sig_hex_length;

pub const nip19_bech32_identifier_bytes_max: u16 = Limits.nip19_bech32_identifier_bytes_max;
pub const nip19_bech32_hrp_bytes_max: u8 = Limits.nip19_bech32_hrp_bytes_max;
pub const nip19_tlv_type_max: u8 = Limits.nip19_tlv_type_max;
pub const nip19_tlv_length_max: u8 = Limits.nip19_tlv_length_max;
pub const nip19_tlv_entries_max: u8 = Limits.nip19_tlv_entries_max;
pub const nip19_tlv_scratch_bytes_max: u16 = Limits.nip19_tlv_scratch_bytes_max;
pub const nip19_relays_max: u8 = Limits.nip19_relays_max;
pub const nip19_identifier_tlv_bytes_max: u8 = Limits.nip19_identifier_tlv_bytes_max;

pub const nip21_uri_bytes_max: u16 = Limits.nip21_uri_bytes_max;
pub const nip21_scheme_prefix_bytes: u8 = Limits.nip21_scheme_prefix_bytes;

pub const nip02_contacts_max: u16 = Limits.nip02_contacts_max;
pub const nip02_contact_tag_items_max: u8 = Limits.nip02_contact_tag_items_max;
pub const nip02_contact_relay_url_bytes_max: u16 = Limits.nip02_contact_relay_url_bytes_max;
pub const nip02_contact_petname_bytes_max: u16 = Limits.nip02_contact_petname_bytes_max;

pub const nip65_relays_max: u16 = Limits.nip65_relays_max;
pub const nip65_relay_tag_items_max: u8 = Limits.nip65_relay_tag_items_max;
pub const nip65_relay_url_bytes_max: u16 = Limits.nip65_relay_url_bytes_max;
pub const nip65_marker_bytes_max: u8 = Limits.nip65_marker_bytes_max;

pub const nip04_shared_secret_bytes: u8 = Limits.nip04_shared_secret_bytes;
pub const nip04_iv_bytes: u8 = Limits.nip04_iv_bytes;
pub const nip04_plaintext_max_bytes: u32 = Limits.nip04_plaintext_max_bytes;
pub const nip04_ciphertext_min_bytes: u8 = Limits.nip04_ciphertext_min_bytes;
pub const nip04_ciphertext_max_bytes: u32 = Limits.nip04_ciphertext_max_bytes;
pub const nip04_iv_base64_bytes: u8 = Limits.nip04_iv_base64_bytes;
pub const nip04_payload_min_bytes: u8 = Limits.nip04_payload_min_bytes;
pub const nip04_payload_max_bytes: u32 = Limits.nip04_payload_max_bytes;

pub const nip44_version: u8 = Limits.nip44_version;
pub const nip44_conversation_key_bytes: u8 = Limits.nip44_conversation_key_bytes;
pub const nip44_nonce_bytes: u8 = Limits.nip44_nonce_bytes;
pub const nip44_mac_bytes: u8 = Limits.nip44_mac_bytes;
pub const nip44_message_keys_bytes: u8 = Limits.nip44_message_keys_bytes;
pub const nip44_plaintext_min_bytes: u16 = Limits.nip44_plaintext_min_bytes;
pub const nip44_plaintext_max_bytes: u16 = Limits.nip44_plaintext_max_bytes;
pub const nip44_ciphertext_min_bytes: u16 = Limits.nip44_ciphertext_min_bytes;
pub const nip44_ciphertext_max_bytes: u32 = Limits.nip44_ciphertext_max_bytes;
pub const nip44_payload_decoded_min_bytes: u16 = Limits.nip44_payload_decoded_min_bytes;
pub const nip44_payload_decoded_max_bytes: u32 = Limits.nip44_payload_decoded_max_bytes;
pub const nip44_payload_base64_min_bytes: u16 = Limits.nip44_payload_base64_min_bytes;
pub const nip44_payload_base64_max_bytes: u32 = Limits.nip44_payload_base64_max_bytes;

pub const nip45_hll_hex_length: u16 = Limits.nip45_hll_hex_length;

pub const nip46_uri_bytes_max: u16 = Limits.nip46_uri_bytes_max;
pub const nip46_message_json_bytes_max: u32 = Limits.nip46_message_json_bytes_max;
pub const nip46_message_id_bytes_max: u8 = Limits.nip46_message_id_bytes_max;
pub const nip46_message_params_max: u8 = Limits.nip46_message_params_max;
pub const nip46_relays_max: u8 = Limits.nip46_relays_max;
pub const nip46_permissions_max: u8 = Limits.nip46_permissions_max;
pub const nip46_secret_bytes_max: u16 = Limits.nip46_secret_bytes_max;

pub const nip49_version: u8 = Limits.nip49_version;
pub const nip49_key_bytes: u8 = Limits.nip49_key_bytes;
pub const nip49_salt_bytes: u8 = Limits.nip49_salt_bytes;
pub const nip49_nonce_bytes: u8 = Limits.nip49_nonce_bytes;
pub const nip49_ciphertext_bytes: u8 = Limits.nip49_ciphertext_bytes;
pub const nip49_payload_bytes: u8 = Limits.nip49_payload_bytes;
pub const nip49_bech32_bytes_max: u16 = Limits.nip49_bech32_bytes_max;
pub const nip49_password_bytes_max: u16 = Limits.nip49_password_bytes_max;
pub const nip49_password_normalized_bytes_max: u16 =
    Limits.nip49_password_normalized_bytes_max;
pub const nip49_scrypt_r: u8 = Limits.nip49_scrypt_r;
pub const nip49_scrypt_p: u8 = Limits.nip49_scrypt_p;

pub const nipb7_servers_max: u16 = Limits.nipb7_servers_max;
pub const nipb7_server_tag_items_max: u8 = Limits.nipb7_server_tag_items_max;
pub const nipb7_server_url_bytes_max: u16 = Limits.nipb7_server_url_bytes_max;
pub const nipb7_blob_url_bytes_max: u16 = Limits.nipb7_blob_url_bytes_max;
pub const nipb7_blob_extension_bytes_max: u16 = Limits.nipb7_blob_extension_bytes_max;

pub const nip06_mnemonic_bytes_max: u16 = Limits.nip06_mnemonic_bytes_max;
pub const nip06_passphrase_bytes_max: u16 = Limits.nip06_passphrase_bytes_max;
pub const nip06_normalized_bytes_max: u16 = Limits.nip06_normalized_bytes_max;
pub const nip06_seed_bytes: u8 = Limits.nip06_seed_bytes;
pub const nip06_secret_key_bytes: u8 = Limits.nip06_secret_key_bytes;
pub const bip85_entropy_bytes_max: u8 = Limits.bip85_entropy_bytes_max;
pub const bip85_mnemonic_bytes_max: u16 = Limits.bip85_mnemonic_bytes_max;

pub const nip05_identifier_bytes_max: u16 = Limits.nip05_identifier_bytes_max;
pub const nip05_relays_max: u8 = Limits.nip05_relays_max;

pub const nip50_search_field_bytes_max: u16 = Limits.nip50_search_field_bytes_max;

pub const nip77_negentropy_protocol_version: u8 = Limits.nip77_negentropy_protocol_version;
pub const nip77_negentropy_hex_payload_bytes_max: u32 =
    Limits.nip77_negentropy_hex_payload_bytes_max;
pub const nip77_negentropy_session_steps_max: u16 = Limits.nip77_negentropy_session_steps_max;

comptime {
    std.debug.assert(Limits.content_bytes_max <= Limits.event_json_max);
    std.debug.assert(Limits.relay_message_bytes_max >= Limits.event_json_max);
    std.debug.assert(Limits.tag_item_bytes_max <= Limits.content_bytes_max);
    std.debug.assert(Limits.id_hex_length == Limits.pubkey_hex_length);
    std.debug.assert(Limits.sig_hex_length == Limits.id_hex_length * 2);
    std.debug.assert(Limits.filter_tag_keys_max > 0);
    std.debug.assert(Limits.filter_tag_keys_max <= Limits.filter_tag_values_max);
    std.debug.assert(Limits.subscription_id_bytes_max > 0);
    std.debug.assert(Limits.message_filters_max > 0);
    std.debug.assert(Limits.message_filters_max <= Limits.nip11_limitation_max_filters_max);
    std.debug.assert(Limits.kind_max > 0);
    std.debug.assert(Limits.kind_max == std.math.maxInt(u16));
    std.debug.assert(Limits.nip11_supported_nips_max > 0);
    std.debug.assert(
        Limits.nip11_limitation_max_message_length_max <= Limits.relay_message_bytes_max,
    );
    std.debug.assert(
        Limits.nip11_limitation_max_subid_length_max == Limits.subscription_id_bytes_max,
    );
    std.debug.assert(Limits.nip11_limitation_max_event_tags_max == Limits.tags_max);
    std.debug.assert(Limits.nip11_limitation_max_content_length_max == Limits.content_bytes_max);
    std.debug.assert(Limits.nip11_limitation_min_pow_difficulty_max <= 256);

    std.debug.assert(Limits.nip19_bech32_hrp_bytes_max >= 4);
    std.debug.assert(Limits.nip19_bech32_hrp_bytes_max <= 16);
    std.debug.assert(Limits.nip19_tlv_type_max == 255);
    std.debug.assert(Limits.nip19_tlv_length_max == 255);
    std.debug.assert(Limits.nip19_tlv_entries_max > 0);
    std.debug.assert(
        Limits.nip19_tlv_scratch_bytes_max >= @as(u16, Limits.nip19_tlv_entries_max) * 2,
    );
    std.debug.assert(
        Limits.nip19_tlv_scratch_bytes_max >=
            @as(u16, Limits.nip19_tlv_entries_max) *
                (@as(u16, 2) + @as(u16, Limits.nip19_tlv_length_max)),
    );
    std.debug.assert(Limits.nip19_identifier_tlv_bytes_max <= Limits.nip19_tlv_length_max);
    std.debug.assert(Limits.nip19_relays_max > 0);
    std.debug.assert(Limits.nip21_scheme_prefix_bytes == 6);
    std.debug.assert(
        Limits.nip21_uri_bytes_max >=
            @as(u16, Limits.nip21_scheme_prefix_bytes) + Limits.nip19_bech32_identifier_bytes_max,
    );
    std.debug.assert(Limits.nip02_contacts_max <= Limits.tags_max);
    std.debug.assert(Limits.nip02_contact_tag_items_max >= 2);
    std.debug.assert(Limits.nip02_contact_tag_items_max <= Limits.tag_items_max);
    std.debug.assert(Limits.nip02_contact_relay_url_bytes_max <= Limits.tag_item_bytes_max);
    std.debug.assert(Limits.nip02_contact_petname_bytes_max <= Limits.tag_item_bytes_max);
    std.debug.assert(Limits.nip65_relays_max <= Limits.tags_max);
    std.debug.assert(Limits.nip65_relay_tag_items_max >= 2);
    std.debug.assert(Limits.nip65_relay_tag_items_max <= Limits.tag_items_max);
    std.debug.assert(Limits.nip65_relay_url_bytes_max <= Limits.tag_item_bytes_max);
    std.debug.assert(Limits.nip65_marker_bytes_max == 5);

    std.debug.assert(Limits.nip44_version == 2);
    std.debug.assert(Limits.nip44_conversation_key_bytes == 32);
    std.debug.assert(Limits.nip44_nonce_bytes == 32);
    std.debug.assert(Limits.nip44_mac_bytes == 32);
    std.debug.assert(Limits.nip44_message_keys_bytes == 76);
    std.debug.assert(Limits.nip44_plaintext_min_bytes == 1);
    std.debug.assert(Limits.nip44_plaintext_max_bytes == 65_535);
    std.debug.assert(Limits.nip44_ciphertext_min_bytes == 34);
    std.debug.assert(Limits.nip44_ciphertext_max_bytes == 65_538);
    std.debug.assert(Limits.nip44_payload_decoded_min_bytes == 99);
    std.debug.assert(Limits.nip44_payload_decoded_max_bytes == 65_603);
    std.debug.assert(Limits.nip44_payload_base64_min_bytes == 132);
    std.debug.assert(Limits.nip44_payload_base64_max_bytes == 87_472);
    std.debug.assert(
        Limits.nip44_payload_decoded_min_bytes ==
            @as(u16, 1) + Limits.nip44_nonce_bytes + Limits.nip44_ciphertext_min_bytes +
                Limits.nip44_mac_bytes,
    );
    std.debug.assert(
        Limits.nip44_payload_decoded_max_bytes ==
            @as(u32, 1) + Limits.nip44_nonce_bytes + Limits.nip44_ciphertext_max_bytes +
                Limits.nip44_mac_bytes,
    );
    std.debug.assert(
        Limits.nip44_payload_base64_min_bytes ==
            @as(u16, @intCast(@divTrunc(Limits.nip44_payload_decoded_min_bytes + 2, 3) * 4)),
    );
    std.debug.assert(
        Limits.nip44_payload_base64_max_bytes ==
            @as(u32, @divTrunc(Limits.nip44_payload_decoded_max_bytes + 2, 3) * 4),
    );

    std.debug.assert(Limits.nip45_hll_hex_length == 512);
    std.debug.assert(Limits.nip45_hll_hex_length % 2 == 0);

    std.debug.assert(Limits.nip46_uri_bytes_max >= Limits.tag_item_bytes_max);
    std.debug.assert(Limits.nip46_message_json_bytes_max <= Limits.nip44_plaintext_max_bytes);
    std.debug.assert(Limits.nip46_message_id_bytes_max > 0);
    std.debug.assert(Limits.nip46_message_params_max > 0);
    std.debug.assert(Limits.nip46_relays_max > 0);
    std.debug.assert(Limits.nip46_permissions_max > 0);
    std.debug.assert(Limits.nip46_secret_bytes_max > 0);
    std.debug.assert(Limits.nip46_secret_bytes_max <= Limits.tag_item_bytes_max);

    std.debug.assert(Limits.nip49_version == 0x02);
    std.debug.assert(Limits.nip49_key_bytes == 32);
    std.debug.assert(Limits.nip49_salt_bytes == 16);
    std.debug.assert(Limits.nip49_nonce_bytes == 24);
    std.debug.assert(Limits.nip49_ciphertext_bytes == Limits.nip49_key_bytes + 16);
    std.debug.assert(
        Limits.nip49_payload_bytes ==
            1 +
                1 +
                Limits.nip49_salt_bytes +
                Limits.nip49_nonce_bytes +
                1 +
                Limits.nip49_ciphertext_bytes,
    );
    std.debug.assert(
        Limits.nip49_bech32_bytes_max ==
            9 + 1 + @divFloor((@as(u32, Limits.nip49_payload_bytes) * 8) + 4, 5) + 6,
    );
    std.debug.assert(Limits.nip49_password_bytes_max > 0);
    std.debug.assert(
        Limits.nip49_password_normalized_bytes_max >= Limits.nip49_password_bytes_max,
    );
    std.debug.assert(Limits.nip49_scrypt_r == 8);
    std.debug.assert(Limits.nip49_scrypt_p == 1);

    std.debug.assert(Limits.nip06_mnemonic_bytes_max >= 128);
    std.debug.assert(Limits.nip06_passphrase_bytes_max > 0);
    std.debug.assert(Limits.nip06_seed_bytes == 64);
    std.debug.assert(Limits.nip06_secret_key_bytes == 32);
    std.debug.assert(Limits.nip05_identifier_bytes_max <= Limits.tag_item_bytes_max);
    std.debug.assert(Limits.nip05_relays_max > 0);
    std.debug.assert(Limits.nip05_relays_max <= Limits.nip46_relays_max);

    std.debug.assert(Limits.nip50_search_field_bytes_max > 0);
    std.debug.assert(Limits.nip50_search_field_bytes_max <= Limits.tag_item_bytes_max);

    std.debug.assert(Limits.nip77_negentropy_protocol_version == 0x61);
    std.debug.assert(Limits.nip77_negentropy_hex_payload_bytes_max > 0);
    std.debug.assert(
        Limits.nip77_negentropy_hex_payload_bytes_max <= Limits.relay_message_bytes_max,
    );
    std.debug.assert(Limits.nip77_negentropy_session_steps_max > 0);
    std.debug.assert(Limits.nip77_negentropy_session_steps_max >= Limits.message_filters_max);
}

test "limits relation checks stay true" {
    try std.testing.expect(Limits.content_bytes_max <= Limits.event_json_max);
    try std.testing.expect(Limits.relay_message_bytes_max >= Limits.event_json_max);
    try std.testing.expect(Limits.tag_item_bytes_max <= Limits.content_bytes_max);
    try std.testing.expect(Limits.id_hex_length == Limits.pubkey_hex_length);
    try std.testing.expect(Limits.sig_hex_length == Limits.id_hex_length * 2);
    try std.testing.expect(Limits.filter_tag_keys_max > 0);
    try std.testing.expect(Limits.filter_tag_keys_max <= Limits.filter_tag_values_max);
    try std.testing.expect(Limits.message_filters_max > 0);
    try std.testing.expect(Limits.message_filters_max <= Limits.nip11_limitation_max_filters_max);
    try std.testing.expect(Limits.kind_max > 0);
    try std.testing.expect(Limits.kind_max == std.math.maxInt(u16));
    try std.testing.expect(Limits.nip11_supported_nips_max > 0);
    try std.testing.expect(
        Limits.nip11_limitation_max_message_length_max <= Limits.relay_message_bytes_max,
    );
    try std.testing.expect(
        Limits.nip11_limitation_max_subid_length_max == Limits.subscription_id_bytes_max,
    );
    try std.testing.expect(Limits.nip11_limitation_max_event_tags_max == Limits.tags_max);
    try std.testing.expect(
        Limits.nip11_limitation_max_content_length_max == Limits.content_bytes_max,
    );
    try std.testing.expect(Limits.nip11_limitation_min_pow_difficulty_max <= 256);

    try std.testing.expect(Limits.nip19_bech32_hrp_bytes_max >= 4);
    try std.testing.expect(Limits.nip19_bech32_hrp_bytes_max <= 16);
    try std.testing.expect(Limits.nip19_tlv_type_max == 255);
    try std.testing.expect(Limits.nip19_tlv_length_max == 255);
    try std.testing.expect(Limits.nip19_tlv_entries_max > 0);
    try std.testing.expect(
        Limits.nip19_tlv_scratch_bytes_max >= @as(u16, Limits.nip19_tlv_entries_max) * 2,
    );
    try std.testing.expect(
        Limits.nip19_tlv_scratch_bytes_max >=
            @as(u16, Limits.nip19_tlv_entries_max) *
                (@as(u16, 2) + @as(u16, Limits.nip19_tlv_length_max)),
    );
    try std.testing.expect(Limits.nip19_identifier_tlv_bytes_max <= Limits.nip19_tlv_length_max);
    try std.testing.expect(Limits.nip19_relays_max > 0);
    try std.testing.expect(Limits.nip21_scheme_prefix_bytes == 6);
    try std.testing.expect(
        Limits.nip21_uri_bytes_max >=
            @as(u16, Limits.nip21_scheme_prefix_bytes) + Limits.nip19_bech32_identifier_bytes_max,
    );
    try std.testing.expect(Limits.nip02_contacts_max <= Limits.tags_max);
    try std.testing.expect(Limits.nip02_contact_tag_items_max >= 2);
    try std.testing.expect(Limits.nip02_contact_tag_items_max <= Limits.tag_items_max);
    try std.testing.expect(Limits.nip02_contact_relay_url_bytes_max <= Limits.tag_item_bytes_max);
    try std.testing.expect(Limits.nip02_contact_petname_bytes_max <= Limits.tag_item_bytes_max);
    try std.testing.expect(Limits.nip65_relays_max <= Limits.tags_max);
    try std.testing.expect(Limits.nip65_relay_tag_items_max >= 2);
    try std.testing.expect(Limits.nip65_relay_tag_items_max <= Limits.tag_items_max);
    try std.testing.expect(Limits.nip65_relay_url_bytes_max <= Limits.tag_item_bytes_max);
    try std.testing.expect(Limits.nip65_marker_bytes_max == 5);

    try std.testing.expect(Limits.nip44_version == 2);
    try std.testing.expect(Limits.nip44_conversation_key_bytes == 32);
    try std.testing.expect(Limits.nip44_nonce_bytes == 32);
    try std.testing.expect(Limits.nip44_mac_bytes == 32);
    try std.testing.expect(Limits.nip44_message_keys_bytes == 76);
    try std.testing.expect(Limits.nip44_plaintext_min_bytes == 1);
    try std.testing.expect(Limits.nip44_plaintext_max_bytes == 65_535);
    try std.testing.expect(Limits.nip44_ciphertext_min_bytes == 34);
    try std.testing.expect(Limits.nip44_ciphertext_max_bytes == 65_538);
    try std.testing.expect(Limits.nip44_payload_decoded_min_bytes == 99);
    try std.testing.expect(Limits.nip44_payload_decoded_max_bytes == 65_603);
    try std.testing.expect(Limits.nip44_payload_base64_min_bytes == 132);
    try std.testing.expect(Limits.nip44_payload_base64_max_bytes == 87_472);
    try std.testing.expect(
        Limits.nip44_payload_decoded_min_bytes ==
            @as(u16, 1) + Limits.nip44_nonce_bytes + Limits.nip44_ciphertext_min_bytes +
                Limits.nip44_mac_bytes,
    );
    try std.testing.expect(
        Limits.nip44_payload_decoded_max_bytes ==
            @as(u32, 1) + Limits.nip44_nonce_bytes + Limits.nip44_ciphertext_max_bytes +
                Limits.nip44_mac_bytes,
    );
    try std.testing.expect(
        Limits.nip44_payload_base64_min_bytes ==
            @as(u16, @intCast(@divTrunc(Limits.nip44_payload_decoded_min_bytes + 2, 3) * 4)),
    );
    try std.testing.expect(
        Limits.nip44_payload_base64_max_bytes ==
            @as(u32, @divTrunc(Limits.nip44_payload_decoded_max_bytes + 2, 3) * 4),
    );

    try std.testing.expect(Limits.nip45_hll_hex_length == 512);
    try std.testing.expect(Limits.nip45_hll_hex_length % 2 == 0);

    try std.testing.expect(Limits.nip06_mnemonic_bytes_max >= 128);
    try std.testing.expect(Limits.nip06_passphrase_bytes_max > 0);
    try std.testing.expect(Limits.nip06_seed_bytes == 64);
    try std.testing.expect(Limits.nip06_secret_key_bytes == 32);

    try std.testing.expect(Limits.nip50_search_field_bytes_max > 0);
    try std.testing.expect(Limits.nip50_search_field_bytes_max <= Limits.tag_item_bytes_max);

    try std.testing.expect(Limits.nip77_negentropy_protocol_version == 0x61);
    try std.testing.expect(Limits.nip77_negentropy_hex_payload_bytes_max > 0);
    try std.testing.expect(
        Limits.nip77_negentropy_hex_payload_bytes_max <= Limits.relay_message_bytes_max,
    );
    try std.testing.expect(Limits.nip77_negentropy_session_steps_max > 0);
    try std.testing.expect(Limits.nip77_negentropy_session_steps_max >= Limits.message_filters_max);
}

test "limits negative-space boundaries are explicit" {
    const content_exceeds_event = Limits.content_bytes_max + 1 > Limits.event_json_max;
    const signature_not_truncated = Limits.sig_hex_length != Limits.id_hex_length;
    const uri_capacity_underflows =
        Limits.nip21_uri_bytes_max <
        @as(u16, Limits.nip21_scheme_prefix_bytes) + Limits.nip19_bech32_identifier_bytes_max;
    const filter_tag_keys_overflow = Limits.filter_tag_keys_max > Limits.filter_tag_values_max;
    const kind_max_mismatch = Limits.kind_max != std.math.maxInt(u16);
    const tlv_scratch_underflows =
        Limits.nip19_tlv_scratch_bytes_max <
        @as(u16, Limits.nip19_tlv_entries_max) *
            (@as(u16, 2) + @as(u16, Limits.nip19_tlv_length_max));
    const nip44_decoded_min_mismatch =
        Limits.nip44_payload_decoded_min_bytes !=
        @as(u16, 1) + Limits.nip44_nonce_bytes + Limits.nip44_ciphertext_min_bytes +
            Limits.nip44_mac_bytes;
    const nip44_decoded_max_mismatch =
        Limits.nip44_payload_decoded_max_bytes !=
        @as(u32, 1) + Limits.nip44_nonce_bytes + Limits.nip44_ciphertext_max_bytes +
            Limits.nip44_mac_bytes;
    const nip45_hll_length_not_exact = Limits.nip45_hll_hex_length != 512;
    const nip50_search_field_overflow =
        Limits.nip50_search_field_bytes_max > Limits.tag_item_bytes_max;
    const nip77_protocol_version_mismatch =
        Limits.nip77_negentropy_protocol_version != 0x61;
    const nip77_hex_payload_overflow =
        Limits.nip77_negentropy_hex_payload_bytes_max > Limits.relay_message_bytes_max;
    const nip77_session_steps_underflow =
        Limits.nip77_negentropy_session_steps_max < Limits.message_filters_max;

    try std.testing.expect(!content_exceeds_event);
    try std.testing.expect(signature_not_truncated);
    try std.testing.expect(!uri_capacity_underflows);
    try std.testing.expect(!filter_tag_keys_overflow);
    try std.testing.expect(!kind_max_mismatch);
    try std.testing.expect(!tlv_scratch_underflows);
    try std.testing.expect(!nip44_decoded_min_mismatch);
    try std.testing.expect(!nip44_decoded_max_mismatch);
    try std.testing.expect(!nip45_hll_length_not_exact);
    try std.testing.expect(!nip50_search_field_overflow);
    try std.testing.expect(!nip77_protocol_version_mismatch);
    try std.testing.expect(!nip77_hex_payload_overflow);
    try std.testing.expect(!nip77_session_steps_underflow);
}
