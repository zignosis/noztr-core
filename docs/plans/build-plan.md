# noztr Build Plan (Phase E Final)

Date: 2026-03-09

This artifact is finalized for implementation execution and is aligned to:

- `docs/plans/v1-scope.md`
- `docs/plans/v1-api-contracts.md`
- `docs/research/v1-implementation-decisions.md`
- `docs/guides/NOZTR_STYLE.md`
- frozen defaults `D-001`, `D-002`, `D-004`, and `D-036` in `docs/plans/nostr-principles.md`

## Decisions

- `PE-001`: freeze implementation sequencing into executable phases with measurable completion gates.
- `PE-002`: keep the deterministic-and-compatible Layer 1 posture (`D-036`) as canonical in all
  core entry points; compatibility remains explicit where it would blur trust-boundary contracts and
  must not degrade bounded deterministic behavior.
- `PE-003`: require parity-core `nip11` in the core delivery schedule and gate closure criteria.
- `PE-004`: preserve extension-lane placeholders as documentation-only (`H2/H3` roadmap lanes) with no
  v1 scope expansion.
- `PE-005`: carry only low/medium impact accepted-risk items into Phase F; no high-impact ambiguity may
  remain `decision-needed` at Phase E close.
- `PE-006`: security hardening defaults are frozen for implementation: reduced secp module surface,
  commit-SHA pinning, typed backend outage boundaries, strict transcript/auth wrappers, normalized
  NIP-42 relay path binding, unbracketed IPv6 authority rejection, and strict PoW commitment
  truthfulness/floor policy.
- `PE-007`: maintain a dedicated security hardening register in
  `docs/plans/security-hardening-register.md` and treat it as the canonical status tracker for
  low/edge security follow-ups.
- `PE-008`: start and track LLM-usability evaluation in
  `docs/plans/llm-usability-pass.md` before RC API freeze closure (`OQ-E-006`).
- `PE-009`: freeze Layer 1 trust-boundary defaults for current kernel boundaries (lowercase-only critical hex,
   deterministic `ids`/`authors` lowercase-prefix filter semantics (`1..64`), unknown filter-field
   rejection, strict relay `OK` rejection status-prefix validation, and path-bound `ws`/`wss`
   NIP-42 origin policy).
- `PE-010`: treat `docs/guides/NOZTR_STYLE.md` as the project-level strictness profile baseline for
  trust-boundary API shape, compatibility isolation, and caller-owned buffer conventions.
- `PE-011`: evaluate compatibility and ergonomics through an explicit Layer 2 adapter track; use
  `OQ-E-006` to decide adapter behavior and freeze it only after vectors and usability evidence.
- `PE-012`: adopt Phase F parity execution model v1 for interop parity-all lanes: canonical taxonomy
  (`LIB_SUPPORTED`, `HARNESS_COVERED`, `NOT_COVERED_IN_THIS_PASS`, `LIB_UNSUPPORTED`), canonical
  depth labels (`BASELINE`, `EDGE`, `DEEP`), non-zero exit only on `HARNESS_COVERED` failures,
  and no default use of overloaded `unsupported` wording.
- `PE-013`: restrict active parity gate operations to the rust lane (`rust-nostr`) and keep the
  TypeScript `nostr-tools` parity-all lane as a re-runnable non-gating audit evidence lane.
  - rationale note: `rust-nostr` is the active lane because it is a strong production reference and
    ecosystem proxy, not because it overrides NIP authority or Zig-native design goals.

## Strategic Notes

- Zig core-principles alignment: prioritize clarity, control, simplicity, explicit errors/memory,
  and deterministic outcomes because these properties preserve auditability and parity repeatability.
- Reference posture: active parity against `rust-nostr` is meant to increase ecosystem confidence
  and surface lessons from a strong deployed implementation, not to require mimicry of every edge
  behavior.
- Layer 1 posture: choose the narrowest deterministic behavior that remains correct, bounded,
  explicit, and ecosystem-compatible.
- Zig posture: preserve Zig-native API shape and bounded-system guarantees where they improve the
  library without breaking protocol or ecosystem correctness.
- Compatibility rule: do not reject input merely to express purity when the broader shape is still
  spec-valid, unambiguous, and bounded.
- Adapter rule: keep explicit compatibility adapters only for cases where broader acceptance would
  otherwise blur Layer 1 contracts.
- Architecture intent: strict kernel and compatibility adapter remain separated so interop improves
  without weakening trust-boundary defaults.

## Implementation Schedule

Note: these are implementation phases, not planning prompt phases.

Implementation status snapshot (post-I7 closure):

- I0-I7 are complete and validated (`zig build test --summary all`, `zig build`).
- I4 optional modules (`nip19_bech32`, `nip21_uri`, `nip02_contacts`, `nip65_relays`) remain implemented
  with required non-interference coverage.
- I5 gates passed: staged `nip44` decrypt checks (`length -> version -> MAC -> decrypt -> padding`),
  staged `nip59` unwrap (`wrap -> seal -> rumor`), and vector floors plus public-error forcing
  coverage are validated.
- I6 gate note: optional extension modules are implemented, vector floors are met, and extension
  tests pass with I6 enabled and disabled.
- I7 closure evidence recorded in:
  `docs/archive/plans/i7-regression-evidence.md`,
  `docs/archive/plans/i7-api-contract-trace-checklist.md`, and
  `docs/archive/plans/i7-phase-f-kickoff-handoff.md`.
- Phase-state convention: planning prompt phase records remain closed in `decision-log`, while
  implementation execution is on the post-I7 baseline and proceeds through Phase F kickoff actions.
- Overengineering/correctness mitigation pass is applied on docs/contracts: trust-boundary path wording
  clarified, message error ambiguity reduced, and strict filter semantics tightened to deterministic
  lowercase-prefix matching.
- Contract sync deltas are reflected in active docs: NIP-44 padded-length helper uses `u32`
  return semantics, parser `OutOfMemory` variants are documented where implemented,
  strict event/filter kind boundary is `<= 65535`, NIP-50 unsupported multi-colon tokens are
  ignored, and NIP-09 coordinate matching rejects duplicate `d` tags.
- Transcript naming cleanup is tracked in docs: canonical strict path is
  `transcript_mark_client_req` plus `transcript_apply_relay`.
- PoW trust-boundary path is explicit: canonical strict callers use
  `pow_meets_difficulty_verified_id`; unchecked helper behavior is internal-only.
- Phase F execution is active on the post-I7 baseline; kickoff tracking is in
  `docs/archive/plans/phase-f-kickoff.md`.
- Phase F risk burn-down is active with replay pass evidence in
  `docs/archive/plans/phase-f-risk-burndown.md` (`UT-E-003`/`UT-E-004`).
- Current implementation state remains post-I7 closure baseline; no default-policy changes are
  introduced by kickoff tracking.
- Active parity cadence runs rust parity-all plus aggregate `zig` gates only.
- Active rust parity status is `22/22 HARNESS_COVERED`, `DEEP`, `PASS`.
- TypeScript parity lane is a re-runnable non-gating audit evidence lane; historical Phase F
  snapshots are preserved in the archive packet.
- Comparative evidence path for active NIP-59 deep parity remains:
  `cargo run --manifest-path tools/interop/rust-nostr-parity-all/Cargo.toml` and
  `zig build test --summary all -- --test-filter "nip59"` (`src/nip59_wrap.zig`).
- Trigger-governance status: no `UT-E-001`/`A-D-001` trigger criteria fired, so no
  policy/default changes were considered.
- Rule remains: any future trigger firing requires a decision-log entry before any default changes.
- Phase F parity model v1 canonical artifacts are active:
  - `docs/archive/plans/phase-f-parity-matrix.md`
  - `docs/archive/plans/phase-f-parity-ledger.md`
- Policy note: parity model v1 adoption changes interop reporting shape only; strictness/default
  policy remains unchanged.
- Policy note: rust-only active parity governance changes operations scope only; strictness/default
  policy and library behavior remain unchanged.
- Layer 2 compatibility/ergonomic adapter work remains deferred until Layer 1 execution and
  `OQ-E-006` closure.
- Phase G local-only release-readiness closure is complete as of 2026-03-10; remote readiness
  `no-3uj` remains deferred-by-operator and outside the completed local closure gate.
- Active planning state has moved to Phase H kickoff for additional NIP expansion in
  `docs/plans/phase-h-kickoff.md` and `docs/plans/phase-h-additional-nips-plan.md`.
- NIP-06 dependency strategy is resolved for current planning: adopt `libwally-core` behind the
  approved pinned crypto backend policy and a narrow boundary module.
- Phase H Wave 1 execution has started:
  - required Phase H0 NIP-06 freeze is complete.
  - `NIP-25` strict native reaction parsing/helpers are implemented in `src/nip25_reactions.zig`.
  - `NIP-10` strict kind-1 thread/reply helpers are implemented in `src/nip10_threads.zig`.
  - `NIP-18` strict repost helpers are implemented in `src/nip18_reposts.zig`.
  - `NIP-22` strict comment helpers are implemented in `src/nip22_comments.zig`.
  - `NIP-27` strict inline `nostr:` reference helpers are implemented in
    `src/nip27_references.zig`.
  - `NIP-51` strict public-list helpers and bounded bookmark/emoji tag builders are implemented in
    `src/nip51_lists.zig`.
  - Wave 1, the implemented-NIP audit, Wave 2 / `NIP-46`, Wave 3 / `NIP-06`, and the post-Wave
    `NIP-51` private-list follow-up are complete.
  - Next execution focus is implemented-surface robustness / real-world validation before any
    further protocol expansion.

Phase G closure and Phase H transition from current baseline:
- keep TypeScript parity references non-gating and prevent active-cadence wording regressions.
- run rust parity cadence plus aggregate Zig gates on dependency/toolchain changes.
- treat `UT-E-003`/`UT-E-004` as maintenance-mode items; reopen only on new behavior-class discovery.
- treat remote readiness `no-3uj` as deferred-by-operator and outside the completed Phase G local
  closure gate.
- execute additional-NIP expansion planning and sequencing in Phase H artifacts.

## Implemented NIP Review Criteria

Use this matrix when reviewing implemented behavior for accidental over-narrowing or unnecessary
ecosystem friction. The standard is not "be permissive"; it is "be deterministic, bounded, and
compatible unless there is a concrete reason not to be."

Review axes for every implemented NIP:
- NIP text: what the relevant NIP(s) actually require, permit, or leave open.
- Real ecosystem prevalence: what widely deployed producers and consumers appear to emit or accept.
- `rust-nostr` parity signal: what a strong production reference does in practice and what that
  implies for compatibility confidence.
- `nostr-tools` ecosystem signal: what the largest widely used JavaScript library appears to emit or
  accept, used as a secondary non-gating compatibility signal rather than an active release gate.
  Every implemented NIP audit must include a `nostr-tools` cross-check, using runtime harness
  coverage when possible and explicit source-review evidence otherwise.
- Security / trust-boundary impact: whether acceptance or rejection preserves cryptographic
  validity, typed failures, explicit bounds, deterministic state transitions, zeroization where
  required, and resistance to ambiguity or malformed input.
- Zig-native bounded-contract quality: whether the behavior keeps the API explicit, caller-buffer
  first where appropriate, bounded, simple to reason about, and production-useful for both humans
  and LLM agents.

Temperament rule for review and implementation:
- Apply KISS to protocol behavior as well as code structure: prefer the simplest bounded behavior
  that is correct, deterministic, and ecosystem-compatible.
- Do not add narrow helper rules, extra typed failures, or special-case parsing unless they produce
  clear trust-boundary, correctness, or interoperability benefit.
- When safe, prefer ignoring irrelevant or future-compatible input over poisoning the whole helper
  path.
- Explicit is good; fussy is not.

Cross-cutting review lenses for every implemented NIP:
- Compatibility cost versus benefit: do not pay ecosystem friction unless correctness, safety,
  determinism, or boundedness actually improves.
- Overengineering / unnecessary reinvention: do not reinvent what Zig stdlib, approved pinned
  backend boundaries, or existing in-repo helpers already provide; do not add speculative helpers,
  generic layers, or API breadth that turns the library into infrastructure for hypothetical future
  libraries instead of a production protocol kernel.
- LLM and human usability: public names, typed errors, and call sequences should be easy to
  discover and reason about without hidden context.

Tracker and landing discipline:
- Treat all `br` mutations and all git-writing steps as serial-only operations.
- Never parallelize `br update/close/create`, `br sync --flush-only`, or any `git commit`.
- Canonical order when tracker state changes:
  `br update/close/create` -> `br sync --flush-only` -> `git add .beads/` -> `git commit`

| NIP | Review Criteria From `D-036` |
| --- | --- |
| 01 | Preserve hard rejection for cryptographic invalidity and malformed critical fields; review filter-field rejection, lowercase-only critical hex, and relay `OK` status rules to confirm each narrowing is protocol-necessary or materially safer rather than merely tidier. |
| 02 | Preserve kind scoping and pubkey validity; review whether valid relay-hint and petname shapes are accepted without forcing an unnecessarily narrow contact-tag interpretation. |
| 03 | Preserve exact attestation target references, bounded proof decoding, and the accepted local proof floor (magic/version/sha256 root digest/Bitcoin attestation); review proof-shape strictness so we reject malformed `1040` events without pretending to perform deeper networked OpenTimestamps / Bitcoin verification that the kernel does not actually implement. |
| 09 | Preserve author-bound deletion integrity and typed target failures; review whether any accepted `e`/`a` delete shape from the NIP is being rejected without a safety reason. |
| 10 | Preserve deterministic thread extraction and malformed-marker rejection while keeping reviewed compatibility for legacy `mention` tags and four-slot pubkey fallback; review any future narrowing against both ecosystem pressure and whether the extra accepted data actually improves trust-boundary behavior. |
| 11 | Preserve typed known-field validation with unknown-field tolerance; review whether known-field typing or pubkey strictness rejects inputs the NIP intentionally leaves open. |
| 13 | Preserve checked PoW truthfulness and bounded nonce handling; review nonce-tag shape rules only where real producers emit broader but still unambiguous forms. |
| 17 | Preserve bounded kind-`14` message parsing, wrap-to-rumor trust-boundary reuse, and kind-`10050` relay-list extraction; review recipient/reply/subject tag exactness against real producer output without widening the kernel into chat orchestration or kind-`15` file-transfer policy. |
| 18 | Preserve repost target consistency and embedded-event verification; review whether addressable repost/helper shapes accepted in the ecosystem remain deterministic enough for Layer 1. |
| 19 | Preserve exact codec correctness and forbidden-secret handling; review only if bech32 casing or TLV acceptance is broader in practice while still standards-valid. |
| 21 | Preserve deterministic `nostr:` URI parsing; review whether any lowercase-only or boundary-token rule is stricter than the URI/NIP actually requires. |
| 22 | Preserve root/parent/linkage correctness and NIP-73 consistency; review mandatory `K/k`, `P/p`, and root-scope requirements against deployed comment traffic so we do not reject valid-but-common comment structures without strong justification. |
| 23 | Preserve required `d` editability, bounded long-form metadata extraction, and deterministic hashtag ordering; review optional metadata exactness so we reject malformed title/image/summary/published-at tags without turning harmless unknown or future article metadata into whole-helper failures. |
| 24 | Preserve bounded kind-`0` metadata extras parsing and deterministic generic tag handling; review deprecated-field fallback and generic tag breadth so we accept real metadata/tag shapes without partially re-implementing NIP-73-owned `i` grammar in the wrong module. |
| 25 | Preserve target determinism and NIP-30-valid custom emoji handling; review target heuristics and emoji-tag requirements to ensure we reject malformed reactions, not merely unfamiliar but still valid ones. |
| 26 | Preserve exact `delegation` tag shape, supported condition grammar, message-string/signature correctness, and pure event-condition checks; review any future widening only if real producer behavior demonstrates broader but still deterministic condition or hex-tag shapes. |
| 27 | Preserve stable spans and decoded references; review lowercase-only `nostr:` handling and malformed-fragment fallback so URI extraction remains spec-correct without dropping harmless real-world forms. |
| 29 | Preserve bounded relay-generated event parsing and pure fixed-capacity state reduction without embedding load/fetch/subscription logic in the kernel; review compatibility shims such as `public`/`open` metadata aliases only where deployed helper behavior makes them materially useful. |
| 05 | Preserve spec-shaped local-part validation, bare-domain `_` canonicalization, exact well-known URL composition, and bounded `names` / `relays` / `nip46` extraction; review optional-map strictness only where broader ecosystem responses remain deterministic and useful instead of silently widening identifier grammar beyond the NIP. |
| 32 | Preserve bounded kind-`1985` label-event extraction, non-`1985` self-label extraction, and exact `e`/`p`/`a`/`r`/`t` target matching; review namespace/label/tag-item breadth so we ignore unrelated future-compatible tags without accepting malformed supported target tags or drifting into label-management workflow logic. |
| 36 | Preserve exact `content-warning` tag detection/building and the accepted NIP-32 namespace bridge, while reviewing empty-reason and extra-item handling so the helper stays ecosystem-compatible without turning into moderation policy or richer content workflow logic. |
| 37 | Preserve exact kind-`31234` `d`/`k` metadata parsing, blank-content deleted-draft handling, NIP-44 draft/private-relay decryption boundaries, and kind-`10013` private relay-tag extraction; review only where broader deployed draft or private-relay payload shapes remain deterministic and reusable without turning the kernel into draft-sync or editor workflow. |
| 56 | Preserve bounded kind-`1984` report extraction/building, required `p` target presence, typed report enums, and tolerant handling of clearly generic `e`/`p` forms; review note/blob-report exactness so the kernel stays deterministic without pretending to be a moderation-policy engine. |
| 58 | Preserve deterministic badge definition / award / profile-badge parsing and pair validation while keeping unmatched profile display pairs safely ignorable; review optional badge metadata and relay-hint exactness so the kernel stays interoperable without turning into badge presentation or sync workflow logic. |
| 39 | Preserve bounded kind-`10011` claim extraction and deterministic proof material without embedding provider fetch policy in the kernel; review provider/identity/proof validation only where broader real-world forms remain unambiguous and production-useful. |
| 40 | Preserve explicit expiration parsing and typed boundary failures; review only if real traffic uses spec-valid but non-canonical timestamp/tag forms. |
| 42 | Preserve replay safety, origin binding, and typed auth failures; review path binding, `ws`/`wss` distinction, and IPv6 rules against operational interoperability evidence before freezing them as unquestionable defaults. |
| 44 | Preserve cryptographic staging, typed failures, and zeroization; compatibility review is secondary here and should only consider standards-backed variant handling, not permissive decoding. |
| 45 | Preserve bounded extension parsing and state transitions; review whether extension message shapes are being narrowed beyond the extension spec or common peer behavior. |
| 50 | Preserve bounded token parsing and explicit unsupported forms; review whether rejected search-token patterns are malformed or just broader than our current parser. |
| 51 | Preserve set metadata bounds, coordinate-kind checks, and deterministic extraction; review bookmark/list-family narrowing, optional emoji-set coordinates, and future list-shape breadth against both the NIP tables and real producer behavior. |
| 59 | Preserve staged unwrap integrity, sender continuity, and bounded scratch usage; review only if interoperability pressure appears on wrapper/seal/rumor envelope shapes that remain unambiguous and safe. |
| 65 | Preserve relay URL validation, marker typing, and bounded extraction; review normalization and accepted marker breadth so we reject malformed relays rather than merely non-preferred formatting. |
| 70 | Preserve deny-by-default protected-event semantics and exact tag meaning; review whether any tag-shape exactness exceeds what NIP-70 needs for deterministic behavior. |
| 73 | Preserve bounded external-id parse/build/match behavior and shared ownership of generic `i` grammar; review kind/value strictness so we reject malformed external IDs without fragmenting the grammar across per-NIP helper reimplementations. |
| 84 | Preserve deterministic highlight-source extraction, bounded `p` attribution/url-reference parsing, and optional `context`/`comment` handling without drifting into reader UX; review long-form source-tag and role/marker tolerance so the kernel stays interoperable without becoming article/highlight workflow logic. |
| 92 | Preserve exact `imeta` pair parsing, required `url` plus at least one supported metadata field, NIP-94-aligned value validation, repeated fallback support, and URL-to-content matching that rejects prefix-only embeddings; review only where broader deployed `imeta` field handling remains deterministic and does not collapse supported-field trust boundaries into generic string maps. |
| 94 | Preserve exact kind-`1063` parsing, required `url`/lowercase-MIME/`x` handling, bounded optional metadata tags, repeated fallback support, and typed duplicate/malformed-tag failures; review optional field breadth only where broader deployed shapes remain deterministic and do not weaken the trust boundary for core file metadata. |
| 99 | Preserve bounded classified-listing metadata extraction/building for `30402` / `30403`, required `d`, typed price/status handling, ordered image/hashtag support, and ignored unrelated tags; review field exactness only where broader deployed listing metadata remains deterministic and does not pull commerce/search workflow into the kernel. |
| 77 | Preserve bounded negentropy state transitions and strict session parsing; review message-shape rejection only where broader but still well-defined peer behavior exists. |

Review execution rule:
- A behavior is too strict when it creates material ecosystem incompatibility without improving
  correctness, safety, determinism, or boundedness.
- A behavior is acceptable to keep narrow when it closes ambiguity, prevents malformed input
  acceptance, or protects a trust boundary in a way that a broader rule cannot.
- A divergence from `rust-nostr` is acceptable when it is NIP-grounded, test-backed, bounded, and
  materially improves correctness, determinism, or Zig-native contract quality without causing
  disproportionate ecosystem friction.
- A mismatch with `nostr-tools` is a compatibility signal to evaluate, not an automatic defect; its
  weight is highest when it reinforces other ecosystem evidence.

Required per-NIP contract discipline:
- Freeze a short spec-to-contract checklist before closure:
  - supported kinds
  - required tags / fields
  - optional tags / fields
  - multiplicity and ordering rules
  - normalization / canonicalization rules
  - ignored / unsupported shapes
  - explicit non-goals and SDK-side ownership where relevant
- No NIP closes until every checklist line is mapped to one of:
  - code
  - tests
  - examples
  - explicit accepted non-goal
- Treat builder/parser symmetry as a mandatory closure class where both surfaces exist:
  - builder output round-trips through parser
  - parser-accepted canonical shapes are buildable
  - malformed near-canonical shapes fail predictably
- Treat public error semantics as a mandatory review class:
  - error variants must describe the real remediation path
  - invalid input must not surface as capacity exhaustion
  - capacity exhaustion must not surface as invalid input
- When a NIP is `LIB_UNSUPPORTED` or only weakly covered in reference lanes, require one extra
  spec-first challenge pass before closure.
- If the review process or closure standard becomes stricter mid-stream, run a retroactive backfill
  pass over all recently closed or newly expanded NIPs touched before the new rule landed.
  - minimum backfill output:
    - checklist coverage confirmed or corrected
    - adversarial/error-contract review applied where newly required
    - canonical audit artifact updated if conclusions or status changed

Required adversarial coverage:
- Every implemented or newly expanded protocol surface must have:
  - happy-path tests
  - per-field negative corpus
  - hostile/adversarial inputs or transcripts where the protocol shape warrants them
- "Hostile transcript" means malformed, contradictory, replay-like, oversized-within-bounds,
  near-canonical, or ordering-sensitive inputs designed to attack the trust boundary rather than
  merely fail ordinary parsing.
- Boundary-heavy modules such as auth, encryption, relay-management, wrapping, remote-signing,
  list privacy, and RPC/message surfaces must explicitly include hostile transcript coverage.
- Boundary-heavy SDK-facing modules must also expose at least one consumer-facing hostile or
  invalid example fixture in `examples/` so downstream users can see the intended rejection path,
  not only the valid flow.

### Implemented NIP Audit Execution

Run the audit serially, one implemented NIP at a time, before further phase expansion work.

Per-NIP audit steps:
1. Create or claim one beads audit issue for the NIP and freeze the exact review target.
2. Gather evidence from:
   - relevant NIP text
   - current `noztr` code and tests
   - `rust-nostr` harness/source behavior
   - `nostr-tools` harness/source behavior for the same NIP
   - existing in-repo notes about real producer or ecosystem behavior
3. Review with the required axes and cross-cutting lenses above.
4. Record findings only when they are evidence-backed:
   - likely bug
   - likely unnecessary incompatibility
   - likely trust-boundary/security problem
   - likely overengineering or unnecessary reinvention
5. Run a second-pass challenge on the draft findings to remove false positives, preference-only
   comments, or conclusions unsupported by the evidence.
6. Run an adversarial audit pass focused on:
   - builder/parser symmetry mismatches
   - public error-contract mismatches
   - hostile transcripts or near-canonical malformed shapes
   - checklist lines that are not yet proven by tests/examples
7. Resolve each accepted finding by one of:
   - immediate fix
   - documented accepted-risk
   - linked follow-up issue
   - explicit intentional divergence
8. Update canonical docs only where policy, accepted behavior, or current status changed; keep the
   remaining audit evidence in the beads issue and update the consolidated audit report in
   `docs/plans/implemented-nip-audit-report.md`.
9. Create one local git commit scoped to the completed audit item after post-Review-B/adversarial
   green gates
   and canonical doc updates are in place.
10. Close the audit issue only when findings, evidence classes, outcome, and any follow-up items are
   all recorded explicitly.

Audit quality rules:
- No NIP is audited by vibe or memory only.
- No reference library is treated as protocol authority.
- No finding is accepted without a severity, evidence basis, and interoperability rationale.
- "No issue found" is recorded explicitly when that is the result.
- Every implemented NIP audit must record both `rust-nostr` and `nostr-tools` evidence status,
  even when one of them is only `SOURCE_REVIEW_ONLY`.
- Every completed implemented-NIP audit that changes code or canonical docs must land as its own
  local git commit before the next NIP audit begins.
- Every completed implemented-NIP audit must also update the canonical consolidated audit artifact
  when the accepted behavior, findings, or current status changed.
- When the audit process itself changed after some NIPs were already closed, the first full-surface
  audit under the stronger process must explicitly backfill those recently closed NIPs before the
  repo can claim the new standard is satisfied.

Consolidated audit artifact:
- `docs/plans/implemented-nip-audit-report.md` is the canonical summary for audit findings,
  decisions, accepted risks, and follow-up links after the autonomous audit completes.
- beads issues hold per-NIP raw evidence; the report holds the systematic review-ready synthesis.

### Implemented Surface Robustness / Real-World Validation Execution

Use this when the goal is to harden already-implemented surfaces before adding more NIPs. This is
not a separate governance model. It reuses the implemented-NIP audit standards above and extends
them with stronger integration and interoperability evidence.

Run the robustness pass serially, one implemented surface at a time.

Per-surface robustness steps:
1. Create or claim one beads issue for the target hardening pass and freeze the exact scope.
   Examples: `NIP-46`, `NIP-06`, `NIP-51` private lists, `NIP-44`, `NIP-59`.
2. Reuse the same review axes, temperament rule, and cross-cutting lenses from the implemented-NIP
   audit.
3. Gather stronger execution evidence than a normal parity review where practical:
   - current `noztr` code/tests
   - NIP text
   - `rust-nostr`
   - `nostr-tools`
   - protocol-shaped integration samples, replay inputs, or real-world message/event examples
4. Prefer findings in these classes:
   - latent bug under realistic composition
   - unnecessary interoperability friction under real producer/consumer behavior
   - trust-boundary weakness that only appears in end-to-end or composed flows
   - unnecessary complexity that makes maintenance or safe usage harder than needed
5. Keep the fix posture narrow:
   - do not broaden acceptance casually
   - do not add orchestration or app-flow logic into Layer 1
   - prefer adapters only when broader compatibility would otherwise blur the kernel contract
6. Run the same two review-cycle discipline used by the implementation loop:
   - Review Cycle A: correctness, edge cases, parity/ecosystem, overengineering, usability
   - Review Cycle B: challenge the fixes and remove any regression or unnecessary complexity
7. Add an adversarial hardening pass:
   - hostile or contradictory transcripts
   - builder/parser symmetry challenges
   - public error-contract challenges
   - invalid fixtures that are realistic enough for SDK/app consumers to misuse
8. For boundary-heavy SDK-facing surfaces, ensure `examples/` includes at least one hostile or
   invalid consumer-facing fixture that matches the hardened failure contract.
9. Run fresh gates after the final candidate:
   - focused surface tests first
   - `zig build test --summary all`
   - `zig build`
   - focused parity/interop commands where applicable
10. Update canonical docs only where accepted behavior, active risks, or current state changed.
   Keep the consolidated outcome in `docs/plans/implemented-nip-audit-report.md` if the pass
   changes accepted conclusions or opens new follow-ups.
11. Land one local git commit scoped to the completed robustness item before moving to the next one.

Robustness pass quality rules:
- Reuse existing procedure; do not create a new ad hoc review process per surface.
- Treat real-world/interoperability evidence as a strengthening layer on top of the audit, not as a
  replacement for the audit standards.
- Prefer hardening the highest-value, most integration-sensitive surfaces first before resuming new
  protocol expansion.
- When a scope question is really a kernel-vs-SDK ownership question, consult
  `docs/plans/noztr-sdk-ownership-matrix.md` before widening `noztr` or deferring deterministic
  protocol glue out of it.

### Post-Kernel Follow-Up Status

Use this after the accepted kernel expansion is complete and `noztr` shifts into SDK-supporting
maintenance rather than new broad NIP expansion.

Completed in order:
1. SDK-consumer integration / hardening pass
   - local Zig dependency path is documented
   - downstream example packages are wired into `zig build test --summary all`
2. Nostr-relevant `BIP-85` follow-up
   - bounded lowercase-hex entropy text plus English BIP39 child entropy/mnemonic helpers are
     implemented
3. Full `NIP-06` Unicode `NFKD` normalization
   - repo-owned static Unicode tables and bounded runtime normalization are implemented
4. `NIP-51` deprecated `NIP-04` compatibility adapter
   - explicitly re-evaluated and still deferred pending real interoperability evidence

Current rule:
- keep the deprecated `NIP-04` private-list adapter deferred unless real interoperability evidence
  justifies widening the kernel
- prefer further `noztr` work only when it clearly improves SDK consumption, deterministic kernel
  reuse, or proven interoperability

## Post-Kernel Requested NIP Execution

The next requested-NIP lane after the current kernel-complete baseline is tracked in
`docs/plans/post-kernel-requested-nips-loop.md`.

Required execution policy:
- run the requested NIPs serially, one at a time
- freeze the exact kernel slice before implementation starts
- require two explicit reviews per NIP:
  - Review A: correctness / parity / trust boundary
  - Review B: boundary / usability / overengineering
- require one explicit adversarial audit pass per NIP after Review B fixes:
  - spec-to-contract checklist completion
  - builder/parser symmetry
  - per-field negative corpus
  - hostile transcripts or hostile fixtures where relevant
  - public error-contract checks
- require at least one scoped git commit per NIP before the next NIP starts
- require examples and active-doc updates as part of each NIP closure
- for split NIPs, stop at the deterministic protocol-kernel boundary and record the remaining SDK
  surface explicitly

## Phase F hard-gate closure status (epic `no-dr3`)

- `no-21a` Gate 1 (scope freeze first): complete.
  Representative-set freeze is recorded and locked before gate reruns
  (`docs/archive/plans/phase-f-replay-inputs.md`, `docs/archive/plans/phase-f-parity-matrix.md`).
- `no-hbo` Gate 2 (three consecutive full-gate runs): complete.
  Full sequence executed three times consecutively from controlled state with stable pass outcomes.
- `no-fof` Gate 3 (fail-fast on drift): complete.
  No drift detected across the three-run window; all three runs are recorded in
  `docs/archive/plans/phase-f-risk-burndown.md`.
- `no-6jx` Gate 4 (no-new-findings closure rationale): complete.
  Closure rationale based on latest incremental candidates is recorded in
  `docs/archive/plans/phase-f-risk-burndown.md`.
- `no-1jh` Gate 5 (governance/docs closure with open P0/P1 check): complete.
  `br query "status=open AND (priority=0 OR priority=1)" --json --limit 0`
  pre-check: `count=0`, ids: none; post-check: `count=0`, ids: none.
- Policy note: rust lane remains active and the TypeScript lane remains a re-runnable non-gating
  audit evidence lane.

### Phase G closure note (local-only baseline)

- Phase F hard-gate closure (`no-dr3`) is complete and preserved as historical evidence.
- Phase G local-only release-readiness checklist is complete.
- `UT-E-003` and `UT-E-004` are in maintenance mode; reopen only on new behavior-class discovery.
- Blocker visibility: `no-3uj` remains open for git/Dolt remote + sync readiness.
- Remote readiness is deferred-by-operator and is not a Phase G closure gate in the current local
  execution environment.
- Active planning state moves to Phase H kickoff.

### Phase G non-remote release-readiness checklist status

- Status: non-remote checklist pass is complete for local closure.
- Cadence/gates: rust parity cadence plus aggregate `zig` gates are current for kickoff baseline.
- Policy reaffirmed: `UT-E-003`/`UT-E-004` remain maintenance-mode only, with no burn-down expansion
  unless a new behavior class is discovered.
- Governance reaffirmed: rust lane is active; TypeScript remains a re-runnable non-gating audit
  evidence lane.
- Scope note: remote readiness (`no-3uj`) remains deferred-by-operator and outside this
  non-remote checklist pass.
- Transition note: additional-NIP expansion planning now proceeds in Phase H artifacts.

### Phase I0 - Foundation and Shared Contracts

- Modules/files: `src/root.zig`, `src/limits.zig`, `src/errors.zig`, `build.zig` test wiring.
- Deliverables:
  - root export skeleton aligned to Phase D contract names.
  - shared limits and typed boundary error sets.
  - crypto boundary setup for I1 signatures on resolved default path:
    in-repo thin Zig wrapper over pinned `bitcoin-core/secp256k1` BIP340/Schnorr backend.
  - boundary rule captured: no direct backend calls outside one boundary module.
  - aggregate `zig build` and `zig build test --summary all` steps wired.
- Test/vector plan:
  - compile-time invariants for limits and relation checks.
  - smoke tests for root exports and typed error imports.
- Exit gate:
  - static library builds; tests pass with zero leaks.
  - no public catch-all errors; Layer 1 defaults documented in module headers.

### Phase I1 - Core Event and Filter Kernel

- Modules/files: `src/nip01_event.zig`, `src/nip01_filter.zig`.
- Deliverables:
  - deterministic event parse/serialize/verify split (`verify_id`, `verify_signature`, `verify`).
  - deterministic replace decision (`created_at`, lexical `id`).
  - typed verify outage distinction (`BackendUnavailable`) separated from cryptographic invalidity.
  - strict filter grammar and pure match semantics (`AND` within filter, `OR` across filters).
  - strict `ids`/`authors` lowercase hex-prefix model (`1..64`) with nibble-precision prefix matching,
    lowercase-only `#x` keys, and typed tag-key overflow (`TooManyTagKeys`).
- Test/vector plan:
  - `nip01_event`: minimum `5 valid + 5 invalid`; include duplicate-key reject, invalid hex,
    invalid id/sig, max bounds, tie-break vectors.
  - `nip01_filter`: minimum `5 valid + 5 invalid`; include malformed `#x`, empty `#x` array reject,
    overflow paths,
    `since > until` reject, OR-of-filters behavior.
  - every public error variant has a forcing test.
- Exit gate:
  - canonical serialization and id computation deterministic across repeated runs.
  - strict parser rejects malformed/ambiguous critical fields.
  - signature closure satisfies all required acceptance criteria:
    - backend pinned by commit or tag.
    - boundary-only call graph (no direct backend calls elsewhere).
    - deterministic typed-error mapping for sign/verify/pubkey parse outcomes.
    - explicit backend outage mapped to typed boundary error (no generic verify failure).
    - BIP340 vector suite pass plus required negative corpus.
    - differential verification checks pass against pinned reference behavior.
    - no unbounded runtime allocation in signature paths.

### Phase I2 - Message Grammar, Auth/Protected, and Relay Info Core

- Modules/files: `src/nip01_message.zig`, `src/nip42_auth.zig`, `src/nip70_protected.zig`,
  `src/nip11.zig`.
- Deliverables:
  - typed client/relay union grammar with exact arity checks and multi-filter `REQ`/`COUNT` support.
  - strict relay `OK` grammar requires lowercase-hex event id.
  - relay `OK` status semantics are explicit: success accepts empty/free-form status; rejection
    requires prefixed status (`<prefix>: <message>`).
  - transcript state enforcement with explicit client marker
    (`transcript_mark_client_req`, `transcript_apply_relay`) and strict flow
    (`REQ marker; relay EVENT* -> EOSE? -> EVENT* -> CLOSED?`; `CLOSED` is terminal).
  - auth challenge validation and bounded authenticated-pubkey state.
  - challenge-set boundary typing distinguishes empty from too-long challenge input.
  - challenge rotation semantics: set-challenge clears authenticated pubkey set.
  - auth required-tag strictness: duplicate `relay`/`challenge` tags are rejected.
  - strict relay origin matching compares normalized scheme/host/port/path, ignores query/fragment,
    normalizes missing path to `/`, supports bracketed IPv6 authorities, and rejects unbracketed
    IPv6 authorities.
  - freshness policy uses bounded symmetric skew: timestamps within the window are accepted;
    future beyond window rejects `FutureTimestamp`; stale beyond window rejects `StaleTimestamp`.
  - auth backend outage distinction typed separately from invalid signature.
  - protected-event gate with default deny unless auth context matches.
  - `nip11` partial-document parse with strict known-field typing, strict pubkey hex validation,
    and typed bounded caps.
- Test/vector plan:
  - `nip01_message`, `nip42_auth`, `nip70_protected`, `nip11`: each minimum `5 valid + 5 invalid`.
  - transcript forcing tests for invalid order and prefix mapping.
  - NIP-42 vectors include challenge rotation auth-set clear, duplicate required-tag reject, future
    timestamp reject, stale timestamp reject, typed empty-vs-too-long challenge-set failures,
    normalized-path match/mismatch (`/` default, query/fragment ignored), bracketed-IPv6
    origin match/mismatch, unbracketed-IPv6 reject, and backend outage mapping.
  - `nip11` vectors include unknown-field ignore, known-field type mismatch reject, invalid pubkey
    reject, and cap overflow typed errors.
- Exit gate:
  - all parity-core messaging and trust-boundary modules pass deterministic transcript and policy tests.
  - `nip11` included in pass criteria (cannot defer beyond this phase).

### Phase I3 - Core Lifecycle Policy Primitives

- Modules/files: `src/nip09_delete.zig`, `src/nip40_expire.zig`, `src/nip13_pow.zig`.
- Deliverables:
  - author-bound deletion rules for `e`/`a` targets.
  - checked delete extraction wrapper for relay-safe callers (`delete_extract_targets_checked`).
  - strict expiration parse and deterministic boundary helper.
  - deterministic PoW leading-zero and nonce-tag validation.
  - strict PoW commitment policy: `actual_bits >= commitment` and `commitment >= required_bits`
    when nonce commitment is present.
  - checked PoW verification wrapper (`pow_meets_difficulty_verified_id`) to couple id validity with
    difficulty checks.
- Test/vector plan:
  - each module minimum `5 valid + 5 invalid`.
  - boundary vectors: expiration equality second, delete cross-author reject,
    malformed nonce and difficulty range errors, commitment-below-required reject, and
    actual-below-commitment reject.
  - wrapper vectors: checked delete kind guard and checked PoW invalid-id reject.
- Exit gate:
  - pure helper behavior deterministic and side-effect free.
  - lifecycle error-path coverage includes all typed public errors.

### Phase I4 - Optional Identity and Relay Metadata Codecs

- Modules/files: `src/nip19_bech32.zig`, `src/nip21_uri.zig`, `src/nip02_contacts.zig`,
  `src/nip65_relays.zig`.
- Deliverables:
  - strict HRP/TLV codec behavior and URI parsing boundary.
  - strict kind-scoped extraction for contacts and relay lists.
- Test/vector plan:
  - each optional module minimum `3 valid + 3 invalid` (current accepted default).
  - required vectors include checksum/mixed-case/TLV failures, forbidden `nsec`, marker/url rejects.
  - non-interference tests ensure optional paths do not mutate core parser defaults.
- Exit gate:
  - optional modules pass minimum vector gate and keep core ABI/behavior stable.

### Phase I5 - Core Private Messaging Crypto and Wrap

- Modules/files: `src/nip44.zig`, `src/nip59_wrap.zig`.
- Deliverables:
  - stdlib-only NIP-44 v2 implementation with staged decrypt check order:
    `length -> version -> MAC -> decrypt -> padding`.
  - decrypt returns typed `InvalidPadding` when post-padding plaintext UTF-8 validation fails.
  - constant-time MAC compare and secret wipe helper usage.
  - staged NIP-59 unwrap (`wrap -> seal -> rumor`) uses recipient private key material to derive
    per-layer NIP-44 conversation keys (`wrap.pubkey` then `seal.pubkey`), enforces unsigned rumor
    semantics (reject rumor `sig`), and preserves sender continuity checks.
- Test/vector plan:
  - `nip44`: official vectors plus invalid corpus; minimum `5 valid + 5 invalid` is floor,
    official corpus depth supersedes floor.
  - `nip59_wrap`: minimum `5 valid + 5 invalid`; include spoof and malformed layer failures.
  - deterministic fixed-nonce harness for encryption parity tests.
- Exit gate:
  - pinned NIP-44 vectors pass in full.
  - no unbounded/runtime-heap allocation in `nip44` encrypt/decrypt hot paths.
  - `nip59_unwrap` strict path uses caller-provided bounded scratch for inner event parsing.

### Phase I6 - Optional Extension Message Lane (H1 Optional Only)

- Modules/files: `src/nip45_count.zig`, `src/nip50_search.zig`, `src/nip77_negentropy.zig`.
- Deliverables:
  - strict extension parsers and bounded state transitions.
  - `nip77_negentropy` strict parse APIs include `negentropy_close_parse` and
    `negentropy_err_parse` (`NEG-CLOSE`/`NEG-ERR`) with typed `InvalidNegErr` boundaries.
  - explicit feature-gated integration points; no core default mutation.
- Test/vector plan:
  - each module minimum `3 valid + 3 invalid`.
  - `nip77` ordering/session overflow vectors are mandatory.
  - `nip77` strict `NEG-CLOSE` and `NEG-ERR` parse/error vectors are mandatory.
  - extension gate tests verify disabled-extension core behavior remains unchanged.
- Exit gate:
  - extension modules compile/test under feature gate.
  - disabling extensions keeps all core tests green.

### Phase I7 - Hardening, Conformance Sweep, and Release Candidate Handoff

- Modules/files: all implemented v1 modules.
- Deliverables:
  - full cross-module regression pass.
  - contract-to-implementation trace checklist for every public API.
  - implementation handoff package for Phase F kickoff.
- Test/vector plan:
  - rerun all module vectors and aggregate leak checks.
  - replay deterministic transcript and crypto check-order suites.
  - verify every public error variant still has direct forcing coverage.
- Exit gate:
  - `zig build test --summary all` pass with zero leaks.
  - `zig build` static library artifact produced.
  - implementation kickoff artifact inputs complete for Phase F.

## Per-Phase Build and Quality Gates

- Required for every phase closure:
  - `zig build test --summary all` passes.
  - `zig build` succeeds.
  - no unresolved high-impact ambiguity in `decision-needed` status.
  - TigerStyle constraints remain enforceable (function length, line width, assertion density,
    explicit errors, bounded control flow).

## Risks and Assumptions

- `R-E-001` crypto implementation correctness risk in `nip44` remains high-impact implementation risk;
  mitigated by pinned vectors, invalid corpus, deterministic nonce harness, and staged checks.
- `R-E-004` backend-boundary correctness risk on selected secp256k1/BIP340 path: boundary misuse or
  API leakage can break deterministic and typed-error contracts; mitigated by a single boundary
  module, pinned backend revision, and differential verification corpus.
- `R-E-005` secp hardening drift risk: broadened wrapper/call surface can reintroduce unsafe direct
  backend usage; mitigated by reduced boundary module exports and commit-SHA pinning in canonical
  records.
- `R-E-002` optional-lane drift risk remains medium; mitigated by explicit non-interference tests and
  extension gate checks.
- `R-E-003` bounded capacities may need empirical adjustment; mitigated by typed overflow errors and
  explicit reversal triggers in tradeoff register.
- `A-E-001` assumes Zig stdlib crypto surfaces used by contracts remain stable across implementation.
- `A-E-002` assumes parity source snapshots (`D-001`) remain sufficient for v1 execution window.
- `A-E-003` assumes the selected secp256k1 backend path can be pinned and wrapped without violating
  zero-unbounded-runtime-work and typed-error boundary requirements.
- `A-E-004` was resolved post-Phase E by `D-030`: NIP-06 will use the vetted `libwally-core`
  path behind the approved pinned crypto backend policy and a narrow boundary module.

## Edge-Case Audit Closure

- Status: edge-case audit is closed with no unresolved Medium+ findings.
- Security hardening register: `docs/plans/security-hardening-register.md`.
- LLM-usability artifact: `docs/plans/llm-usability-pass.md`.
- Transcript canonical path reference: `transcript_mark_client_req` then `transcript_apply_relay`.
- PoW canonical trust-boundary reference: `pow_meets_difficulty_verified_id`
  (unchecked helper is internal-only).
- Follow-up observations (low):
  - closed: normalized-path binding in NIP-42 relay origin matching (`/` default;
    query/fragment ignored).
  - closed: unbracketed IPv6 authority rejection in NIP-42 relay origin matching.
  - closed: canonical event runtime shape/UTF-8 validation guards.
  - closed: PoW commitment truthfulness/floor enforcement (`actual_bits >= commitment >=
    required_bits`).
  - current hygiene baseline: Tiger hard checks are clean in `src/` (`>100` columns none,
    `>70`-line functions none).
  - quality follow-up: strict-width and anti-pattern cleanup remains tracked where applicable.
  - in progress: LLM-first usability evaluation started post-security checkpoint and before
    release-candidate API freeze (`docs/plans/llm-usability-pass.md`).

## Unresolved Tradeoff Register

`UT-E-001`
- Topic: optional module vector depth beyond `3 valid + 3 invalid` baseline.
- Impact: medium.
- Status: accepted-risk.
- Default: keep baseline for v1; increase only when parity corpus shows drift.
- Mitigation: gate every optional module with required invalid-path vectors and non-interference tests.
- Reversal Trigger: optional parity regressions or repeated escaped defects.
- Owner: Phase F owner.

`UT-E-002`
- Topic: compatibility API physical placement (`co-located` vs `compat/` namespace).
- Impact: low.
- Status: accepted-risk.
- Default: strict APIs remain canonical; choose file layout in implementation kickoff without behavior
  change.
- Mitigation: enforce identical typed contracts and strict-default path tests regardless of placement.
- Reversal Trigger: measurable maintenance burden or accidental policy leakage.
- Owner: Phase F owner.

`UT-E-003`
- Topic: NIP-44 differential replay depth in CI beyond pinned corpus.
- Impact: medium.
- Status: accepted-risk.
- Default: ship with pinned official vectors first; add cross-language replay in hardening cycle if
  gap evidence appears.
- Mitigation: keep deterministic fixtures and add replay scaffold in Phase F kickoff checklist.
- Reversal Trigger: observed divergence against parity references in integration testing.
- Owner: Phase F owner.

`UT-E-004`
- Topic: differential hardening depth for the selected secp256k1/BIP340 boundary beyond I1 baseline.
- Impact: medium.
- Status: accepted-risk.
- Default: enforce I1 baseline acceptance criteria, then expand differential corpus only when parity or
  integration evidence shows remaining risk.
- Mitigation: keep required I1 acceptance criteria mandatory and schedule extra corpus depth in I7 when
  drift indicators appear.
- Reversal Trigger: observed divergence against pinned references or repeated boundary regressions.
- Owner: Phase I owner.

## Open Questions

- `OQ-E-001`: determine Phase F target threshold for optional vector expansion candidates
  (`nip77_negentropy`, `nip45_count`) based on first implementation corpus outcomes.
- `OQ-E-002`: decide final compatibility namespace placement in implementation kickoff without
  changing strict-default behavior.
- `OQ-E-003`: decide whether to promote NIP-44 cross-language differential replay from optional to
  required CI gate before first release candidate.
- `OQ-E-004`: what additional differential hardening depth beyond I1 baseline should become mandatory
  before first release candidate.
- `OQ-E-005`: resolved post-Phase E by `D-030`; H-phase NIP-06 planning now assumes
  `libwally-core` behind the approved pinned crypto backend policy and a narrow boundary module.
- `OQ-E-006`: complete LLM-first usability evaluation closure criteria in
  `docs/plans/llm-usability-pass.md` before release-candidate API freeze. Status: in-progress.
  This question is the gate for freezing Layer 2 compatibility adapter defaults under
  `docs/guides/NOZTR_STYLE.md`.

## Ambiguity Checkpoint

`A-E-001`
- Topic: optional vector-depth escalation timing.
- Impact: medium.
- Status: accepted-risk.
- Default: keep baseline optional gate in implementation start; escalate on parity evidence.
- Owner: Phase F owner.

`A-E-002`
- Topic: compatibility API file placement.
- Impact: low.
- Status: accepted-risk.
- Default: placement decision deferred to kickoff artifact; strict behavior frozen.
- Owner: Phase F owner.

`A-E-003`
- Topic: NIP-44 cross-language differential replay in CI.
- Impact: medium.
- Status: accepted-risk.
- Default: required pinned corpus now; differential replay conditional on integration evidence.
- Owner: Phase F owner.

Ambiguity checkpoint result: high-impact `decision-needed` count = 0.

## Definition Of Done For Implementation Handoff

- Implementation schedule accepted as executable with no architecture clarification blockers.
- Every v1 module from `docs/plans/v1-api-contracts.md` is mapped to one implementation phase.
- Parity-core gates explicitly include `nip11` completion and tests.
- Strict-vs-compat policy is consistent with `D-036` (deterministic-and-compatible Layer 1 posture,
  explicit compatibility where needed).
- Unresolved tradeoffs are recorded with status, mitigation, reversal trigger, and owner.
- Extension-lane placeholders remain documentation-only and do not add v1 module scope.
- No high-impact ambiguity remains `decision-needed`.

## Tradeoffs

## Tradeoff T-E-001: Front-load parity-core completion versus mixed core/optional sequencing

- Context: implementation can prioritize full parity-core closure first or interleave optional modules
  early for broader surface progress.
- Options:
  - O1: front-load parity-core and crypto core before optional lanes.
  - O2: interleave optional modules with core phases.
- Decision: O1.
- Benefits: earlier trust-boundary stability and lower risk of core contract drift.
- Costs: optional feature availability arrives later.
- Risks: perceived slower parity breadth.
- Mitigations: keep optional phases explicit and time-bounded with clear gates.
- Reversal Trigger: external integration requires optional module completion before core hardening.
- Principles Impacted: P01, P03, P05, P06.
- Scope Impacted: I1, I2, I3, I5 sequencing.

## Tradeoff T-E-002: Preserve optional vector baseline versus raising all optional modules now

- Context: optional modules currently use `3 valid + 3 invalid`; raising to core-level depth improves
  confidence but increases immediate delivery load.
- Options:
  - O1: keep baseline and escalate based on evidence.
  - O2: raise all optional modules to `5 valid + 5 invalid` immediately.
- Decision: O1.
- Benefits: predictable execution cadence and consistency with Phase D default.
- Costs: lower initial optional corpus depth.
- Risks: optional regressions may be detected later.
- Mitigations: enforce non-interference tests and targeted escalation triggers.
- Reversal Trigger: repeated optional parity defects.
- Principles Impacted: P03, P05, P06.
- Scope Impacted: I4, I6 optional modules.

## Tradeoff T-E-003: Freeze Layer 1 posture now versus defer policy reconciliation

- Context: prior artifacts contained stale and overly blunt strict-vs-compat wording in build
  sequencing text.
- Options:
  - O1: freeze policy now to `D-036` and remove contradiction.
  - O2: defer strict/compat resolution into implementation phase.
- Decision: O1.
- Benefits: prevents default-behavior drift and makes it explicit that correctness and ecosystem
  compatibility matter together.
- Costs: more judgment is required when deciding whether a narrower rule is justified.
- Risks: reviewers could still over-apply the old "strict is better" shorthand.
- Mitigations: explicit compatibility entry points remain available and test-backed, and the
  implemented-NIP review criteria matrix is canonical.
- Reversal Trigger: frozen default update accepted in decision log.
- Principles Impacted: P01, P03, P05.
- Scope Impacted: all parser/validator module boundaries.

## Principles Compliance

- Required sections present: `Decisions`, `Tradeoffs`, `Open Questions`, `Principles Compliance`.
- `P01`: trust-boundary modules and crypto sequencing are front-loaded with explicit rejection gates.
- `P02`: module schedule remains protocol-kernel focused; extension-lane placeholders stay docs-only.
- `P03`: schedule and vector gates target behavior parity, not API shape mimicry.
- `P04`: relay/auth/protected behavior remains explicit in dedicated module phases.
- `P05`: deterministic behavior and staged-check ordering are phase-gated.
- `P06`: bounded memory/work and caller-buffer contracts remain mandatory in every phase.
