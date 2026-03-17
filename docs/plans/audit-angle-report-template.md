---
title: Audit Angle Report Template
doc_type: reference
status: active
owner: noztr
read_when:
  - writing_audit_angle_reports
  - checking_audit_completeness
depends_on:
  - docs/plans/exhaustive-pre-freeze-audit.md
  - docs/plans/exhaustive-pre-freeze-audit-matrix.md
canonical: true
---

# Audit Angle Report Template

Use this template for each dedicated `no-ard` audit angle report.

## Required Header

- angle name
- date
- issue / packet ID
- author

## Required Sections

### Purpose

- what this angle is trying to prove or falsify
- what it does not cover

### Scope

- exact files, modules, or NIP groups reviewed
- explicit exclusions

### Standards

- exact standards or heuristics used
- why they are the right bar for this angle

### Evidence Sources

- local code
- tests
- docs
- external comparison libraries or references
- whether evidence is primary, secondary, or weak

### Coverage

- what was explicitly checked
- what was explicitly not checked
- matrix rows touched

### Findings

Use severity labels:
- `critical`
  - actively unsafe, invalidates audit evidence, or blocks all release confidence
- `high`
  - serious trust-boundary, correctness, or architecture issue that strongly pressures redesign
- `medium`
  - real defect or inconsistency, but not by itself decisive on rewrite
- `low`
  - worthwhile cleanup or clarity improvement

Each finding must include:
- title
- severity
- exact scope
- why it matters
- evidence
- whether it suggests:
  - targeted fix
  - bounded redesign
  - major rewrite pressure

### Accepted Exceptions

For each accepted exception:
- scope
- rationale
- risk
- reversal trigger

### Residual Risk

- what still worries this angle after review
- what remains unknown

### Suggested Remediation Candidates

- list only
- no code changes from the report by default
- classify each candidate as:
  - targeted fix
  - bounded redesign
  - major rewrite pressure

### Completion Statement

- why this angle is complete
- what evidence would require reopening it

## Report Rules

- do not claim whole-library coverage unless the matrix actually supports it
- distinguish fresh evidence from reused prior evidence
- if prior evidence is partial, say so
- if an area is not checked, name it explicitly
- do not blur findings with remediation execution
- do not propose immediate fixes from the angle report; route all remediation pressure to the later
  meta-analysis
