-- Student companion features: class routine, attendance, CT marks, study log
-- and expenses, plus the hardening those features rely on.
--
-- Run this after 0001_init.sql in the Supabase SQL editor. It is safe to run
-- more than once.

-- ---------------------------------------------------------------------------
-- hardening of the existing tables
-- ---------------------------------------------------------------------------

-- Lab courses carry fractional credits such as 0.75, which numeric(3, 1) would
-- silently round to 0.8 and so skew the CGPA.
alter table public.courses alter column credits type numeric(4, 2);

-- Lets child tables reference (course id, owner) together, so the database
-- rejects a row that points at a course owned by somebody else. Foreign keys
-- bypass RLS, so the policies alone cannot catch that.
create unique index if not exists courses_id_user_idx
  on public.courses (id, user_id);

alter table public.assignments drop constraint if exists assignments_course_id_fkey;
alter table public.assignments drop constraint if exists assignments_course_owner_fkey;
alter table public.assignments
  add constraint assignments_course_owner_fkey
  foreign key (course_id, user_id) references public.courses (id, user_id)
  on delete cascade;

-- ---------------------------------------------------------------------------
-- profiles: personal targets
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists weekly_study_goal_minutes integer not null default 600
    check (weekly_study_goal_minutes between 0 and 10080);

alter table public.profiles
  add column if not exists monthly_budget numeric(10, 2)
    check (monthly_budget >= 0);

comment on column public.profiles.monthly_budget is 'NULL until the student sets a budget.';

-- ---------------------------------------------------------------------------
-- class_slots: the weekly routine
-- ---------------------------------------------------------------------------
create table if not exists public.class_slots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null,
  weekday smallint not null check (weekday between 1 and 7),
  start_minute smallint not null check (start_minute between 0 and 1439),
  end_minute smallint not null check (end_minute between 1 and 1440),
  room text,
  created_at timestamptz not null default now(),
  check (end_minute > start_minute),
  foreign key (course_id, user_id) references public.courses (id, user_id)
    on delete cascade
);

comment on column public.class_slots.weekday is '1 = Monday ... 7 = Sunday, matching Dart''s DateTime.weekday.';
comment on column public.class_slots.start_minute is 'Minutes after midnight. A class time is a wall clock, not an instant, so it carries no time zone.';

create index if not exists class_slots_user_day_idx
  on public.class_slots (user_id, weekday, start_minute);
create index if not exists class_slots_course_id_idx
  on public.class_slots (course_id);

-- ---------------------------------------------------------------------------
-- attendance_records
-- ---------------------------------------------------------------------------
create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null,
  held_on date not null,
  session smallint not null default 1 check (session >= 1),
  status text not null check (status in ('present', 'late', 'absent')),
  created_at timestamptz not null default now(),
  -- `session` separates two classes of one course on the same day. The app
  -- upserts on this key, so marking a class twice corrects it, never doubles it.
  unique (user_id, course_id, held_on, session),
  foreign key (course_id, user_id) references public.courses (id, user_id)
    on delete cascade
);

create index if not exists attendance_records_course_id_idx
  on public.attendance_records (course_id);

-- ---------------------------------------------------------------------------
-- ct_marks: class test results
-- ---------------------------------------------------------------------------
create table if not exists public.ct_marks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid not null,
  title text not null check (length(btrim(title)) > 0),
  obtained numeric(5, 2) not null check (obtained >= 0),
  total numeric(5, 2) not null default 20 check (total > 0),
  held_on date,
  created_at timestamptz not null default now(),
  check (obtained <= total),
  foreign key (course_id, user_id) references public.courses (id, user_id)
    on delete cascade
);

create index if not exists ct_marks_user_id_idx on public.ct_marks (user_id);
create index if not exists ct_marks_course_id_idx on public.ct_marks (course_id);

-- ---------------------------------------------------------------------------
-- study_sessions
-- ---------------------------------------------------------------------------
create table if not exists public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid,
  topic text not null check (length(btrim(topic)) > 0),
  minutes integer not null check (minutes between 1 and 1440),
  studied_on date not null,
  notes text,
  created_at timestamptz not null default now(),
  -- Study time survives deleting the course. Only course_id is cleared, because
  -- user_id is part of this key but must stay set.
  foreign key (course_id, user_id) references public.courses (id, user_id)
    on delete set null (course_id)
);

create index if not exists study_sessions_user_day_idx
  on public.study_sessions (user_id, studied_on desc);
create index if not exists study_sessions_course_id_idx
  on public.study_sessions (course_id);

-- ---------------------------------------------------------------------------
-- expenses
-- ---------------------------------------------------------------------------
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (length(btrim(title)) > 0),
  amount numeric(10, 2) not null check (amount > 0),
  category text not null default 'other' check (
    category in ('food', 'transport', 'education', 'housing', 'mobile', 'health', 'fun', 'other')
  ),
  spent_on date not null,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists expenses_user_day_idx
  on public.expenses (user_id, spent_on desc);

-- ---------------------------------------------------------------------------
-- row level security
-- ---------------------------------------------------------------------------
alter table public.class_slots enable row level security;
alter table public.attendance_records enable row level security;
alter table public.ct_marks enable row level security;
alter table public.study_sessions enable row level security;
alter table public.expenses enable row level security;

drop policy if exists "own class slots" on public.class_slots;
create policy "own class slots" on public.class_slots
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own attendance" on public.attendance_records;
create policy "own attendance" on public.attendance_records
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own ct marks" on public.ct_marks;
create policy "own ct marks" on public.ct_marks
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own study sessions" on public.study_sessions;
create policy "own study sessions" on public.study_sessions
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own expenses" on public.expenses;
create policy "own expenses" on public.expenses
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
