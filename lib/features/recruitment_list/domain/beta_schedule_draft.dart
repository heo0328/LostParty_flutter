/// Incomplete editor values are separate from a server-authorized schedule.
class BetaScheduleInput {
  const BetaScheduleInput({
    this.weekday,
    this.minute,
    this.enabled = false,
    this.additional = 1,
  });
  final int? weekday, minute;
  final bool enabled;
  final int additional;
  BetaScheduleInput copy({
    int? weekday,
    int? minute,
    bool clearMinute = false,
    bool? enabled,
    int? additional,
  }) => BetaScheduleInput(
    weekday: weekday ?? this.weekday,
    minute: clearMinute ? null : minute ?? this.minute,
    enabled: enabled ?? this.enabled,
    additional: additional ?? this.additional,
  );
  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'minute': minute,
    'enabled': enabled,
    'additional': additional,
  };
}
