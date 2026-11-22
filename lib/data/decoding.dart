/// Helpers for turning the untyped results of the PostgREST builder into rows.
///
/// `SupabaseClient.from()` returns a builder typed as `dynamic`, so every
/// response needs normalising in one place instead of at each call site.
List<Map<String, dynamic>> asRowList(dynamic rows) {
  if (rows is! List) return const <Map<String, dynamic>>[];
  return rows
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

Map<String, dynamic> asRow(dynamic row) {
  if (row is Map) return Map<String, dynamic>.from(row);
  throw const FormatException('Expected a single row from the database');
}
