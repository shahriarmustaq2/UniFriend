-- Optional demo data so a fresh account has something on screen.
--
-- Run every migration first. Then replace the email below with your own and run
-- this in the Supabase SQL editor. It is not a migration: it touches one account
-- only, and it adds nothing if that account already has a semester, so running
-- it twice is safe.
do $$
declare
  uid uuid := (select id from auth.users where email = 'you@example.com');
  last_term uuid;
  this_term uuid;
  se uuid;
  db uuid;
  os uuid;
  os_lab uuid;
  db_lab uuid;
  ct3 uuid;
begin
  if uid is null then
    raise exception 'No account with that email. Edit the email in this script first.';
  end if;

  if exists (select 1 from public.semesters where user_id = uid) then
    raise notice 'This account already has a semester; nothing was added.';
    return;
  end if;

  insert into public.semesters (user_id, name, starts_on, classes_ended_on)
  values (uid, 'Level 2 Term 1', current_date - 200, current_date - 90)
  returning id into last_term;
  insert into public.semesters (user_id, name, starts_on)
  values (uid, 'Level 2 Term 2', current_date - 45)
  returning id into this_term;

  update public.profiles set current_semester_id = this_term, monthly_budget = 6000
  where id = uid;

  insert into public.vacations (user_id, semester_id, title, starts_on, ends_on)
  values (uid, this_term, 'Mid-term break', current_date - 20, current_date - 14);

  -- Last term, with results.
  insert into public.courses (user_id, semester_id, code, title, credits, kind, grade_points)
  values
    (uid, last_term, 'CSE2101', 'Computer Networks', 3.0, 'theory', 3.50),
    (uid, last_term, 'CSE2103', 'Networks Lab', 0.75, 'sessional', 3.75),
    (uid, last_term, 'MATH2101', 'Discrete Mathematics', 3.0, 'theory', 3.25);

  -- This term.
  insert into public.courses (user_id, semester_id, code, title, credits, kind, marks)
  values (uid, this_term, 'CSE2200', 'Software Engineering', 3.0, 'theory', '{"assignment": 8}')
  returning id into se;
  insert into public.courses (user_id, semester_id, code, title, credits, kind)
  values (uid, this_term, 'CSE2202', 'Database Systems', 3.0, 'theory')
  returning id into db;
  insert into public.courses (user_id, semester_id, code, title, credits, kind)
  values (uid, this_term, 'CSE2204', 'Operating Systems', 3.0, 'theory')
  returning id into os;
  insert into public.courses (user_id, semester_id, code, title, credits, kind, marks)
  values (uid, this_term, 'CSE2205', 'Operating Systems Lab', 0.75, 'sessional', '{"quiz": 16}')
  returning id into os_lab;
  insert into public.courses (user_id, semester_id, code, title, credits, kind)
  values (uid, this_term, 'CSE2203', 'Database Lab', 1.5, 'sessional')
  returning id into db_lab;

  -- Weekly theory classes, a weekly lab, and a 0.75 credit lab every other
  -- week counted from a class this week.
  insert into public.class_slots (user_id, course_id, weekday, start_minute, end_minute, room)
  select uid, v.course_id, v.weekday, v.start_minute, v.end_minute, v.room
  from (values
    (se, 6, 480, 530, 'Room 301'),
    (db, 6, 540, 590, 'Room 204'),
    (os, 7, 480, 530, 'Room 301'),
    (se, 1, 540, 590, 'Room 301'),
    (db, 2, 480, 530, 'Room 204'),
    (os, 3, 540, 590, 'Room 301'),
    (db_lab, 2, 600, 770, 'DB Lab')
  ) as v (course_id, weekday, start_minute, end_minute, room);

  insert into public.class_slots
    (user_id, course_id, weekday, start_minute, end_minute, room, repeat_weeks, anchor_date)
  values (
    uid, os_lab, extract(isodow from current_date)::smallint, 840, 1010, 'OS Lab', 2,
    current_date
  );

  insert into public.attendance_records (user_id, course_id, held_on, status)
  select uid, c.course_id, current_date - d.days_ago, d.status
  from (values (se), (db), (os)) as c (course_id)
  cross join (values
    (7, 'present'), (28, 'late'), (35, 'absent'), (42, 'present')
  ) as d (days_ago, status);
  insert into public.attendance_records (user_id, course_id, held_on, status)
  values (uid, se, current_date - 3, 'cancelled');

  insert into public.ct_marks (user_id, course_id, title, obtained, total, held_on)
  values
    (uid, se, 'CT 1', 17, 20, current_date - 30),
    (uid, se, 'CT 2', 14.5, 20, current_date - 10),
    (uid, db, 'CT 1', 16, 20, current_date - 25),
    (uid, os, 'CT 1', 11, 20, current_date - 8);

  insert into public.assignments (user_id, course_id, title, due_date, is_completed)
  values
    (uid, os, 'Report on page replacement', now() + interval '2 days', false),
    (uid, db, 'ER diagram', now() + interval '5 days', false),
    (uid, se, 'Sprint 4 demo', now() + interval '9 days', false),
    (uid, se, 'Sprint 3 retro', now() - interval '8 days', true);

  insert into public.exams (user_id, course_id, title, kind, held_on)
  values (uid, os, 'OS CT 2', 'ct', current_date + 4)
  returning id into ct3;
  insert into public.exams (user_id, course_id, title, kind, held_on)
  values (uid, os_lab, 'OS Lab viva', 'viva', current_date + 20);

  insert into public.study_tasks (user_id, course_id, exam_id, title, planned_for, is_done)
  values
    (uid, os, ct3, 'Deadlock detection', current_date, false),
    (uid, os, ct3, 'Banker''s algorithm', current_date + 1, false),
    (uid, db, null, 'Normal forms practice', current_date - 1, false),
    (uid, se, null, 'Read chapter 6', current_date, true);

  insert into public.study_sessions (user_id, course_id, topic, minutes, studied_on)
  values
    (uid, os, 'Scheduling algorithms', 75, current_date),
    (uid, db, 'SQL joins', 50, current_date - 1);

  insert into public.notices (user_id, title, body, is_pinned)
  values
    (uid, 'Library books due Friday', 'Return or renew everything borrowed this term.', true),
    (uid, 'Term final routine published', 'Check the notice board for rooms.', false);

  insert into public.expenses (user_id, title, amount, category, spent_on)
  values
    (uid, 'Hall dining', 1800, 'food', current_date - 3),
    (uid, 'Bus pass', 300, 'transport', current_date - 5),
    (uid, 'OS textbook', 650, 'study', current_date - 8),
    (uid, 'Mobile data pack', 299, 'mobile', current_date - 1);
end $$;
