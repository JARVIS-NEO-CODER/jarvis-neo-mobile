import 'package:flutter/material.dart';
import '../core/pc_bridge.dart';
import '../core/remote_bridge.dart';

class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});
  @override State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> {
  final local = JarvisPcBridge();
  final remote = JarvisRemoteBridge();
  Map<String, dynamic> state = {};
  String status = 'Recherche de la session PC…';
  bool busy = false;

  bool get connected => remote.isConnected || local.isConnected;

  @override
  void initState() {
    super.initState();
    local.events.listen(_event);
    remote.events.listen(_event);
    _restore();
  }

  void _event(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['type'] == 'state' && event['state'] is Map) {
      state = Map<String, dynamic>.from(event['state'] as Map);
    }
    if (event['type'] == 'authenticated') status = 'PC distant authentifié';
    if (event['type'] == 'error') status = '${event['code'] ?? 'Erreur'}';
    if (event['type'] == 'disconnected') status = 'Connexion interrompue';
    setState(() {});
  }

  Future<void> _restore() async {
    try {
      await remote.loadSaved();
      try { await remote.connect(); } catch (_) {}
      if (!remote.isConnected) {
        try { await local.reconnect(); } catch (_) {}
      }
      if (connected) {
        await _send('status');
        await _send('sync');
        status = remote.isConnected ? 'PC connecté à distance' : 'PC connecté en local';
      } else {
        status = 'PC non connecté';
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _send(String action, [Map<String, dynamic> args = const {}]) async {
    if (!connected) {
      setState(() => status = 'Connecte d’abord un PC');
      return;
    }
    try {
      if (remote.isConnected) {
        await remote.action(action, args);
      } else {
        await local.action(action, args);
      }
      if (mounted) setState(() => status = 'Commande envoyée');
    } catch (e) {
      if (mounted) setState(() => status = 'Commande refusée : $e');
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _sensitive(String action, String title, String message) async {
    if (await _confirm(title, message)) await _send(action);
  }

  @override
  void dispose() {
    local.dispose();
    remote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pcName = state['device'] ?? state['name'] ?? 'JARVIS NEO PC';
    final pcMode = state['mode'] ?? 'inconnu';
    final pcStatus = state['status'] ?? (connected ? 'connecté' : 'hors ligne');
    return RefreshIndicator(
      onRefresh: _restore,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
            Icon(connected ? Icons.desktop_windows : Icons.desktop_access_disabled, size: 42, color: connected ? Colors.cyan : Colors.grey),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$pcName', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              Text('$pcStatus • mode $pcMode', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 4), Text(status, style: TextStyle(color: connected ? Colors.cyan : Colors.orange)),
            ])),
            IconButton(onPressed: busy ? null : _restore, icon: const Icon(Icons.refresh)),
          ]))),
          const SizedBox(height: 14),
          const Text('Centre de contrôle', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.35, children: [
            _Control(label: 'Volume +', icon: Icons.volume_up, onTap: () => _send('pc.volume', {'delta': 5})),
            _Control(label: 'Volume −', icon: Icons.volume_down, onTap: () => _send('pc.volume', {'delta': -5})),
            _Control(label: 'Play / Pause', icon: Icons.play_pause, onTap: () => _send('pc.media', {'command': 'play_pause'})),
            _Control(label: 'Actualiser', icon: Icons.sync, onTap: () => _send('sync')),
            _Control(label: 'Capture écran', icon: Icons.screenshot_monitor, onTap: () => _send('pc.screenshot')),
            _Control(label: 'Verrouiller', icon: Icons.lock, onTap: () => _sensitive('pc.lock', 'Verrouiller le PC ?', 'Le PC sera verrouillé immédiatement.')),
            _Control(label: 'Bureau distant', icon: Icons.screen_share, onTap: () => _send('pc.remote_desktop.open')),
            _Control(label: 'Mode Sentinel', icon: Icons.shield, onTap: () => _send('sentinel.status')),
          ]),
          const SizedBox(height: 14),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.terminal), title: const Text('Commande JARVIS'), subtitle: const Text('Les actions sensibles demandent une confirmation.')),
            ListTile(leading: const Icon(Icons.monitor), title: const Text('État du PC'), subtitle: Text('Connexion: ${connected ? 'active' : 'inactive'}'), trailing: IconButton(onPressed: connected ? () => _send('status') : null, icon: const Icon(Icons.refresh))),
          ])),
          const SizedBox(height: 10),
          const Text('Note : les commandes affichées sont envoyées via le protocole JARVIS NEO. Leur exécution dépend des capacités exposées par le moteur PC.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _Control extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _Control({required this.label, required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => Card(child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.cyan, size: 30), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))]))));
}
