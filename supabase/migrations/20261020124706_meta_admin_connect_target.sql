-- Store the agency-selected client on each one-time Meta OAuth state.
-- The callback can then associate the Instagram account with the intended
-- client without trusting a client ID passed through the browser callback.
alter table public.oauth_states
  add column if not exists client_id uuid references public.clients(id) on delete cascade;

create index if not exists oauth_states_client_id_idx
  on public.oauth_states(client_id);

drop policy if exists "user owns oauth state" on public.oauth_states;
create policy "client owns oauth state" on public.oauth_states
  for all
  using (user_id = auth.uid() and public.owns_client(client_id))
  with check (user_id = auth.uid() and public.owns_client(client_id));
