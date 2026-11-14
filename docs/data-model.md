# Data model

The initial migration creates an integration ledger rather than attempting to replace either provider's system of record.

## Tables

| Table | Purpose |
|---|---|
| `provider_events` | Durable record of inbound Stripe event IDs and processing state |
| `customers` | Minimal internal customer identity and optional provider mapping |
| `payments` | Normalized payment facts from Stripe |
| `sync_jobs` | Retryable QuickBooks synchronization work |
| `provider_mappings` | Links internal records to provider entity IDs |
| `audit_events` | Append-only operational event trail |

## Important invariants

- `provider_events(provider, external_event_id)` is unique, so webhook redelivery cannot enqueue duplicate work.
- `payments(provider, external_payment_id)` is unique.
- A sync job has a stable idempotency key and an attempt counter.
- Amounts are stored as integer minor units (for example, cents), never floating point. Currency is stored as an uppercase ISO 4217 code.
- Provider payload JSON is optional diagnostic context; redact it and apply retention limits before production use.

## Initial migration

See `supabase/migrations/001_initial_schema.sql`. It uses PostgreSQL UUIDs and timestamps and can be applied in a disposable Supabase development project.
