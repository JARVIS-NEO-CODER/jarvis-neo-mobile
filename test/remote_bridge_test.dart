import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_neo_mobile/core/remote_bridge.dart';

void main() {
  test('remote bridge exposes the shared protocol', () {
    expect(JarvisRemoteBridge.protocol, 'jarvis-neo/1');
  });

  test('remote bridge rejects non-WSS relay URLs', () async {
    final bridge = JarvisRemoteBridge();
    expect(
      () => bridge.saveConfiguration(relayUrl: 'ws://relay.example', nodeId: 'node-123'),
      throwsA(isA<FormatException>()),
    );
    await bridge.dispose();
  });

  test('remote bridge rejects an empty node id', () async {
    final bridge = JarvisRemoteBridge();
    expect(
      () => bridge.saveConfiguration(relayUrl: 'wss://relay.example', nodeId: ''),
      throwsA(isA<FormatException>()),
    );
    await bridge.dispose();
  });
}
