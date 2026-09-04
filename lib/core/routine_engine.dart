import 'models.dart';
class RoutineEngine {
  final List<Routine> routines = [];
  void add(Routine routine) => routines.add(routine);
  List<Routine> matching({String? event, String? device, DateTime? time}) {
    return routines.where((r) => r.enabled).toList();
  }
}
