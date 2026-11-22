import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState, PostgrestException;
import 'package:unifriend/data/auth_repository.dart';
import 'package:unifriend/data/change_feed.dart';
import 'package:unifriend/data/reminder_gateway.dart';
import 'package:unifriend/data/remote_rows.dart';
import 'package:unifriend/providers/core_providers.dart';
import 'package:unifriend/providers/reminder_providers.dart';
import 'package:unifriend/providers/sync_providers.dart';
import 'package:unifriend/utils/date_utils.dart';
import 'package:unifriend/utils/reminder_plan.dart';

late SharedPreferences testPrefs;

/// Fresh device storage. Call from `setUp`.
Future<void> resetDeviceStorage() async {
  SharedPreferences.setMockInitialValues({});
  testPrefs = await SharedPreferences.getInstance();
}

int _nextId = 0;
String newId() => 'id-${++_nextId}';

/// Everything behind the app in one place: an in-memory server that behaves
/// like the database, plus fake realtime, notifications and auth. The app's
/// real store and notifiers run on top of it.
class FakeBackend {
  String? user;
  final remote = InMemoryRemote();
  final feed = FakeChangeFeed();
  final reminders = FakeReminderGateway();
  final auth = FakeAuth();

  /// Makes every read fail the way a server error would (not a lost
  /// connection, which falls back to the saved copy).
  set failReads(bool value) => remote.failReads = value;

  /// How many pages were read from the server, across all tables.
  int get reads => remote.reads;

  /// Adds a row for the current [user], as the database would store it.
  Row add(String table, Row values) {
    final row = <String, dynamic>{
      'id': newId(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      if (table != 'profiles') 'user_id': user,
      ...values,
    };
    remote.rows(table).add(row);
    return row;
  }

  /// The current [user]'s rows of [table].
  List<Row> rows(String table) {
    final owner = table == 'profiles' ? 'id' : 'user_id';
    return remote.rows(table).where((r) => r[owner] == user).toList();
  }

  List<Override> get overrides => [
    sharedPreferencesProvider.overrideWithValue(testPrefs),
    remoteRowsProvider.overrideWithValue(remote),
    changeFeedProvider.overrideWithValue(feed),
    reminderGatewayProvider.overrideWithValue(reminders),
    authRepositoryProvider.overrideWithValue(auth),
    currentUserProvider.overrideWithValue(null),
    currentUserIdProvider.overrideWith((ref) => ref.watch(testUserProvider)),
    testUserProvider.overrideWith(() => TestUser(user)),
  ];
}

/// Who the fake session belongs to. Tests change it to simulate auth events.
final testUserProvider = NotifierProvider<TestUser, String?>(
  () => TestUser(null),
);

class TestUser extends Notifier<String?> {
  final String? initial;

  TestUser(this.initial);

  @override
  String? build() => initial;

  void set(String? user) => state = user;
}

/// A semester under way, with a theory course, a second theory course, an
/// alternate-week lab, and an older graded course in last semester. Every
/// course has a class today.
SeededData seed(FakeBackend db, String user) {
  final previous = db.user;
  db.user = user;
  final now = DateTime.now();
  final today = AppDate.dayOf(now);
  String day(DateTime d) => AppDate.toDbDate(d);

  final older = db.add('semesters', {
    'name': 'Level 1 Term 2',
    'starts_on': day(AppDate.addDays(today, -200)),
    'classes_ended_on': day(AppDate.addDays(today, -90)),
  });
  final semester = db.add('semesters', {
    'name': 'Level 2 Term 1',
    'starts_on': day(AppDate.addDays(today, -40)),
    'classes_ended_on': null,
  });
  db.add('profiles', {
    'id': user,
    'full_name': 'Test Student',
    'monthly_budget': 5000,
    'weekly_study_goal_minutes': 600,
    'current_semester_id': semester['id'],
  });

  Row course(
    String code,
    String title, {
    String kind = 'theory',
    double credits = 3,
    double? grade,
    Map<String, double> marks = const {},
    String? semesterId,
  }) => db.add('courses', {
    'code': code,
    'title': title,
    'credits': credits,
    'kind': kind,
    'semester_id': semesterId ?? semester['id'],
    'grade_points': grade,
    'marks': marks,
    'classes_ended_on': null,
  });

  final se = course(
    'CSE2100',
    'Software Engineering with a very long course title indeed',
    marks: {'assignment': 9},
  );
  final os = course('CSE2104', 'Operating Systems');
  final lab = course(
    'CSE2102',
    'Operating Systems Lab',
    kind: 'sessional',
    credits: 0.75,
  );
  course(
    'CSE1101',
    'Structured Programming',
    grade: 3.75,
    semesterId: older['id'] as String,
  );

  Row slot(Row course, int start, int end, {int repeat = 1, String? room}) =>
      db.add('class_slots', {
        'course_id': course['id'],
        'weekday': now.weekday,
        'start_minute': start,
        'end_minute': end,
        'room': room,
        'repeat_weeks': repeat,
        'anchor_date': repeat == 2 ? day(today) : null,
      });

  slot(se, 480, 530, room: 'Room 301');
  slot(os, 600, 650);
  slot(lab, 840, 1010, repeat: 2, room: 'OS Lab');

  for (var i = 1; i <= 4; i++) {
    db.add('attendance_records', {
      'course_id': os['id'],
      'held_on': day(AppDate.addDays(today, -7 * i)),
      'session': 1,
      'status': i == 1 ? 'present' : 'absent',
    });
  }
  db.add('attendance_records', {
    'course_id': se['id'],
    'held_on': day(AppDate.addDays(today, -7)),
    'session': 1,
    'status': 'present',
  });
  for (var i = 1; i <= 4; i++) {
    db.add('ct_marks', {
      'course_id': se['id'],
      'title': 'CT $i',
      'obtained': 12.5 + i,
      'total': 20,
      'held_on': day(today),
      'created_at': now.add(Duration(seconds: i)).toUtc().toIso8601String(),
    });
  }
  db.add('assignments', {
    'course_id': se['id'],
    'title': 'Sprint demo',
    'due_date': AppDate.addDays(today, 2).toUtc().toIso8601String(),
    'is_completed': false,
  });
  db.add('assignments', {
    'course_id': os['id'],
    'title': 'Lab report that is already late',
    'due_date': AppDate.addDays(today, -2).toUtc().toIso8601String(),
    'is_completed': false,
  });
  db.add('notices', {
    'title': 'Midterm schedule',
    'body': 'Check the board',
    'is_pinned': true,
  });
  final exam = db.add('exams', {
    'course_id': os['id'],
    'title': 'OS CT 3',
    'kind': 'ct',
    'held_on': day(AppDate.addDays(today, 3)),
  });
  db.add('study_tasks', {
    'course_id': os['id'],
    'exam_id': exam['id'],
    'title': 'Page replacement',
    'planned_for': day(today),
    'is_done': false,
  });
  db.add('study_sessions', {
    'course_id': os['id'],
    'topic': 'Scheduling',
    'minutes': 75,
    'studied_on': day(today),
    'notes': null,
  });
  db.add('expenses', {
    'title': 'Hall dining',
    'amount': 1800,
    'category': 'food',
    'spent_on': day(today),
    'note': null,
  });
  db.user = previous;
  return SeededData(
    semesterId: semester['id'] as String,
    seId: se['id'] as String,
    osId: os['id'] as String,
    labId: lab['id'] as String,
  );
}

class SeededData {
  final String semesterId;
  final String seId;
  final String osId;
  final String labId;

  const SeededData({
    required this.semesterId,
    required this.seId,
    required this.osId,
    required this.labId,
  });
}

/// Phone-sized, with overflow reported as a test failure by default.
void usePhoneScreen(WidgetTester tester, {Size size = const Size(360, 740)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Swaps the test framework's blocky placeholder font for the Roboto the app
/// really uses, so an overflow reported here is one a student would see.
Future<void> loadRealFont() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('Run these tests with flutter test');
  final fonts = Directory('$root/bin/cache/artifacts/material_fonts');
  final loader = FontLoader('Roboto');
  for (final name in ['Regular', 'Medium', 'Bold']) {
    final file = File('${fonts.path}/Roboto-$name.ttf');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
  }
  await loader.load();
}

/// A server held in memory. It applies the same cascades as the real schema,
/// and tests can take it offline or make it refuse writes.
class InMemoryRemote implements RemoteRows {
  final Map<String, List<Row>> tables = {};
  bool offline = false;
  bool failReads = false;
  int reads = 0;

  /// When set, every write fails with this database error code.
  String? rejectCode;

  /// Writes the server applied, in order, as (kind, table, id).
  final List<(String, String, String?)> log = [];

  List<Row> rows(String table) => tables.putIfAbsent(table, () => []);

  void _checkOnline() {
    if (offline) throw http.ClientException('offline');
  }

  void _checkWrite() {
    _checkOnline();
    final code = rejectCode;
    if (code != null) throw PostgrestException(message: 'no', code: code);
  }

  @override
  Future<List<Row>> selectPage(
    String table, {
    required String ownerColumn,
    required String ownerId,
    required String orderColumn,
    required bool ascending,
    required int from,
    required int to,
  }) async {
    _checkOnline();
    reads++;
    if (failReads) {
      throw PostgrestException(message: 'read failed', code: '500');
    }
    final mine = rows(table).where((r) => r[ownerColumn] == ownerId).toList();
    if (from >= mine.length) return [];
    return [
      for (final row in mine.sublist(
        from,
        to + 1 > mine.length ? mine.length : to + 1,
      ))
        Map.of(row),
    ];
  }

  @override
  Future<Row> upsert(String table, Row values, {String? onConflict}) async {
    _checkWrite();
    final keys = onConflict?.split(',') ?? const ['id'];
    final list = rows(table);
    final at = list.indexWhere((r) => keys.every((k) => r[k] == values[k]));
    late Row row;
    if (at >= 0) {
      row = {...list[at], ...values};
      list[at] = row;
    } else {
      row = {
        'id': values['id'] ?? newId(),
        'created_at': '2026-11-01T10:00:00Z',
        ...values,
      };
      list.add(row);
    }
    log.add(('upsert', table, row['id'] as String?));
    return Map.of(row);
  }

  @override
  Future<Row> update(
    String table,
    String id, {
    required String ownerColumn,
    required String ownerId,
    required Row values,
  }) async {
    _checkWrite();
    final list = rows(table);
    final at = list.indexWhere(
      (r) => r['id'] == id && r[ownerColumn] == ownerId,
    );
    if (at < 0) throw PostgrestException(message: 'gone', code: 'PGRST116');
    list[at] = {...list[at], ...values};
    log.add(('update', table, id));
    return Map.of(list[at]);
  }

  @override
  Future<void> delete(
    String table,
    String id, {
    required String ownerColumn,
    required String ownerId,
  }) async {
    _checkWrite();
    final removed = rows(table)
        .where((r) => r['id'] == id && r[ownerColumn] == ownerId);
    if (removed.isEmpty) return;
    rows(table).removeWhere((r) => r['id'] == id);
    log.add(('delete', table, id));
    _cascade(table, id);
  }

  /// What the foreign keys in the migrations do.
  void _cascade(String table, String id) {
    void clear(String child, String column) {
      for (final row in rows(child)) {
        if (row[column] == id) row[column] = null;
      }
    }

    switch (table) {
      case 'semesters':
        rows('vacations').removeWhere((r) => r['semester_id'] == id);
        clear('profiles', 'current_semester_id');
        final courses = rows('courses')
            .where((r) => r['semester_id'] == id)
            .toList();
        rows('courses').removeWhere((r) => r['semester_id'] == id);
        for (final course in courses) {
          _cascade('courses', course['id'] as String);
        }
      case 'courses':
        for (final child in const [
          'assignments',
          'class_slots',
          'attendance_records',
          'ct_marks',
        ]) {
          rows(child).removeWhere((r) => r['course_id'] == id);
        }
        clear('study_sessions', 'course_id');
        clear('study_tasks', 'course_id');
        clear('exams', 'course_id');
      case 'exams':
        clear('study_tasks', 'exam_id');
    }
  }

  @override
  Future<void> ping(String ownerId) async => _checkOnline();
}

class FakeChangeFeed implements ChangeFeed {
  void Function(String table, String? rowId, {required bool isDelete})?
  _listener;
  int stops = 0;

  bool get isListening => _listener != null;

  void emit(String table, String? rowId, {bool isDelete = false}) =>
      _listener?.call(table, rowId, isDelete: isDelete);

  @override
  void Function() listen(
    String userId,
    void Function(String table, String? rowId, {required bool isDelete})
    onChange,
  ) {
    _listener = onChange;
    return () {
      _listener = null;
      stops++;
    };
  }
}

class FakeReminderGateway implements ReminderGateway {
  List<PlannedReminder> scheduled = [];
  int writes = 0;
  bool permission = true;
  int tests = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<String> get tappedRoutes => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async {
    scheduled = plan;
    writes++;
  }

  @override
  Future<void> cancelAll() async => scheduled = [];

  @override
  Future<void> showTest() async => tests++;
}

class FakeAuth extends Fake implements AuthRepository {
  final List<String> resetEmails = [];
  final List<String> newPasswords = [];
  int signOuts = 0;
  Stream<AuthState> events = const Stream.empty();

  @override
  Stream<AuthState> get authStateChanges => events;

  @override
  Future<void> sendPasswordReset(String email) async => resetEmails.add(email);

  @override
  Future<void> updatePassword(String password) async =>
      newPasswords.add(password);

  @override
  Future<void> signOut() async => signOuts++;
}

const AuthState recoveryEvent = AuthState(
  AuthChangeEvent.passwordRecovery,
  null,
);
