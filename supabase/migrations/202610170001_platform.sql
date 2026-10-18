-- ForceAim agency platform schema. Apply with Supabase SQL editor or Supabase CLI.
create extension if not exists pgcrypto;
create type public.app_role as enum ('admin','client');
create table public.clients (
 id uuid primary key default gen_random_uuid(), business_name text not null,
 country text, timezone text, whatsapp text, preferred_contact text,
 instagram_username text, instagram_url text, instagram_account_type text,
 instagram_creator_or_business text, current_followers bigint check(current_followers is null or current_followers >= 0),
 average_reel_views bigint check(average_reel_views is null or average_reel_views >= 0),
 instagram_notes text, onboarding_status text not null default 'not_started' check(onboarding_status in ('not_started','in_progress','submitted','complete')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 role public.app_role not null default 'client', client_id uuid unique references public.clients(id) on delete cascade,
 full_name text not null default '', email text not null default '', created_at timestamptz not null default now(),
 constraint client_profile_requires_client check(role <> 'client' or client_id is not null)
);
create index profiles_client_id_idx on public.profiles(client_id);
create table public.onboarding_responses (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references public.clients(id) on delete cascade,
 step text not null check(step in ('basic','instagram','business','baseline','preferences')),
 response jsonb not null default '{}', submitted_at timestamptz, updated_at timestamptz not null default now(),
 unique(client_id,step)
);
create table public.performance_baselines (
 id uuid primary key default gen_random_uuid(), client_id uuid not null unique references public.clients(id) on delete cascade,
 starting_followers bigint check(starting_followers is null or starting_followers >= 0), average_reel_views bigint check(average_reel_views is null or average_reel_views >= 0),
 monthly_leads bigint check(monthly_leads is null or monthly_leads >= 0), calls_booked bigint check(calls_booked is null or calls_booked >= 0),
 calls_attended bigint check(calls_attended is null or calls_attended >= 0), clients_acquired bigint check(clients_acquired is null or clients_acquired >= 0),
 monthly_revenue numeric check(monthly_revenue is null or monthly_revenue >= 0), goal_90_days text, submitted_at timestamptz not null default now()
);
create table public.oauth_states (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 provider text not null, state text not null unique, expires_at timestamptz not null, created_at timestamptz not null default now()
);
create table public.instagram_connections (
 id uuid primary key default gen_random_uuid(), client_id uuid not null unique references public.clients(id) on delete cascade,
 instagram_user_id text, username text, token_expires_at timestamptz,
 granted_permissions text[] not null default '{}', status text not null default 'disconnected', connected_at timestamptz,
 updated_at timestamptz not null default now()
);
-- Access tokens are encrypted by the application; RLS has no user policies.
create table public.instagram_tokens (
 client_id uuid primary key references public.clients(id) on delete cascade,
 encrypted_access_token text not null, updated_at timestamptz not null default now()
);
create table public.content_references (
 id uuid primary key default gen_random_uuid(), title text not null, description text, category text not null default 'Other',
 video_storage_path text, instagram_url text, youtube_url text, hook_analysis text, storytelling_structure text,
 recording_instructions text, caption_style text, editing_instructions text, animation_notes text,
 status text not null default 'draft' check(status in ('draft','published')), created_by uuid references auth.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.reference_private_notes (
 reference_id uuid primary key references public.content_references(id) on delete cascade,
 note text not null default '', updated_by uuid references auth.users(id), updated_at timestamptz not null default now()
);
create table public.client_references (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references public.clients(id) on delete cascade,
 reference_id uuid not null references public.content_references(id) on delete cascade, published boolean not null default false,
 assigned_by uuid references auth.users(id), assigned_at timestamptz not null default now(),
 unique(client_id,reference_id)
);
create table public.reference_reviews (
 id uuid primary key default gen_random_uuid(), client_reference_id uuid not null references public.client_references(id) on delete cascade,
 reviewed_by uuid not null references auth.users(id), reviewed_at timestamptz not null default now(),
 unique(client_reference_id)
);
create table public.video_projects (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references public.clients(id) on delete cascade,
 reference_id uuid references public.content_references(id) on delete set null, title text not null, description text,
 recording_notes text, raw_storage_path text not null, status text not null default 'Uploaded'
 check(status in ('Uploaded','Queued for Editing','Editing','Ready for Review','Changes Requested','Approved','Ready to Publish','Published')),
 approved_by uuid references auth.users(id), approved_at timestamptz,
 published_at timestamptz, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index video_client_status_idx on public.video_projects(client_id,status);
create table public.video_versions (
 id uuid primary key default gen_random_uuid(), video_id uuid not null references public.video_projects(id) on delete cascade,
 version_number integer not null check(version_number > 0), storage_path text not null, uploaded_by uuid references auth.users(id),
 created_at timestamptz not null default now(), unique(video_id,version_number)
);
create table public.video_feedback (
 id uuid primary key default gen_random_uuid(), video_id uuid not null references public.video_projects(id) on delete cascade,
 client_id uuid not null references public.clients(id) on delete cascade, feedback text not null,
 action text not null check(action in ('approved','changes_requested')), created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table public.video_private_notes (
 id uuid primary key default gen_random_uuid(), video_id uuid not null references public.video_projects(id) on delete cascade,
 client_id uuid not null references public.clients(id) on delete cascade, note text not null,
 created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table public.video_status_history (
 id uuid primary key default gen_random_uuid(), video_id uuid not null references public.video_projects(id) on delete cascade,
 status text not null, changed_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table public.calendar_entries (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references public.clients(id) on delete cascade,
 title text not null, platform text not null default 'Instagram', reference_id uuid references public.content_references(id) on delete set null,
 video_id uuid references public.video_projects(id) on delete set null, scheduled_at timestamptz,
 status text not null default 'Idea' check(status in ('Idea','Reference Assigned','Awaiting Recording','Editing','Awaiting Approval','Approved','Scheduled','Published')),
 notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index calendar_client_date_idx on public.calendar_entries(client_id,scheduled_at);
create table public.performance_metrics (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references public.clients(id) on delete cascade,
 video_id uuid references public.video_projects(id) on delete set null, video_title text, instagram_url text, published_at date, recorded_at date not null,
 followers bigint check(followers is null or followers >= 0), views bigint check(views is null or views >= 0),
 reach bigint check(reach is null or reach >= 0), likes bigint check(likes is null or likes >= 0),
 comments bigint check(comments is null or comments >= 0), shares bigint check(shares is null or shares >= 0),
 saves bigint check(saves is null or saves >= 0), leads bigint check(leads is null or leads >= 0),
 calls_booked bigint check(calls_booked is null or calls_booked >= 0), calls_attended bigint check(calls_attended is null or calls_attended >= 0),
 clients_acquired bigint check(clients_acquired is null or clients_acquired >= 0), revenue numeric check(revenue is null or revenue >= 0),
 source text not null default 'manual' check(source in ('manual','meta')), created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create index metrics_client_date_idx on public.performance_metrics(client_id,recorded_at desc);
create table public.client_private_notes (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references public.clients(id) on delete cascade,
 note text not null, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 event_type text not null, message text not null, entity_type text, entity_id uuid, read_at timestamptz,
 created_at timestamptz not null default now()
);
create table public.activity_log (
 id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users(id), client_id uuid references public.clients(id) on delete cascade,
 event_type text not null, entity_type text, entity_id uuid, details jsonb not null default '{}', created_at timestamptz not null default now()
);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'); $$;
create or replace function public.owns_client(target uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.client_id=target and p.role='client'); $$;
create or replace function public.current_client_id() returns uuid language sql stable security definer set search_path=public as $$
 select client_id from public.profiles where id=auth.uid(); $$;
create view public.client_dashboard with (security_invoker=true) as
 select c.id,c.business_name,c.instagram_username,c.instagram_url,c.current_followers,c.onboarding_status,
 (select pb.starting_followers from public.performance_baselines pb where pb.client_id=c.id limit 1) as starting_followers,
 (select count(*) from public.video_projects v where v.client_id=c.id and v.status not in ('Approved','Published'))::int as active_videos,
 (select count(*) from public.client_references cr where cr.client_id=c.id and cr.published)::int as assigned_references
 from public.clients c;
alter table public.clients enable row level security;
alter table public.profiles enable row level security;
alter table public.onboarding_responses enable row level security;
alter table public.performance_baselines enable row level security;
alter table public.oauth_states enable row level security;
alter table public.instagram_connections enable row level security;
alter table public.instagram_tokens enable row level security;
alter table public.content_references enable row level security;
alter table public.reference_private_notes enable row level security;
alter table public.client_references enable row level security;
alter table public.reference_reviews enable row level security;
alter table public.video_projects enable row level security;
alter table public.video_versions enable row level security;
alter table public.video_feedback enable row level security;
alter table public.video_private_notes enable row level security;
alter table public.video_status_history enable row level security;
alter table public.calendar_entries enable row level security;
alter table public.performance_metrics enable row level security;
alter table public.client_private_notes enable row level security;
alter table public.notifications enable row level security;
alter table public.activity_log enable row level security;
create policy "admin all clients" on public.clients for all using(public.is_admin()) with check(public.is_admin());
create policy "client reads own client" on public.clients for select using(id=public.current_client_id());
create policy "client updates own details" on public.clients for update using(public.owns_client(id)) with check(public.owns_client(id));
create or replace function public.protect_client_onboarding_status() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is not null and not public.is_admin() and new.onboarding_status is distinct from old.onboarding_status then
  raise exception 'Clients cannot change onboarding status directly';
 end if;
 return new;
end $$;
create trigger protect_client_onboarding_status before update on public.clients for each row execute function public.protect_client_onboarding_status();
create policy "admin all profiles" on public.profiles for all using(public.is_admin()) with check(public.is_admin());
create policy "user reads own profile" on public.profiles for select using(id=auth.uid());
create policy "user updates own nonprivileged profile" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid() and role='client' and client_id=public.current_client_id());
create policy "admin onboarding" on public.onboarding_responses for all using(public.is_admin()) with check(public.is_admin());
create policy "client manages own onboarding" on public.onboarding_responses for all using(public.owns_client(client_id)) with check(public.owns_client(client_id));
create policy "admin baselines" on public.performance_baselines for all using(public.is_admin()) with check(public.is_admin());
create policy "client baseline read" on public.performance_baselines for select using(public.owns_client(client_id));
create policy "client submits baseline" on public.performance_baselines for all using(public.owns_client(client_id)) with check(public.owns_client(client_id));
create policy "admin oauth states" on public.oauth_states for all using(public.is_admin()) with check(public.is_admin());
create policy "user owns oauth state" on public.oauth_states for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "admin instagram connection" on public.instagram_connections for all using(public.is_admin()) with check(public.is_admin());
create policy "client reads instagram status" on public.instagram_connections for select using(public.owns_client(client_id));
revoke all on public.instagram_tokens from public, anon, authenticated;
grant all on public.instagram_tokens to service_role;
create policy "admin refs" on public.content_references for all using(public.is_admin()) with check(public.is_admin());
create policy "admin private reference notes" on public.reference_private_notes for all using(public.is_admin()) with check(public.is_admin());
create policy "client sees published assigned refs" on public.content_references for select using(exists(select 1 from public.client_references cr where cr.reference_id=id and cr.client_id=public.current_client_id() and cr.published));
create policy "admin ref assignments" on public.client_references for all using(public.is_admin()) with check(public.is_admin());
create policy "client reads assigned refs" on public.client_references for select using(client_id=public.current_client_id() and published);
create policy "client records own reviews" on public.reference_reviews for insert with check(reviewed_by=auth.uid() and exists(select 1 from public.client_references cr where cr.id=client_reference_id and cr.client_id=public.current_client_id()));
create policy "client reads own reviews" on public.reference_reviews for select using(exists(select 1 from public.client_references cr where cr.id=client_reference_id and cr.client_id=public.current_client_id()));
create policy "admin reviews" on public.reference_reviews for select using(public.is_admin());
create policy "admin video access" on public.video_projects for all using(public.is_admin()) with check(public.is_admin());
create policy "client own videos" on public.video_projects for select using(client_id=public.current_client_id());
create policy "client submits own videos" on public.video_projects for insert with check(public.owns_client(client_id) and created_by=auth.uid() and status='Uploaded' and approved_by is null and raw_storage_path like video_projects.client_id::text||'/%' and (reference_id is null or exists(select 1 from public.client_references cr where cr.client_id=video_projects.client_id and cr.reference_id=video_projects.reference_id and cr.published)));
create policy "admin versions" on public.video_versions for all using(public.is_admin()) with check(public.is_admin());
create policy "client reads own versions" on public.video_versions for select using(exists(select 1 from public.video_projects v where v.id=video_id and v.client_id=public.current_client_id()));
create policy "admin feedback" on public.video_feedback for all using(public.is_admin()) with check(public.is_admin());
create policy "client submits own feedback" on public.video_feedback for insert with check(client_id=public.current_client_id() and created_by=auth.uid() and exists(select 1 from public.video_projects v where v.id=video_feedback.video_id and v.client_id=video_feedback.client_id));
create policy "client reads own feedback" on public.video_feedback for select using(client_id=public.current_client_id());
create policy "admin private video notes" on public.video_private_notes for all using(public.is_admin()) with check(public.is_admin());
create policy "admin video history" on public.video_status_history for all using(public.is_admin()) with check(public.is_admin());
create policy "client reads video history" on public.video_status_history for select using(exists(select 1 from public.video_projects v where v.id=video_id and v.client_id=public.current_client_id()));
create policy "admin calendar" on public.calendar_entries for all using(public.is_admin()) with check(public.is_admin());
create policy "client calendar read" on public.calendar_entries for select using(client_id=public.current_client_id());
create policy "admin metrics" on public.performance_metrics for all using(public.is_admin()) with check(public.is_admin());
create policy "client metrics read" on public.performance_metrics for select using(client_id=public.current_client_id());
create policy "admin private notes" on public.client_private_notes for all using(public.is_admin()) with check(public.is_admin());
create policy "admin notifications" on public.notifications for all using(public.is_admin()) with check(public.is_admin());
create policy "user own notifications" on public.notifications for select using(user_id=auth.uid());
create policy "user marks own notifications" on public.notifications for update using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "admin activity" on public.activity_log for all using(public.is_admin()) with check(public.is_admin());
create policy "client activity read" on public.activity_log for select using(client_id=public.current_client_id());
create or replace function public.log_video_event() returns trigger language plpgsql security definer set search_path=public as $$
declare actor uuid; recipient record; event_name text;
begin
 actor := auth.uid();
 if tg_op='INSERT' then event_name := 'video_uploaded'; else event_name := 'video_status_changed'; end if;
 insert into public.activity_log(actor_id,client_id,event_type,entity_type,entity_id,details)
 values(actor,new.client_id,event_name,'video',new.id,jsonb_build_object('title',new.title,'status',new.status));
 for recipient in select p.id from public.profiles p where p.role='admin' or (p.role='client' and p.client_id=new.client_id) loop
  if tg_op='INSERT' and recipient.id=actor then continue; end if;
  insert into public.notifications(user_id,event_type,message,entity_type,entity_id)
  values(recipient.id,event_name,case when event_name='video_uploaded' then 'New footage was submitted.' else 'A video status changed to '||new.status||'.' end,'video',new.id);
 end loop;
 return new;
end $$;
create trigger video_event_log after insert or update of status on public.video_projects for each row execute function public.log_video_event();
create or replace function public.log_reference_review() returns trigger language plpgsql security definer set search_path=public as $$
declare cid uuid; admin_profile record;
begin
 select client_id into cid from public.client_references where id=new.client_reference_id;
 insert into public.activity_log(actor_id,client_id,event_type,entity_type,entity_id)
 values(new.reviewed_by,cid,'reference_reviewed','reference',new.client_reference_id);
 for admin_profile in select id from public.profiles where role='admin' loop
  insert into public.notifications(user_id,event_type,message,entity_type,entity_id)
  values(admin_profile.id,'reference_reviewed','A client marked a content reference as reviewed.','reference',new.client_reference_id);
 end loop;
 return new;
end $$;
create trigger reference_review_log after insert on public.reference_reviews for each row execute function public.log_reference_review();
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('client-videos','client-videos',false,524288000,array['video/mp4','video/quicktime']) on conflict(id) do update set public=false;
create policy "admin manages private videos" on storage.objects for all using(bucket_id='client-videos' and public.is_admin()) with check(bucket_id='client-videos' and public.is_admin());
create policy "client uploads to own folder" on storage.objects for insert with check(bucket_id='client-videos' and (storage.foldername(name))[1]=public.current_client_id()::text);
create policy "client reads own video files" on storage.objects for select using(bucket_id='client-videos' and (storage.foldername(name))[1]=public.current_client_id()::text);
create policy "client reads assigned reference video files" on storage.objects for select using(
 bucket_id='client-videos' and (storage.foldername(name))[1]='library' and exists(
  select 1 from public.content_references r join public.client_references cr on cr.reference_id=r.id
  where r.video_storage_path=name and cr.client_id=public.current_client_id() and cr.published
 )
);
grant select,insert,update,delete on all tables in schema public to authenticated, service_role;
grant usage,select on all sequences in schema public to authenticated, service_role;
grant select on public.client_dashboard to authenticated;
-- The broad table grant above must not re-grant authenticated access to tokens.
revoke all on public.instagram_tokens from public, anon, authenticated;
grant all on public.instagram_tokens to service_role;
