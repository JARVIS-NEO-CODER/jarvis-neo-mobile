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
  String? _deviceId;
  final _uuid = const Uuid();
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription? _socketSub;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null && _token != null;
  String? get deviceId => _deviceId;

  Stream<DiscoveredPc> discover({Duration timeout = const Duration(seconds: 6)}) async* {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0,
        reuseAddress: true, reusePort: false);
    final end = DateTime.now().add(timeout);
    try {
      socket.broadcastEnabled = true;
      await for (final event in socket.timeout(timeout, onTimeout: (_) => socket.close())) {
        if (event != RawSocketEvent.read) continue;
        final datagram = socket.receive();
        if (datagram == null) continue;
        try {
          final data = jsonDecode(utf8.decode(datagram.data));
          if (data['type'] == 'jarvis_discovery' && data['protocol'] == protocol) {
            yield DiscoveredPc(host: datagram.address.address,
                port: (data['port'] as num).toInt(),
                name: '${data['device'] ?? 'JARVIS NEO PC'}');
          }
        } catch (_) {}
        if (DateTime.now().isAfter(end)) break;
      }
    } finally {
      socket.close();
    }
  }

  Future<void> connect(DiscoveredPc pc, String pairingCode) async {
    await disconnect();
    final uri = Uri.parse('ws://${pc.host}:${pc.port}/mobile/ws');
    final channel = IOWebSocketChannel.connect(uri);
    _channel = channel;
    await channel.ready;

    final paired = Completer<Map<String, dynamic>>();
    _socketSub = channel.stream.listen((raw) {
      try {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (!paired.isCompleted && data['type'] == 'paired') {
          paired.complete(data);
        } else {
          _events.add(data);
        }
      } catch (_) {}
    }, onError: (Object error, StackTrace stack) {
      if (!paired.isCompleted) paired.completeError(error, stack);
      _events.add({'type': 'error', 'code': 'SOCKET_ERROR', 'message': '$error'});
    }, onDone: () {
      if (!paired.isCompleted) paired.completeError(StateError('Connexion fermée pendant l’appairage'));
      _token = null;
      _channel = null;
      _events.add({'type': 'disconnected'});
    });

    _deviceId = _uuid.v4();
    channel.sink.add(jsonEncode({
      'type': 'pair', 'protocol': protocol, 'code': pairingCode, 'device_id': _deviceId,
    }));

    try {
      final data = await paired.future.timeout(const Duration(seconds: 10));
      if (data['type'] != 'paired' || data['token'] == null) {
        throw StateError('Appairage refusé par JARVIS NEO PC');
      }
      _token = data['token'] as String;
      _events.add(data);
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> ping() => _send({'type': 'ping'});
  Future<void> status() => _send({'type': 'status'});
  Future<void> sync() => _send({'type': 'sync'});

  Future<void> action(String name, [Map<String, dynamic> args = const {}]) =>
      _send({'type': 'action', 'action': name, 'args': args});

  Future<void> _send(Map<String, dynamic> body) async {
    final channel = _channel;
    final token = _token;
    if (channel == null || token == null) throw StateError('PC non connecté');
    body['token'] = token;
    body['request_id'] = _uuid.v4();
    channel.sink.add(jsonEncode(body));
  }

  Future<void> disconnect() async {
    _token = null;
    _deviceId = null;
    final sub = _socketSub;
    _socketSub = null;
    await sub?.cancel();
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
    _events.add({'type': 'disconnected'});
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
