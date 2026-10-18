/// Matches a search input to an API name, ignoring English letter case only.
/// Never use this comparison for stored identities or ownership checks.
bool matchesCharacterLookupName(String input, String apiName) {
  if (input.length != apiName.length) return false;
  int fold(int code) => code >= 65 && code <= 90 ? code + 32 : code;
  for (var i = 0; i < input.length; i++) {
    if (fold(input.codeUnitAt(i)) != fold(apiName.codeUnitAt(i))) return false;
  }
  return true;
}
