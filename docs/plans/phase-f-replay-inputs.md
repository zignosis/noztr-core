# Phase F Replay Inputs

Date: 2026-03-09

Purpose: define explicit replay fixtures for Phase F risk burn-down, without changing defaults.

## UT-E-003 NIP-44 Cross-Implementation Replay Input Set

Set ID: `UT-E-003`

Scope: deterministic NIP-44 replay inputs used across local and cross-implementation runs.

Policy note: frozen defaults and strictness policy remain unchanged (`D-001`..`D-004`).

| Fixture ID | Source anchor | conversation_key_hex | nonce_hex | plaintext_expectation | payload_expectation_base64 |
| --- | --- | --- | --- | --- | --- |
| `UT-E-003-FX-001` | `src/nip44.zig` `encrypt_vectors[0]` | `c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d` | `0000000000000000000000000000000000000000000000000000000000000001` | `a` | `AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABee0G5VSK0/9YypIObAtDKfYEAjD35uVkHyB0F4DwrcNaCXlCWZKaArsGrY6M9wnuTMxWfp1RTN9Xga8no+kF5Vsb` |
| `UT-E-003-FX-002` | `src/nip44.zig` `encrypt_vectors[1]` | `c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d` | `f00000000000000000000000000000f00000000000000000000000000000000f` | `🍕🫃` | `AvAAAAAAAAAAAAAAAAAAAPAAAAAAAAAAAAAAAAAAAAAPSKSK6is9ngkX2+cSq85Th16oRTISAOfhStnixqZziKMDvB0QQzgFZdjLTPicCJaV8nDITO+QfaQ61+KbWQIOO2Yj` |
| `UT-E-003-FX-003` | `src/nip44.zig` `encrypt_vectors[2]` | `3e2b52a63be47d34fe0a80e34e73d436d6963bc8f39827f327057a9986c20a45` | `b635236c42db20f021bb8d1cdff5ca75dd1a0cc72ea742ad750f33010b24f73b` | `表ポあA鷗ŒéＢ逍Üßªąñ丂㐀𠀀` | `ArY1I2xC2yDwIbuNHN/1ynXdGgzHLqdCrXUPMwELJPc7s7JqlCMJBAIIjfkpHReBPXeoMCyuClwgbT419jUWU1PwaNl4FEQYKCDKVJz+97Mp3K+Q2YGa77B6gpxB/lr1QgoqpDf7wDVrDmOqGoiPjWDqy8KzLueKDcm9BVP8xeTJIxs=` |
| `UT-E-003-FX-004` | `src/nip44.zig` `encrypt_vectors[3]` | `d5a2f879123145a4b291d767428870f5a8d9e5007193321795b40183d4ab8c2b` | `b20989adc3ddc41cd2c435952c0d59a91315d8c5218d5040573fc3749543acaf` | `ability🤝的 ȺȾ` | `ArIJia3D3cQc0sQ1lSwNWakTFdjFIY1QQFc/w3SVQ6yvbG2S0x4Yu86QGwPTy7mP3961I1XqB6SFFTzqDZZavhxoWMj7mEVGMQIsh2RLWI5EYQaQDIePSnXPlzf7CIt+voTD` |
| `UT-E-003-FX-005` | `src/nip44.zig` `encrypt_vectors[4]` | `3b15c977e20bfe4b8482991274635edd94f366595b1a3d2993515705ca3cedb8` | `8d4442713eb9d4791175cb040d98d6fc5be8864d6ec2f89cf0895a2b2b72d1b1` | `pepper👀їжак` | `Ao1EQnE+udR5EXXLBA2Y1vxb6IZNbsL4nPCJWisrctGxY3AduCS+jTUgAAnfvKafkmpy15+i9YMwCdccisRa8SvzW671T2JO4LFSPX31K4kYUKelSAdSPwe9NwO6LhOsnoJ+` |

Malformed boundary increment (deterministic reject corpus):

- Top-level fixture shape now also supports `malformed_fixtures` entries with
  `{ id, conversation_key_hex, payload_base64, expectation }`.
- Added case: `UT-E-003-MAL-001` using known-good key
  `c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d`,
  payload `AQ==`, expectation `decrypt_reject`.
- Added case: `UT-E-003-MAL-002` using the same known-good key,
  payload `AA==`, expectation `decrypt_reject`.
- Added case: `UT-E-003-MAL-003` using the same known-good key,
  payload `Ag==`, expectation `decrypt_reject`.
- Added case: `UT-E-003-MAL-004` using the same known-good key,
  payload `Aw==`, expectation `decrypt_reject`.
- Added case: `UT-E-003-MAL-005` using the same known-good key,
  payload `` (empty), expectation `decrypt_reject`.
