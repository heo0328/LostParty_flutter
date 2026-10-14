import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_visibility_write_plan.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_create_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_visibility_command.dart';

void main() {
  test('그룹 전용으로 바꾸면 listing을 만들고 모집 visibility만 패치한다', () {
    final plan = PartyVisibilityWritePlan.change(
      visibility: RecruitmentVisibility.group,
      recruitmentRevision: 4,
      serverTimestamp: 'server-ts',
      currentRecruitment: {
        'title': '방',
        'visibility': RecruitmentVisibility.public,
        'groupId': 'group-1',
        'revision': 4,
      },
    );

    expect(plan.recruitmentPatch['visibility'], RecruitmentVisibility.group);
    expect(plan.recruitmentPatch['revision'], 5);
    expect(plan.deleteListing, isFalse);
    expect(plan.listingDocument?['visibility'], RecruitmentVisibility.group);
    expect(plan.listingDocument?['groupId'], 'group-1');
    expect(plan.listingDocument?['title'], '방');
  });

  test('전체 공개로 바꾸면 listing을 삭제한다', () {
    final plan = PartyVisibilityWritePlan.change(
      visibility: RecruitmentVisibility.public,
      recruitmentRevision: 2,
      serverTimestamp: 'server-ts',
      currentRecruitment: {
        'visibility': RecruitmentVisibility.group,
        'groupId': 'group-1',
      },
    );

    expect(plan.recruitmentPatch['visibility'], RecruitmentVisibility.public);
    expect(plan.listingDocument, isNull);
    expect(plan.deleteListing, isTrue);
  });

  test('비그룹원은 그룹 전용에선 못 보고, 해제하면 보이며, 다시 켜면 숨는다', () {
    var recruitment = <String, Object?>{
      'schemaVersion': 1,
      'visibility': RecruitmentVisibility.group,
      'groupId': 'group-1',
      'status': 'active',
      'revision': 1,
    };
    Map<String, Object?>? listing = Map<String, Object?>.from(recruitment);

    expect(_visibleToNonGroupMember(recruitment), isFalse);
    expect(listing['visibility'], RecruitmentVisibility.group);

    final toPublic = PartyVisibilityWritePlan.change(
      visibility: RecruitmentVisibility.public,
      recruitmentRevision: 1,
      serverTimestamp: 'ts-2',
      currentRecruitment: recruitment,
    );
    recruitment = {...recruitment, ...toPublic.recruitmentPatch};
    listing = toPublic.deleteListing ? null : listing;
    expect(_visibleToNonGroupMember(recruitment), isTrue);
    expect(listing, isNull);

    final toGroup = PartyVisibilityWritePlan.change(
      visibility: RecruitmentVisibility.group,
      recruitmentRevision: 2,
      serverTimestamp: 'ts-3',
      currentRecruitment: recruitment,
    );
    recruitment = {...recruitment, ...toGroup.recruitmentPatch};
    listing = toGroup.listingDocument;
    expect(_visibleToNonGroupMember(recruitment), isFalse);
    expect(listing?['visibility'], RecruitmentVisibility.group);
    expect(toGroup.deleteListing, isFalse);
  });

  test('잘못된 visibility는 거절한다', () {
    expect(
      const PartyVisibilityCommandValidator().validate(
        const PartyVisibilityCommand(
          recruitmentId: 'raid-1',
          visibility: 'hidden',
          expectedRecruitmentRevision: 1,
        ),
      ),
      PartyVisibilityFailure.invalidRequest,
    );
    expect(
      const PartyVisibilityCommandValidator().validate(
        const PartyVisibilityCommand(
          recruitmentId: 'raid-1',
          visibility: RecruitmentVisibility.public,
          expectedRecruitmentRevision: 1,
        ),
      ),
      isNull,
    );
  });
}

bool _visibleToNonGroupMember(Map<String, Object?> recruitment) =>
    recruitment['visibility'] == RecruitmentVisibility.public;
