import 'security_policy.dart';
class PurchaseGuard {
  static Future<bool> requestFinalConfirmation({required String summary}) async {
    // Intentionally never auto-confirms a real payment. UI must call this gate
    // and obtain an explicit user action before invoking an external checkout.
    return false;
  }
  static bool requiresConfirmation() => SecurityPolicy.paymentAlwaysManual();
}
