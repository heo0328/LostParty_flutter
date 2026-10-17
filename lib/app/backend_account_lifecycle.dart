import 'dart:async';

import '../features/account/data/backend_account_read_api.dart';
import '../features/account/data/scoped_account_runtime.dart';
import '../features/account/domain/account_read_session.dart';
import '../features/account/domain/server_account_read_repository.dart';
import '../features/account/presentation/viewmodels/scoped_account_view_model.dart';

/// App-owned opt-in binding. Disabled mode creates no new runtime or DB.
class BackendAccountLifecycle {
  BackendAccountLifecycle({
    required this.api,
    required ServerAccountReadRepository registrations,
    bool enabled = configuredEnabled,
    bool allowHttp = false,
    ScopedCacheDatabaseFactory databaseFactory = openScopedAccountCacheDatabase,
  }) {
    runtime = enabled
        ? ScopedAccountRuntime(
            api: api,
            registrations: registrations,
            enabled: true,
            allowHttp: allowHttp,
            databaseFactory: databaseFactory,
          )
        : null;
    model = runtime == null ? null : ScopedAccountViewModel(runtime!);
  }
  static const configuredEnabled = bool.fromEnvironment(
    'BACKEND_LIFECYCLE_READS_ENABLED',
  );
  final DioBackendAccountReadApi api;
  late final ScopedAccountRuntime? runtime;
  late final ScopedAccountViewModel? model;
  Future<void>? _closing;
  bool get enabled => model != null;

  bool isCurrent(AccountReadScope scope) =>
      _closing == null &&
      api.session.isAuthenticated &&
      api.session.userId == scope.userId &&
      api.session.generation == scope.generation;

  void onCommandStarted(AccountReadScope scope) {
    if (isCurrent(scope)) model?.beginCommand();
  }

  void onCommandFinished(AccountReadScope scope) {
    if (isCurrent(scope) && model != null) unawaited(model!.finishCommand());
  }

  Future<void> refresh(AccountReadScope scope) async {
    if (!isCurrent(scope)) return;
    // A verified/management return must not join a GET started before it.
    model?.invalidate(notify: false);
    await model?.refreshRegistrations();
  }

  Future<void> close() {
    if (_closing case final closing?) return closing;
    model?.dispose();
    return _closing = runtime?.close() ?? Future.value();
  }
}
