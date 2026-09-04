class SyncState {
  bool connected=false;
  DateTime? lastSync;
  String? error;
  void markSynced(){connected=true;lastSync=DateTime.now();error=null;}
  void markError(Object e){connected=false;error=e.toString();}
}
