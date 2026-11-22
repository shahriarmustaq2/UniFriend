import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:unifriend/data/errors.dart';
import 'package:unifriend/data/row_store.dart';

import 'support/fakes.dart';

void main() {
  late InMemoryRemote remote;
  late RowStore store;
  String? user = 'a';

  setUp(() async {
    await resetDeviceStorage();
    remote = InMemoryRemote();
    user = 'a';
    store = RowStore(
      remote: remote,
      prefs: testPrefs,
      currentUserId: () => user,
    );
  });

  Future<List<Map<String, dynamic>>> fetchNotes() =>
      store.fetch('notices', orderColumn: 'created_at');

  group('reading', () {
    test('only returns the signed-in student\'s rows', () async {
      remote.rows('notices').addAll([
        {'id': '1', 'user_id': 'a', 'title': 'mine'},
        {'id': '2', 'user_id': 'b', 'title': 'theirs'},
      ]);
      final rows = await fetchNotes();
      expect(rows.map((r) => r['title']), ['mine']);
    });

    test('offline, it shows the copy saved on the device', () async {
      remote.rows('notices').add({'id': '1', 'user_id': 'a', 'title': 'saved'});
      await fetchNotes();
      remote.offline = true;

      final rows = await fetchNotes();
      expect(rows.single['title'], 'saved');
      expect(store.isOffline, isTrue);
    });

    test(
      'offline with nothing saved, it fails rather than claim no data',
      () async {
        remote.offline = true;
        expect(fetchNotes, throwsA(isA<http.ClientException>()));
      },
    );

    test('a server error is not hidden behind the saved copy', () async {
      await fetchNotes();
      remote.failReads = true;
      expect(fetchNotes, throwsA(isA<PostgrestException>()));
    });

    test('coming back online clears the offline flag', () async {
      await fetchNotes();
      remote.offline = true;
      await fetchNotes();
      remote.offline = false;
      await store.checkConnection();
      expect(store.isOffline, isFalse);
    });

    test('reads every page of a large table', () async {
      for (var i = 0; i < 2500; i++) {
        remote.rows('notices').add({'id': '$i', 'user_id': 'a'});
      }
      expect(await fetchNotes(), hasLength(2500));
    });
  });

  group('writing', () {
    test('a new row gets its id and owner here', () async {
      final row = await store.insert('notices', {'title': 'Hi'});
      expect(row['id'], isA<String>());
      expect(row['user_id'], 'a');
      expect(remote.rows('notices').single['title'], 'Hi');
    });

    test('offline, a write fails clearly and nothing is queued', () async {
      remote.offline = true;
      await expectLater(
        store.insert('notices', {'title': 'Hi'}),
        throwsA(predicate((Object e) => isNetworkFailure(e))),
      );
      expect(store.isOffline, isTrue);
      remote.offline = false;
      await store.checkConnection();
      expect(remote.rows('notices'), isEmpty);
    });

    test('saved writes update the copy on the device', () async {
      await fetchNotes();
      final row = await store.insert('notices', {'title': 'Hi'});
      await store.update('notices', row['id'] as String, {'title': 'Bye'});
      remote.offline = true;
      expect((await fetchNotes()).single['title'], 'Bye');

      remote.offline = false;
      await store.delete('notices', row['id'] as String);
      remote.offline = true;
      expect(await fetchNotes(), isEmpty);
    });

    test('upserting by key corrects the row instead of adding one', () async {
      const key = ['user_id', 'course_id', 'held_on', 'session'];
      final values = {
        'course_id': 'c',
        'held_on': '2026-11-20',
        'session': 1,
        'status': 'present',
      };
      await store.upsertByKey('attendance_records', values, keyColumns: key);
      await store.upsertByKey('attendance_records', {
        ...values,
        'status': 'absent',
      }, keyColumns: key);
      expect(remote.rows('attendance_records'), hasLength(1));
      expect(remote.rows('attendance_records').single['status'], 'absent');
    });

    test(
      'a write is remembered briefly, so its realtime echo is ignored',
      () async {
        final row = await store.insert('notices', {'title': 'Hi'});
        expect(store.isOwnRecentWrite(row['id'] as String), isTrue);
        expect(store.isOwnRecentWrite('someone-else'), isFalse);
      },
    );

    test('nothing can be written while signed out', () async {
      user = null;
      expect(
        () => store.insert('notices', {'title': 'Hi'}),
        throwsA(isA<NotSignedInError>()),
      );
    });
  });

  group('accounts on one device', () {
    test('each student has their own saved copy', () async {
      remote.rows('notices').addAll([
        {'id': '1', 'user_id': 'a', 'title': 'A'},
        {'id': '2', 'user_id': 'b', 'title': 'B'},
      ]);
      await fetchNotes();
      user = 'b';
      await fetchNotes();

      remote.offline = true;
      expect((await fetchNotes()).single['title'], 'B');
      user = 'a';
      expect((await fetchNotes()).single['title'], 'A');
    });

    test('signing out wipes only that student\'s copy', () async {
      remote.rows('notices').addAll([
        {'id': '1', 'user_id': 'a'},
        {'id': '2', 'user_id': 'b'},
      ]);
      await fetchNotes();
      user = 'b';
      await fetchNotes();
      await testPrefs.setString('outbox.a', '[]');

      await store.clearUser('a');
      expect(
        testPrefs.getKeys().where((k) => k.contains('.a.') || k == 'outbox.a'),
        isEmpty,
      );
      expect(store.hasSavedRow('notices', '2'), isTrue);
    });
  });
}
