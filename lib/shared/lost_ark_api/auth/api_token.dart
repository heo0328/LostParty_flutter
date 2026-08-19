class ApiToken {
  factory ApiToken(String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) {
      throw const FormatException('API token must not be empty.');
    }

    return ApiToken._(normalizedValue);
  }

  const ApiToken._(this.value);

  final String value;

  String get authorizationHeaderValue => 'bearer $value';

  @override
  String toString() => 'ApiToken(***)';
}
