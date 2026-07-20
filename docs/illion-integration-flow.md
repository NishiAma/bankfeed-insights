# Illion Integration Flow

### Authentication

Every call Valiant's server makes to illion carries an `X-API-KEY` header
(a static key identifying Valiant as the calling application). This is
separate from per-customer auth: once a customer is created (see below),
illion returns a `customerId` and `encryptionKey` pair that must be
included on every subsequent call *for that customer* — it's how illion
scopes requests to the right bank connection, on top of the app-level API
key.

### Workflow of linking a bank account and triggering the bank statement.

- The product specialist invites the customer to the application form.
- The customer sign in to Valiant portal.
- The customer clicks on `Link your business bank feed` button.
   Valiant creates a `BankConnection` record (`status: pending`) before
   calling illion at all — this is our own internal tracking row,
   independent of anything illion returns, so we have somewhere to record
   what happened even if the customer drops off before finishing (e.g. at
   the bank picker or the credential screen).
   Illion's `List Institutions` API is called: `GET /institutions`
- The customer selects an institution.
- The customer provides the login credentials for the bank of statements.
   Illion's `Create Customer` API is called: `POST /customer/create`, submitting
   the selected institution + credentials. On success this returns a
   `customerId` and `encryptionKey` for this bank connection — both are
   written onto the `BankConnection` row created at the start, and are
   required on every following call.
- If the bank requires a second factor (e.g. SMS code), `/customer/create`
   responds with `"type": "additionalInformationNeeded"` instead of a
   `customerId`, listing the extra field(s) needed plus a `submitTo` URL.
   Valiant shows the requested field(s) to the customer and `POST`s their
   answer to that `submitTo` URL — not back to `/customer/create` — which
   responds with either the final `customerId`/`encryptionKey`, or another
   `additionalInformationNeeded` challenge if the bank needs another step.
   `BankConnection.status → mfa_required` while waiting on the customer,
   back to `pending`/`processing` once submitted.
- If success, the success response is received. Then the list of accounts for the user is requested.
   Illion's `List Customer Accounts` API is called: `POST /customer/accounts`
   (passing the `customerId`/`encryptionKey` from the previous step).
- The customer selects the account & submits.
   Valiant generates a single-use `callback_token` and writes it onto the
   same `BankConnection` row (`status → processing`), then calls illion's
   `Retrieve Customer Data` API: `POST /customer/data`, passing the
   `customerId`/`encryptionKey`, the selected account IDs, and
   `"async": true` with `callbackUrl: https://api.valiant.com/webhooks/illion/{callback_token}`.
   This is the call that actually triggers retrieval — illion responds
   immediately with an acknowledgement (not the data itself), then does
   the work in the background. See `data-processing-and-storing.md` for
   how that token is checked when the webhook lands.
   A success response is sent to the customer with a message saying that the account is being processed and the results will be sent to the service provider (Valiant)
- **Polling fallback**: the webhook is the primary path, but it can be lost
   (network issue, illion retry exhausted, etc.), so a scheduled job also
   checks periodically for any `BankConnection` still stuck in `processing`
   past an SLA (e.g. 10 minutes) and actively calls `POST /customer/data`
   again (this time without `async`, or re-polling) to fetch the result
   directly, rather than leaving the application stranded indefinitely.
   This also covers local/dev environments where illion can't reach an
   inbound webhook URL at all.

### Workflow of receiving the customer account's statements by Valiant.

- Once illion finishes processing, it POSTs the completed statement data as
   a JSON payload to the `callbackUrl` Valiant supplied in the
   `POST /customer/data` call above. This inbound URL is **Valiant's own
   endpoint** (something like `POST /webhooks/illion/{callback_token}`), not an
   illion API — `/customer/data` is only the name of the call Valiant made
   *to* illion to request the data; illion doesn't call back on that same
   path.
