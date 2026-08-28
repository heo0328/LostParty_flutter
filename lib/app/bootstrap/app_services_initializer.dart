import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/player/data/datasources/firestore_player_binding_store.dart';
import '../../features/player/data/repositories/player_binding_repository_impl.dart';
import '../../features/player/data/repositories/firestore_player_activity_repository.dart';
import '../../features/player/domain/entities/player_session.dart';
import 'anonymous_auth_initializer.dart';
import 'firebase_app_initializer.dart';

Future<PlayerSession> initializeAppServices() async {
  await initializeFirebaseApp();
  final authUid = await AnonymousAuthInitializer(
    FirebaseAnonymousAuthGateway(FirebaseAuth.instance),
  ).initialize();
  final session = await PlayerBindingRepositoryImpl(
    FirestorePlayerBindingStore(FirebaseFirestore.instance),
  ).getOrCreate(authUid: authUid);
  await FirestorePlayerActivityRepository(
    FirebaseFirestore.instance,
  ).recordAppLaunch(playerId: session.playerId);
  return session;
}
