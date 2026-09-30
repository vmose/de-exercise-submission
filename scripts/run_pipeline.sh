#!/usr/bin/env bash
# The one command that runs everything, from a clean clone:
#   bash scripts/run_pipeline.sh
#
# Order: DQ1 (file-level gate) -> dbt seed -> dbt build (raw -> staging/DQ2 ->
# identity resolution/DQ3 -> reconciliation -> marts -> B3 tests) -> DQ4
# (publish gate) -> refresh the DQ log views.
#
# Exit code is DQ4's: 0 if this run's outputs were published, 1 if DQ4 kept
# the last known-good outputs instead. Either way this script itself
# completes and leaves a full set of DQ records behind — a blocked
# publication is an expected, handled outcome, not a broken pipeline.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "=================================================================="
echo "DQ1 — validating source files on arrival"
echo "=================================================================="
python3 scripts/dq1_preflight.py

echo
echo "=================================================================="
echo "dbt seed — reference lookups (country_lookup)"
echo "=================================================================="
dbt seed --profiles-dir . --project-dir .

mkdir -p dq_logs

echo
echo "=================================================================="
echo "dbt build — raw -> staging (DQ2) -> identity resolution (DQ3) ->"
echo "reconciliation (A3) -> marts (B1/B2), plus B3 tests"
echo "=================================================================="
dbt build --profiles-dir . --project-dir . --exclude dq1_log dq4_log
BUILD_STATUS=$?
if [ $BUILD_STATUS -ne 0 ]; then
    echo "(one or more B3 tests failed above — expected/handled by DQ4 below, not aborting)"
fi

echo
echo "=================================================================="
echo "DQ4 — publish gate"
echo "=================================================================="
python3 scripts/dq4_publish_gate.py
DQ4_STATUS=$?

echo
echo "=================================================================="
echo "Refreshing DQ log views"
echo "=================================================================="
dbt run --profiles-dir . --project-dir . --select dq1_log dq4_log

echo
echo "Done. DQ1 log: dq_logs/dq1_results.csv | DQ4 log: dq_logs/dq4_results.csv"
echo "Database: inkomoko.duckdb (schemas: main_raw, main_staging, main_intermediate, main_marts, main_quality, published)"
exit $DQ4_STATUS
