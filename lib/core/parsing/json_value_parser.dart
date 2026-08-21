class JsonValueParser {
  const JsonValueParser._();

  static int intValue(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value is String ? value : value.toString();
  }

  static bool boolValue(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    switch (value?.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
      default:
        return fallback;
    }
  }

  static int timestampMillis(dynamic value, {int fallback = 0}) {
    final timestamp = intValue(value, fallback: fallback);
    if (timestamp > 0 && timestamp < 1000000000000) {
      return timestamp * 1000;
    }
    return timestamp;
  }

  static T enumValue<T extends Enum>(
    dynamic value,
    List<T> values, {
    required T fallback,
  }) {
    final index = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (index != null && index >= 0 && index < values.length) {
      return values[index];
    }
    final name = value?.toString().trim().toLowerCase();
    if (name != null && name.isNotEmpty) {
      for (final item in values) {
        if (item.name.toLowerCase() == name) {
          return item;
        }
      }
    }
    return fallback;
  }

  static List<dynamic> listValue(dynamic value) {
    return value is List ? value : const [];
  }

  static Map<String, dynamic>? mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
