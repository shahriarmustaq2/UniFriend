import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// True when a request failed because the server could not be reached, as
/// opposed to the server answering with an error.
bool isNetworkFailure(Object error) =>
    error is http.ClientException ||
    error is TimeoutException ||
    error is AuthRetryableFetchException;

/// The database or API error code of a failed request, if it has one.
String? postgrestCode(Object error) =>
    error is PostgrestException ? error.code : null;

/// Turns a Supabase/Postgrest failure into something worth showing a student.
String readableError(Object error) {
  if (error is NotSignedInError) {
    return 'Your session has ended. Please sign in again.';
  }
  if (isNetworkFailure(error)) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  if (error is AuthException) {
    final message = error.message;
    // Supabase repeats the status text in front of the useful part.
    final separator = message.indexOf(': ');
    return separator == -1 ? message : message.substring(separator + 2);
  }
  if (error is PostgrestException) {
    switch (error.code) {
      case '42501':
        return 'You do not have access to that.';
      case '23503':
        return 'That item is still linked to something else.';
      case '23505':
        return 'That already exists.';
      case '23514':
        return 'One of the values is outside the allowed range.';
      case 'PGRST116':
        return 'That item no longer exists.';
      // The app is newer than the database: a migration has not been run yet.
      case 'PGRST205':
      case '42P01':
      case '42703':
      case 'PGRST204':
        return 'This feature needs a database update. See docs/SETUP.md.';
      default:
        return error.message;
    }
  }
  if (error is StateError) return error.message;
  if (error is FormatException) return 'The server sent an unexpected reply.';
  return 'Something went wrong. Please try again.';
}

/// Thrown when a request is attempted without an active session. Kept distinct
/// from a network failure so it gets its own message.
class NotSignedInError implements Exception {
  const NotSignedInError();

  @override
  String toString() => 'NotSignedInError';
}
