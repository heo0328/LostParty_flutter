import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/player/data/datasources/firestore_player_binding_store.dart';
import '../../features/player/data/repositories/player_binding_repository_impl.dart';
import '../../features/player/data/repositories/firestore_player_activity_repository.dart';
import '../../features/player/domain/entities/player_session.dart';
import '../../features/account_recovery/data/repositories/firebase_account_recovery_sign_in_repository.dart';
import '../../features/account_recovery/domain/entities/account_recovery_status.dart';
import '../../features/account_recovery/domain/repositories/account_recovery_sign_in_repository.dart';
import 'anonymous_auth_initializer.dart';
import 'app_startup_result.dart';
import 'firebase_app_initializer.dart';

Future<PlayerSession> initializeAppServices() async {
  await initializeFirebaseApp();
  final authGateway = FirebaseAnonymousAuthGateway(FirebaseAuth.instance);
  final authUid = await AnonymousAuthInitializer(authGateway).initialize();
  return _initializePlayerServices(authUid);
}

Future<AppStartupResult> inspectAppStartup() async {
  await initializeFirebaseApp();
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const AppStartupAuthenticationRequired();
  if (user.isAnonymous) {
    return AppStartupReady(await _initializePlayerServices(user.uid));
  }

  final session = await _playerBindingRepository().getExisting(
    authUid: user.uid,
  );
  if (session == null) {
    await FirebaseAuth.instance.signOut();
    return const AppStartupAuthenticationRequired();
  }
  await _recordAppLaunch(session);
  return AppStartupReady(session);
}

Future<PlayerSession> startNewAppServices() async {
  final authUid = await AnonymousAuthInitializer(
    FirebaseAnonymousAuthGateway(FirebaseAuth.instance),
  ).initialize();
  return _initializePlayerServices(authUid);
}

Future<PlayerSession?> recoverAppServices() async {
  final result = await FirebaseAccountRecoverySignInRepository()
      .signInWithGoogle();
  if (result is AccountRecoverySignInCancelled) return null;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Account recovery did not create an authenticated user.');
  }
  final session = await _playerBindingRepository().getExisting(
    authUid: user.uid,
  );
  if (session == null) {
    if (result case AccountRecoverySignInRecovered(isNewUser: true)) {
      try {
        await user.delete();
      } on FirebaseAuthException {
        // A missing binding is never promoted to a Player, even if cleanup fails.
      }
    }
    await FirebaseAuth.instance.signOut();
    throw const AccountRecoveryException(
      AccountRecoveryFailureReason.recoveryAccountNotFound,
    );
  }
  await _recordAppLaunch(session);
  return session;
}

Future<PlayerSession> _initializePlayerServices(String authUid) async {
  final session = await _playerBindingRepository().getOrCreate(
    authUid: authUid,
  );
  await _recordAppLaunch(session);
  return session;
}

PlayerBindingRepositoryImpl _playerBindingRepository() =>
    PlayerBindingRepositoryImpl(
      FirestorePlayerBindingStore(FirebaseFirestore.instance),
    );

Future<void> _recordAppLaunch(PlayerSession session) async {
  await FirestorePlayerActivityRepository(
    FirebaseFirestore.instance,
  ).recordAppLaunch(playerId: session.playerId);
}
