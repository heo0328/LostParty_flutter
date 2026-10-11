/// A failed room does not invalidate successfully repaired rooms or the list stream.
class PartyRaidListingBackfillFailure implements Exception {
  PartyRaidListingBackfillFailure(
    this.completed,
    this.unattempted,
    Map<String, String> failures,
  ) : failures = Map.unmodifiable(failures);

  final int completed;
  final int unattempted;
  final Map<String, String> failures;

  @override
  String toString() =>
      '목록 보정: 처리 $completed, 실패 ${failures.length}, '
      '미시도 $unattempted, 유형 ${failures.values.toSet().join(', ')}';
}
