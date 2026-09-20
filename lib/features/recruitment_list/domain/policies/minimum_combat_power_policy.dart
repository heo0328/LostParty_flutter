enum MinimumCombatPowerDecision {
  unrestricted,
  satisfied,
  missing,
  belowMinimum;

  bool get isAllowed =>
      this == MinimumCombatPowerDecision.unrestricted ||
      this == MinimumCombatPowerDecision.satisfied;
}

class MinimumCombatPowerPolicy {
  const MinimumCombatPowerPolicy();

  MinimumCombatPowerDecision evaluate({
    required num? minimum,
    required num? actual,
  }) {
    if (minimum == null || minimum <= 0) {
      return MinimumCombatPowerDecision.unrestricted;
    }
    if (actual == null) return MinimumCombatPowerDecision.missing;
    return actual >= minimum
        ? MinimumCombatPowerDecision.satisfied
        : MinimumCombatPowerDecision.belowMinimum;
  }
}
