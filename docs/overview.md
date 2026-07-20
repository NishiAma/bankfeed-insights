# Bank Statement Integration — Overview

A single end-to-end view of the flow described in
[`illion-integration-flow.md`](illion-integration-flow.md) (linking,
authentication, triggering retrieval) and
[`data-processing-and-storing.md`](data-processing-and-storing.md) (webhook
processing, storage, availability). For the underlying database schema, see
[`schema.md`](schema.md).

```mermaid
sequenceDiagram
    actor Customer
    participant Valiant
    participant Illion
    participant Webhook as Valiant Webhook
    participant Queue as Job Queue
    participant Worker as Sidekiq Worker
    participant Blob as Blob Storage
    participant DB as Database

    Customer->>Valiant: Click "Link your business bank feeds"
    Valiant->>Valiant: Create BankConnection (status: pending)
    Valiant->>Illion: GET /institutions
    Illion-->>Valiant: List of institutions
    Customer->>Valiant: Select institution + enter credentials
    Valiant->>Illion: POST /customer/create

    alt MFA required
        Illion-->>Valiant: additionalInformationNeeded + submitTo
        Valiant->>Customer: Show requested field(s)
        Customer->>Valiant: Submit answer
        Valiant->>Illion: POST submitTo
    end

    Illion-->>Valiant: customerId + encryptionKey
    Valiant->>Valiant: Write onto BankConnection
    Valiant->>Illion: POST /customer/accounts
    Illion-->>Valiant: List of accounts
    Customer->>Valiant: Select account(s) & submit
    Valiant->>Valiant: Generate callback_token, status -> processing
    Valiant->>Illion: POST /customer/data (async: true, callbackUrl)
    Illion-->>Valiant: Acknowledgement (not the data itself)
    Valiant-->>Customer: "Processing — results will be sent to your service provider"

    Note over Illion,Webhook: Async — illion does the retrieval work in the background
    Illion->>Webhook: POST callbackUrl (statement data JSON)
    Webhook->>Webhook: Verify callback_token against BankConnection
    Webhook->>Blob: Save raw payload
    Webhook-->>Illion: 200 OK
    Webhook->>Queue: Enqueue processing job

    Note over Valiant,Illion: Polling fallback — if no webhook lands within an SLA, a scheduled job calls POST /customer/data directly instead

    Queue->>Worker: Dequeue job
    Worker->>Blob: Load raw payload
    Worker->>Worker: Normalise into Account/Transaction rows
    Worker->>DB: Upsert Account/Transaction (dedupe_hash)
    Worker->>Worker: Compute StatementMetrics (see lib/bankfeed_insights/calculators/)
    Worker->>DB: Save StatementMetrics

    alt Success
        Worker->>DB: BankConnection.status -> completed
        Worker->>Valiant: Publish bank_statements.completed event
    else Failure
        Worker->>DB: BankConnection.status -> failed (with error_message)
        Worker->>Valiant: Surface failure to Product Specialist
    end

    Note over Valiant: Front-end and the loan assessment engine (ProductIQ) read StatementMetrics
```
