import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jarvis_neo_mobile/core/pc_bridge.dart';

Future<Map<String, dynamic>> nextEvent(
  StreamIterator<Map<String, dynamic>> events,
  bool Function(Map<String, dynamic>) predicate,
) async {
  while (await events.moveNext()) {
    final event = events.current;
    if (predicate(event)) return event;
  }
  throw StateError('PC bridge event stream closed before expected event');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real PC bridge E2E contract', () async {
    SharedPreferences.setMockInitialValues({});
    final bridge = JarvisPcBridge();
    final events = StreamIterator<Map<String, dynamic>>(bridge.events);
    final pc = DiscoveredPc(host: '127.0.0.1', port: 8890, name: 'JARVIS NEO E2E');

    try {
      await bridge.connect(pc, '123456');
      expect(bridge.isConnected, isTrue);
      expect(bridge.deviceId, isNotNull);

      final paired = await nextEvent(events, (e) => e['type'] == 'paired');
      expect(paired['protocol'], 'jarvis-neo/1');
      expect(paired['token'], isNotNull);

      final initialStatus = await nextEvent(events, (e) => e['type'] == 'status');
      expect(initialStatus['protocol'], 'jarvis-neo/1');
      expect(initialStatus['data']['online'], isTrue);

      await bridge.ping();
      final pong = await nextEvent(events, (e) => e['type'] == 'pong');
      expect(pong['protocol'], 'jarvis-neo/1');

      await bridge.status();
      final status = await nextEvent(events, (e) => e['type'] == 'status');
      expect(status['protocol'], 'jarvis-neo/1');
      expect(status['data']['online'], isTrue);

      await bridge.sync();
      final sync = await nextEvent(events, (e) => e['type'] == 'sync');
      expect(sync['protocol'], 'jarvis-neo/1');
      expect(sync['data']['online'], isTrue);

      await bridge.action('ouvre test');
      final action = await nextEvent(events, (e) => e['type'] == 'action_result');
      expect(action['protocol'], 'jarvis-neo/1');
      expect(action['action'], 'ouvre test');
      expect(action['data']['ok'], isTrue);

      await bridge.reconnect();
      expect(bridge.isConnected, isTrue);
      final reconnectedStatus = await nextEvent(events, (e) => e['type'] == 'status');
      expect(reconnectedStatus['protocol'], 'jarvis-neo/1');
      expect(reconnectedStatus['data']['online'], isTrue);

      await bridge.ping();
      final pongAfterReconnect = await nextEvent(events, (e) => e['type'] == 'pong');
      expect(pongAfterReconnect['protocol'], 'jarvis-neo/1');
    } finally {
      await bridge.dispose();
      await events.cancel();
    }
  });
}
