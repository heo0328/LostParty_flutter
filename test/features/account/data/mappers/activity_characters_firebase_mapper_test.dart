import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/mappers/activity_characters_firebase_mapper.dart';
import 'package:lost_party/features/account/domain/entities/save_activity_characters_command.dart';

void main() {
  test('permission-denied tells the user to deploy current Rules', () {
    final mapped = mapActivityCharactersFirebaseException(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      ),
    );

    expect(mapped.failure, ActivityCharactersSaveFailure.permissionDenied);
    expect(mapped.message, contains('Firestore Rules'));
  });

  test('unavailable keeps a retryable connection message', () {
    final mapped = mapActivityCharactersFirebaseException(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'The service is currently unavailable.',
      ),
    );

    expect(mapped.failure, ActivityCharactersSaveFailure.unavailable);
    expect(mapped.message, contains('네트워크'));
  });

  test('unknown codes keep the Firebase error code in the message', () {
    final mapped = mapActivityCharactersFirebaseException(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'too much contention',
      ),
    );

    expect(mapped.failure, ActivityCharactersSaveFailure.unavailable);
    expect(mapped.message, contains('failed-precondition'));
  });
}
