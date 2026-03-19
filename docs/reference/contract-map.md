---
title: Public Contract Map
doc_type: release_reference
status: active
owner: noztr
read_when:
  - routing_public_noztr_jobs
  - finding_post_core_symbols
  - onboarding_public_consumers
canonical: true
---

# Public Contract Map

This is the public task-to-symbol map for the main non-core `noztr` surfaces.

Use it when you know the job you want to do, but do not yet know which module or example to open.

## Routing Table

| Job | Module | Start here | Example | Hostile example |
| --- | --- | --- | --- | --- |
| Identity lookup and bunker discovery | `nip05_identity`, `nip46_remote_signing` | `noztr.nip05_identity`, `noztr.nip46_remote_signing` | [discovery_recipe.zig](/workspace/projects/noztr/examples/discovery_recipe.zig) | [nip05_adversarial_example.zig](/workspace/projects/noztr/examples/nip05_adversarial_example.zig) |
| Remote-signing requests, responses, URIs, and discovery | `nip46_remote_signing` | `noztr.nip46_remote_signing` | [remote_signing_recipe.zig](/workspace/projects/noztr/examples/remote_signing_recipe.zig) | [remote_signing_adversarial_example.zig](/workspace/projects/noztr/examples/remote_signing_adversarial_example.zig) |
| One-recipient gift-wrap outbound build and unwrap | `nip59_wrap`, `nip17_private_messages` | `noztr.nip59_wrap`, `noztr.nip17_private_messages` | [nip17_wrap_recipe.zig](/workspace/projects/noztr/examples/nip17_wrap_recipe.zig) | [nip59_adversarial_example.zig](/workspace/projects/noztr/examples/nip59_adversarial_example.zig) |
| File-message parse and deterministic file-tag building | `nip17_private_messages` | `noztr.nip17_private_messages` | [nip17_example.zig](/workspace/projects/noztr/examples/nip17_example.zig) | [nip17_adversarial_example.zig](/workspace/projects/noztr/examples/nip17_adversarial_example.zig) |
| Wallet Connect URI, envelopes, and typed JSON contracts | `nip47_wallet_connect` | `noztr.nip47_wallet_connect` | [nip47_example.zig](/workspace/projects/noztr/examples/nip47_example.zig) | [wallet_connect_adversarial_example.zig](/workspace/projects/noztr/examples/wallet_connect_adversarial_example.zig) |
| Relay-admin JSON-RPC helpers | `nip86_relay_management` | `noztr.nip86_relay_management` | [relay_admin_recipe.zig](/workspace/projects/noztr/examples/relay_admin_recipe.zig) | [relay_admin_adversarial_example.zig](/workspace/projects/noztr/examples/relay_admin_adversarial_example.zig) |
| Relay discovery metadata and monitor announcements | `nip66_relay_discovery` | `noztr.nip66_relay_discovery` | [nip66_example.zig](/workspace/projects/noztr/examples/nip66_example.zig) | [nip66_adversarial_example.zig](/workspace/projects/noztr/examples/nip66_adversarial_example.zig) |
| HTTP auth event and header helpers | `nip98_http_auth` | `noztr.nip98_http_auth` | [nip98_example.zig](/workspace/projects/noztr/examples/nip98_example.zig) | [http_auth_adversarial_example.zig](/workspace/projects/noztr/examples/http_auth_adversarial_example.zig) |
| Subject tags for text notes | `nip14_subjects` | `noztr.nip14_subjects` | [nip14_example.zig](/workspace/projects/noztr/examples/nip14_example.zig) | none |
| Public-channel metadata, linkage, and moderation tags | `nip28_public_chat` | `noztr.nip28_public_chat` | [nip28_example.zig](/workspace/projects/noztr/examples/nip28_example.zig) | [nip28_adversarial_example.zig](/workspace/projects/noztr/examples/nip28_adversarial_example.zig) |
| Custom emoji tag parsing and build helpers | `nip30_custom_emoji` | `noztr.nip30_custom_emoji` | [nip30_example.zig](/workspace/projects/noztr/examples/nip30_example.zig) | none |
| Private-key encryption boundary | `nip49_private_key_encryption` | `noztr.nip49_private_key_encryption` | [nip49_example.zig](/workspace/projects/noztr/examples/nip49_example.zig) | [private_key_encryption_adversarial_example.zig](/workspace/projects/noztr/examples/private_key_encryption_adversarial_example.zig) |
| Group replay and poll tally reduction | `nip29_relay_groups`, `nip88_polls` | `noztr.nip29_relay_groups`, `noztr.nip88_polls` | [nip29_reducer_recipe.zig](/workspace/projects/noztr/examples/nip29_reducer_recipe.zig), [nip88_example.zig](/workspace/projects/noztr/examples/nip88_example.zig) | [nip29_adversarial_example.zig](/workspace/projects/noztr/examples/nip29_adversarial_example.zig), [polls_adversarial_example.zig](/workspace/projects/noztr/examples/polls_adversarial_example.zig) |
| Unknown/custom-kind fallback summaries | `nip31_alt_tags` | `noztr.nip31_alt_tags` | [nip31_example.zig](/workspace/projects/noztr/examples/nip31_example.zig) | none |
| User-status metadata and linkage tags | `nip38_user_status` | `noztr.nip38_user_status` | [nip38_example.zig](/workspace/projects/noztr/examples/nip38_example.zig) | none |
| Video-event metadata, variant fields, and imported-origin helpers | `nip71_video_events` | `noztr.nip71_video_events` | [nip71_example.zig](/workspace/projects/noztr/examples/nip71_example.zig) | none |
| Moderated-community definitions, post linkage, and approval contracts | `nip72_moderated_communities` | `noztr.nip72_moderated_communities` | [nip72_example.zig](/workspace/projects/noztr/examples/nip72_example.zig) | [nip72_adversarial_example.zig](/workspace/projects/noztr/examples/nip72_adversarial_example.zig) |
| Git repository metadata and repository state | `nip34_git` | `noztr.nip34_git` | [nip34_example.zig](/workspace/projects/noztr/examples/nip34_example.zig) | none |
| Calendar event, calendar, and RSVP helpers | `nip52_calendar_events` | `noztr.nip52_calendar_events` | [nip52_example.zig](/workspace/projects/noztr/examples/nip52_example.zig) | none |
| Live activity metadata and live-chat addressing | `nip53_live_activities` | `noztr.nip53_live_activities` | [nip53_example.zig](/workspace/projects/noztr/examples/nip53_example.zig) | none |
| Wiki article, merge-request, and redirect metadata | `nip54_wiki` | `noztr.nip54_wiki` | [nip54_example.zig](/workspace/projects/noztr/examples/nip54_example.zig) | none |
| Nutzap informational, event, and redemption-marker contracts | `nip61_nutzaps` | `noztr.nip61_nutzaps` | [nip61_example.zig](/workspace/projects/noztr/examples/nip61_example.zig) | [nip61_adversarial_example.zig](/workspace/projects/noztr/examples/nip61_adversarial_example.zig) |
| Zap-goal metadata and goal-reference tags | `nip75_zap_goals` | `noztr.nip75_zap_goals` | [nip75_example.zig](/workspace/projects/noztr/examples/nip75_example.zig) | none |
| Opaque app-data `kind:30078` helpers | `nip78_app_data` | `noztr.nip78_app_data` | [nip78_example.zig](/workspace/projects/noztr/examples/nip78_example.zig) | none |
| Handler recommendations, endpoints, and client tags | `nip89_handlers` | `noztr.nip89_handlers` | [nip89_example.zig](/workspace/projects/noztr/examples/nip89_example.zig) | [nip89_adversarial_example.zig](/workspace/projects/noztr/examples/nip89_adversarial_example.zig) |

## Scope Note

These surfaces are still protocol-kernel helpers.

They do not own:

- network fetches
- session orchestration
- relay-management workflow
- storage or cache policy
- UI or application flow
