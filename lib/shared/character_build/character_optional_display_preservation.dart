import 'build_integrity_snapshot.dart';

/// 재인증 Character 전체 `set` 때 기존 선택 표시 필드를 보존한다.
///
/// 손상된 `buildIntegritySnapshot`이나 잘못된 `combatPower`는 포함하지 않는다.
Map<String, Object?> preservedOptionalCharacterDisplayFields(
  Map<String, dynamic>? existing,
) {
  if (existing == null || existing.isEmpty) {
    return const <String, Object?>{};
  }

  final preserved = <String, Object?>{};
  final combatPower = existing['combatPower'];
  if (combatPower is num) {
    final value = combatPower.toDouble();
    if (value.isFinite && value >= 0) {
      preserved['combatPower'] = combatPower;
    }
  }

  final integrityRaw = existing['buildIntegritySnapshot'];
  final parsed = BuildIntegritySnapshot.tryFromFields(
    integrityRaw,
    parseDate: _parseCheckedAt,
  );
  if (parsed != null && integrityRaw is Map) {
    preserved['buildIntegritySnapshot'] = Map<String, Object?>.from(
      integrityRaw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  return preserved;
}

DateTime? _parseCheckedAt(Object? value) {
  return switch (value) {
    DateTime dateTime => dateTime.toUtc(),
    String text => DateTime.tryParse(text)?.toUtc(),
    _ => null,
  };
}
