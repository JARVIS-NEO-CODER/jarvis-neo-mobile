import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/pc_bridge.dart';
import '../core/remote_bridge.dart';

class SentinelPage extends StatefulWidget {
  const SentinelPage({super.key});

  @override
  State<SentinelPage> createState() => _SentinelPageState();
}

class _SentinelPageState extends State<SentinelPage> with WidgetsBindingObserver {
  final pc = JarvisPcBridge();
  final remote = JarvisRemoteBridge();
  CameraController? camera;
  Timer? refreshTimer;
  bool initializing = false;
  bool remoteMode = false;
  bool pcEnabled = false;
  bool pcCamera = false;
  bool pcAlarm = false;
  String message = 'Connexion au Sentinel PC…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connect();
  }

  Future<void> _connect() async {
    await pc.loadSavedSession();
    try {
      await pc.reconnect();
      remoteMode = false;
    } catch (_) {
      try {
        await remote.loadSaved();
        await remote.connect();
        remoteMode = true;
      } catch (_) {
        if (mounted) setState(() => message = 'PC non connecté. Le Sentinel local reste disponible.');
      }
    }
    if (mounted) await _refreshPcStatus();
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshPcStatus());
  }

  Future<void> _refreshPcStatus() async {
    final bridge = remoteMode ? remote : pc;
    if (!bridge.isConnected) return;
    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription sub;
    sub = bridge.events.listen((event) {
      final result = event['result'];
      if (event['type'] == 'response' && result is Map<String, dynamic> && !completer.isCompleted) {
        completer.complete(result);
      }
    });
    try {
      await bridge.action('sentinel.status');
      final result = await completer.future.timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        pcEnabled = result['enabled'] == true;
        pcCamera = result['camera_enabled'] == true;
        pcAlarm = result['alarm'] == true;
        message = remoteMode ? 'Sentinel PC connecté en Remote.' : 'Sentinel PC connecté en local.';
      });
    } catch (_) {
      if (mounted) setState(() => message = 'Sentinel PC connecté, état indisponible.');
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _togglePc() async {
    final target = !pcEnabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(target ? 'Activer Sentinel PC ?' : 'Désactiver Sentinel PC ?'),
        content: Text(target ? 'La surveillance de sécurité du PC sera activée.' : 'La surveillance de sécurité du PC sera arrêtée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (confirmed != true) return;
    final bridge = remoteMode ? remote : pc;
    if (!bridge.isConnected) {
      if (mounted) setState(() => message = 'PC non connecté.');
      return;
    }
    try {
      await bridge.action(target ? 'sentinel.enable' : 'sentinel.disable', {'confirmed': true});
      await _refreshPcStatus();
    } catch (e) {
      if (mounted) setState(() => message = 'Action Sentinel refusée : $e');
    }
  }

  Future<void> _toggleLocalCamera() async {
    if (camera != null) {
      await camera!.dispose();
      camera = null;
      if (mounted) setState(() {});
      return;
    }
    if (initializing) return;
    setState(() => initializing = true);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Aucune caméra disponible.');
      final selected = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final next = CameraController(selected, ResolutionPreset.medium, enableAudio: false);
      await next.initialize();
      if (!mounted) {
        await next.dispose();
        return;
      }
      camera = next;
      setState(() => initializing = false);
    } catch (e) {
      if (mounted) setState(() => initializing = false);
      if (mounted) setState(() => message = 'Caméra locale indisponible : $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      camera?.dispose();
      camera = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    camera?.dispose();
    pc.dispose();
    remote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = camera?.value.isInitialized == true;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: ListTile(
          leading: Icon(pcEnabled ? Icons.shield : Icons.shield_outlined, size: 42, color: pcEnabled ? Colors.cyan : null),
          title: const Text('SENTINEL PC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          subtitle: Text(message),
          trailing: pcAlarm ? const Icon(Icons.warning_amber, color: Colors.orange) : null,
        )),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _togglePc,
          icon: Icon(pcEnabled ? Icons.shield_outlined : Icons.shield),
          label: Text(pcEnabled ? 'DÉSACTIVER SENTINEL PC' : 'ACTIVER SENTINEL PC'),
        ),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.security), title: const Text('Sécurité PC'), subtitle: Text(pcEnabled ? 'Surveillance active' : 'Surveillance inactive'), trailing: Icon(pcEnabled ? Icons.check_circle : Icons.circle_outlined)),
          ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('Caméra PC'), subtitle: Text(pcCamera ? 'Signal caméra actif' : 'Signal caméra inactif')),
          ListTile(leading: const Icon(Icons.notifications_active_outlined), title: const Text('Alarme'), subtitle: Text(pcAlarm ? 'Alerte active' : 'Aucune alerte')),
        ])),
        const SizedBox(height: 16),
        const Text('Caméra du téléphone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (ready) ClipRRect(borderRadius: BorderRadius.circular(18), child: AspectRatio(aspectRatio: camera!.value.aspectRatio, child: CameraPreview(camera!)))
        else Container(height: 190, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(18)), child: const Center(child: Icon(Icons.videocam_off_outlined, size: 58, color: Colors.grey))),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: initializing ? null : _toggleLocalCamera, icon: Icon(ready ? Icons.stop_circle_outlined : Icons.videocam), label: Text(initializing ? 'Démarrage…' : ready ? 'ARRÊTER CAMÉRA LOCALE' : 'ACTIVER CAMÉRA LOCALE')),
        const SizedBox(height: 10),
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Sentinel PC utilise les commandes authentifiées de JARVIS NEO. La caméra du téléphone reste un flux local et ne transmet rien au PC automatiquement.'))),
      ],
    );
  }
}
