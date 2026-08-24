import 'package:firebase_auth/firebase_auth.dart';

abstract class AnonymousAuthGateway {
  bool get hasCurrentUser;

  Future<void> signInAnonymously();
}

class FirebaseAnonymousAuthGateway implements AnonymousAuthGateway {
  FirebaseAnonymousAuthGateway(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  bool get hasCurrentUser => _firebaseAuth.currentUser != null;

  @override
  Future<void> signInAnonymously() async {
    await _firebaseAuth.signInAnonymously();
  }
}

class AnonymousAuthInitializer {
  const AnonymousAuthInitializer(this._gateway);

  final AnonymousAuthGateway _gateway;

  Future<void> initialize() async {
    if (_gateway.hasCurrentUser) return;

    await _gateway.signInAnonymously();
    if (!_gateway.hasCurrentUser) {
      throw StateError('Anonymous authentication did not create a user.');
    }
  }
}
