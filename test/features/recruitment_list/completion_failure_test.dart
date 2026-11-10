import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/completion_failure.dart';

void main() {
  test(
    'completion guidance separates expiry, state, authority and validation',
    () {
      expect(
        completionFailureMessage('COMMAND_CONTEXT_EXPIRED'),
        contains('확인 시간이'),
      );
      expect(
        completionFailureMessage('CYCLE_CHANGED'),
        '정보가 변경되었습니다. 다시 확인해 주세요.',
      );
      expect(
        completionFailureMessage('TARGET_CONTEXT_STALE'),
        contains('정보가 변경'),
      );
      expect(completionFailureMessage('TARGET_LEADER_REQUIRED'), '권한이 없습니다.');
      expect(
        completionFailureMessage('CONTEXT_INVALID'),
        '정보를 확인하지 못했습니다. 다시 확인해 주세요.',
      );
      expect(
        completionFailureMessage('ROUND_NOT_ACTIVE'),
        isNot(contains('이미 완료')),
      );
      expect(
        completionFailureMessage('CLIENT_UPGRADE_REQUIRED'),
        '앱을 업데이트해 주세요.',
      );
      expect(completionFailureMessage('UNKNOWN_CODE'), isNull);
    },
  );
  test(
    'unknown original result takes priority over a later rejection explanation',
    () {
      for (final code in [
        'CONTEXT_INVALID',
        'SERVICE_UNAVAILABLE',
        'COMMAND_CONTEXT_EXPIRED',
      ]) {
        expect(
          completionFailureMessage(code, unresolved: true),
          '결과를 확인하지 못했습니다. 다시 시도해 주세요.',
        );
      }
    },
  );
  test(
    'diagnostics contain only bounded code, HTTP status and UUID request id',
    () {
      const id = '0d505a6f-4d83-457b-add0-84213a182bfa';
      expect(
        completionDiagnostic(
          'CONTEXT_INVALID',
          const AccountReadException(
            'CONTEXT_INVALID',
            status: 400,
            requestId: id,
          ),
        ),
        '오류 코드: CONTEXT_INVALID\nHTTP 상태: 400\n요청 식별자: $id',
      );
      expect(
        completionDiagnostic(
          'Bearer secret',
          const AccountReadException(
            'CONTEXT_INVALID',
            status: 999,
            requestId: 'secret\nbody',
          ),
        ),
        isEmpty,
      );
    },
  );
}
