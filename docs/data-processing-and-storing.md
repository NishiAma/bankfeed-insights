# Data processing and storing

- Illion sends a POST request with Bank statement data as a JSON payload to Valiant webhook.

- At the webhook endpoint, the request is verified: the `callbackUrl` we
  gave illion in the `POST /customer/data` call includes a single-use
  callback token (e.g. `/webhooks/illion/{callback_token}`). illion doesn't sign
  webhook payloads, so this token is our authentication — it's checked
  against a pending `BankConnection` and invalidated after the first
  successful use, so the URL can't be replayed. Once verified: save the
  raw payload **to blob storage (e.g. S3), not inline in the primary
  database** — a raw illion payload can run ~500KB per customer, and
  keeping it out of Postgres avoids bloating row-level backups/encryption
  costs for data most services never need to touch directly — respond
  with 200 OK, put the request in a queue.

- A Sidekiq worker dequeues the job — pulling the reference to the raw
  payload that was saved in the webhook step above (not re-fetching
  anything from illion, the full statement data already arrived in that
  POST) — then processes the raw payload:
  - **Normalise**: map illion's raw shape into our own schema, not just
    a straight dump of the payload — `statementData.details[]` becomes
    `Transaction` rows, string amounts (`"123.45"`) become decimals,
    `dd-mm-yyyy` dates become real dates, and illion's `tags` are kept
    alongside (not instead of) our own categorisation. This keeps
    everything downstream decoupled from illion's specific field names —
    if we add a second bank-data provider later, only this mapping step
    changes.
  - **Save**: persist the normalised `Account`/`Transaction` rows to the
    database — as an **upsert**, not a plain insert. illion can retry a
    webhook delivery, and a customer can re-link the same account later
    for a refresh, so each transaction gets a dedupe key (e.g. a hash of
    `account_id + date + amount + description`) and is upserted on that
    key. Without this, a retried webhook or a re-link would duplicate
    every transaction rather than leaving existing rows untouched.

### Failure handling

- If the worker throws (bad/unexpected payload shape, DB error, etc.), the
  job retries a handful of times with backoff (standard Sidekiq behaviour)
  before giving up.
- On final failure, the `BankConnection`'s status flips to `failed` with
  an error message — the application shouldn't be left silently stuck in
  "processing" forever. This should also surface to the Product Specialist
  (e.g. a flag on the application), since a failed statement pull blocks
  the loan assessment step.
- Partial failures are treated as full failures for a given account: we
  don't persist half-normalised transactions, since a loan assessment
  reading an incomplete statement is worse than one that visibly failed.

### Security

- The `encryptionKey` illion returns per customer (see
  `illion-integration-flow.md`) is envelope-encrypted at rest (e.g.
  KMS-wrapped), not stored as plain text — it's what lets us pull that
  customer's data again, and illion has said if it's lost they can't
  recover it for us.
- Account numbers and BSBs are masked before they're queryable by the rest
  of the app — only the last 4 digits are ever stored unmasked/rendered;
  the full values live only in the raw payload in blob storage, which is
  access-controlled separately from normal application data.
- The blob storage bucket and the `encryptionKey` column are both
  restricted to the ingestion worker — most services (front-end APIs, the
  loan assessment engine) only ever need the normalised `Account`/
  `Transaction` rows, never the raw payload or the provider credentials.

### Metrics & availability to the rest of the system

- Once `Account`/`Transaction` rows are saved, the same worker run (or a
  follow-up job) computes the calculations we care about (e.g. average
  monthly income, gambling % of expenditure, short-term lender exposure —
  see `script/bank_analysis.rb`) and stores them as `StatementMetrics`
  rows, not just leaving them as something re-computed on every read.
- `BankConnection.status` flips to `completed` and an event (e.g.
  `bank_statements.completed`) is published, so the front-end and the
  loan assessment engine (ProductIQ) can react rather than polling.
- Consumers read `StatementMetrics`, not raw transactions — this keeps the
  metric definitions versioned (`computation_version`), so the loan
  engine can pin to the logic it was tuned against even if we change how
  a metric is calculated later.
