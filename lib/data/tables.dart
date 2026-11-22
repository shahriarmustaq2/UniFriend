import '../models/assignment.dart';
import '../models/attendance_record.dart';
import '../models/class_slot.dart';
import '../models/course.dart';
import '../models/ct_mark.dart';
import '../models/expense.dart';
import '../models/notice.dart';
import '../models/semester.dart';
import '../models/study_plan.dart';
import '../models/study_session.dart';
import 'remote_rows.dart';

/// Everything the app needs to know to read and write one table of a student's
/// rows. Adding a table means adding one of these, plus its migration.
class TableSpec<T> {
  final String name;
  final String orderColumn;
  final bool ascending;
  final T Function(Row row) decode;

  /// The row's own columns. `id` and `user_id` are filled in by the store.
  final Row Function(T item) encode;
  final String Function(T item) idOf;

  const TableSpec({
    required this.name,
    required this.decode,
    required this.encode,
    required this.idOf,
    this.orderColumn = 'created_at',
    this.ascending = false,
  });
}

class Tables {
  Tables._();

  static final semesters = TableSpec<Semester>(
    name: 'semesters',
    orderColumn: 'starts_on',
    ascending: true,
    decode: Semester.fromMap,
    encode: (s) => s.toRow(),
    idOf: (s) => s.id,
  );

  static final vacations = TableSpec<Vacation>(
    name: 'vacations',
    orderColumn: 'starts_on',
    ascending: true,
    decode: Vacation.fromMap,
    encode: (v) => v.toRow(),
    idOf: (v) => v.id,
  );

  static final courses = TableSpec<Course>(
    name: 'courses',
    decode: Course.fromMap,
    encode: (c) => c.toRow(),
    idOf: (c) => c.id,
  );

  static final assignments = TableSpec<Assignment>(
    name: 'assignments',
    orderColumn: 'due_date',
    ascending: true,
    decode: Assignment.fromMap,
    encode: (a) => a.toRow(),
    idOf: (a) => a.id,
  );

  static final notices = TableSpec<Notice>(
    name: 'notices',
    decode: Notice.fromMap,
    encode: (n) => n.toRow(),
    idOf: (n) => n.id,
  );

  static final classSlots = TableSpec<ClassSlot>(
    name: 'class_slots',
    orderColumn: 'start_minute',
    ascending: true,
    decode: ClassSlot.fromMap,
    encode: (s) => s.toRow(),
    idOf: (s) => s.id,
  );

  static final attendance = TableSpec<AttendanceRecord>(
    name: 'attendance_records',
    orderColumn: 'held_on',
    decode: AttendanceRecord.fromMap,
    encode: (r) => r.toRow(),
    idOf: (r) => r.id,
  );

  static final ctMarks = TableSpec<CtMark>(
    name: 'ct_marks',
    decode: CtMark.fromMap,
    encode: (m) => m.toRow(),
    idOf: (m) => m.id,
  );

  static final studySessions = TableSpec<StudySession>(
    name: 'study_sessions',
    orderColumn: 'studied_on',
    decode: StudySession.fromMap,
    encode: (s) => s.toRow(),
    idOf: (s) => s.id,
  );

  static final studyTasks = TableSpec<StudyTask>(
    name: 'study_tasks',
    orderColumn: 'planned_for',
    ascending: true,
    decode: StudyTask.fromMap,
    encode: (t) => t.toRow(),
    idOf: (t) => t.id,
  );

  static final exams = TableSpec<Exam>(
    name: 'exams',
    orderColumn: 'held_on',
    ascending: true,
    decode: Exam.fromMap,
    encode: (e) => e.toRow(),
    idOf: (e) => e.id,
  );

  static final expenses = TableSpec<Expense>(
    name: 'expenses',
    orderColumn: 'spent_on',
    decode: Expense.fromMap,
    encode: (e) => e.toRow(),
    idOf: (e) => e.id,
  );

  /// Every table the realtime feed listens to. `profiles` is read separately,
  /// since it holds one row keyed by the user's id.
  static const List<String> synced = [
    'profiles',
    'semesters',
    'vacations',
    'courses',
    'assignments',
    'notices',
    'class_slots',
    'attendance_records',
    'ct_marks',
    'study_sessions',
    'study_tasks',
    'exams',
    'expenses',
  ];
}
