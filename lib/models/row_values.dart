import '../utils/date_utils.dart';

/// Sentinel that lets a `copyWith` tell "leave unchanged" apart from "set this
/// nullable field back to null".
const Object unset = Object();

/// `created_at` and other timestamps, read as local time.
DateTime readInstant(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();

/// A `date` column, which carries no time zone.
DateTime? readDate(Object? value) =>
    value == null ? null : AppDate.fromDbDate(value as String);

String? writeDate(DateTime? value) =>
    value == null ? null : AppDate.toDbDate(value);

/// Trimmed text, with blank read as null.
String? readText(Object? value) {
  final text = (value as String?)?.trim();
  return (text == null || text.isEmpty) ? null : text;
}

double? readDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
