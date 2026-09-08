import '../entities/class_synergy.dart';
import '../entities/game_catalog.dart';
import '../../data/catalogs/class_synergy_catalog.dart';

/// 신청자 목록·상세에서 직업명과 특성(branchId/이름)을 받아
/// 로컬 시너지 카탈로그의 주요 시너지(isPrimary)를 반환한다.
///
/// - 서포터 역할은 딜러 시너지 대상에서 제외된다.
/// - 특성 미확인이면 공통 효과만 반환한다.
/// - 선택 채용은 실제 보유로 단정하지 않으며, 결과에 `adoption` 정보를 함께 담는다.
/// - 알 수 없는 직업이나 서포터 역할이면 빈 목록과 함께 상태를 반환한다.
class ClassSynergyService {
  const ClassSynergyService({ClassSynergyCatalog? catalog})
      : _catalog = catalog ?? const ClassSynergyCatalog();

  final ClassSynergyCatalog _catalog;

  /// [className]: Lost Ark API 직업명 또는 카탈로그 ID/별칭.
  /// [role]: `GameCatalogRole.dealer` 이외는 서포터로 보고 빈 목록을 반환한다.
  /// [branchNameOrId]: 특성 미확인이면 null. null이면 공통 효과만 반환한다.
  ///
  /// 반환값의 [ClassSynergyResolution.status]로 상태를 구분한다.
  /// 주요 시너지만 필요하면 `.primary`를, 전체(부가 포함)는 `.synergies`를 쓴다.
  ClassSynergyResolution resolve({
    required String className,
    required GameCatalogRole role,
    String? branchNameOrId,
  }) {
    return _catalog.resolve(
      classNameOrId: className,
      role: role,
      branchNameOrId: branchNameOrId,
    );
  }

  /// 항상 채용(`SynergyAdoption.always`)인 주요 시너지 레이블 목록만 반환한다.
  /// 결과가 없거나 서포터이면 빈 목록을 반환한다.
  List<String> alwaysPrimaryLabels({
    required String className,
    required GameCatalogRole role,
    String? branchNameOrId,
  }) {
    final resolution = resolve(
      className: className,
      role: role,
      branchNameOrId: branchNameOrId,
    );
    return [
      for (final synergy in resolution.primary)
        if (synergy.adoption == SynergyAdoption.always) synergy.type.label,
    ];
  }
}
