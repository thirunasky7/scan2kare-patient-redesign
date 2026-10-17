/// User-facing error text from API JSON or thrown exceptions.
String friendlyApiError(
  dynamic data, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (data is Map) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return first.first.toString();
      }
      if (first != null && first.toString().trim().isNotEmpty) {
        return first.toString();
      }
    }
    final message = data['message']?.toString().trim() ?? '';
    if (message.isNotEmpty &&
        message.toLowerCase() != 'validation error' &&
        !message.toLowerCase().startsWith('exception:')) {
      return message;
    }
  }
  if (data is String && data.trim().isNotEmpty) {
    return data.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  }
  return fallback;
}

String friendlyException(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  return friendlyApiError(
    error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
    fallback: fallback,
  );
}
