# Data Quality

## Issue list

| # | Issue | Source / column | Records affected | Handling | Fix at source |
|---|---|---|---|---|---|
| 1 | Repayment extract shape changed without notice: `amount` renamed to `amount_paid`, new `agent_code` column added | `cbs_repayments_day2.csv` | 27 rows (the whole file) | **Quarantined at DQ1** (file never loaded to any layer); last good extract (day1) kept in service. See `contracts/source_schemas.yml` v1 and C1 in the README. | CBS/extract owner: any column rename or addition must go through a reviewed contract bump before the next nightly run, not be discovered by a failed load |
| 2 | Country recorded as free text with 17 spelling/case/language variants of 5 countries (`Tchad`, `TCD`, `td`, `S. Sudan`, `Kenya ` w/ trailing space, `ethiopia`, ...) | `ims_clients.csv` / `country` | all 1,448 rows use one of these forms | **Corrected**: normalized to ISO2 via `seeds/country_lookup.csv` | Advisory system: constrain `country` to a fixed dropdown/enum, not free text |
| 3 | `date_of_birth` missing | `ims_clients.csv` / `date_of_birth` | 72 rows | **Quarantined** (DOB is required — used for identity matching and the minor safeguarding flag) | Advisory system: make DOB a required field at data entry |
| 4 | `date_of_birth` present but unparseable (neither `YYYY-MM-DD` nor `DD/MM/YYYY`, e.g. bare year only) | `ims_clients.csv` / `date_of_birth` | 29 rows | **Quarantined** | Advisory system: enforce one date format at entry, ideally a date picker not free text |
| 5 | Exact duplicate `ims_client_id` (same key re-submitted, e.g. after a form re-sync) | `ims_clients.csv` / `ims_client_id` | 41 rows (kept the most recently updated of each pair) | **Corrected** (deduped, most-recent kept); duplicates logged | Advisory system: idempotent upsert on export/sync instead of appending |
| 6 | `sex` recorded inconsistently: `male`/`m`/`Male`, and some rows hold bare codes `1`/`2` or are blank | `ims_clients.csv` / `sex` | 141 rows (44 blank, 36 `m`, 23 `f`, 20 `2`, 18 `1`) not cleanly mappable to male/female | **Corrected to `unknown`** rather than quarantined — `sex` isn't used in identity matching or any mart in this exercise, so failing a whole record over it would be disproportionate | Advisory system: fix the `1`/`2` numeric-code leak (likely an unmapped select-list export) and stop allowing blank |
| 7 | Numeric fields use inconsistent thousands separators: comma (`"11,360.00"`), space (`"1 175 000"`), or none | `cbs_loans.principal`, `cbs_repayments.amount`, `cbs_control_totals.*_amount` | initially misclassified ~7 loans + 1 repayment as unparseable until the parser was fixed to strip both | **Corrected** (parser now strips both `,` and space before casting) | CBS export: emit a single consistent numeric format (plain, no thousands separator) |
| 8 | `principal` missing/blank after all parsing | `cbs_loans.csv` / `principal` | 0 after fix (was mis-flagged before fix; see #7) | n/a | n/a |
| 9 | Duplicate `loan_id` | `cbs_loans.csv` / `loan_id` | 1 row | **Quarantined** (duplicate copy) | CBS export: enforce PK uniqueness at export |
| 10 | Repayment `amount` unparseable after normalization (non-numeric residue) | `cbs_repayments_day1.csv` / `amount` | 1 row | **Quarantined** | CBS: validate amount field before extract |
| 11 | Currency alias `KSH`/`Ksh` used alongside `KES` for the same currency | `cbs_loans.csv`, `cbs_repayments_*.csv`, `fx_rates.csv`, `cbs_control_totals.csv` | 15 loan rows, several fx/control rows | **Corrected** (aliased to `KES`) | All CBS-side systems: standardize on ISO 4217 codes only |
| 12 | Loan `status` casing/wording varies (`active`/`Active`/`ACTIVE`, `Closed`/`Closed (obligations met)`) | `cbs_loans.csv` / `status` | all 812 rows use one of these forms | **Corrected** (folded to `active`/`closed`) | CBS export: use a fixed enum |
| 13 | `cbs_fx_rate` / `principal_usd_cbs` missing for every KES-denominated loan | `cbs_loans.csv` | 156 rows (all KES loans) | **Accepted as unusable, not corrected**: B1 computes its own USD conversion from `fx_rates.csv` instead of relying on these columns for any currency, sidestepping the gap entirely | CBS core system: fix whatever excludes KES from its own FX conversion step |
| 14 | `fx_rates.units_per_usd` missing or non-positive | `fx_rates.csv` | 1 row | **Quarantined** | FX publisher: validate before publishing |
| 15 | Duplicate `(currency, rate_date, rate_type)` in FX rates | `fx_rates.csv` | 1 pair (kept latest `published_at`) | **Corrected** (deduped) | FX publisher: enforce uniqueness on that key |
| 16 | `rate_type` casing varies (`Official`/`official`) | `fx_rates.csv` | subset of 1,045 rows | **Corrected** (folded to lowercase) | FX publisher: fixed enum |
| 17 | `paid_at` timestamps mix UTC (`Z`) and local (`+02:00`/`+03:00`) offsets, and DuckDB's plain `TIMESTAMP` cast (used here) keeps the literal wall-clock digits rather than normalizing — so a transaction near a month boundary can land in a different calendar month depending on which offset it happened to be tagged with | `cbs_repayments_*.csv` / `paid_at` | small (2–8) transactions per month boundary; visible as ±1–6 count/amount differences in several country-months in A3 | **Flagged, not corrected**: I tested re-bucketing in UTC and in `Africa/Nairobi` and neither clearly outperformed the current (naive) bucketing against `cbs_control_totals`, so I did not pick one without being able to justify it — see `DECISIONS.md` | CBS/channel integrators: record `paid_at` in one consistent, declared timezone (or true UTC) across every channel |
| 18 | Repayment reconciliation fails for the most recent month in every country (all `2026-07`) | `cbs_repayments_day1.csv` vs `cbs_control_totals.csv` | 5 country-months | **Flagged, not corrected**: day1 is a mid-month extract cut on 2026-07-29/30, so July is structurally incomplete relative to a full-month control total; day2 (which reaches further into July) was rejected at DQ1 for the schema-drift reason above (#1) | Extract owner: fix #1 first — once a schema-compliant later extract is available, this should close on its own |
| 19 | 140 IMS clients are minors (age < 18 as of the pipeline's as-of date) | `ims_clients.csv` | 140 rows | **Flagged** as restricted personal data (`is_minor`), carried through to `fct_loans` as an internal safeguarding check only; excluded from the donor-facing `rpt_country_month_summary`; zero currently link to an active loan | Advisory system: no source fix needed, this is expected in the population — flag is a downstream control |
| 20 | 17 enterprise identities have linked records disagreeing on country or date of birth despite a confident (mostly ID-number) match | derived, `int_client_crosswalk` | 17 enterprise_client_ids | **Flagged for review** (DQ3), not auto-corrected — don't know which system is right | Whichever system is wrong: correct at entry once a person confirms which value is right |
| 21 | 150 candidate identity pairs share a phone number and country but don't meet the auto-merge bar | derived, `int_review_queue` | 150 pairs | **Flagged for review**, never auto-merged (see `DECISIONS.md`) | n/a — human judgment call, not a data defect necessarily |
| 22 | `fingerprint_template_ref` is classified `excluded` | `cbs_borrowers.csv` | 592 rows (1 column) | **Dropped before any layer** (DQ1), never loaded | n/a — working as designed; flagged here only to evidence the control fired |

## Latest DQ1 → DQ4 run output

Reproduced from `dq_logs/dq1_results.csv`, `main_quality.dq2_summary`, `main_intermediate.dq3_identity_summary` and `dq_logs/dq4_results.csv` after the most recent `bash scripts/run_pipeline.sh`.

### DQ1 — on arrival

| source | file | status | row_count | excluded cols dropped | reason |
|---|---|---|---|---|---|
| ims_clients | ims_clients.csv | PASS | 1,448 | 0 | |
| cbs_borrowers | cbs_borrowers.csv | PASS | 592 | 1 | |
| cbs_loans | cbs_loans.csv | PASS | 812 | 0 | |
| cbs_repayments | cbs_repayments_day1.csv | PASS | 2,488 | 0 | |
| cbs_repayments | cbs_repayments_day2.csv | **FAIL** | 27 | — | header does not match contract v1: missing `['amount']`; unexpected `['amount_paid', 'agent_code']` |
| fx_rates | fx_rates.csv | PASS | 1,045 | 0 | |
| cbs_control_totals | cbs_control_totals.csv | PASS | 35 | 0 | |
| investment_screening | investment_screening.csv | PASS | 110 | 0 | |

### DQ2 — per record (staging)

| source | raw | passed | quarantined | passed + quarantined = raw? |
|---|---|---|---|---|
| ims_clients | 1,448 | 1,337 | 111 | ✅ |
| cbs_borrowers | 592 | 592 | 0 | ✅ |
| cbs_loans | 812 | 811 | 1 | ✅ |
| cbs_repayments | 2,488 | 2,487 | 1 | ✅ |
| fx_rates | 1,045 | 1,043 | 2 | ✅ |
| cbs_control_totals | 35 | 35 | 0 | ✅ |

### DQ3 — after identity resolution

| Metric | Value |
|---|---|
| Total enterprise identities | 1,425 |
| Matched across both systems | 450 |
| Advisory-only, unmatched | 849 |
| Banking-only, unmatched | 126 |
| Matched via ID number (tier 1) | 1,129 |
| Matched via name+DOB+country (tier 2) | 296 |
| Enterprise IDs with a conflicting attribute | 17 |
| Review-queue pairs (not merged) | 150 |

### DQ4 — before publication

Most recent run: **BLOCKED**. `assert_reconciliation_within_tolerance` (A3) failed on 14 of 35 country/month/currency rows — all on the repayments side (loans reconcile 35/35). Root causes: issues #17 and #18 above. `published.fct_loans` and `published.rpt_country_month_summary` were left as they were before this run (currently: never yet published, since this is the case in every run so far with the data provided). Full history in `dq_logs/dq4_results.csv`.
