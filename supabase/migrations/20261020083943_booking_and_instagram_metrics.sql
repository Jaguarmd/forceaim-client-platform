-- Booking funnel tracking and additional Instagram metric fields.
-- Apply this migration before deploying code that reads these columns/tables.

alter table public.clients
  add column if not exists booking_url text;

alter table public.performance_metrics
  add column if not exists follows bigint check (follows is null or follows >= 0),
  add column if not exists unfollows bigint check (unfollows is null or unfollows >= 0),
  add column if not exists profile_link_taps bigint check (profile_link_taps is null or profile_link_taps >= 0),
  add column if not exists accounts_engaged bigint check (accounts_engaged is null or accounts_engaged >= 0),
  add column if not exists total_interactions bigint check (total_interactions is null or total_interactions >= 0);

create table if not exists public.booking_click_events (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  clicked_at timestamptz not null default now(),
  source text not null default 'tracked_link'
);
create index if not exists booking_click_client_date_idx
  on public.booking_click_events(client_id, clicked_at desc);

create table if not exists public.booking_events (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  invitee_uri text not null unique,
  scheduled_event_uri text,
  status text not null check (status in ('active', 'canceled')),
  scheduled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists booking_events_client_status_idx
  on public.booking_events(client_id, status, scheduled_at desc);

alter table public.booking_click_events enable row level security;
alter table public.booking_events enable row level security;

create policy "admin reads booking clicks" on public.booking_click_events
  for select to authenticated using (public.is_admin());
create policy "client reads own booking clicks" on public.booking_click_events
  for select to authenticated using (public.owns_client(client_id));
create policy "admin manages booking events" on public.booking_events
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "client reads own booking events" on public.booking_events
  for select to authenticated using (public.owns_client(client_id));

grant select on public.booking_click_events, public.booking_events to authenticated;
grant all on public.booking_click_events, public.booking_events to service_role;

