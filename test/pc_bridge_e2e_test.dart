import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jarvis_neo_mobile/core/pc_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real PC bridge E2E contract', () async {
    SharedPreferences.setMockInitialValues({});
    final bridge = JarvisPcBridge();
    final latest = <String, Map<String, dynamic>>{};
    final waiters = <String, Completer<Map<String, dynamic>>>{};
    final subscription = bridge.events.listen((event) {
      final type = event['type'];
      if (type is! String) return;
      latest[type] = event;
      final waiter = waiters.remove(type);
      if (waiter != null && !waiter.isCompleted) waiter.complete(event);
    });

    Future<Map<String, dynamic>> waitFor(String type) {
      final cached = latest[type];
      if (cached != null) return Future.value(cached);
      final waiter = Completer<Map<String, dynamic>>();
      waiters[type] = waiter;
      return waiter.future.timeout(const Duration(seconds: 8));
    }

    final pc = DiscoveredPc(host: '127.0.0.1', port: 8890, name: 'JARVIS NEO E2E');

    try {
      await bridge.connect(pc, '123456');
      expect(bridge.isConnected, isTrue);
      expect(bridge.deviceId, isNotNull);

      final paired = await waitFor('paired');
      expect(paired['protocol'], 'jarvis-neo/1');
      expect(paired['token'], isNotNull);

      final initialStatus = await waitFor('status');
      expect(initialStatus['protocol'], 'jarvis-neo/1');
      expect(initialStatus['data']['online'], isTrue);

      await bridge.ping();
      final pong = await waitFor('pong');
      expect(pong['protocol'], 'jarvis-neo/1');

      await bridge.status();
      final status = await waitFor('status');
      expect(status['protocol'], 'jarvis-neo/1');
      expect(status['data']['online'], isTrue);

      await bridge.sync();
      final sync = await waitFor('sync');
      expect(sync['protocol'], 'jarvis-neo/1');
      expect(sync['data']['online'], isTrue);

      await bridge.action('ouvre test');
      final action = await waitFor('action_result');
      expect(action['protocol'], 'jarvis-neo/1');
      expect(action['action'], 'ouvre test');
      expect(action['data']['ok'], isTrue);

      await bridge.reconnect();
      expect(bridge.isConnected, isTrue);
      final reconnectedStatus = await waitFor('status');
      expect(reconnectedStatus['protocol'], 'jarvis-neo/1');
      expect(reconnectedStatus['data']['online'], isTrue);

      await bridge.ping();
      final pongAfterReconnect = await waitFor('pong');
      expect(pongAfterReconnect['protocol'], 'jarvis-neo/1');
    } finally {
      await bridge.dispose();
      await subscription.cancel();
    }
  });
}
