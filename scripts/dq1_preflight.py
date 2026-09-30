#!/usr/bin/env python3
"""
DQ1 — on arrival, before a file is loaded.

For every source declared in contracts/source_schemas.yml:
  1. Confirm the file's header matches the declared, versioned column list.
  2. Confirm every column in the header is classified in classification.yaml.
  3. Record the row count.
  4. Stop the load of that file if (1) or (2) fails: no bytes from a failed
     file are copied into validated/, so dbt never sees it. The last
     validated copy (if any) is left in place, so downstream layers keep
     running on last-good data.

On success, the file is copied into validated/ with any `excluded`-classified
columns dropped (Rule 2: excluded columns must never reach any layer, raw
included) — validated/ is what the raw dbt models read from, never source/
directly, so a failed or excluded column physically cannot flow downstream.

Every check, pass or fail, is appended to dq_logs/dq1_results.csv, which a
dbt source turns into a queryable table for reviewers.

Usage:
    python scripts/dq1_preflight.py
Exit code is always 0: DQ1 failing a *file* is an expected, handled outcome,
not a script crash. The pipeline continues with whatever passed.
"""
import csv
import datetime as dt
import glob
import os
import sys

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE_DIR = os.path.join(ROOT, "source")
VALIDATED_DIR = os.path.join(ROOT, "validated")
LOG_DIR = os.path.join(ROOT, "dq_logs")
CONTRACT_PATH = os.path.join(ROOT, "contracts", "source_schemas.yml")
CLASSIFICATION_PATH = os.path.join(SOURCE_DIR, "classification.yaml")
LOG_PATH = os.path.join(LOG_DIR, "dq1_results.csv")

LOG_FIELDS = [
    "checked_at", "source", "file", "contract_version", "status",
    "row_count", "columns_dropped_excluded", "reason",
]


def read_header(path):
    with open(path, "r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.reader(fh)
        header = next(reader)
        row_count = sum(1 for _ in reader)
    return [h.strip() for h in header], row_count


def load_contract():
    with open(CONTRACT_PATH) as fh:
        return yaml.safe_load(fh)["sources"]


def load_classification():
    with open(CLASSIFICATION_PATH) as fh:
        return yaml.safe_load(fh)["files"]


def classification_key_for(match_pattern):
    """classification.yaml keys files literally, including the '*' glob for
    the repayments family; everything else matches the contract's match
    pattern verbatim."""
    return match_pattern


def check_file(source_name, contract, classification_map, file_path):
    fname = os.path.basename(file_path)
    expected_cols = contract["columns"]
    version = contract["version"]

    class_key = classification_key_for(contract["match"])
    classified_cols = classification_map.get(class_key)
    if classified_cols is None:
        return {
            "status": "FAIL", "row_count": None, "columns_dropped_excluded": 0,
            "reason": f"no classification entry found for '{class_key}' in classification.yaml",
        }, None

    try:
        header, row_count = read_header(file_path)
    except Exception as exc:  # unreadable file is itself a DQ1 failure
        return {
            "status": "FAIL", "row_count": None, "columns_dropped_excluded": 0,
            "reason": f"could not read file: {exc}",
        }, None

    missing = [c for c in expected_cols if c not in header]
    extra = [c for c in header if c not in expected_cols]
    if missing or extra:
        reason_bits = []
        if missing:
            reason_bits.append(f"missing columns {missing}")
        if extra:
            reason_bits.append(f"unexpected columns {extra}")
        return {
            "status": "FAIL", "row_count": row_count, "columns_dropped_excluded": 0,
            "reason": f"header does not match contract v{version}: " + "; ".join(reason_bits),
        }, None

    unclassified = [c for c in header if c not in classified_cols]
    if unclassified:
        return {
            "status": "FAIL", "row_count": row_count, "columns_dropped_excluded": 0,
            "reason": f"columns not classified in classification.yaml: {unclassified}",
        }, None

    excluded_cols = [c for c, cls in classified_cols.items() if cls == "excluded" and c in header]
    keep_cols = [c for c in header if c not in excluded_cols]

    return {
        "status": "PASS", "row_count": row_count,
        "columns_dropped_excluded": len(excluded_cols), "reason": "",
    }, keep_cols


def write_validated_copy(file_path, keep_cols, dest_path):
    with open(file_path, "r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        rows = [{k: row[k] for k in keep_cols} for row in reader]
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    with open(dest_path, "w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=keep_cols)
        writer.writeheader()
        writer.writerows(rows)


def append_log(rows):
    os.makedirs(LOG_DIR, exist_ok=True)
    file_exists = os.path.exists(LOG_PATH)
    with open(LOG_PATH, "a", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=LOG_FIELDS)
        if not file_exists:
            writer.writeheader()
        writer.writerows(rows)


def main():
    contracts = load_contract()
    classification = load_classification()
    checked_at = dt.datetime.now(dt.timezone.utc).isoformat()
    log_rows = []
    any_fail = False

    for source_name, contract in contracts.items():
        pattern = os.path.join(SOURCE_DIR, contract["match"])
        matches = sorted(glob.glob(pattern))
        if not matches:
            log_rows.append({
                "checked_at": checked_at, "source": source_name, "file": contract["match"],
                "contract_version": contract["version"], "status": "FAIL",
                "row_count": "", "columns_dropped_excluded": 0,
                "reason": "no file found matching this source's pattern",
            })
            any_fail = True
            continue

        for file_path in matches:
            fname = os.path.basename(file_path)
            result, keep_cols = check_file(source_name, contract, classification, file_path)
            log_rows.append({
                "checked_at": checked_at, "source": source_name, "file": fname,
                "contract_version": contract["version"], **result,
            })
            if result["status"] == "PASS":
                if len(matches) > 1:
                    # multi-file sources (repayments) land as one file per
                    # daily extract; the raw model merges them by key.
                    dest = os.path.join(VALIDATED_DIR, source_name, fname)
                else:
                    dest = os.path.join(VALIDATED_DIR, f"{source_name}.csv")
                write_validated_copy(file_path, keep_cols, dest)
                print(f"[DQ1 PASS] {source_name}/{fname}: {result['row_count']} rows, "
                      f"{result['columns_dropped_excluded']} excluded column(s) dropped -> {dest}")
            else:
                any_fail = True
                print(f"[DQ1 FAIL] {source_name}/{fname}: {result['reason']} "
                      f"— load stopped, last validated copy (if any) retained.")

    append_log(log_rows)
    print(f"\nDQ1 log written to {os.path.relpath(LOG_PATH, ROOT)}")
    if any_fail:
        print("DQ1: one or more files failed and were not loaded. See log above / dq1_results.csv.")
    return 0  # a failed file is a handled outcome, not a script error


if __name__ == "__main__":
    sys.exit(main())
