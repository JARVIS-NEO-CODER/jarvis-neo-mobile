import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/pc_bridge.dart';
import '../core/remote_bridge.dart';

class RemoteDesktopPage extends StatefulWidget {
  const RemoteDesktopPage({super.key});

  @override
  State<RemoteDesktopPage> createState() => _RemoteDesktopPageState();
}

class _RemoteDesktopPageState extends State<RemoteDesktopPage> {
  final pc = JarvisPcBridge();
  final remote = JarvisRemoteBridge();
  Timer? timer;
  Uint8List? frame;
  bool loading = false;
  bool remoteMode = false;
  String status = 'Bureau à distance prêt.';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    await pc.loadSavedSession();
    try {
      await pc.reconnect();
      if (mounted) setState(() => status = 'PC connecté en local.');
    } catch (_) {
      try {
        await remote.loadSaved();
        await remote.connect();
        remoteMode = true;
        if (mounted) setState(() => status = 'PC connecté en Remote 4G/5G.');
      } catch (e) {
        if (mounted) setState(() => status = 'PC non connecté. Appaire/configure le PC.');
      }
    }
    if (mounted) await _capture();
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _capture());
  }

  Future<Map<String, dynamic>?> _request(String action) async {
    final bridge = remoteMode ? remote : pc;
    final events = bridge.events;
    final requestIdFuture = Completer<Map<String, dynamic>>();
    late StreamSubscription sub;
    sub = events.listen((event) {
      if (event['type'] == 'response' && event['result'] is Map<String, dynamic>) {
        final result = event['result'] as Map<String, dynamic>;
        if (!requestIdFuture.isCompleted) requestIdFuture.complete(result);
      }
    });
    try {
      await bridge.action(action);
      return await requestIdFuture.future.timeout(const Duration(seconds: 8));
    } catch (e) {
      if (mounted) setState(() => status = 'Commande distante indisponible : $e');
      return null;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _capture() async {
    if (loading) return;
    if (!(remoteMode ? remote.isConnected : pc.isConnected)) return;
    loading = true;
    try {
      final result = await _request('pc.screen.capture');
      final encoded = result?['image_base64'];
      if (encoded is String && encoded.isNotEmpty && mounted) {
        setState(() {
          frame = base64Decode(encoded);
          status = remoteMode ? 'Aperçu Remote actif.' : 'Aperçu PC actif.';
        });
      }
    } finally {
      loading = false;
    }
  }

  Future<void> _lock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verrouiller le PC ?'),
        content: const Text('JARVIS va demander au PC de se verrouiller.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verrouiller')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await (remoteMode ? remote : pc).action('pc.lock', {'confirmed': true});
    if (mounted) {
      setState(() => status = result.toString());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    pc.dispose();
    remote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Icon(Icons.desktop_windows, color: remoteMode ? Colors.cyan : null),
            title: const Text('BUREAU À DISTANCE', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(status),
            trailing: IconButton(onPressed: _capture, icon: const Icon(Icons.refresh)),
          ),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            clipBehavior: Clip.antiAlias,
            child: frame == null
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.desktop_access_disabled, size: 56, color: Colors.grey), SizedBox(height: 10), Text('Aucun aperçu reçu', style: TextStyle(color: Colors.grey))]))
                : InteractiveViewer(minScale: 1, maxScale: 3, child: Image.memory(frame!, fit: BoxFit.contain)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _capture, icon: const Icon(Icons.camera_alt), label: const Text('Actualiser'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: _lock, icon: const Icon(Icons.lock_outline), label: const Text('Verrouiller'))),
        ]),
        const SizedBox(height: 12),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Le bureau utilise actuellement le pont snapshot sécurisé : aperçu JPEG périodique et actions authentifiées. Le streaming vidéo continu et le contrôle souris/clavier nécessitent un transport média dédié.'))),
      ],
    );
  }
}
