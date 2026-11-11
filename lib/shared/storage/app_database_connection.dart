import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

/// Keeps native defaults and database names while enabling browser persistence.
QueryExecutor openAppDatabase(String name) => driftDatabase(
  name: name,
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
    onResult: (result) {
      if (result.chosenImplementation == WasmStorageImplementation.inMemory) {
        unawaited(result.resolvedExecutor.close());
        throw StateError('Browser persistent database storage is unavailable.');
      }
      if (kDebugMode) {
        debugPrint(
          'Database $name: ${result.chosenImplementation.name}; '
          'missing features: ${result.missingFeatures}',
        );
      }
    },
  ),
);
