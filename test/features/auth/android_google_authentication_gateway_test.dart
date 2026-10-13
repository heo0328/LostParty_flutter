import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/auth/data/android_google_authentication_gateway.dart';
import 'package:lost_party/features/auth/domain/google_authentication_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('lostparty/google_auth');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'each new attempt sends its own server nonce and returns evidence only',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return 'test-google-proof';
      });
      final gateway = AndroidGoogleAuthenticationGateway();
      for (final nonce in ['first-server-nonce', 'next-server-nonce']) {
        final proof = await gateway.authenticate(
          serverClientId: 'web-client',
          nonce: nonce,
        );
        expect(proof.idToken, 'test-google-proof');
        expect(proof.toString(), isNot(contains(proof.idToken)));
      }
      expect(calls.map((call) => call.arguments['nonce']), [
        'first-server-nonce',
        'next-server-nonce',
      ]);
      expect(calls.every((call) => call.method == 'authenticate'), isTrue);
      expect(
        calls.every((call) => call.arguments['serverClientId'] == 'web-client'),
        isTrue,
      );
    },
  );

  test('rejects empty transaction inputs before invoking native UI', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return 'proof';
    });
    final gateway = AndroidGoogleAuthenticationGateway();
    await expectLater(
      gateway.authenticate(serverClientId: 'web', nonce: ' '),
      throwsArgumentError,
    );
    await expectLater(
      gateway.authenticate(serverClientId: '', nonce: 'nonce'),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test(
    'blocks overlapping authentication and clearing, then permits a new attempt',
    () async {
      final pending = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (_) => pending.future);
      final gateway = AndroidGoogleAuthenticationGateway();
      final first = gateway.authenticate(serverClientId: 'web', nonce: 'first');
      final busy = isA<GoogleAuthenticationException>().having(
        (error) => error.failure,
        'failure',
        GoogleAuthenticationFailure.busy,
      );
      await expectLater(
        gateway.authenticate(serverClientId: 'web', nonce: 'second'),
        throwsA(busy),
      );
      await expectLater(gateway.clearCredentialState(), throwsA(busy));
      pending.complete('proof');
      await first;
      await gateway.authenticate(serverClientId: 'web', nonce: 'third');
    },
  );

  test(
    'cancellation is distinguishable and native details are not exposed',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'CANCELLED',
          message: 'sensitive-provider-data',
          details: 'private-data',
        );
      });
      final gateway = AndroidGoogleAuthenticationGateway();
      await expectLater(
        gateway.authenticate(serverClientId: 'web', nonce: 'nonce'),
        throwsA(
          isA<GoogleAuthenticationException>()
              .having(
                (error) => error.failure,
                'failure',
                GoogleAuthenticationFailure.cancelled,
              )
              .having(
                (error) => error.toString(),
                'redacted',
                isNot(contains('sensitive-provider-data')),
              ),
        ),
      );
      messenger.setMockMethodCallHandler(channel, (_) async => 'new-proof');
      expect(
        (await gateway.authenticate(
          serverClientId: 'web',
          nonce: 'new-nonce',
        )).idToken,
        'new-proof',
      );
    },
  );

  test(
    'missing or malformed evidence cannot become an authentication proof',
    () async {
      final gateway = AndroidGoogleAuthenticationGateway();
      for (final response in <Object?>[null, '', ' ', 42]) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        await expectLater(
          gateway.authenticate(serverClientId: 'web', nonce: 'nonce'),
          throwsA(
            isA<GoogleAuthenticationException>().having(
              (error) => error.failure,
              'failure',
              GoogleAuthenticationFailure.invalidResponse,
            ),
          ),
        );
      }
    },
  );

  test('clearing sends no credential or server transaction data', () async {
    MethodCall? received;
    messenger.setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });
    await AndroidGoogleAuthenticationGateway().clearCredentialState();
    expect(received?.method, 'clearCredentialState');
    expect(received?.arguments, isNull);
  });
}
