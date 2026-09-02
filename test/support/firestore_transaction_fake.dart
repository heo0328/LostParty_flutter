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
      _Collection(path, this);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final result = await transactionHandler(transaction);
    for (final path in transaction.deleted) {
      documents.remove(path);
      writes.add(path);
    }
    for (final entry in transaction.pending.entries) {
      final existing = documents[entry.key];
      if (existing == null || transaction.replaced.contains(entry.key)) {
        documents[entry.key] = Map<String, dynamic>.from(entry.value);
      } else {
        documents[entry.key] = {...existing, ...entry.value};
      }
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
  _Collection(this.path, this.firestore);
  @override
  final String path;
  @override
  final TransactionFirestoreFake firestore;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document('${this.path}/$path', firestore);

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final prefix = '$path/';
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final entry in firestore.documents.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final rest = entry.key.substring(prefix.length);
      if (rest.isEmpty || rest.contains('/')) continue;
      docs.add(_QueryDoc(rest, Map<String, dynamic>.from(entry.value)));
    }
    return _QuerySnapshot(docs);
  }
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.path, this.firestore);
  @override
  final String path;
  @override
  final TransactionFirestoreFake firestore;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection('$path/$collectionPath', firestore);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    final data = firestore.documents[path];
    return _Snapshot<Map<String, dynamic>>(
      data == null ? null : Map<String, dynamic>.from(data),
    );
  }
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

// ignore: subtype_of_sealed_class
class _QueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDoc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
}

// ignore: subtype_of_sealed_class
class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.firestore);
  final TransactionFirestoreFake firestore;
  final pending = <String, Map<String, dynamic>>{};
  final replaced = <String>{};
  final deleted = <String>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    if (pending.isNotEmpty || deleted.isNotEmpty) {
      throw StateError('Read after write.');
    }
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

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    pending[documentReference.path] = Map<String, dynamic>.from(data as Map);
    replaced.add(documentReference.path);
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    deleted.add(documentReference.path);
    return this;
  }
}
