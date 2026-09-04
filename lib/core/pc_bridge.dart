import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';

class DiscoveredPc {
  final String host;
  final int port;
  final String name;
  DiscoveredPc({required this.host, required this.port, required this.name});
}

class JarvisPcBridge {
  static const discoveryPort = 47821;
  static const protocol = 'jarvis-neo/1';
  IOWebSocketChannel? _channel;
  String? _token;
  StreamSubscription? _discoverySub;
  final _uuid = const Uuid();

  Stream<DiscoveredPc> discover({Duration timeout = const Duration(seconds: 6)}) async* {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort,
        reuseAddress: true, reusePort: true);
    socket.broadcastEnabled = true;
    final end = DateTime.now().add(timeout);
    try {
      await for (final event in socket.timeout(timeout, onTimeout: (_) => socket.close())) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram == null) continue;
          try {
            final data = jsonDecode(utf8.decode(datagram.data));
            if (data['type'] == 'jarvis_discovery' && data['protocol'] == protocol) {
              yield DiscoveredPc(host: datagram.address.address,
                  port: (data['port'] as num).toInt(), name: '${data['device'] ?? 'JARVIS NEO PC'}');
            }
          } catch (_) {}
        }
        if (DateTime.now().isAfter(end)) break;
      }
    } finally {
      socket.close();
    }
  }

  Future<void> connect(DiscoveredPc pc, String pairingCode) async {
    await disconnect();
    final uri = Uri.parse('ws://${pc.host}:${pc.port}/mobile/ws');
    _channel = IOWebSocketChannel.connect(uri);
    await _channel!.ready;
    _channel!.sink.add(jsonEncode({
      'type': 'pair',
      'protocol': protocol,
      'code': pairingCode,
      'device_id': _uuid.v4(),
    }));
    final first = await _channel!.stream.first;
    final data = jsonDecode(first as String);
    if (data['type'] != 'paired' || data['token'] == null) {
      await disconnect();
      throw StateError('Appairage refusé par JARVIS NEO PC');
    }
    _token = data['token'] as String;
  }

  Stream<Map<String, dynamic>> get events => _channel!.stream.map((x) => jsonDecode(x as String) as Map<String, dynamic>);

  Future<void> ping() => _send({'type': 'ping'});

  Future<void> status() => _send({'type': 'status'});

  Future<void> action(String name, [Map<String, dynamic> args = const {}]) =>
      _send({'type': 'action', 'action': name, 'args': args});

  Future<void> _send(Map<String, dynamic> body) async {
    if (_channel == null || _token == null) throw StateError('PC non connecté');
    body['token'] = _token;
    body['request_id'] = _uuid.v4();
    _channel!.sink.add(jsonEncode(body));
  }

  Future<void> disconnect() async {
    _token = null;
    final c = _channel;
    _channel = null;
    await c?.sink.close();
    await _discoverySub?.cancel();
    _discoverySub = null;
  }
}
