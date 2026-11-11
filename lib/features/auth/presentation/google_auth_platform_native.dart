import 'package:flutter/widgets.dart';
import '../data/android_google_authentication_gateway.dart';
import '../domain/auth_session_controller.dart';
import '../domain/google_authentication_gateway.dart';

GoogleAuthenticationGateway createGoogleAuthenticationGateway() =>
    AndroidGoogleAuthenticationGateway();

Widget buildWebGoogleButton({
  required AuthSessionController auth,
  required bool remember,
  required ValueChanged<bool> onLocked,
  required VoidCallback onSuccess,
}) => const SizedBox.shrink();
