import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote_rows.dart';
import '../data/row_store.dart';
import '../data/tables.dart';
import 'core_providers.dart';

/// One student's rows of a table, held in memory, with create, update and
/// delete. Each feature's notifier only names its table and its sort order.
///
/// Watching the user id is what keeps accounts apart: signing in as somebody
/// else rebuilds the list, so nobody ever sees the previous student's data.
///
/// Mutations apply the row the database returned rather than refetching the
/// table. A write that succeeded therefore cannot be reported as a failure just
/// because a follow-up read failed, which would invite a duplicate retry.
abstract class PersonalListNotifier<T> extends AsyncNotifier<List<T>> {
  TableSpec<T> get spec;
  int compare(T a, T b);

  RowStore get store => ref.read(rowStoreProvider);

  @override
  Future<List<T>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return <T>[];
    final rows = await ref
        .read(rowStoreProvider)
        .fetch(
          spec.name,
          orderColumn: spec.orderColumn,
          ascending: spec.ascending,
        );
    return rows.map(spec.decode).toList()..sort(compare);
  }

  /// Saves a new row. The id on [draft] is ignored.
  Future<T> insert(T draft) async {
    final saved = spec.decode(
      await store.insert(spec.name, spec.encode(draft)),
    );
    applyLocal(saved);
    return saved;
  }

  /// Saves every column of an existing row.
  Future<T> save(T item) => patch(spec.idOf(item), spec.encode(item));

  /// Changes some columns of the row with [id].
  Future<T> patch(String id, Row values) async {
    final saved = spec.decode(await store.update(spec.name, id, values));
    applyLocal(saved);
    return saved;
  }

  Future<void> delete(String id) async {
    await store.delete(spec.name, id);
    removeLocal(id);
  }

  T? byId(String id) =>
      state.value?.where((item) => spec.idOf(item) == id).firstOrNull;

  /// Adds [item], or replaces the row that has the same id.
  void applyLocal(T item) {
    final id = spec.idOf(item);
    final others = (state.value ?? <T>[]).where((e) => spec.idOf(e) != id);
    state = AsyncData([...others, item]..sort(compare));
  }

  void removeLocal(String id) {
    final current = state.value ?? <T>[];
    state = AsyncData(current.where((e) => spec.idOf(e) != id).toList());
  }
}
