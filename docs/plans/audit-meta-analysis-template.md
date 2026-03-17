---
title: Audit Meta-Analysis Template
doc_type: reference
status: active
owner: noztr
read_when:
  - synthesizing_completed_audit_angles
  - deciding_remediation_posture
depends_on:
  - docs/plans/exhaustive-pre-freeze-audit.md
  - docs/plans/exhaustive-pre-freeze-audit-matrix.md
  - docs/plans/audit-angle-report-template.md
canonical: true
---

# Audit Meta-Analysis Template

Use this after the required `no-ard` angle reports are complete.

## Inputs

- completed angle reports
- finalized matrix state
- exhaustive audit draft ledger

## Required Questions

1. What issue patterns recur across multiple angles?
2. Which findings are isolated versus systemic?
3. Do the findings mainly argue for:
   - targeted fixes
   - bounded redesign
   - major rewrite
4. Which accepted exceptions still look defensible after the full audit?
5. Which areas remain too uncertain for a freeze claim?

## Required Sections

### Cross-Angle Patterns

- repeated bug classes
- repeated ownership problems
- repeated API-consistency problems
- repeated performance or memory problems

### Rewrite Pressure Assessment

- `low`
  - findings are mostly isolated and locally remediable
- `medium`
  - one or two surface families likely need redesign
- `high`
  - problems cluster around shared architecture or public ownership shape

### Remediation Posture Decision

- choose exactly one starting posture:
  - targeted fixes
  - bounded redesign
  - major rewrite

### Rationale

- why that posture is the best match for the evidence
- why the alternatives are not the right first move

### Freeze Readiness

- can the repo proceed toward RC-freeze?
- if not, what explicitly blocks it?

### Next Lanes

- list the exact remediation or freeze-prep lanes to open

## Decision Rule

Do not choose “targeted fixes” merely because the local fixes look easy.

Choose the posture that best matches the pattern across reports, not the cheapest immediate patch
set.
