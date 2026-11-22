-- Finishes 0004_rework.sql if its run stopped near the end: the access
-- policies for the new tables, and publishing them for live updates. Running
-- the whole of 0004 again does the same; this is the short version. Safe to run
-- more than once.

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

do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    raise notice 'No supabase_realtime publication here, nothing to do.';
    return;
  end if;

  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime' and puballtables
  ) then
    raise notice 'supabase_realtime already publishes every table.';
    return;
  end if;

  foreach t in array array[
    'profiles', 'courses', 'assignments', 'notices', 'class_slots',
    'attendance_records', 'ct_marks', 'study_sessions', 'expenses',
    'semesters', 'vacations', 'exams', 'study_tasks'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- What should now be true. Every row should say true.
select 'policies' as check, count(*) = 4 as ok
from pg_policies
where schemaname = 'public'
  and tablename in ('semesters', 'vacations', 'exams', 'study_tasks')
union all
select 'courses have a semester', not exists (
  select 1 from public.courses where semester_id is null
)
union all
select 'cancelled classes allowed', exists (
  select 1 from pg_constraint
  where conname = 'attendance_records_status_check'
    and pg_get_constraintdef(oid) like '%cancelled%'
);
