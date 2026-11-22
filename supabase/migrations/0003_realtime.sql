-- Publishes changes so that one device sees another's edits without a reload.
-- Row level security still decides who receives what.
--
-- Run this after 0002_student_companion.sql. It is safe to run more than once.
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

  foreach t in array array[
    'profiles', 'courses', 'assignments', 'notices', 'class_slots',
    'attendance_records', 'ct_marks', 'study_sessions', 'expenses'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
