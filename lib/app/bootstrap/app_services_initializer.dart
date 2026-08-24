import 'package:firebase_auth/firebase_auth.dart';

import 'anonymous_auth_initializer.dart';
import 'firebase_app_initializer.dart';

Future<void> initializeAppServices() async {
  await initializeFirebaseApp();
  await AnonymousAuthInitializer(
    FirebaseAnonymousAuthGateway(FirebaseAuth.instance),
  ).initialize();
}
