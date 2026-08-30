import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/group_join_command.dart';
import '../mappers/group_document_mapper.dart';

/// 계약 §2. 모든 그룹 명령은 `AuthUid -> PlayerId` active binding과 Player
/// active 상태를 Transaction 안에서 먼저 확정한 뒤 명령별 읽기를 시작한다.
class GroupCommandRunner {
  const GroupCommandRunner({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Future<GroupJoinCommandResult> run(
    Future<GroupJoinCommandResult> Function(Transaction, String) action,
  ) => runMapped(
    onAuthFailure: GroupJoinCommandResult.failure,
    onContractFailure: () =>
        const GroupJoinCommandResult.failure(GroupJoinFailure.unknown),
    onInvalidRequest: () =>
        const GroupJoinCommandResult.failure(GroupJoinFailure.invalidRequest),
    onFirebaseFailure: (code) =>
        GroupJoinCommandResult.failure(groupFirebaseFailure(code)),
    onUnknownFailure: () =>
        const GroupJoinCommandResult.failure(GroupJoinFailure.unknown),
    action: action,
  );

  /// 초대코드 등 결과 타입이 다른 명령이 binding 부트스트랩을 재사용한다.
  Future<T> runMapped<T>({
    required T Function(GroupJoinFailure) onAuthFailure,
    required T Function() onContractFailure,
    required T Function() onInvalidRequest,
    required T Function(String code) onFirebaseFailure,
    required T Function() onUnknownFailure,
    required Future<T> Function(Transaction, String) action,
  }) async {
    final authUid = _firebaseAuth.currentUser?.uid;
    if (authUid == null) {
      return onAuthFailure(GroupJoinFailure.unauthenticated);
    }
    try {
      return await _firestore.runTransaction((transaction) async {
        final binding = await transaction.get(
          _firestore.collection('authBindings').doc(authUid),
        );
        final bindingData = binding.data();
        final playerId = bindingData?['playerId'];
        if (bindingData?['status'] != 'active' ||
            playerId is! String ||
            playerId.isEmpty) {
          return onAuthFailure(GroupJoinFailure.playerBindingMissing);
        }
        final player = await transaction.get(
          _firestore.collection('players').doc(playerId),
        );
        if (player.data()?['status'] != 'active') {
          return onAuthFailure(GroupJoinFailure.playerBindingMissing);
        }
        return action(transaction, playerId);
      });
    } on GroupContractException {
      return onContractFailure();
    } on ArgumentError {
      return onInvalidRequest();
    } on StateError {
      return onInvalidRequest();
    } on FirebaseException catch (error) {
      return onFirebaseFailure(error.code);
    } catch (_) {
      return onUnknownFailure();
    }
  }
}

/// 계약 §11. permission-denied / failed-precondition / aborted·unavailable을
/// 서로 다른 Domain 실패로 나눈다. 정원·revision 경쟁은 Repository가 먼저
/// 구체 실패를 반환하고, Rules·Transaction 충돌만 여기로 온다.
GroupJoinFailure groupFirebaseFailure(String code) => switch (code) {
  'permission-denied' => GroupJoinFailure.permissionDenied,
  'not-found' => GroupJoinFailure.groupNotFound,
  // 선행 조건·revision 불일치성 충돌 → 새로고침 후 재시도 안내.
  'failed-precondition' => GroupJoinFailure.revisionConflict,
  'unavailable' || 'deadline-exceeded' || 'aborted' =>
    GroupJoinFailure.temporarilyUnavailable,
  _ => GroupJoinFailure.unknown,
};

/// Firestore Timestamp를 Domain DateTime으로 바꾸는 공통 mapper.
final groupFirestoreMapper = GroupDocumentMapper(
  toDateTime: (value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime dateTime => dateTime,
    _ => throw const FormatException('Expected Firestore Timestamp.'),
  },
);
