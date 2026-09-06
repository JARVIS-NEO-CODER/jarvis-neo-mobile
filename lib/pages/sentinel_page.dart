import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SentinelPage extends StatefulWidget {
  const SentinelPage({super.key});
  @override State<SentinelPage> createState() => _SentinelPageState();
}

class _SentinelPageState extends State<SentinelPage> with WidgetsBindingObserver {
  CameraController? controller;
  bool enabled = false;
  bool initializing = false;
  String message = 'Sentinel est désactivé.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _toggle() async {
    if (enabled) {
      await _stopCamera();
    } else {
      await _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (initializing) return;
    setState(() { initializing = true; message = 'Initialisation de la caméra…'; });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('Aucune caméra disponible sur cet appareil.');
      final selected = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final next = CameraController(selected, ResolutionPreset.medium, enableAudio: false);
      await next.initialize();
      if (!mounted) { await next.dispose(); return; }
      controller = next;
      setState(() { enabled = true; initializing = false; message = 'Surveillance caméra active.'; });
    } catch (e) {
      setState(() { initializing = false; enabled = false; message = 'Caméra indisponible : $e'; });
    }
  }

  Future<void> _stopCamera() async {
    final current = controller;
    controller = null;
    await current?.dispose();
    if (mounted) setState(() { enabled = false; message = 'Sentinel désactivé. Caméra arrêtée.'; });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (enabled) _stopCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = controller?.value.isInitialized == true;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        Icon(enabled ? Icons.shield : Icons.shield_outlined, color: enabled ? Colors.cyan : Colors.grey, size: 44),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SENTINEL', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ])),
      ]))),
      const SizedBox(height: 14),
      if (ready) ClipRRect(borderRadius: BorderRadius.circular(20), child: AspectRatio(aspectRatio: controller!.value.aspectRatio, child: CameraPreview(controller!)))
      else Container(height: 220, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black12, border: Border.all(color: Colors.white12)), child: const Center(child: Icon(Icons.videocam_off_outlined, size: 64, color: Colors.grey))),
      const SizedBox(height: 14),
      SizedBox(height: 54, child: FilledButton.icon(onPressed: initializing ? null : _toggle, icon: Icon(enabled ? Icons.stop_circle_outlined : Icons.videocam), label: Text(initializing ? 'Démarrage…' : enabled ? 'DÉSACTIVER SENTINEL' : 'ACTIVER SENTINEL'))),
      const SizedBox(height: 12),
      Card(child: Column(children: const [
        ListTile(leading: Icon(Icons.lock_outline), title: Text('Contrôle local'), subtitle: Text('La caméra reste désactivable immédiatement depuis cette page.')),
        ListTile(leading: Icon(Icons.visibility_outlined), title: Text('État actuel'), subtitle: Text('Cette V1 fournit le flux caméra local. La détection intelligente d’événements nécessite encore un moteur d’analyse.')),
      ])),
    ]);
  }
}
