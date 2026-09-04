import 'dart:async';
import 'package:flutter/material.dart';
import '../core/pc_bridge.dart';

class PcConnectionPage extends StatefulWidget {
  const PcConnectionPage({super.key});
  @override State<PcConnectionPage> createState() => _PcConnectionPageState();
}

class _PcConnectionPageState extends State<PcConnectionPage> {
  final bridge = JarvisPcBridge();
  final code = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? events;
  List<DiscoveredPc> pcs = [];
  Map<String, dynamic> state = {};
  String? selected;
  bool scanning = false;
  String message = 'Recherche du PC JARVIS NEO…';

  @override
  void initState() {
    super.initState();
    events = bridge.events.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'state' || event['type'] == 'status' || event['type'] == 'paired') {
        final incoming = event['state'];
        if (incoming is Map) state = Map<String, dynamic>.from(incoming);
      }
      if (event['type'] == 'action_result') message = 'Commande reçue par le PC.';
      if (event['type'] == 'error') message = '${event['code'] ?? 'Erreur'}';
      if (event['type'] == 'disconnected') message = 'PC déconnecté.';
      setState(() {});
    });
    scan();
  }

  Future<void> scan() async {
    setState(() { scanning = true; message = 'Recherche du PC JARVIS NEO…'; pcs = []; });
    await for (final pc in bridge.discover()) {
      if (!pcs.any((x) => x.host == pc.host && x.port == pc.port) && mounted) {
        setState(() => pcs.add(pc));
      }
    }
    if (mounted) setState(() { scanning = false; if (pcs.isEmpty) message = 'Aucun PC trouvé sur le réseau local.'; });
  }

  Future<void> pair() async {
    if (pcs.isEmpty) return;
    final pc = pcs.firstWhere((x) => x.host == selected, orElse: () => pcs.first);
    final value = code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      setState(() => message = 'Le code doit contenir 6 chiffres.');
      return;
    }
    try {
      await bridge.connect(pc, value);
      await bridge.sync();
      if (mounted) setState(() => message = 'PC connecté et synchronisé.');
    } catch (e) {
      if (mounted) setState(() => message = 'Échec de connexion : $e');
    }
  }

  Future<void> command(String action, [Map<String, dynamic> args = const {}]) async {
    try { await bridge.action(action, args); }
    catch (e) { if (mounted) setState(() => message = '$e'); }
  }

  @override
  void dispose() {
    events?.cancel();
    code.dispose();
    bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = bridge.isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('JARVIS NEO PC')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Icon(connected ? Icons.link : Icons.link_off, color: connected ? Colors.cyan : Colors.grey, size: 34),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(connected ? 'PC connecté' : 'PC non connecté', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ])),
        ]))),
        if (!connected) ...[
          const SizedBox(height: 12),
          if (pcs.isNotEmpty) DropdownButtonFormField<String>(value: selected ?? pcs.first.host, decoration: const InputDecoration(labelText: 'PC détecté'), items: pcs.map((pc) => DropdownMenuItem(value: pc.host, child: Text('${pc.name} • ${pc.host}:${pc.port}'))).toList(), onChanged: (v) => setState(() => selected = v)),
          if (pcs.isEmpty) OutlinedButton.icon(onPressed: scanning ? null : scan, icon: const Icon(Icons.radar), label: Text(scanning ? 'Recherche…' : 'Rechercher le PC')),
          const SizedBox(height: 12),
          TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, obscureText: true, decoration: const InputDecoration(labelText: 'Code d’appairage à 6 chiffres', prefixIcon: Icon(Icons.pin))),
          FilledButton.icon(onPressed: pcs.isEmpty ? null : pair, icon: const Icon(Icons.link), label: const Text('Connecter et synchroniser')),
        ] else ...[
          const SizedBox(height: 12),
          if (state.isNotEmpty) Card(child: ListTile(leading: const Icon(Icons.sync), title: const Text('État synchronisé'), subtitle: Text('${state['mode'] ?? 'Mode inconnu'} • ${state['status'] ?? 'opérationnel'}'))),
          const SizedBox(height: 8),
          const Text('Contrôle rapide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Volume +'), onPressed: () => command('pc.volume', {'delta': 5})),
            ActionChip(label: const Text('Volume −'), onPressed: () => command('pc.volume', {'delta': -5})),
            ActionChip(label: const Text('Play/Pause'), onPressed: () => command('pc.media', {'command': 'play_pause'})),
            ActionChip(label: const Text('Statut'), onPressed: () => bridge.status()),
          ]),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: () => bridge.disconnect(), icon: const Icon(Icons.link_off), label: const Text('Déconnecter ce PC')),
        ],
      ]),
    );
  }
}
