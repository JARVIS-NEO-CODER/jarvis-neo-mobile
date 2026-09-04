import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';

class JarvisRemoteBridge {
  static const protocol = 'jarvis-neo/1';
  static const _relayKey = 'jarvis_remote_relay';
  static const _nodeKey = 'jarvis_remote_node';
  static const _tokenKey = 'jarvis_pc_token';
  static const _deviceKey = 'jarvis_pc_device_id';

  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  final _uuid = const Uuid();
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  bool _manualDisconnect = false;
  bool _connecting = false;
  String? _relayUrl;
  String? _nodeId;
  String? _token;
  String? _deviceId;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null;

  Future<void> loadSaved() async {
    final p = await SharedPreferences.getInstance();
    _relayUrl = p.getString(_relayKey);
    _nodeId = p.getString(_nodeKey);
    _token = p.getString(_tokenKey);
    _deviceId = p.getString(_deviceKey);
  }

  Future<void> saveConfiguration({required String relayUrl, required String nodeId}) async {
    final uri = Uri.tryParse(relayUrl.trim());
    if (uri == null || uri.scheme != 'wss' || uri.host.isEmpty) {
      throw const FormatException('Le relais distant doit utiliser wss://.');
    }
    if (nodeId.trim().isEmpty || nodeId.trim().length > 128) {
      throw const FormatException('Identifiant Remote PC invalide.');
    }
    _relayUrl = relayUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    _nodeId = nodeId.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_relayKey, _relayUrl!);
    await p.setString(_nodeKey, _nodeId!);
  }

  Future<void> connect() async {
    await loadSaved();
    if (_relayUrl == null || _nodeId == null || _token == null || _deviceId == null) {
      throw StateError('Configure le relais, le Node ID et appaire d’abord le PC sur le réseau local.');
    }
    _reconnectTimer?.cancel();
    await _closeSocket();
    _manualDisconnect = false;
    await _connectOnce();
  }

  Future<void> _connectOnce() async {
    if (_connecting || _manualDisconnect || _channel != null) return;
    _connecting = true;
    try {
      final uri = Uri.parse('${_relayUrl!}/ws');
      final channel = IOWebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready;
      final attached = Completer<void>();
      _subscription = channel.stream.listen((raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (!attached.isCompleted && data['type'] == 'remote_attached') {
            attached.complete();
            channel.sink.add(jsonEncode({
              'type': 'authenticate',
              'protocol': protocol,
              'token': _token,
              'device_id': _deviceId,
            }));
            return;
          }
          _events.add(data);
        } catch (e) {
          _events.add({'type': 'error', 'code': 'INVALID_REMOTE_FRAME', 'message': '$e'});
        }
      }, onError: (Object error, StackTrace stack) {
        if (!attached.isCompleted) attached.completeError(error, stack);
        _events.add({'type': 'error', 'code': 'REMOTE_SOCKET_ERROR', 'message': '$error'});
      }, onDone: () {
        _channel = null;
        _subscription = null;
        if (!attached.isCompleted) attached.completeError(StateError('Connexion Remote fermée.'));
        if (!_manualDisconnect) {
          _events.add({'type': 'disconnected', 'reconnectable': true});
          _scheduleReconnect();
        }
      });

      channel.sink.add(jsonEncode({
        'type': 'remote',
        'protocol': protocol,
        'node_id': _nodeId,
      }));
      await attached.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      if (!_manualDisconnect) _scheduleReconnect();
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (_manualDisconnect || _channel != null) return;
      try {
        await _connectOnce();
      } catch (_) {}
    });
  }

  Future<void> ping() => _send({'type': 'ping'});
  Future<void> status() => _send({'type': 'status'});
  Future<void> sync() => _send({'type': 'sync'});
  Future<void> action(String name, [Map<String, dynamic> args = const {}]) => _send({'type': 'action', 'action': name, 'args': args});

  Future<void> _send(Map<String, dynamic> body) async {
    final channel = _channel;
    if (channel == null || _token == null || _deviceId == null) throw StateError('PC distant non connecté');
    body['protocol'] = protocol;
    body['token'] = _token;
    body['device_id'] = _deviceId;
    body['request_id'] = _uuid.v4();
    channel.sink.add(jsonEncode(body));
  }

  Future<void> _closeSocket() async {
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    await _closeSocket();
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
