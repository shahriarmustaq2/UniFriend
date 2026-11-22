-- The rework: semesters with vacations, theory and sessional courses with a
-- mark sheet, classes every other week, cancelled classes, a study plan with
-- exams, and fewer expense categories.
--
-- Run this after 0003_realtime.sql in the Supabase SQL editor. It is safe to run
-- more than once, and it carries existing data across:
--   * free-text semester names on courses become semester rows,
--   * each student's latest semester becomes their current one,
--   * the old expense categories are merged into the new six.
-- It needs Postgres 15 or newer, like 0002.

-- ---------------------------------------------------------------------------
-- semesters
-- ---------------------------------------------------------------------------
create table if not exists public.semesters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  starts_on date not null,
  classes_ended_on date,
  created_at timestamptz not null default now(),
  check (classes_ended_on is null or classes_ended_on >= starts_on)
);

comment on column public.semesters.starts_on is 'Week 1 of the semester is the week containing this date. Weeks start on Saturday in the app.';
comment on column public.semesters.classes_ended_on is 'Last day of classes, once the student marks them as over.';

create unique index if not exists semesters_id_user_idx on public.semesters (id, user_id);
create index if not exists semesters_user_start_idx on public.semesters (user_id, starts_on);

-- ---------------------------------------------------------------------------
-- vacations
-- ---------------------------------------------------------------------------
create table if not exists public.vacations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  semester_id uuid not null,
  title text not null default '',
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  foreign key (semester_id, user_id) references public.semesters (id, user_id)
    on delete cascade
);

comment on table public.vacations is 'No classes during these days. A week wholly inside vacations does not count towards the week number.';

create index if not exists vacations_semester_idx on public.vacations (semester_id);

-- ---------------------------------------------------------------------------
-- courses: semester, kind, marks, end of classes
-- ---------------------------------------------------------------------------
alter table public.courses add column if not exists semester_id uuid;
alter table public.courses add column if not exists kind text not null default 'theory';
alter table public.courses add column if not exists marks jsonb not null default '{}'::jsonb;
alter table public.courses add column if not exists classes_ended_on date;

alter table public.courses drop constraint if exists courses_kind_check;
alter table public.courses
  add constraint courses_kind_check check (kind in ('theory', 'sessional'));

alter table public.courses drop constraint if exists courses_marks_object_check;
alter table public.courses
  add constraint courses_marks_object_check check (jsonb_typeof(marks) = 'object');

alter table public.courses drop constraint if exists courses_semester_owner_fkey;
alter table public.courses
  add constraint courses_semester_owner_fkey
  foreign key (semester_id, user_id) references public.semesters (id, user_id)
  on delete cascade;

create index if not exists courses_semester_idx on public.courses (semester_id);

comment on column public.courses.marks is 'Marks entered by hand, keyed by part (attendance, ct, assignment, final, quiz, performance, viva), each out of its share of 100.';
comment on column public.courses.grade_points is 'A grade entered directly, which wins over the marks. NULL to work it out from the marks.';
comment on column public.courses.semester is 'Legacy free-text semester, kept for reference. The app uses semester_id.';

-- Free-text semesters become semester rows, one per distinct name per student.
-- A course with no name goes into "My courses". The start date is a guess, the
-- earliest course created under that name, and the student can correct it.
insert into public.semesters (user_id, name, starts_on)
select c.user_id,
       min(coalesce(nullif(btrim(c.semester), ''), 'My courses')),
       min(c.created_at)::date
from public.courses c
where c.semester_id is null
  and not exists (
    select 1 from public.semesters s
    where s.user_id = c.user_id
      and lower(s.name) = lower(coalesce(nullif(btrim(c.semester), ''), 'My courses'))
  )
group by c.user_id, lower(coalesce(nullif(btrim(c.semester), ''), 'My courses'));

update public.courses c
set semester_id = s.id
from public.semesters s
where c.semester_id is null
  and s.user_id = c.user_id
  and lower(s.name) = lower(coalesce(nullif(btrim(c.semester), ''), 'My courses'));

-- ---------------------------------------------------------------------------
-- profiles: the current semester
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists current_semester_id uuid;

alter table public.profiles drop constraint if exists profiles_current_semester_fkey;
alter table public.profiles
  add constraint profiles_current_semester_fkey
  foreign key (current_semester_id, id) references public.semesters (id, user_id)
  on delete set null (current_semester_id);

update public.profiles p
set current_semester_id = (
  select s.id from public.semesters s
  where s.user_id = p.id
  order by s.starts_on desc, s.created_at desc
  limit 1
)
where p.current_semester_id is null;

-- ---------------------------------------------------------------------------
-- class_slots: every other week
-- ---------------------------------------------------------------------------
alter table public.class_slots
  add column if not exists repeat_weeks smallint not null default 1;
alter table public.class_slots add column if not exists anchor_date date;

alter table public.class_slots drop constraint if exists class_slots_repeat_weeks_check;
alter table public.class_slots
  add constraint class_slots_repeat_weeks_check check (repeat_weeks in (1, 2));

alter table public.class_slots drop constraint if exists class_slots_anchor_check;
alter table public.class_slots
  add constraint class_slots_anchor_check
  check (repeat_weeks = 1 or anchor_date is not null);

comment on column public.class_slots.anchor_date is 'For a class every other week: the date of one real class, from which the rhythm is counted. Vacation weeks do not count.';

-- ---------------------------------------------------------------------------
-- attendance_records: cancelled classes
-- ---------------------------------------------------------------------------
alter table public.attendance_records drop constraint if exists attendance_records_status_check;
alter table public.attendance_records
  add constraint attendance_records_status_check
  check (status in ('present', 'late', 'absent', 'cancelled'));

-- ---------------------------------------------------------------------------
-- expenses: six categories
-- ---------------------------------------------------------------------------
alter table public.expenses drop constraint if exists expenses_category_check;
update public.expenses set category = 'study' where category = 'education';
update public.expenses set category = 'other' where category in ('housing', 'fun');
alter table public.expenses
  add constraint expenses_category_check
  check (category in ('food', 'transport', 'study', 'mobile', 'health', 'other'));
alter table public.expenses alter column category set default 'other';

-- ---------------------------------------------------------------------------
-- exams and study_tasks: the study plan
-- ---------------------------------------------------------------------------
create table if not exists public.exams (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid,
  title text not null check (length(btrim(title)) > 0),
  kind text not null default 'other' check (
    kind in ('ct', 'quiz', 'midterm', 'final', 'viva', 'other')
  ),
  held_on date not null,
  created_at timestamptz not null default now(),
  foreign key (course_id, user_id) references public.courses (id, user_id)
    on delete set null (course_id)
);

create unique index if not exists exams_id_user_idx on public.exams (id, user_id);
create index if not exists exams_user_day_idx on public.exams (user_id, held_on);

create table if not exists public.study_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_id uuid,
  exam_id uuid,
  title text not null check (length(btrim(title)) > 0),
  planned_for date not null,
  is_done boolean not null default false,
  created_at timestamptz not null default now(),
  foreign key (course_id, user_id) references public.courses (id, user_id)
    on delete set null (course_id),
  foreign key (exam_id, user_id) references public.exams (id, user_id)
    on delete set null (exam_id)
);

create index if not exists study_tasks_user_day_idx on public.study_tasks (user_id, planned_for);
create index if not exists study_tasks_exam_idx on public.study_tasks (exam_id);

-- ---------------------------------------------------------------------------
-- row level security
-- ---------------------------------------------------------------------------
alter table public.semesters enable row level security;
alter table public.vacations enable row level security;
alter table public.exams enable row level security;
alter table public.study_tasks enable row level security;

drop policy if exists "own semesters" on public.semesters;
create policy "own semesters" on public.semesters
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own vacations" on public.vacations;
create policy "own vacations" on public.vacations
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own exams" on public.exams;
create policy "own exams" on public.exams
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "own study tasks" on public.study_tasks;
create policy "own study tasks" on public.study_tasks
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- realtime
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here, nothing to do.';
    return;
  end if;

  -- A publication for all tables already covers these, and cannot take single
  -- tables.
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime' and puballtables
  ) then
    raise notice 'supabase_realtime already publishes every table.';
    return;
  end if;

  foreach t in array array['semesters', 'vacations', 'exams', 'study_tasks'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
