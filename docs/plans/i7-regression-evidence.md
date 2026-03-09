# I7 Regression Evidence

Date: 2026-03-08

Purpose: record I7 closure evidence for full-suite regressions, deterministic replay checks, and
vector/forcing coverage posture.

## Environment Snapshot

- Timestamp (UTC): `2026-03-08T18:44:47Z`
- Repo: `/workspace/projects/noztr`
- Commit: `a47547d`
- OS: `Linux 6.18.13-200.fc43.x86_64 x86_64 GNU/Linux`
- Zig: `0.15.2`
- Build option posture: default run plus core-only run (`enable_i6_extensions=true/false`) via
  `build.zig` dual-test wiring.

## Full Suite Command Evidence

- Command: `zig build test --summary all`
  - Result: pass
  - Summary: `8/8` steps succeeded; `420/422` tests passed; `2` skipped.
  - Suite split: extension-enabled run `219 passed, 1 skipped`; core-only run `201 passed, 1 skipped`.
- Command: `zig build`
  - Result: pass
  - Artifact: static library build completed without errors.

## Transcript Replay Evidence

- Command: `zig test src/nip01_message.zig --test-filter transcript`
- Result: pass (`9/9`).
- Replay checks covered:
  - relay-before-mark reject,
  - canonical transcript flow accept (`transcript_mark_client_req` + `transcript_apply_relay`),
  - post-EOSE same-subscription event accept,
  - mismatched-subscription and invalid-order rejects,
  - terminal `CLOSED` behavior.

## Crypto Check-Order Replay Evidence

- Command: `zig test src/nip44.zig --test-filter "staged check order"`
- Result: pass (`2/2`).
- Replay checks covered:
  - decrypt enforces `version` validation before MAC validation,
  - decrypt enforces MAC validation before padding checks.

## Module Vector and Forcing Summary

- Core module floor (`5 valid + 5 invalid`) remains enforced in co-located suites for
  `nip01_event`, `nip01_filter`, `nip01_message`, `nip42_auth`, `nip70_protected`, `nip09_delete`,
  `nip40_expire`, `nip13_pow`, `nip44`, `nip59_wrap`, and `nip11`.
- Optional module floor (`3 valid + 3 invalid`) remains enforced for
  `nip19_bech32`, `nip21_uri`, `nip02_contacts`, `nip65_relays`, `nip45_count`, `nip50_search`, and
  `nip77_negentropy`.
- Exhaustive per-public-error forcing matrix:

| Module | Public error set | Exhaustive variants (implementation-aligned) | Forcing refs |
| --- | --- | --- | --- |
| `nip01_event` | `EventParseError` | `InputTooShort`, `InputTooLong`, `OutOfMemory`, `InvalidJson`, `InvalidField`, `InvalidHex`, `InvalidUtf8`, `DuplicateField`, `TooManyTags`, `TooManyTagItems`, `TagItemTooLong` | `src/nip01_event.zig:1012`, `src/nip01_event.zig:1099`, `src/nip01_event.zig:1165`, `src/nip01_event.zig:1219` |
| `nip01_event` | `EventShapeError` | `InvalidUtf8`, `ContentTooLong`, `TooManyTags`, `TooManyTagItems`, `TagItemTooLong` | `src/nip01_event.zig:958`, `src/nip01_event.zig:998`, `src/nip01_event.zig:1015` |
| `nip01_event` | `EventSerializeError` | `InvalidUtf8`, `ContentTooLong`, `TooManyTags`, `TooManyTagItems`, `TagItemTooLong`, `BufferTooSmall` | `src/nip01_event.zig:906`, `src/nip01_event.zig:925` (direct `BufferTooSmall` force), `src/nip01_event.zig:962` |
| `nip01_event` | `EventVerifyError`/`EventVerifyIdError` | `InvalidId`, `InvalidSignature`, `InvalidPubkey`, `BackendUnavailable` (+ `EventShapeError` variants via checked-id path) | `src/nip01_event.zig:1242`, `src/nip01_event.zig:1405`, `src/nip01_event.zig:1449` |
| `nip01_filter` | `FilterParseError` | `InputTooLong`, `OutOfMemory`, `InvalidFilter`, `InvalidHex`, `InvalidTagKey`, `TooManyTagKeys`, `TooManyIds`, `TooManyAuthors`, `TooManyKinds`, `TooManyTagValues`, `InvalidTimeWindow`, `ValueOutOfRange` | `src/nip01_filter.zig:1002`, `src/nip01_filter.zig:1015`, `src/nip01_filter.zig:1129` |
| `nip01_message` | `MessageParseError` | `InputTooLong`, `InvalidMessage`, `InvalidCommand`, `InvalidArity`, `InvalidFieldType`, `InvalidFilter`, `InvalidEvent`, `InvalidPrefix` | `src/nip01_message.zig:1398`, `src/nip01_message.zig:1463`, `src/nip01_message.zig:1510` |
| `nip01_message` | `MessageEncodeError` | `BufferTooSmall`, `ValueOutOfRange` | `src/nip01_message.zig:1692`, `src/nip01_message.zig:1717` |
| `nip01_message` | transcript transition errors | `InvalidTranscriptTransition` | `src/nip01_message.zig:1750`, `src/nip01_message.zig:1795`, `src/nip01_message.zig:1879` |
| `nip42_auth` | `AuthError` | `ChallengeEmpty`, `ChallengeTooLong`, `RelayUrlMismatch`, `ChallengeMismatch`, `InvalidAuthEventKind`, `MissingRelayTag`, `MissingChallengeTag`, `DuplicateRequiredTag`, `FutureTimestamp`, `StaleTimestamp`, `InvalidSignature`, `BackendUnavailable`, `PubkeySetFull` | `src/nip42_auth.zig:630`, `src/nip42_auth.zig:744` |
| `nip70_protected` | `ProtectedError` | `ProtectedAuthRequired`, `ProtectedPubkeyMismatch` | `src/nip70_protected.zig:84` |
| `nip09_delete` | `DeleteExtractError`/`DeleteExtractCheckedError` | `BufferTooSmall`, `EmptyDeleteTargets`, `InvalidETag`, `InvalidATag`, `InvalidAddressCoordinate`, `InvalidDeleteEventKind` | `src/nip09_delete.zig:472`, `src/nip09_delete.zig:483`, `src/nip09_delete.zig:602` |
| `nip09_delete` | `DeleteError` | `InvalidDeleteEventKind`, `EmptyDeleteTargets`, `InvalidETag`, `InvalidATag`, `InvalidAddressCoordinate`, `CrossAuthorDelete` | `src/nip09_delete.zig:602`, `src/nip09_delete.zig:636` |
| `nip40_expire` | `ExpirationError` | `InvalidExpirationTag`, `InvalidTimestamp` | `src/nip40_expire.zig:183` |
| `nip13_pow` | `PowError`/`PowVerifiedIdError` | `DifficultyOutOfRange`, `InvalidNonceTag`, `InvalidNonceCounter`, `InvalidNonceCommitment`, `InvalidId` | `src/nip13_pow.zig:339`, `src/nip13_pow.zig:483`, `src/nip13_pow.zig:545` |
| `nip19_bech32` | `Nip19Error` | `InvalidBech32`, `InvalidChecksum`, `MixedCase`, `InvalidPrefix`, `InvalidPayload`, `MissingRequiredTlv`, `MalformedKnownOptionalTlv`, `BufferTooSmall`, `ValueOutOfRange` | `src/nip19_bech32.zig:757`, `src/nip19_bech32.zig:832`, `src/nip19_bech32.zig:860` |
| `nip21_uri` | `Nip21Error` | `InvalidUri`, `InvalidScheme`, `ForbiddenEntity`, `InvalidEntityEncoding` | `src/nip21_uri.zig:146` |
| `nip02_contacts` | `ContactsError` | `InvalidEventKind`, `InvalidContactTag`, `InvalidPubkey`, `BufferTooSmall` | `src/nip02_contacts.zig:191` |
| `nip65_relays` | `RelaysError` | `InvalidEventKind`, `InvalidRelayTag`, `InvalidRelayUrl`, `InvalidMarker`, `BufferTooSmall` | `src/nip65_relays.zig:398` |
| `nip44` | `Nip44Error` | `InvalidPrivateKey`, `InvalidPublicKey`, `InvalidConversationKeyLength`, `InvalidNonceLength`, `InvalidPlaintextLength`, `InvalidPayloadLength`, `InvalidVersion`, `UnsupportedEncoding`, `InvalidBase64`, `InvalidMac`, `InvalidPadding`, `BufferTooSmall`, `EntropyUnavailable` | `src/nip44.zig:688`, `src/nip44.zig:825` |
| `nip59_wrap` | `WrapError` | `InvalidWrapEvent`, `InvalidSealEvent`, `InvalidRumorEvent`, `InvalidWrapKind`, `InvalidSealKind`, `InvalidSealSignature`, `SenderMismatch`, `DecryptFailed`, `OutOfMemory` | `src/nip59_wrap.zig:1022`, `src/nip59_wrap.zig:1406`, `src/nip59_wrap.zig:1435` |
| `nip45_count`* | `CountError` | `InvalidCountMessage`, `InvalidCountObject`, `InvalidCountValue`, `InvalidApproximateValue`, `InvalidHllHex`, `InvalidHllLength`, `InvalidQueryId` | `src/nip45_count.zig:353`, `src/nip45_count.zig:371` |
| `nip50_search`* | `SearchError` + parser wrapper errors | `InvalidSearchValue`, `InvalidSearchToken`, `BufferTooSmall` (from `search_tokens_parse`) | `src/nip50_search.zig:164`, `src/nip50_search.zig:196`, `src/nip50_search.zig:213` |
| `nip77_negentropy`* | `NegentropyError` | `InvalidNegOpen`, `InvalidNegMsg`, `InvalidNegClose`, `InvalidNegErr`, `InvalidHexPayload`, `UnsupportedVersion`, `ReservedTimestamp`, `InvalidOrdering`, `SessionStateExceeded` | `src/nip77_negentropy.zig:562`, `src/nip77_negentropy.zig:637` |
| `nip11` | `Nip11Error` | `OutOfMemory`, `InvalidJson`, `InvalidKnownFieldType`, `InvalidStructuredField`, `InvalidPubkey`, `TooManySupportedNips`, `LimitationOutOfRange`, `InputTooLong` | `src/nip11.zig:430`, `src/nip11.zig:505`, `src/nip11.zig:532` |

`*` I6 extension modules are feature-gated at root export level by build option
`enable_i6_extensions`.
- Optional-module non-interference and gate coverage remains active in root tests:
  `src/root.zig:269`, `src/root.zig:328`, `src/root.zig:358`.
- Skipped-test note: `2` skips are expected and non-regressive in this run profile; they come from
  the deterministic guard in `src/nip01_filter.zig:1023` (`SkipZigTest` branch at
  `src/nip01_filter.zig:1030`) and are observed once per enabled/core-only test run.
