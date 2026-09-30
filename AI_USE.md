# AI Use

I used Claude (Anthropic), in an agentic coding session with shell/file access, throughout this exercise, as explicitly permitted by the brief. Concretely:

- **Data profiling.** I had it write and run one-off Python/DuckDB snippets against the raw CSVs to inventory column values, formats, and anomalies (country spelling variants, currency aliases, ID formats, duplicate keys, timestamp offset mixes, thousands-separator inconsistencies) before designing any rule. Every issue in `DATA_QUALITY.md` was found this way, not assumed.
- **Pipeline code.** It wrote the dbt models, the `contracts/source_schemas.yml` contract, `scripts/dq1_preflight.py`, `scripts/dq4_publish_gate.py`, `scripts/run_pipeline.sh`, the seed, macros, and the test suite, iterating against real `dbt run`/`dbt test` output rather than writing it blind , e.g. the thousands-separator bug in `parse_number` was caught and fixed because a test run showed loans being wrongly quarantined, not by inspection alone.
- **Root-cause investigation.** For the A3 repayments reconciliation failures, it ran additional experiments (UTC vs. `Africa/Nairobi` timestamp bucketing) to test a hypothesis before writing it up, rather than asserting a cause without checking it.
- **Documentation drafting.** `DECISIONS.md`, `DATA_QUALITY.md`, `OPERATIONS.md`, and this file were drafted by it from the actual pipeline output (row counts, test results, DQ logs), which I then reviewed.

Every design decision , the matching tiers, the reconciliation tolerance, the FX rate choice, what not to build, the inbox answer , is mine; I directed each one and can defend and modify any part of this live, including rewriting a model or changing a rule on the spot.
