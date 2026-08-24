import 'package:firebase_auth/firebase_auth.dart';

abstract class AnonymousAuthGateway {
  String? get currentAuthUid;

  Future<void> signInAnonymously();
}

class FirebaseAnonymousAuthGateway implements AnonymousAuthGateway {
  FirebaseAnonymousAuthGateway(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  String? get currentAuthUid => _firebaseAuth.currentUser?.uid;

  @override
  Future<void> signInAnonymously() async {
    await _firebaseAuth.signInAnonymously();
  }
}

class AnonymousAuthInitializer {
  const AnonymousAuthInitializer(this._gateway);

  final AnonymousAuthGateway _gateway;

  Future<String> initialize() async {
    final currentAuthUid = _gateway.currentAuthUid;
    if (currentAuthUid != null) return currentAuthUid;

    await _gateway.signInAnonymously();
    final createdAuthUid = _gateway.currentAuthUid;
    if (createdAuthUid == null) {
      throw StateError('Anonymous authentication did not create a user.');
    }
    return createdAuthUid;
  }
}
