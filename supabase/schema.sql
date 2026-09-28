create extension if not exists "uuid-ossp";

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

alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.focus_sessions enable row level security;

drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Users can view own tasks" on public.tasks;
drop policy if exists "Users can insert own tasks" on public.tasks;
drop policy if exists "Users can update own tasks" on public.tasks;
drop policy if exists "Users can delete own tasks" on public.tasks;
drop policy if exists "Users can view own focus sessions" on public.focus_sessions;
drop policy if exists "Users can insert own focus sessions" on public.focus_sessions;
drop policy if exists "Users can update own focus sessions" on public.focus_sessions;
drop policy if exists "Users can delete own focus sessions" on public.focus_sessions;

create policy "Allow anonymous profile access" on public.profiles
for all using (true) with check (true);

create policy "Allow anonymous task access" on public.tasks
for all using (true) with check (true);

create policy "Allow anonymous focus session access" on public.focus_sessions
for all using (true) with check (true);
