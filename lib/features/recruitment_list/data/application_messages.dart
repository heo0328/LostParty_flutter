import '../../account/domain/server_registration_api.dart';
import 'beta/beta_contract.dart';

abstract interface class ApplicationMessagesGateway {
  bool get applicationMessagesEnabled;
  Future<ApplicationMessagePresets> applicationMessagePresets();
}

class ApplicationMessagesReader implements ApplicationMessagesGateway {
  const ApplicationMessagesReader(this.api);
  final BackendRegistrationApi api;
  @override
  bool get applicationMessagesEnabled => true;
  @override
  Future<ApplicationMessagePresets> applicationMessagePresets() async {
    // This account endpoint intentionally does not carry contract_profile.
    final raw = await api.request('/v2/me/application-message-presets');
    return ApplicationMessagePresets(raw!);
  }
}
