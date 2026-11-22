import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'decoding.dart';

typedef Row = Map<String, dynamic>;

/// The operations the app needs from the server. An interface so everything
/// above it can be tested without a network.
abstract class RemoteRows {
  Future<List<Row>> selectPage(
    String table, {
    required String ownerColumn,
    required String ownerId,
    required String orderColumn,
    required bool ascending,
    required int from,
    required int to,
  });

  Future<Row> upsert(String table, Row values, {String? onConflict});

  Future<Row> update(
    String table,
    String id, {
    required String ownerColumn,
    required String ownerId,
    required Row values,
  });

  Future<void> delete(
    String table,
    String id, {
    required String ownerColumn,
    required String ownerId,
  });

  /// Reachability check: a one-row read that fails only if the server does.
  Future<void> ping(String ownerId);
}

class SupabaseRemoteRows implements RemoteRows {
  SupabaseRemoteRows(this.client);

  final SupabaseClient client;

  /// A bad connection can hang rather than fail, so a request gives up after
  /// this long and the student is told the server could not be reached.
  static const Duration _timeout = Duration(seconds: 12);

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
    final rows = await client
        .from(table)
        .select()
        .eq(ownerColumn, ownerId)
        .order(orderColumn, ascending: ascending)
        // A tiebreak, so that rows sharing a value cannot move between pages.
        .order('id')
        .range(from, to)
        .timeout(_timeout);
    return asRowList(rows);
  }

  @override
  Future<Row> upsert(String table, Row values, {String? onConflict}) async {
    final row = await client
        .from(table)
        .upsert(values, onConflict: onConflict)
        .select()
        .single()
        .timeout(_timeout);
    return asRow(row);
  }

  @override
  Future<Row> update(
    String table,
    String id, {
    required String ownerColumn,
    required String ownerId,
    required Row values,
  }) async {
    final row = await client
        .from(table)
        .update(values)
        .eq('id', id)
        .eq(ownerColumn, ownerId)
        .select()
        .single()
        .timeout(_timeout);
    return asRow(row);
  }

  @override
  Future<void> delete(
    String table,
    String id, {
    required String ownerColumn,
    required String ownerId,
  }) async {
    await client
        .from(table)
        .delete()
        .eq('id', id)
        .eq(ownerColumn, ownerId)
        .timeout(_timeout);
  }

  @override
  Future<void> ping(String ownerId) async {
    await client
        .from('profiles')
        .select('id')
        .eq('id', ownerId)
        .limit(1)
        .timeout(_timeout);
  }
}
