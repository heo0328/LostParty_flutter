import 'package:flutter/material.dart';

import 'app/backend_app.dart';
import 'shared/diagnostics/startup_timing.dart';

void main() {
  StartupTiming.start();
  WidgetsFlutterBinding.ensureInitialized();
  StartupTiming.active?.attachFrames();
  runApp(const BackendApp());
}
