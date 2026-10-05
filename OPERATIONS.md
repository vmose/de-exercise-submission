# Operations

## Nightly run

`bash scripts/run_pipeline.sh`, scheduled once nightly after CBS's end-of-day extract lands: DQ1 (per-file gate) → `dbt seed` → `dbt build` (raw → staging/DQ2 → identity resolution/DQ3 → reconciliation/A3 → marts, plus B3 tests) → DQ4 (publish gate) → refresh DQ log views. Exit code is DQ4's: 0 = published, 1 = blocked (last good outputs kept). A scheduler should alert on non-zero, not just non-completion , a **blocked** run is a successful, safe run that still needs a person.

## Alerts, and who acts on them

| Alert | Trigger | Who |
|---|---|---|
| File rejected at DQ1 | Any row in `dq_logs/dq1_results.csv` for this run has `status=FAIL` | Data engineer on call , usually a source contract needs reviewing, not an emergency fix |
| Pipeline blocked at DQ4 | Exit code 1 | Data engineer on call, same night; donor/lending-manager-facing reports are late but never wrong |
| Reconciliation drift trending, not just failing | A country/month that passed last run fails this run, or a fail's magnitude grows run over run | Data engineer, next business day , early signal of a slow-building extract or upstream process problem |
| Quarantine volume spikes | DQ2 quarantined count for any source jumps materially vs. its trailing average | Data engineer + source-system owner , usually means an upstream form/process changed |
| Review queue / DQ3 conflicts growing unreviewed | `int_review_queue` or `dq3_identity_conflicts` row count climbs without anyone clearing it | Advisory/banking ops lead , a people-process gap, not a pipeline one |

## Freshness and reliability targets (proposed)

- **Freshness:** validated outputs available by 06:00 local time, for a source file landing by 02:00 , generous given current data volumes (thousands of rows, seconds of runtime).
- **Reliability:** at least 99% of scheduled nightly runs complete (publish or block cleanly) without manual intervention over a rolling 30 days; a run that crashes outright (vs. blocking cleanly at DQ4) is an incident, since blocking is expected behavior but crashing is not.
- **Reconciliation:** loans within tolerance every run (currently 35/35); repayments trending toward 100% as the two diagnosed root causes (schema-drift rejection, timestamp timezone ambiguity) are resolved. Not a hard gate today, since donor reporting already correctly withholds on failure.

## When reconciliation fails

1. DQ4 already kept last-good outputs , no bad number reaches anyone. No emergency action needed overnight.
2. Next business day, the on-call engineer reads `DATA_QUALITY.md` / `dq_logs/dq4_results.csv` for the failing rows and known causes.
3. If the cause is already diagnosed (as with issues #17/#18 in `DATA_QUALITY.md`), confirm it's still the same shape of problem, not a new one, and log that decision.
4. If new, drill into `int_reconciliation` for the specific country/month/currency, and back to `stg_cbs_repayments_quarantine` / `stg_cbs_loans_quarantine` for anything dropped that quarter should have counted.
5. Fix at the diagnosed layer (contract review for a schema issue, a staging normalization rule for a parsing issue, escalate to the source-system owner for anything upstream) and re-run. Never manually edit a mart to force a pass.

## When to add something this exercise doesn't need

- **A columnar store / warehouse (Snowflake/BigQuery etc.), replacing DuckDB:** when a single nightly run stops finishing inside the freshness window, or the working set stops fitting comfortably in memory on one machine , call it low tens of millions of rows on current hardware. Today: thousands of rows, sub-second per model. Not close.
- **Streaming ingestion:** when a business need for intraday (not nightly) client or loan visibility is explicitly stated and justifies the added operational complexity of a real-time pipeline , not because streaming is more modern. No such need has been stated.
- **A dedicated orchestrator (Airflow/Dagster) over cron + this script:** once there is more than one pipeline, cross-pipeline dependencies, or a need for per-task retry/backfill UI beyond "re-run the script." One pipeline, one schedule, doesn't need it yet.
- **Probabilistic/fuzzy identity matching:** once a manually labelled validation sample shows the current deterministic tiers are leaving a materially costly number of true matches unmatched , see `DECISIONS.md`.
