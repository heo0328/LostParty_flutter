import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/policies/account_label_policy.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import '../../../support/server_account_read_fakes.dart';

void main() {
  Map<String, dynamic> registration(int n, String label, {bool main = false}) =>
      registrationJson()
        ..['registration_id'] =
            '${n.toString().padLeft(8, '0')}-1111-4111-8111-111111111111'
        ..['label'] = label
        ..['is_main'] = main;

  test(
    'whole paginated roster counts named subs and recalculates after main switch',
    () async {
      final session = ReadSessionFake();
      final api = ReadApiFake();
      var switched = false;
      api.onRegistrations = (cursor) async => ServerRegistrationPage.fromJson({
        'items': cursor == null
            ? [registration(1, '', main: !switched), registration(2, '')]
            : [registration(3, '직접 이름'), registration(4, '', main: switched)],
        'next_cursor': cursor == null ? 'next' : null,
      });
      final repository = ServerAccountReadRepository(api, session);
      final first = await repository.loadRegistrations();
      expect(AccountLabelPolicy.serverLabels(first).values.toList(), [
        '메인 계정',
        '부계정 1',
        '직접 이름',
        '부계정 3',
      ]);
      switched = true;
      final second = await repository.loadRegistrations();
      expect(AccountLabelPolicy.serverLabels(second).values.toList(), [
        '부계정 1',
        '부계정 2',
        '직접 이름',
        '메인 계정',
      ]);
      expect(second.map((a) => a.label), ['', '', '직접 이름', '']);
      expect(AccountLabelPolicy.serverLabels(second.skip(1)).values.toList(), [
        '부계정 1',
        '직접 이름',
        '메인 계정',
      ]);
      session.dispose();
    },
  );

  for (final value in [null, 3, true, List.filled(41, 'a').join()]) {
    test('registration label rejects invalid type or size $value', () {
      expect(
        () => ServerAccountRegistration.fromJson(
          registrationJson()..['label'] = value,
        ),
        throwsFormatException,
      );
    });
  }
  test('empty label does not relax other required text', () {
    expect(
      () => ServerAccountRegistration.fromJson(
        registrationJson()
          ..['label'] = ''
          ..['registration_id'] = '',
      ),
      throwsFormatException,
    );
  });
}
