-- Sumera Pomodoro – Supabase schema.
-- Run in Supabase Dashboard > SQL Editor. Safe to run more than once: it
-- creates missing tables, adds new columns to existing ones (keeping data)
-- and replaces the access policies.
--
-- Also required: Authentication > Sign In / Providers > "Allow anonymous sign-ins".

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------------ tables

create table if not exists public.profiles (
  id uuid primary key default uuid_generate_v4(),
  email text unique,
  full_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.tasks (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  is_done boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.focus_sessions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.profiles(id) on delete cascade,
  date date not null,
  minutes integer not null default 0,
  created_at timestamptz not null default now()
);

-- ------------------------------------------- columns used by the app (v1.0)

-- Tasks are matched by the id the app generates on the device.
alter table public.tasks add column if not exists client_id text;
alter table public.tasks add column if not exists estimate integer not null default 0;
alter table public.tasks add column if not exists updated_at timestamptz not null default now();
update public.tasks set client_id = id::text where client_id is null;
alter table public.tasks alter column client_id set not null;
create unique index if not exists tasks_user_client_key
  on public.tasks (user_id, client_id);

-- One row per completed session (older rows were one total per day).
alter table public.focus_sessions add column if not exists client_id text;
alter table public.focus_sessions add column if not exists mode text not null default 'work';
alter table public.focus_sessions add column if not exists completed_at timestamptz;
alter table public.focus_sessions add column if not exists task_client_id text;
update public.focus_sessions set client_id = id::text where client_id is null;
update public.focus_sessions set completed_at = date::timestamptz where completed_at is null;
alter table public.focus_sessions alter column client_id set not null;
alter table public.focus_sessions alter column completed_at set not null;
create unique index if not exists focus_sessions_user_client_key
  on public.focus_sessions (user_id, client_id);
create index if not exists focus_sessions_user_completed_idx
  on public.focus_sessions (user_id, completed_at);

-- ------------------------------------------------------- row level security
-- Every user (including anonymous ones) can only see and change their own
-- rows. The previous "using (true)" policies let anyone holding the public
-- anon key read and delete all users' data.

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.focus_sessions enable row level security;

drop policy if exists "Allow anonymous profile access" on public.profiles;
drop policy if exists "Allow anonymous task access" on public.tasks;
drop policy if exists "Allow anonymous focus session access" on public.focus_sessions;
drop policy if exists "Own profile" on public.profiles;
drop policy if exists "Own tasks" on public.tasks;
drop policy if exists "Own focus sessions" on public.focus_sessions;

create policy "Own profile" on public.profiles
  for all to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "Own tasks" on public.tasks
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Own focus sessions" on public.focus_sessions
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
