import 'package:supabase_flutter/supabase_flutter.dart';

import 'row_store.dart';
import 'tables.dart';

/// Tells the app when a row changed on the server, such as from another device.
abstract class ChangeFeed {
  /// Calls [onChange] with the table and row id of each change, and returns a
  /// function that stops listening.
  void Function() listen(
    String userId,
    void Function(String table, String? rowId, {required bool isDelete})
    onChange,
  );
}

class SupabaseChangeFeed implements ChangeFeed {
  SupabaseChangeFeed(this.client);

  final SupabaseClient client;

  @override
  void Function() listen(
    String userId,
    void Function(String table, String? rowId, {required bool isDelete})
    onChange,
  ) {
    var channel = client.channel('changes-$userId');

    for (final table in Tables.synced) {
      final ownerColumn = RowStore.ownerColumnOf(table);
      final filter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: ownerColumn,
        value: userId,
      );
      void changed(PostgresChangePayload payload) =>
          onChange(table, payload.newRecord['id'] as String?, isDelete: false);

      channel = channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: table,
            filter: filter,
            callback: changed,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            filter: filter,
            callback: changed,
          )
          // Supabase cannot filter delete events, which carry only the row id.
          // The listener checks the id against the student's own rows.
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: table,
            callback: (payload) => onChange(
              table,
              payload.oldRecord['id'] as String?,
              isDelete: true,
            ),
          );
    }

    channel.subscribe();
    return () => client.removeChannel(channel);
  }
}
