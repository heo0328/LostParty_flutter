import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 Repository의 Transaction 콜백을 실행하는 테스트 저장소.
/// Security Rules와 동시성 재시도는 에뮬레이션하지 않는다.
class TransactionFirestoreFake extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final writes = <String>[];
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await transactionHandler(transaction);
    for (final entry in transaction.pending.entries) {
      documents[entry.key] = {...documents[entry.key]!, ...entry.value};
      writes.add(entry.key);
    }
    return result;
  }
}

class TransactionAuthFake extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'auth-1';
}

// SDK 읽기 타입을 테스트에서만 대체한다. 실제 Rules 검증을 대신하지 않는다.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document('${this.path}/$path');
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection('$path/$collectionPath');
}

// ignore: subtype_of_sealed_class
class _Snapshot<T extends Object?> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.firestore);
  final TransactionFirestoreFake firestore;
  final pending = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    if (pending.isNotEmpty) throw StateError('Read after write.');
    final data = firestore.documents[documentReference.path];
    return _Snapshot<T>(
      data == null ? null : Map<String, dynamic>.from(data) as T,
    );
  }

  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    if (!firestore.documents.containsKey(documentReference.path)) {
      throw StateError('Missing document.');
    }
    pending[documentReference.path] = Map<String, dynamic>.from(data);
    return this;
  }
}
