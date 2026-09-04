enum ConfirmationReason { sensitiveAction, purchase, permissionChange, deviceRemoval, destructiveFileAction }
class ConfirmationRequest {
  final ConfirmationReason reason;
  final String message;
  ConfirmationRequest(this.reason,this.message);
}
