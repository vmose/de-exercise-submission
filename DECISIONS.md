# Decisions

## Assumptions

- Country is normalized to ISO2 (`ET`, `KE`, `RW`, `SS`, `TD`) everywhere. `ims_clients.csv` has 17 spelling/case/language variants of five countries (`Tchad`, `TCD`, `south sudan`, `Kenya ` with a trailing space, etc.); these are mapped via `seeds/country_lookup.csv`, our own maintained reference data, not a source system.
- `KSH`/`Ksh` is treated as an alias for `KES` throughout (loans, repayments, fx, control totals).
- Loan/repayment `status` and currency casing are folded to a canonical lowercase/uppercase form (`Active`/`ACTIVE`/`active` → `active`; `Closed (obligations met)` → `closed`).
- Numeric fields sometimes use `,` or a space as a thousands separator (`"1 175 000"`, `"11,360.00"`); both are stripped before casting. This was a real bug I found while building A3 — it silently turned valid principals into "unparseable" quarantines until fixed.
- `investment_screening.csv` is loaded into raw (so it's covered by DQ1/DQ2 like everything else) but not used anywhere downstream: no task requires it, it carries `sensitive`-classified screening decisions, and I have no declared purpose to justify propagating it further (data minimization). If a real use turns up, it should get its own explicit matching/consumption spec, not be joined in speculatively.
- The 75-minute follow-up brief says one more file will be introduced. Nothing here special-cases the current file names/dates beyond what `contracts/source_schemas.yml` declares, so a new day's file just needs to pass DQ1 against that contract.

## Matching rules (A2)

Two-tier, deterministic, **conservative by design** — I decided under-matching (leaving a real pair unmerged) is a safer failure mode than over-matching (merging two different people) for financial identity data, so both tiers require an exact match on a strong signal, nothing fuzzy is auto-merged:

1. **Tier 1 — ID number.** `ims_clients.id_document_number` = `cbs_borrowers.id_number`, after normalizing both (uppercase, strip everything but letters/digits, so `FAR-24-389531` = `far24389531` = `FAR 24 389531`). Government/refugee IDs are the strongest cross-system signal available. **1,129 of 1,425 enterprise identities** matched this way.
2. **Tier 2 — name + DOB + country.** Full name reduced to a sorted, lowercased, punctuation-stripped token set (so `"ABDI HAWA"` = `"Hawa Abdi"` = `"  hawa   abdi "`) combined with exact date-of-birth and country match. Weaker than an ID match (name coincidences are possible, if unlikely, in this population) so tracked separately in DQ3. **296 identities** matched this way.
3. **Unmatched.** No ID and no usable name+DOB+country (either missing on one side or found nowhere else). These become singleton enterprise identities: **849** advisory-only (clients not yet linked to a loan — expected, since not every IMS client has borrowed yet), **126** banking-only (a borrower with no matched advisory record — worth a person looking at; could be a genuine advisory-data gap or a match tier 1/2 missed on a formatting difference).
4. **Review queue, never auto-merged.** Records in different systems sharing a normalized phone number and country, but not merged by tier 1/2, are logged to `int_review_queue` (**150 pairs**) for a person to decide — a phone number can belong to a household, not one person, so it's a candidate, never grounds for a merge on its own.
5. Same-person-under-two-`ims_client_id`s (moved location) is handled by the same rule, not a special case: two IMS records sharing an ID or a name+DOB+country land under the same `enterprise_client_id` automatically.
6. **17 enterprise identities** have linked records that disagree on country or DOB despite being merged (almost always a tier-1 ID match where the two systems recorded a different DOB) — flagged by DQ3, not auto-corrected, since I don't know which system is right.

**What I chose not to do:** fuzzy/phonetic name matching (Jaro-Winkler, Soundex) or probabilistic record linkage (Fellegi-Sunter). Both would likely raise the match rate but need tuned thresholds I can't validate against ground truth in this exercise, and a wrong auto-merge on financial-identity data is a worse outcome than a manual review-queue item. Next step if this were real: score my tier-1/2 output against a small manually-labelled sample, then decide if fuzzy matching's expected lift is worth the false-merge risk.

## Reconciliation tolerance (A3)

±0.5% of the control-total figure (minimum 1 unit, so a control total of e.g. 3 doesn't demand exact-integer matching on counts). Chosen because: loan disbursement totals should tie out essentially exactly (both sides derive from the same disbursement event), so 0.5% is generous, not tight, for that figure; for repayments, a same-day-extract vs a point-in-time control total can legitimately differ by a transaction or two around a cutoff. Loans reconcile at 100% under this tolerance. **Repayments do not** — see `DATA_QUALITY.md` for the two diagnosed root causes (a truncated extract and a timestamp-timezone boundary effect) and why I left the tolerance as-is rather than loosening it until everything passed.

## FX rate choice (B1)

The `official` rate from `fx_rates.csv`, as of the loan's disbursement date (most recent official rate on or before `disbursed_at`), not CBS's own embedded `cbs_fx_rate`/`principal_usd_cbs` — those are **missing for every single KES-denominated loan** (156 loans), a bug in the source system that makes them unusable as a uniform basis. `parallel` rates and "latest known" rates were both rejected: the former isn't what official reporting should use, the latter would misstate the USD value of loans disbursed months before the rate changed.

## Restricted data (minors)

`is_minor` is computed from IMS date of birth (127 of 1,448 raw IMS records) and carried through the crosswalk into `fct_loans` as `borrower_linked_to_minor_record`, purely as an internal safeguarding flag — **zero loans currently link to a minor's record**, which is reassuring but the flag stays in place as a check going forward. This field is explicitly excluded from `rpt_country_month_summary` (the donor-facing mart), which carries no personal data of any kind, per Rule 4.

## What I chose not to do, and why

- No fuzzy matching (above).
- No attempt to force reconciliation to 100% by loosening tolerance or silently interpreting `paid_at` in a way that happens to match — I investigated two plausible timezone interpretations (UTC vs. Africa/Nairobi) and neither clearly outperformed the naive approach already in the model; forcing a fit I can't justify would hide a real data-quality question rather than answer it.
- No attempt to "fix" `investment_screening.csv` into the model — not used, see above.
- I did not build a full graph/union-find identity resolution (multi-hop transitive matching across >2 records via weaker signals); the match-key/blocking approach here handles the cases in this data set (mostly pairs, occasional same-person-under-two-IDs) without that complexity. Next step: if a person turns out to be in 3+ systems or the data grows, revisit with a proper connected-components implementation (a dbt Python model or a small graph library) rather than the key-based blocking used here.

## What I'd do next with more time

- Score the identity match against a manually labelled sample to validate the tier-2 (name+DOB+country) false-positive rate.
- Resolve the repayments reconciliation gap once `cbs_repayments_day2.csv`'s shape is reviewed and the contract is bumped (see `OPERATIONS.md`), then re-run A3 to see how much of the gap that closes versus how much is the timezone-boundary effect.
- Add a small manual-override table for the review queue and DQ3 conflicts, so a person's decision persists across pipeline runs instead of being re-surfaced every night.

## Inbox

> "Once you have matched the clients, can you push the new client ID back into the core banking system every night so loan officers can see it?"

Not as a nightly automated write. Two reasons. First, Rule 1: this pipeline reads from CBS but never writes to it — CBS is a live, regulated system, and writing from an analytics pipeline opens a second, uncontrolled path for corrupting production data (wrong schema assumptions, a bad run, a race with CBS's own transactions), with no compensating control on our side. Second, the match isn't 100% certain: 296 of 1,425 identities are matched on name+DOB+country rather than ID number, 17 have unresolved attribute conflicts, and 150 pairs sit in a review queue. Auto-writing an unreviewed match into a system loan officers act on risks showing them the wrong client's history.

Instead: expose the crosswalk (enterprise ID, source system, source ID, match tier) as a **read-only** view or a small daily export CBS's own integration layer can pull, gated to tier-1 (ID-number) matches plus any tier-2 match a person has confirmed. CBS's engineers control if/how it lands in their schema, under their change control. If loan officers need it sooner, a read-only lookup screen against that export is far lower-risk than a nightly write into CBS.
