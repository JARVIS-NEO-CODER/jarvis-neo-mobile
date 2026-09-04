import 'models.dart';
class DeviceOrchestrator {
  final devices = <JarvisDevice>[];
  JarvisDevice? choose({String? capability, String? preferredType}) {
    final connected = devices.where((d)=>d.connected);
    if (preferredType != null) {
      for (final d in connected) { if (d.type == preferredType) return d; }
    }
    return connected.isEmpty ? null : connected.first;
  }
}
