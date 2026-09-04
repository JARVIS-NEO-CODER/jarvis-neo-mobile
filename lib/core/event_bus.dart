typedef JarvisEventHandler = void Function(String type, Map<String,dynamic> payload);
class JarvisEventBus {
  final _handlers = <JarvisEventHandler>[];
  void subscribe(JarvisEventHandler handler) => _handlers.add(handler);
  void unsubscribe(JarvisEventHandler handler) => _handlers.remove(handler);
  void emit(String type, [Map<String,dynamic> payload = const {}]) {
    for (final handler in List<JarvisEventHandler>.from(_handlers)) { handler(type, payload); }
  }
}
