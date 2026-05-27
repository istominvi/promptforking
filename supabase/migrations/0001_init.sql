-- 0001_init.sql
-- Promptforking — sprint 1 initial schema.
-- Tables: profiles, models, generations. RLS enabled on all.
-- A profile row is auto-created when a new auth user signs up.

-- ----------------------------------------------------------------------------
-- Extensions
-- ----------------------------------------------------------------------------
create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ============================================================================
-- profiles — extends auth.users 1:1; managed by trigger on signup.
-- ============================================================================
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique,
  display_name  text,
  avatar_url    text,
  created_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_all"
  on public.profiles for select
  using (true);

create policy "profiles_update_own"
  on public.profiles for update
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Auto-create profile on auth.users insert.
-- SECURITY DEFINER so it bypasses RLS; pinned search_path for safety.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- models — provider model catalog. Readable by all; only service_role writes.
-- ============================================================================
create table public.models (
  id              text primary key,
  provider        text not null check (provider in ('replicate', 'fal')),
  display_name    text not null,
  kind            text not null check (kind in ('image')),
  default_params  jsonb not null default '{}'::jsonb,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

alter table public.models enable row level security;

create policy "models_select_all"
  on public.models for select
  using (true);
-- No INSERT/UPDATE/DELETE policies → only service_role (BYPASSRLS) can write.

-- Seed initial models. Default params are minimal/sane; can be tuned later.
insert into public.models (id, provider, display_name, kind, default_params) values
  ('fal-ai/flux-pro', 'fal', 'FLUX Pro', 'image',
    '{"image_size":"landscape_4_3","num_inference_steps":28,"guidance_scale":3.5}'::jsonb),
  ('fal-ai/flux/schnell', 'fal', 'FLUX Schnell', 'image',
    '{"image_size":"landscape_4_3","num_inference_steps":4}'::jsonb),
  ('black-forest-labs/flux-1.1-pro', 'replicate', 'FLUX 1.1 Pro', 'image',
    '{"aspect_ratio":"4:3","output_format":"webp","output_quality":80}'::jsonb),
  ('black-forest-labs/flux-schnell', 'replicate', 'FLUX Schnell', 'image',
    '{"aspect_ratio":"4:3","output_format":"webp"}'::jsonb);

-- ============================================================================
-- generations — tree node = one feed post. Root has root_id = id.
-- ============================================================================
create table public.generations (
  id              uuid primary key default gen_random_uuid(),
  author_id       uuid references public.profiles(id) on delete set null,
  parent_id       uuid references public.generations(id) on delete set null,
  root_id         uuid not null references public.generations(id) on delete cascade,
  model_id        text not null references public.models(id),
  prompt          text not null,
  model_params    jsonb not null default '{}'::jsonb,
  image_url       text,
  status          text not null default 'pending'
                    check (status in ('pending', 'succeeded', 'failed')),
  error           text,
  content_rating  text not null default 'sfw',
  is_public       boolean not null default true,
  created_at      timestamptz not null default now()
);

create index generations_parent_id_idx  on public.generations (parent_id);
create index generations_root_id_idx    on public.generations (root_id);
create index generations_author_id_idx  on public.generations (author_id);
create index generations_created_at_idx on public.generations (created_at desc);
create index generations_model_id_idx   on public.generations (model_id);

-- For roots (parent_id IS NULL), pin root_id = id.
-- Forks (parent_id IS NOT NULL) must set root_id explicitly from parent.root_id.
create or replace function public.generations_set_root_id()
returns trigger
language plpgsql
as $$
begin
  if new.parent_id is null then
    new.root_id := new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists generations_set_root_id_trigger on public.generations;
create trigger generations_set_root_id_trigger
  before insert on public.generations
  for each row execute function public.generations_set_root_id();

alter table public.generations enable row level security;

create policy "generations_select_public_or_own"
  on public.generations for select
  using (
    (is_public = true and status = 'succeeded')
    or author_id = (select auth.uid())
  );

create policy "generations_insert_own"
  on public.generations for insert
  with check (author_id = (select auth.uid()));

create policy "generations_update_own"
  on public.generations for update
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));

create policy "generations_delete_own"
  on public.generations for delete
  using (author_id = (select auth.uid()));
