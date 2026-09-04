class JarvisDevice {
  final String id, name, type;
  bool connected;
  DateTime lastSeen;
  JarvisDevice({required this.id, required this.name, required this.type, this.connected=false, DateTime? lastSeen}) : lastSeen=lastSeen??DateTime.now();
}
class Routine {
  final String id, name, description;
  bool enabled;
  Routine({required this.id,required this.name,required this.description,this.enabled=true});
}
class PermissionRule {
  final String capability;
  bool allowed;
  PermissionRule(this.capability,{this.allowed=false});
}
