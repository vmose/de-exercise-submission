# Data Engineering Exercise

## Context

Inkomoko provides finance and business development services to refugee and host-community entrepreneurs in Kenya, Rwanda, Ethiopia, South Sudan and Chad. Client data lives in systems that were never designed to agree with each other. An advisory system records the people we support. A core banking system records their loans and repayments. Neither shares a client key with the other, and the same person can appear more than once, under a different identifier, after moving between locations.

Please stop at the time box. If you run out of time, write down what you would do next and how. We score that as seriously as finished work. We do not score volume, extra tooling or visual polish.

## Setup

You need Python 3.11 or later and a few hundred megabytes of disk. No Docker, cloud account or paid tool is required.

```
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt  # dbt Core with DuckDB
```

The reference tooling is dbt Core on DuckDB. You may use another engine or language if a reviewer can run your work from a clean clone using the steps in your README section.

## The sources

Everything is already in `source/`. Your data set is specific to you.

| File | What it holds |
|---|---|
| `ims_clients.csv` | Advisory system client records |
| `cbs_borrowers.csv` | Core banking borrower records |
| `cbs_loans.csv` | Loans |
| `cbs_repayments_day1.csv` | Repayment extract, first run |
| `cbs_repayments_day2.csv` | Repayment extract, the following day |
| `fx_rates.csv` | Exchange rates by currency, date and rate type |
| `cbs_control_totals.csv` | Totals published by the core banking system, by country and month |
| `investment_screening.csv` | A screening sheet shared by a partner team |
| `classification.yaml` | Classification of every source column |

## Rules that apply

1. Treat everything in `source/` as a production system you may read but never change. Your pipeline never writes to it, and never writes anything back to a source system.
2. Columns classified `excluded` in `classification.yaml` must never be loaded anywhere, including any raw layer.
3. Records about people under 18 are restricted personal data.
4. Assume the output of Part B2 will be shared with an external donor.

## Part A: load and resolve (all candidates)

**A1.** Load the sources into a raw layer. Loading must be repeatable: running the pipeline twice, or running day 1 and then day 2, must not create duplicates.

**A2.** Build a client identity crosswalk that assigns one enterprise client identifier to each real person and links their advisory and banking records. Explain your matching rules. Report how many records matched, how many did not, and which cases you would send to a person for review. Do not merge records you are not confident about.

**A3.** Reconcile your loan and repayment totals against `cbs_control_totals.csv` by country and month. Report each figure as pass or fail against a tolerance you choose and justify.

## Part B: model and report (all candidates)

**B1.** A loan-level mart: one row per loan, carrying the enterprise client identifier, country, and amounts in local currency and in USD. State which exchange rate you used and why.

**B2.** A country and month summary of lending, fit to share with the donor named in Rule 4.

**B3.** Tests that would stop a bad load from reaching B1 or B2.

## Part C: platform (all candidates)

**C1.** The day 2 repayment extract differs in shape from day 1. Make your pipeline detect this class of change and fail safely. Show how the expected shape of this source is declared, reviewed and versioned.

**C2.** Write `OPERATIONS.md`, one page at most, covering:

- how this pipeline would run nightly
- what you would alert on, and who would act on each alert
- the freshness and reliability targets you would propose
- the steps to follow when reconciliation fails
- the measured conditions under which you would add a component this exercise does not need, such as a columnar store or a streaming ingestion path

## Inbox (all candidates)

Answer in `DECISIONS.md`, in under 200 words:

> Message from a lending manager: "Once you have matched the clients, can you push the new client ID back into the core banking system every night so loan officers can see it?"

## What to submit

- Your code, with a README section giving the one command that runs everything from a clean clone.
- `DECISIONS.md`: your assumptions, matching rules, tolerances, what you chose not to do and why, and what you would do next. Two pages at most. English or French.
- `AI_USE.md`: which AI tools you used, if any, and for what.

## How to submit

This private repository was created for you alone. No other candidate can see it, and you cannot see theirs.

1. Accept the repository invitation from your email.
2. Work and push to `main` as you normally would. We do not score commit history.
3. At the deadline in your invitation your access ends, and we score the last commit on `main`. Keep the repository private and do not copy it elsewhere.

Before your follow-up session we will add a branch named `session-day3`. Do not merge it before the session.

## Working alone

Do the exercise on your own. You may use public documentation and AI tools, as described below. Do not discuss the exercise or share your work with anyone else until the recruitment closes. Send any question to People and Culture; we answer every candidate with the same information.

## AI tools

You may use AI assistants. Tell us how in `AI_USE.md`. In the follow-up session you will walk us through your submission and change it live, so be ready to explain and defend every part of it, including anything a tool wrote.

The follow-up session covers a walkthrough of your submission, one live change, one debugging exercise and a design conversation. You may use AI tools during it, with your screen shared. If you need an adjustment to the time box or the session format, ask People and Culture; adjustments do not affect scoring.

## Your data

This repository and your submission are used only for this recruitment. Your work will not be used in any Inkomoko system. Repositories are deleted after the recruitment closes, in line with Inkomoko's retention policy for candidate records.
