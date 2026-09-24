# Data Engineering Exercise

## Context

Inkomoko provides finance and business development services to refugee and host-community entrepreneurs in Kenya, Rwanda, Ethiopia, South Sudan and Chad. Client data lives in systems that were never designed to agree with each other. An advisory system records the people we support. A core banking system records their loans and repayments. Neither shares a client key with the other, and the same person can appear more than once, under a different identifier, after moving between locations.

## What to expect

1. You work on this exercise in a private copy of this repository, in your own GitHub account. The steps are under How to work and submit.
2. You submit by the deadline stated in the message that sent you here. Late submissions are not scored.
3. Two reviewers score every submission independently and in the same way.
4. Candidates whose submission clears review are invited to a follow-up session of about 75 minutes: a walkthrough of your submission, one live change, one debugging exercise and a design conversation.
5. People and Culture tells every candidate the outcome.

Plan for the time stated in the message that sent you here, and stop when it runs out. If you run out of time, write down what you would do next and how. We score that as seriously as finished work. We do not score volume, extra tooling or visual polish.

## Setup

You need Python 3.11 or later and a few hundred megabytes of disk. No Docker, cloud account or paid tool is required.

```
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt  # dbt Core with DuckDB
```

The reference tooling is dbt Core on DuckDB. You may use another engine or language if a reviewer can run your work from a clean clone using the steps in your README section.

## The sources

Everything is in `source/`. Every candidate works with the same data set.

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

## How to work and submit

This repository is public. Your work must not be. Do not fork this repository: a fork of a public repository is public, and other candidates could see your work.

1. In your own GitHub account, create a new **private** repository named `de-exercise-submission`. Leave it empty: no README, licence or `.gitignore`.
2. Copy this repository into it:

   ```
   git clone https://github.com/AmosBunde/de-exercise-template.git de-exercise-submission
   cd de-exercise-submission
   git remote set-url origin https://github.com/<your-username>/de-exercise-submission.git
   git push -u origin main
   ```

3. Work and push to `main` as you normally would. We do not score commit history.
4. Before the deadline, open **Settings**, then **Collaborators**, in your repository and add `AmosBunde` as a collaborator.
5. Before the deadline, send the link to your repository to People and Culture, replying to the message that sent you here.

At the deadline we take a copy of your repository and score the last commit on `main` at that moment. Pushes after the deadline are not scored. Keep your repository private until the recruitment closes.

If you are invited to the follow-up session, we will give you one more data file to work with during it.

## Working alone

Do the exercise on your own. You may use public documentation and AI tools, as described below. Do not discuss the exercise or share your work with anyone else until the recruitment closes. Send any question to People and Culture; we answer every candidate with the same information.

## AI tools

You may use AI assistants. Tell us how in `AI_USE.md`. In the follow-up session you will walk us through your submission and change it live, so be ready to explain and defend every part of it, including anything a tool wrote.

The follow-up session covers a walkthrough of your submission, one live change, one debugging exercise and a design conversation. You may use AI tools during it, with your screen shared. If you need an adjustment to the time box or the session format, ask People and Culture; adjustments do not affect scoring.

## Your data

Your submission is used only for this recruitment. Your work will not be used in any Inkomoko system. Once the recruitment closes you may delete your repository. We delete our copy in line with Inkomoko's retention policy for candidate records.
