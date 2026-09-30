#!/usr/bin/env python3
"""
DQ4 — before publication, before B1 and B2 are refreshed.

Runs `dbt test` (which includes the A3 reconciliation check as
tests/assert_reconciliation_within_tolerance.sql, plus every other B3 test).
Only if every test passes does this copy the current fct_loans and
rpt_country_month_summary tables into the `published` schema — the schema a
downstream consumer (or the donor export) should always read from.

If any test fails, `published` is left exactly as it was after the last
successful run (or empty, if there has never been one) and the reason is
logged, rather than a partially-broken or unreconciled refresh going out.

Usage:
    python scripts/dq4_publish_gate.py
Exit code: 0 if published, 1 if blocked (this is a meaningful signal for a
nightly scheduler to alert on — see OPERATIONS.md).
"""
import datetime as dt
import json
import os
import subprocess
import sys

import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(ROOT, "inkomoko.duckdb")
LOG_DIR = os.path.join(ROOT, "dq_logs")
LOG_PATH = os.path.join(LOG_DIR, "dq4_results.csv")
RUN_RESULTS_PATH = os.path.join(ROOT, "target", "run_results.json")

PUBLISHED_TABLES = {
    "main_marts.fct_loans": "published.fct_loans",
    "main_marts.rpt_country_month_summary": "published.rpt_country_month_summary",
}


def run_dbt_test():
    result = subprocess.run(
        ["dbt", "test", "--profiles-dir", ROOT, "--project-dir", ROOT],
        capture_output=True, text=True,
    )
    print(result.stdout[-4000:])
    if result.returncode != 0:
        print(result.stderr[-2000:], file=sys.stderr)
    return result.returncode == 0


def failed_test_names():
    if not os.path.exists(RUN_RESULTS_PATH):
        return ["unknown (run_results.json not found)"]
    with open(RUN_RESULTS_PATH) as fh:
        results = json.load(fh)["results"]
    return [r["unique_id"].split(".")[-1] for r in results if r["status"] not in ("pass", "success")]


def publish(con):
    con.execute("create schema if not exists published")
    for src, dest in PUBLISHED_TABLES.items():
        con.execute(f"create or replace table {dest} as select *, current_timestamp as _published_at from {src}")


def append_log(row):
    os.makedirs(LOG_DIR, exist_ok=True)
    fields = ["run_at", "status", "reason"]
    file_exists = os.path.exists(LOG_PATH)
    import csv
    with open(LOG_PATH, "a", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        if not file_exists:
            writer.writeheader()
        writer.writerow(row)


def main():
    run_at = dt.datetime.now(dt.timezone.utc).isoformat()
    all_pass = run_dbt_test()

    con = duckdb.connect(DB_PATH)
    try:
        if all_pass:
            publish(con)
            append_log({"run_at": run_at, "status": "PUBLISHED", "reason": "all B3 tests (incl. A3 reconciliation) passed"})
            print("\n[DQ4] PUBLISHED: fct_loans and rpt_country_month_summary refreshed in `published`.")
            return 0
        else:
            failed = failed_test_names()
            reason = "failed tests: " + ", ".join(failed) if failed else "one or more tests failed"
            append_log({"run_at": run_at, "status": "BLOCKED", "reason": reason})
            print(f"\n[DQ4] BLOCKED: {reason}")
            print("[DQ4] `published` left unchanged (last known-good outputs, or empty if there has never been a passing run).")
            return 1
    finally:
        con.close()


if __name__ == "__main__":
    sys.exit(main())
