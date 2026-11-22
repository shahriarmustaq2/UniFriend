-- UniFriend initial schema.
-- Every table is personal: rows belong to exactly one student and are reachable
-- only through that student's auth.uid() via row level security.
--
-- Run this in the Supabase SQL editor (Dashboard -> SQL Editor -> New query).

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

comment on table public.profiles is 'One row per student, keyed by auth.users.id.';

-- Create the profile row automatically whenever a new auth user signs up.
-- security defender is required: the trigger runs as the table owner so it can
-- insert into a table that RLS otherwise locks down to the signed-in user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill accounts that already existed before this migration ran.
insert into public.profiles (id, full_name)
select id, raw_user_meta_data ->> 'full_name'
from auth.users
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- courses
-- ---------------------------------------------------------------------------
create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  code text not null check (length(btrim(code)) > 0),
  title text not null check (length(btrim(title)) > 0),
  credits numeric(3, 1) not null default 3.0 check (credits > 0 and credits <= 12),
  semester text,
  grade_points numeric(3, 2) check (grade_points between 0 and 4),
  created_at timestamptz not null default now()
);

comment on column public.courses.grade_points is 'NULL until the result is published; 0.00 to 4.00.';

create index if not exists courses_user_id_idx on public.courses (user_id);
create index if not exists courses_user_semester_idx on public.courses (user_id, semester);

-- ---------------------------------------------------------------------------
-- assignments
-- ---------------------------------------------------------------------------
create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  title text not null check (length(btrim(title)) > 0),
  due_date timestamptz not null,
  is_completed boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists assignments_user_id_idx on public.assignments (user_id);
create index if not exists assignments_course_id_idx on public.assignments (course_id);
-- The dashboard almost always asks for "what is still open, soonest first".
create index if not exists assignments_open_due_idx
  on public.assignments (user_id, due_date)
  where is_completed = false;

-- ---------------------------------------------------------------------------
-- notices
-- ---------------------------------------------------------------------------
create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (length(btrim(title)) > 0),
  body text,
  is_pinned boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists notices_user_id_idx on public.notices (user_id);
create index if not exists notices_user_created_idx on public.notices (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- row level security
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.assignments enable row level security;
alter table public.notices enable row level security;

-- Wrap auth.uid() in a subselect so Postgres evaluates it once per statement
-- instead of once per row (InitPlan instead of per-row function call).
drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

drop policy if exists "own courses" on public.courses;
create policy "own courses" on public.courses
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own assignments" on public.assignments;
create policy "own assignments" on public.assignments
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own notices" on public.notices;
create policy "own notices" on public.notices
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
