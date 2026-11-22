import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'errors.dart';
import 'remote_rows.dart';

/// Every read and write goes through here.
///
/// Reads are saved on the device, and that copy is shown when the server cannot
/// be reached, so the app stays readable offline. Writes go straight to the
/// server: offline they fail with a clear message instead of being queued. That
/// trade keeps this class small and leaves nothing to reconcile later.
class RowStore extends ChangeNotifier {
  RowStore({
    required this.remote,
    required this.prefs,
    required this.currentUserId,
  });

  final RemoteRows remote;
  final SharedPreferences prefs;
  final String? Function() currentUserId;

  static const Uuid _uuid = Uuid();
  static const int _pageSize = 1000;
  static const Duration _ownWriteWindow = Duration(seconds: 10);

  final Map<String, DateTime> _ownWrites = {};
  bool _isOffline = false;

  /// True after the server could not be reached, until it next can.
  bool get isOffline => _isOffline;

  String requireUserId() {
    final id = currentUserId();
    if (id == null) throw const NotSignedInError();
    return id;
  }

  /// `profiles` is the one table keyed by the user's own id.
  static String ownerColumnOf(String table) =>
      table == 'profiles' ? 'id' : 'user_id';

  void _setOffline(bool value) {
    if (_isOffline == value) return;
    _isOffline = value;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  /// All of the student's rows in [table], fetched page by page because the
  /// server returns at most 1000 rows per request.
  ///
  /// Falls back to the saved copy when offline. With no saved copy the failure
  /// is rethrown, because an empty list would claim there is no data.
  Future<List<Row>> fetch(
    String table, {
    required String orderColumn,
    bool ascending = false,
  }) async {
    final user = requireUserId();
    try {
      final rows = <Row>[];
      while (true) {
        final page = await remote.selectPage(
          table,
          ownerColumn: ownerColumnOf(table),
          ownerId: user,
          orderColumn: orderColumn,
          ascending: ascending,
          from: rows.length,
          to: rows.length + _pageSize - 1,
        );
        rows.addAll(page);
        if (page.length < _pageSize) break;
      }
      await _writeCache(user, table, rows);
      _setOffline(false);
      return rows;
    } catch (error) {
      if (!isNetworkFailure(error)) rethrow;
      _setOffline(true);
      final saved = _readCache(user, table);
      if (saved == null) rethrow;
      return saved;
    }
  }

  // -------------------------------------------------------------------------
  // Writes
  // -------------------------------------------------------------------------

  /// Creates a row owned by the signed-in student.
  Future<Row> insert(String table, Row values) {
    final user = requireUserId();
    return _send(
      table,
      () =>
          remote.upsert(table, {...values, 'id': _uuid.v4(), 'user_id': user}),
    );
  }

  /// Creates a row, or updates the one matching [keyColumns].
  Future<Row> upsertByKey(
    String table,
    Row values, {
    required List<String> keyColumns,
  }) {
    final user = requireUserId();
    return _send(
      table,
      () => remote.upsert(table, {
        ...values,
        'user_id': user,
      }, onConflict: keyColumns.join(',')),
    );
  }

  /// Writes the row whose primary key is already known, such as a profile.
  Future<Row> put(String table, String id, Row values) {
    return _send(table, () => remote.upsert(table, {...values, 'id': id}));
  }

  Future<Row> update(String table, String id, Row values) {
    final user = requireUserId();
    return _send(
      table,
      () => remote.update(
        table,
        id,
        ownerColumn: ownerColumnOf(table),
        ownerId: user,
        values: values,
      ),
    );
  }

  Future<void> delete(String table, String id) async {
    final user = requireUserId();
    _ownWrites[id] = DateTime.now();
    await _guard(
      () => remote.delete(
        table,
        id,
        ownerColumn: ownerColumnOf(table),
        ownerId: user,
      ),
    );
    final saved = _readCache(user, table);
    if (saved != null) {
      await _writeCache(
        user,
        table,
        saved.where((r) => r['id'] != id).toList(),
      );
    }
  }

  Future<Row> _send(String table, Future<Row> Function() write) async {
    final user = requireUserId();
    final row = await _guard(write);
    final id = row['id'] as String?;
    if (id != null) _ownWrites[id] = DateTime.now();

    final saved = _readCache(user, table);
    if (saved != null) {
      await _writeCache(user, table, [
        ...saved.where((r) => r['id'] != id),
        row,
      ]);
    }
    return row;
  }

  /// Runs a request and keeps [isOffline] honest about how it went.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      final result = await request();
      _setOffline(false);
      return result;
    } catch (error) {
      if (isNetworkFailure(error)) _setOffline(true);
      rethrow;
    }
  }

  /// Checks whether the server is back. Only meaningful while offline.
  Future<void> checkConnection() async {
    final user = currentUserId();
    if (user == null) return;
    try {
      await remote.ping(user);
      _setOffline(false);
    } catch (error) {
      if (isNetworkFailure(error)) _setOffline(true);
    }
  }

  /// True briefly after this device wrote the row, so its own change arriving
  /// back over the realtime feed does not cause a pointless reload.
  bool isOwnRecentWrite(String id) {
    final at = _ownWrites[id];
    if (at == null) return false;
    if (DateTime.now().difference(at) > _ownWriteWindow) {
      _ownWrites.remove(id);
      return false;
    }
    return true;
  }

  /// Whether [id] is one of the signed-in student's saved rows in [table].
  bool hasSavedRow(String table, String id) {
    final user = currentUserId();
    if (user == null) return false;
    return _readCache(user, table)?.any((r) => r['id'] == id) ?? false;
  }

  /// Removes everything saved on the device for [user]. Run on sign-out, so the
  /// next person on this device cannot find the data.
  Future<void> clearUser(String user) async {
    final prefix = _cachePrefix(user);
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      await prefs.remove(key);
    }
    // Left behind by the old offline outbox, if this device ever had one.
    await prefs.remove('outbox.$user');
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Storage on the device
  // -------------------------------------------------------------------------

  static String _cachePrefix(String user) => 'rows.$user.';

  List<Row>? _readCache(String user, String table) {
    final raw = prefs.getString('${_cachePrefix(user)}$table');
    if (raw == null) return null;
    return (jsonDecode(raw) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _writeCache(String user, String table, List<Row> rows) {
    return prefs.setString('${_cachePrefix(user)}$table', jsonEncode(rows));
  }
}
