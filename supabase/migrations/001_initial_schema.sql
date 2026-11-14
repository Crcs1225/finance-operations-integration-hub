-- Finance Operations Integration Hub
-- Development/demo schema. Apply only to a disposable Supabase project.
-- Supabase provides pgcrypto in typical projects; gen_random_uuid() is built in
-- on supported PostgreSQL versions.

create extension if not exists pgcrypto;

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  display_name text,
  email text,
  stripe_customer_id text unique,
  quickbooks_customer_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.provider_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('stripe', 'quickbooks')),
  external_event_id text not null,
  event_type text not null,
  status text not null default 'received'
    check (status in ('received', 'processing', 'processed', 'duplicate', 'failed', 'ignored')),
  payload jsonb,
  error_message text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (provider, external_event_id)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers(id) on delete set null,
  provider text not null default 'stripe' check (provider = 'stripe'),
  external_payment_id text not null,
  status text not null check (status in ('requires_payment_method', 'requires_confirmation', 'requires_action', 'processing', 'succeeded', 'canceled', 'unknown')),
  amount_minor bigint not null check (amount_minor >= 0),
  currency char(3) not null,
  description text,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, external_payment_id)
);

create table if not exists public.sync_jobs (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  target_provider text not null check (target_provider in ('quickbooks')),
  operation text not null default 'create_payment',
  idempotency_key text not null unique,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'succeeded', 'retry', 'failed', 'needs_review')),
  attempts integer not null default 0 check (attempts >= 0),
  max_attempts integer not null default 5 check (max_attempts > 0),
  next_attempt_at timestamptz not null default now(),
  last_error text,
  provider_response jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.provider_mappings (
  id uuid primary key default gen_random_uuid(),
  internal_entity_type text not null,
  internal_entity_id uuid not null,
  provider text not null,
  provider_entity_type text not null,
  provider_entity_id text not null,
  created_at timestamptz not null default now(),
  unique (internal_entity_type, internal_entity_id, provider, provider_entity_type),
  unique (provider, provider_entity_type, provider_entity_id)
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid,
  action text not null,
  actor text not null default 'system',
  correlation_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_provider_events_status_received
  on public.provider_events(status, received_at desc);
create index if not exists idx_payments_status_created
  on public.payments(status, created_at desc);
create index if not exists idx_sync_jobs_due
  on public.sync_jobs(status, next_attempt_at)
  where status in ('pending', 'retry');
create index if not exists idx_audit_events_entity
  on public.audit_events(entity_type, entity_id, created_at desc);

-- This starter migration intentionally does not enable broad client access.
-- Add RLS policies only when the app's auth model and access roles are defined.
-- Service-role credentials must remain server-side and must never reach a browser.
