import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jarvis_neo_mobile/core/pc_bridge.dart';

Future<Map<String, dynamic>> nextEvent(
  Stream<Map<String, dynamic>> events,
  bool Function(Map<String, dynamic>) predicate,
) async {
  return events.firstWhere(predicate).timeout(const Duration(seconds: 8));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real PC bridge E2E contract', () async {
    SharedPreferences.setMockInitialValues({});
    final bridge = JarvisPcBridge();
    final events = bridge.events;
    final pc = DiscoveredPc(host: '127.0.0.1', port: 8890, name: 'JARVIS NEO E2E');

    await bridge.connect(pc, '123456');
    expect(bridge.isConnected, isTrue);
    expect(bridge.deviceId, isNotNull);

    final initialState = await nextEvent(events, (e) => e['type'] == 'state');
    expect(initialState['state']['protocol'], 'jarvis-neo/1');

    await bridge.ping();
    final pong = await nextEvent(events, (e) => e['type'] == 'response' && e['request_id'] != null);
    expect(pong['ok'], isTrue);
    expect(pong['result']['pong'], isTrue);

    await bridge.status();
    final status = await nextEvent(events, (e) => e['type'] == 'state' && e['request_id'] != null);
    expect(status['state']['mode'], 'e2e');

    await bridge.sync();
    final sync = await nextEvent(events, (e) => e['type'] == 'state' && e['request_id'] != null);
    expect(sync['state']['protocol'], 'jarvis-neo/1');

    await bridge.action('pc.volume', {'level': 42});
    final action = await nextEvent(events, (e) => e['type'] == 'response' && e['request_id'] != null && e['result'] is Map && e['result']['action'] == 'pc.volume');
    expect(action['ok'], isTrue);
    expect(action['result']['args']['level'], 42);

    await bridge.reconnect();
    expect(bridge.isConnected, isTrue);
    await bridge.ping();
    final pongAfterReconnect = await nextEvent(events, (e) => e['type'] == 'response' && e['request_id'] != null);
    expect(pongAfterReconnect['ok'], isTrue);

    await bridge.dispose();
  });
}
