import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/player/data/datasources/firestore_player_binding_store.dart';
import '../../features/player/data/repositories/player_binding_repository_impl.dart';
import 'anonymous_auth_initializer.dart';
import 'firebase_app_initializer.dart';

Future<void> initializeAppServices() async {
  await initializeFirebaseApp();
  final authUid = await AnonymousAuthInitializer(
    FirebaseAnonymousAuthGateway(FirebaseAuth.instance),
  ).initialize();
  await PlayerBindingRepositoryImpl(
    FirestorePlayerBindingStore(FirebaseFirestore.instance),
  ).getOrCreate(authUid: authUid);
}
