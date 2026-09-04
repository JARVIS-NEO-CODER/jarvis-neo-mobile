import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/pc_bridge.dart';
import '../core/remote_bridge.dart';

class PcConnectionPage extends StatefulWidget {
  const PcConnectionPage({super.key});
  @override State<PcConnectionPage> createState() => _PcConnectionPageState();
}

class _PcConnectionPageState extends State<PcConnectionPage> {
  final bridge = JarvisPcBridge();
  final remote = JarvisRemoteBridge();
  final code = TextEditingController();
  final relay = TextEditingController();
  final node = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? events;
  StreamSubscription<Map<String, dynamic>>? remoteEvents;
  List<DiscoveredPc> pcs = [];
  Map<String, dynamic> state = {};
  String? selected;
  bool scanning = false;
  bool remoteConnecting = false;
  String message = 'Recherche du PC JARVIS NEO…';
  String remoteMessage = 'Remote non configuré.';

  @override
  void initState() {
    super.initState();
    events = bridge.events.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'state') {
        final incoming = event['state'];
        if (incoming is Map) state = Map<String, dynamic>.from(incoming);
      }
      if (event['type'] == 'error') message = '${event['code'] ?? 'Erreur'}';
      if (event['type'] == 'disconnected') message = 'PC déconnecté.';
      setState(() {});
    });
    remoteEvents = remote.events.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'state') {
        final incoming = event['state'];
        if (incoming is Map) state = Map<String, dynamic>.from(incoming);
      }
      if (event['type'] == 'authenticated') remoteMessage = 'PC distant authentifié.';
      if (event['type'] == 'error') remoteMessage = '${event['code'] ?? 'Erreur'}';
      if (event['type'] == 'disconnected') remoteMessage = 'Connexion Remote interrompue.';
      setState(() {});
    });
    _loadRemote();
    scan();
  }

  Future<void> _loadRemote() async {
    await remote.loadSaved();
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    relay.text = p.getString('jarvis_remote_relay') ?? '';
    node.text = p.getString('jarvis_remote_node') ?? '';
    setState(() {});
  }

  Future<void> scan() async {
    setState(() { scanning = true; message = 'Recherche du PC JARVIS NEO…'; pcs = []; });
    try {
      await for (final pc in bridge.discover()) {
        if (!pcs.any((x) => x.host == pc.host && x.port == pc.port) && mounted) {
          setState(() => pcs.add(pc));
        }
      }
    } catch (e) {
      if (mounted) message = 'Détection LAN indisponible : $e';
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

  Future<void> configureRemote() async {
    try {
      await remote.saveConfiguration(relayUrl: relay.text, nodeId: node.text);
      if (mounted) setState(() => remoteMessage = 'Configuration Remote enregistrée.');
    } catch (e) {
      if (mounted) setState(() => remoteMessage = '$e');
    }
  }

  Future<void> connectRemote() async {
    setState(() { remoteConnecting = true; remoteMessage = 'Connexion au PC via Internet…'; });
    try {
      await configureRemote();
      await remote.connect();
      await remote.sync();
      if (mounted) setState(() => remoteMessage = 'PC distant connecté et synchronisé.');
    } catch (e) {
      if (mounted) setState(() => remoteMessage = 'Échec Remote : $e');
    } finally {
      if (mounted) setState(() => remoteConnecting = false);
    }
  }

  Future<void> command(String action, [Map<String, dynamic> args = const {}]) async {
    try {
      if (remote.isConnected) await remote.action(action, args);
      else await bridge.action(action, args);
    } catch (e) { if (mounted) setState(() => message = '$e'); }
  }

  @override
  void dispose() {
    events?.cancel();
    remoteEvents?.cancel();
    code.dispose();
    relay.dispose();
    node.dispose();
    bridge.dispose();
    remote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = bridge.isConnected;
    final remoteConnected = remote.isConnected;
    return Scaffold(
      appBar: AppBar(title: const Text('JARVIS NEO PC')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Icon((connected || remoteConnected) ? Icons.link : Icons.link_off, color: (connected || remoteConnected) ? Colors.cyan : Colors.grey, size: 34),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(connected ? 'PC connecté en local' : remoteConnected ? 'PC connecté à distance' : 'PC non connecté', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(connected ? message : remoteConnected ? remoteMessage : 'Choisis un mode de connexion.', style: const TextStyle(color: Colors.grey)),
          ])),
        ]))),
        const SizedBox(height: 12),
        ExpansionTile(title: const Text('Connexion locale'), subtitle: const Text('Wi-Fi / réseau local • appairage 6 chiffres'), initiallyExpanded: !remoteConnected, children: [
          if (!connected) ...[
            if (pcs.isNotEmpty) DropdownButtonFormField<String>(value: selected ?? pcs.first.host, decoration: const InputDecoration(labelText: 'PC détecté'), items: pcs.map((pc) => DropdownMenuItem(value: pc.host, child: Text('${pc.name} • ${pc.host}:${pc.port}'))).toList(), onChanged: (v) => setState(() => selected = v)),
            if (pcs.isEmpty) OutlinedButton.icon(onPressed: scanning ? null : scan, icon: const Icon(Icons.radar), label: Text(scanning ? 'Recherche…' : 'Rechercher le PC')),
            const SizedBox(height: 12),
            TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, obscureText: true, decoration: const InputDecoration(labelText: 'Code d’appairage à 6 chiffres', prefixIcon: Icon(Icons.pin))),
            FilledButton.icon(onPressed: pcs.isEmpty ? null : pair, icon: const Icon(Icons.link), label: const Text('Connecter et synchroniser')),
          ] else
            OutlinedButton.icon(onPressed: () => bridge.disconnect(), icon: const Icon(Icons.link_off), label: const Text('Déconnecter le local')),
        ]),
        const SizedBox(height: 8),
        ExpansionTile(title: const Text('Mode Remote 4G / 5G'), subtitle: const Text('Connexion Internet sécurisée, sans Wi-Fi local'), initiallyExpanded: true, children: [
          TextField(controller: relay, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL du relais WSS', hintText: 'wss://remote.example.com')),
          const SizedBox(height: 10),
          TextField(controller: node, decoration: const InputDecoration(labelText: 'Node ID du PC', hintText: 'Affiché dans les logs JARVIS NEO')),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: configureRemote, icon: const Icon(Icons.save_outlined), label: const Text('Enregistrer'))), const SizedBox(width: 8), Expanded(child: FilledButton.icon(onPressed: remoteConnecting ? null : connectRemote, icon: const Icon(Icons.public), label: Text(remoteConnecting ? 'Connexion…' : 'Connecter')))]),
          const SizedBox(height: 8),
          Text(remoteMessage, style: const TextStyle(color: Colors.grey)),
          if (remoteConnected) OutlinedButton.icon(onPressed: () => remote.disconnect(), icon: const Icon(Icons.link_off), label: const Text('Déconnecter le Remote')),
          const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 14), child: Text('Le PC garde un tunnel sortant vers le relais. Son port local 8890 n’est jamais exposé sur Internet.', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
        if (connected || remoteConnected) ...[
          const SizedBox(height: 12),
          if (state.isNotEmpty) Card(child: ListTile(leading: const Icon(Icons.sync), title: const Text('État synchronisé'), subtitle: Text('${state['mode'] ?? 'Mode inconnu'} • ${state['status'] ?? 'opérationnel'}'))),
          const SizedBox(height: 8),
          const Text('Contrôle rapide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(label: const Text('Volume +'), onPressed: () => command('pc.volume', {'delta': 5})),
            ActionChip(label: const Text('Volume −'), onPressed: () => command('pc.volume', {'delta': -5})),
            ActionChip(label: const Text('Play/Pause'), onPressed: () => command('pc.media', {'command': 'play_pause'})),
            ActionChip(label: const Text('Statut'), onPressed: () => remoteConnected ? remote.status() : bridge.status()),
          ]),
        ],
      ]),
    );
  }
}
