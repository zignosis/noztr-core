---
title: Post Core Contract Map
doc_type: reference
status: active
owner: noztr
phase: phase-h
read_when:
  - routing_post_core_public_surfaces
  - mapping_sdk_jobs_to_noztr_symbols
depends_on:
  - src/root.zig
  - examples/README.md
canonical: true
---

# Post-Core Contract Map

Current task-to-surface routing for the main post-core public modules that are not covered by the
older Phase D core contract document.

Use this as the fast route from job intent to the right public function family, contract layer, and
example file.

## Quick Route

- if the job is still core `NIP-01` / filter / message work, start with
  `docs/plans/v1-api-contracts.md` instead of this document
- if the job is post-core and user-facing, start here, then open the named example file before
  opening source
- when a job is boundary-heavy, open the hostile fixture immediately after the direct example so the
  intended failure contract is visible

## Fast Starting Points

| If you need to... | Open first | Then open |
| --- | --- | --- |
| discover the right module and symbol family | this map | `examples/README.md` |
| learn one post-core job quickly | the matching example in the routing table | the hostile fixture for the same row |
| understand kernel-vs-SDK cutoff | `docs/plans/noztr-sdk-ownership-matrix.md` | the named recipe/example |
| confirm older core event/filter/message contracts | `docs/plans/v1-api-contracts.md` | `examples/nip01_example.zig` |

## Routing Table

| Job | Module | Primary public symbols | Contract layer | Start here | Hostile / failure fixture |
| --- | --- | --- | --- | --- | --- |
| Identity lookup and bunker discovery | `nip05_identity`, `nip46_remote_signing` | `address_parse`, `address_compose_well_known_url`, `profile_parse_json`, `profile_verify_json`, `discovery_parse_well_known`, `discovery_render_nostrconnect_url` | parse/verify and deterministic render only; no HTTP fetch, redirect policy, or caching | `examples/discovery_recipe.zig` | `examples/nip05_adversarial_example.zig` |
| Remote-signing requests, responses, URIs, and discovery | `nip46_remote_signing` | `message_parse_json`, `message_serialize_json`, `request_build_*`, `request_parse_typed`, `response_result_*`, `uri_parse`, `uri_serialize`, `discovery_parse_*` | typed request/response/URI kernel helpers only; no session orchestration | `examples/remote_signing_recipe.zig` | `examples/remote_signing_adversarial_example.zig` |
| One-recipient gift-wrap outbound build and unwrap | `nip59_wrap`, `nip17_private_messages` | `nip59_build_outbound_for_recipient`, `nip59_unwrap`, `nip17_unwrap_message`, `nip17_build_recipient_tag`, `nip17_relay_list_extract` | deterministic one-recipient transcript build plus unwrap; no fanout, mailbox policy, or delivery workflow | `examples/nip17_wrap_recipe.zig` | `examples/nip59_adversarial_example.zig` |
| Wallet Connect envelope and JSON contracts | `nip47_wallet_connect` | `connection_uri_parse`, `connection_uri_format`, `request_event_extract`, `response_event_extract`, `notification_event_extract`, `request_parse_json`, `response_parse_json`, `notification_parse_json` | bounded NWC URI/event/JSON helpers only; no wallet workflow | `examples/nip47_example.zig` | `examples/wallet_connect_adversarial_example.zig` |
| Relay-admin JSON-RPC helpers | `nip86_relay_management` | `method_parse`, `request_parse_json`, `request_serialize_json`, `response_parse_json`, `response_serialize_json` | bounded admin request/response parsing and serialization only | `examples/relay_admin_recipe.zig` | `examples/relay_admin_adversarial_example.zig` |
| HTTP auth event and header helpers | `nip98_http_auth` | `http_auth_extract`, `http_auth_validate_request`, `http_auth_verify_request`, `http_auth_parse_authorization_header`, `http_auth_verify_authorization_header`, `http_auth_build_*` | strict request matching and header helpers only; no middleware or transport flow | `examples/nip98_example.zig` | `examples/http_auth_adversarial_example.zig` |
| Private-key encryption boundary | `nip49_private_key_encryption` | `ncryptsec_parse`, `ncryptsec_format`, `encrypt_secret_key`, `decrypt_secret_key` | bounded payload parse/format and encrypt/decrypt only; caller owns scratch and password policy | `examples/nip49_example.zig` | `examples/private_key_encryption_adversarial_example.zig` |
| Group replay and poll tally reduction | `nip29_groups`, `nip88_polls` | `reduce_events`, `apply_event`, `poll_parse`, `response_parse`, `tally_reduce` | pure reducer and metadata helpers only; no relay/state sync or app policy | `examples/nip29_reducer_recipe.zig`, `examples/nip88_example.zig` | `examples/nip29_adversarial_example.zig`, `examples/polls_adversarial_example.zig` |

## Contract Layer Notes

- full event-object JSON is not the same as canonical preimage JSON
- message/envelope helpers are not event-object parsers
- deterministic kernel helpers stop before workflow, transport, storage, and policy layers
- when a job spans multiple modules, start with the recipe file and then open the named symbols

## Related Docs

- `docs/plans/v1-api-contracts.md`
  - older core contract reference
- `docs/plans/noztr-sdk-ownership-matrix.md`
  - kernel-vs-SDK boundary decisions
- `examples/README.md`
  - task-oriented example and hostile-fixture routing
