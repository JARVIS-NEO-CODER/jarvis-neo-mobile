enum RiskLevel { low, medium, high, critical }
class SecurityPolicy {
  static bool requiresManualConfirmation(RiskLevel risk) => risk == RiskLevel.high || risk == RiskLevel.critical;
  static bool paymentAlwaysManual() => true;
}
