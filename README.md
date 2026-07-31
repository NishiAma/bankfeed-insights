# Bankfeed Insights — Valiant Senior Backend Engineer Technical Test

## Contents

- [`docs/overview.md`](docs/overview.md): a single end-to-end sequence
  diagram tying the two workflow docs below together — start here.
- [`docs/illion-integration-flow.md`](docs/illion-integration-flow.md): authentication and the linking/request-response workflow with illion
  (institution selection, credentials, MFA, async retrieval, polling
  fallback).
- [`docs/data-processing-and-storing.md`](docs/data-processing-and-storing.md): what happens once illion's webhook lands — verification,
  normalisation, idempotent storage, failure handling, security, and how
  results become available to the rest of the system.
- [`docs/schema.md`](docs/schema.md): the data models/schema
  (`User`, `BankConnection`, `Account`, `Transaction`, `StatementMetrics`,
  ...) and their relationships.
- [`bin/bank_analysis.rb`](bin/bank_analysis.rb): entry point that
  loads the sample statement data and prints the report.
- [`lib/bankfeed_insights/`](lib/bankfeed_insights) — the actual
  implementation, one file per concern:
  - `transaction.rb`, `account.rb` — domain model `Struct`s.
  - `statement_loader.rb` — parses illion's raw JSON into `Account`/
    `Transaction` objects.
  - `keywords.rb` — gambling and short-term lender keyword dictionaries.
  - `calculators/average_monthly_income.rb`,
    `calculators/gambling_expenditure.rb`,
    `calculators/short_term_lender_exposure.rb` — the three calculations,
    one module each.
  - `report.rb` — formats and prints the results.
- [`spec/`](spec) — RSpec specs, mirroring the `lib/` structure 1:1.
- [`data/sample_bank_statements.json`](data/sample_bank_statements.json) —
  the provided sample payload, decoded/pretty-printed from the file supplied
  with the test.

## Running the script

```
bundle install
ruby bin/bank_analysis.rb
```

Defaults to `data/sample_bank_statements.json`; optionally pass a different
path as the first argument.

## Running the specs

```
bundle exec rspec
```

## Calculations implemented

1. **Average monthly income (deposits/credits) per account** — Account
   Aggregation.
2. **Gambling expenditure as a % of total expenditure**, across all linked
   accounts — Risk & Expenditure. Transactions are classified from
   description text via our own keyword list rather than the provider's
   pre-supplied `tags`.
3. **Short-term/payday lender exposure** (own addition, not in the example
   list) — count, total repaid, and distinct lenders identified (e.g.
   Ferratum, MoneyMe, Sunshine Loans, G2G Loans). This is a strong
   real-world signal for a lending risk engine and is well represented in
   the sample data.

**Note on the raw payload:** each account's `statementData` also carries
illion's own pre-computed `analysis` (categorised + per-payee breakdowns,
including a far larger lender/gambling-operator taxonomy than the keyword
list here) and `dayEndBalances`/`minDayEndBalance`/`maxDayEndBalance`
(so "highest/lowest daily closing balance" needs no calculation at all —
it's already a field). The calculators here deliberately re-derive
classification from transaction text instead of reading `analysis`
directly, as a decoupling exercise consistent with normalising into our
own schema rather than trusting a specific provider's shape long-term. In
practice, the stronger design is a hybrid: prefer illion's `analysis`/
`tags` where present (broader, provider-maintained coverage — note even
illion falls back to an untagged `Loans.Generic` bucket), and use
keyword matching only to fill gaps it leaves.

