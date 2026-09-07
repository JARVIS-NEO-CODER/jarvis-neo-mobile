import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';

class DiscoveredPc {
  final String host;
  final int port;
  final String name;
  DiscoveredPc({required this.host, required this.port, required this.name});
}

class JarvisPcBridge {
  static const mobilePort = 8890;
  static const protocol = 'jarvis-neo/1';
  static const _hostKey = 'jarvis_pc_host';
  static const _portKey = 'jarvis_pc_port';
  static const _tokenKey = 'jarvis_pc_token';
  static const _deviceIdKey = 'jarvis_pc_device_id';

  IOWebSocketChannel? _channel;
  String? _token;
  String? _deviceId;
  String? _host;
  int? _port;
  final _uuid = const Uuid();
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription? _socketSub;
  bool _manualDisconnect = false;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null && _token != null;
  String? get deviceId => _deviceId;

  Future<void> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_hostKey);
    _port = prefs.getInt(_portKey);
    _token = prefs.getString(_tokenKey);
    _deviceId = prefs.getString(_deviceIdKey);
  }

  Stream<DiscoveredPc> discover({Duration timeout = const Duration(seconds: 6)}) async* {
    final seen = <String>{};
    final candidates = <String>{};

    // Discover the phone's active IPv4 LAN and probe the PC's actual HTTP
    // gateway. This works even when Windows/router UDP broadcast is filtered.
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final address in iface.addresses) {
          final octets = address.address.split('.');
          if (octets.length != 4) continue;
          final prefix = '${octets[0]}.${octets[1]}.${octets[2]}.';
          for (var host = 1; host <= 254; host++) {
            candidates.add('$prefix$host');
          }
        }
      }
    } catch (_) {}

    if (candidates.isEmpty) return;

    final queue = candidates.toList(growable: false);
    var index = 0;
    final deadline = DateTime.now().add(timeout);
    const concurrency = 32;
    final found = StreamController<DiscoveredPc>();

    Future<void> worker() async {
      while (DateTime.now().isBefore(deadline)) {
        final i = index++;
        if (i >= queue.length) return;
        final host = queue[i];
        HttpClient? client;
        try {
          client = HttpClient()..connectionTimeout = const Duration(milliseconds: 350);
          final request = await client
              .getUrl(Uri.parse('http://$host:$mobilePort/mobile/info'))
              .timeout(const Duration(milliseconds: 500));
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          final response = await request.close().timeout(const Duration(milliseconds: 700));
          if (response.statusCode != HttpStatus.ok) continue;
          final body = await utf8.decoder.bind(response).join().timeout(const Duration(milliseconds: 700));
          final data = jsonDecode(body);
          if (data is Map && data['name'] == 'J.A.R.V.I.S. NEO' && data['version'] != null) {
            final key = '$host:$mobilePort';
            if (seen.add(key)) {
              found.add(DiscoveredPc(
                host: host,
                port: mobilePort,
                name: '${data['name']}',
              ));
            }
          }
        } catch (_) {
          // Refused/timeout is normal for every non-JARVIS address.
        } finally {
          client?.close(force: true);
        }
      }
    }

    final workers = List.generate(concurrency, (_) => worker());
    final waiter = Future.wait(workers);
    await for (final pc in found.stream) {
      yield pc;
    }
    await waiter;
    await found.close();
  }

  Future<void> connect(DiscoveredPc pc, String pairingCode) async {
    await disconnect();
    _manualDisconnect = false;
    _host = pc.host;
    _port = pc.port;
    _deviceId ??= _uuid.v4();

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
      if (!paired.isCompleted) {
        paired.completeError(error, stack);
      }
      _events.add({'type': 'error', 'code': 'SOCKET_ERROR', 'message': '$error'});
    }, onDone: () {
      if (!paired.isCompleted) {
        paired.completeError(StateError('Connexion fermée pendant l’appairage'));
      }
      _channel = null;
      if (!_manualDisconnect) {
        _events.add({'type': 'disconnected', 'reconnectable': true});
      }
    });

    channel.sink.add(jsonEncode({
      'type': 'pair',
      'protocol': protocol,
      'code': pairingCode,
      'device_id': _deviceId,
      'name': 'JARVIS NEO Mobile',
    }));

    try {
      final data = await paired.future.timeout(const Duration(seconds: 10));
      if (data['type'] != 'paired' || data['token'] == null || data['protocol'] != protocol) {
        throw StateError('Appairage refusé par JARVIS NEO PC');
      }
      _token = data['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_hostKey, _host!);
      await prefs.setInt(_portKey, _port!);
      await prefs.setString(_tokenKey, _token!);
      await prefs.setString(_deviceIdKey, _deviceId!);
      _events.add(data);
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> reconnect() async {
    await loadSavedSession();
    if (_host == null || _port == null || _token == null || _deviceId == null) {
      throw StateError('Aucune session PC enregistrée');
    }
    await disconnect(clearSaved: false);
    _manualDisconnect = false;
    final uri = Uri.parse('ws://$_host:$_port/mobile/ws');
    final channel = IOWebSocketChannel.connect(uri);
    _channel = channel;
    await channel.ready;
    final ready = Completer<void>();
    _socketSub = channel.stream.listen((raw) {
      try {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (!ready.isCompleted && data['type'] == 'authenticated') {
          ready.complete();
        } else {
          _events.add(data);
        }
      } catch (_) {}
    }, onError: (Object error, StackTrace stack) {
      if (!ready.isCompleted) {
        ready.completeError(error, stack);
      }
      _events.add({'type': 'error', 'code': 'SOCKET_ERROR', 'message': '$error'});
    }, onDone: () {
      _channel = null;
      if (!_manualDisconnect) {
        _events.add({'type': 'disconnected', 'reconnectable': true});
      }
    });
    channel.sink.add(jsonEncode({'type': 'authenticate', 'protocol': protocol, 'token': _token, 'device_id': _deviceId}));
    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      await disconnect(clearSaved: false);
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
    final deviceId = _deviceId;
    if (channel == null || token == null || deviceId == null) throw StateError('PC non connecté');
    body['protocol'] = protocol;
    body['token'] = token;
    body['device_id'] = deviceId;
    body['request_id'] = _uuid.v4();
    channel.sink.add(jsonEncode(body));
  }

  Future<void> disconnect({bool clearSaved = false}) async {
    _manualDisconnect = true;
    final sub = _socketSub;
    _socketSub = null;
    await sub?.cancel();
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
    _token = clearSaved ? null : _token;
    _events.add({'type': 'disconnected'});
    if (clearSaved) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_hostKey);
      await prefs.remove(_portKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_deviceIdKey);
      _host = null;
      _port = null;
      _deviceId = null;
    }
  }

  Future<void> forgetDevice() => disconnect(clearSaved: true);

  Future<void> dispose() async {
    await disconnect(clearSaved: false);
    await _events.close();
  }
}
