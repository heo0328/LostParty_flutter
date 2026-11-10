import 'role_summary.dart';

/// A scoped observation, not permission to delete or transfer a character.
class RosterPresenceObservation {
  RosterPresenceObservation(
    Map<String, dynamic> scope,
    Map<String, dynamic> presence,
  ) {
    roleShape(
      scope,
      'profile registration_id registration_version ownership_revision roster_revision presence_revision evaluated_at',
    );
    roleCheck(scope['profile'] == 'roster-presence-1');
    roleId(scope['registration_id']);
    rolePositive(scope['registration_version']);
    rolePositive(scope['roster_revision']);
    if (scope['ownership_revision'] != null) {
      rolePositive(scope['ownership_revision']);
    }
    roleCheck(
      scope['presence_revision'] is String &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(scope['presence_revision']),
    );
    roleUtc(scope['evaluated_at']);
    roleShape(presence, 'state observed_at');
    roleCheck({'present', 'missing', 'unknown'}.contains(presence['state']));
    if (presence['state'] == 'unknown') {
      roleCheck(presence['observed_at'] == null);
    } else {
      roleUtc(presence['observed_at']);
    }
    this.scope = Map.unmodifiable(scope);
    this.presence = Map.unmodifiable(presence);
  }
  late final Map<String, dynamic> scope, presence;
  bool get missing => presence['state'] == 'missing';
  Map<String, dynamic> toStorage() => {'scope': scope, 'presence': presence};
  factory RosterPresenceObservation.fromStorage(Map<String, dynamic> raw) =>
      RosterPresenceObservation(
        roleMap(raw['scope']),
        roleMap(raw['presence']),
      );
}
