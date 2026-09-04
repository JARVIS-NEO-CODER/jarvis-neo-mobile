import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() => runApp(const JarvisApp());

class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key});
  @override State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> {
  ThemeMode mode = ThemeMode.dark;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'JARVIS NEO Mobile', debugShowCheckedModeBanner: false, themeMode: mode,
    darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xff070b12),
    ),
    theme: ThemeData(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
      scaffoldBackgroundColor: const Color(0xfff4f7fb),
    ),
    home: Home(onTheme: (light) => setState(() => mode = light ? ThemeMode.light : ThemeMode.dark)),
  );
}

class Home extends StatefulWidget {
  final ValueChanged<bool> onTheme;
  const Home({super.key, required this.onTheme});
  @override State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  final tts = FlutterTts();
  final speech = stt.SpeechToText();
  final chat = ChatService();
  final log = ActivityLog();
  bool listening = false;

  Future<void> toggleVoice() async {
    if (listening) {
      await speech.stop();
      setState(() => listening = false);
      return;
    }
    final available = await speech.initialize();
    if (!available) return;
    setState(() => listening = true);
    await speech.listen(onResult: (result) {
      if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
        _sendVoice(result.recognizedWords.trim());
      }
    }, localeId: 'fr_FR');
  }

  Future<void> _sendVoice(String text) async {
    await speech.stop();
    if (mounted) setState(() => listening = false);
    final answer = await chat.ask(text);
    log.add('VOICE', text);
    if (await Prefs().getBool('voice', true)) await tts.speak(answer);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CommandPage(chat: chat, tts: tts, log: log, onVoice: toggleVoice, listening: listening),
      const DevicesPage(), const FilesPage(), const RoutinesPage(), const SentinelPage(),
      SettingsPage(onTheme: widget.onTheme),
    ];
    return Scaffold(
      appBar: AppBar(title: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyan, boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(.8), blurRadius: 12)])),
        const SizedBox(width: 10), const Text('J.A.R.V.I.S. NEO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      ]), actions: [IconButton(onPressed: () => setState(() => tab = 5), icon: const Icon(Icons.settings_outlined))]),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'JARVIS'),
        NavigationDestination(icon: Icon(Icons.devices_other), label: 'Devices'), NavigationDestination(icon: Icon(Icons.folder_open), label: 'Files'),
        NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Routines'), NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Sentinel'),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
      ]),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(
        onPressed: toggleVoice, icon: Icon(listening ? Icons.stop : Icons.mic), label: Text(listening ? 'Écoute…' : 'Parler'),
      ) : null,
    );
  }
}

class CommandPage extends StatefulWidget {
  final ChatService chat; final FlutterTts tts; final ActivityLog log; final VoidCallback onVoice; final bool listening;
  const CommandPage({super.key, required this.chat, required this.tts, required this.log, required this.onVoice, required this.listening});
  @override State<CommandPage> createState() => _CommandPageState();
}

class _CommandPageState extends State<CommandPage> {
  final input = TextEditingController();
  final messages = <Map<String, String>>[];
  bool busy = false;

  Future<void> send() async {
    final q = input.text.trim(); if (q.isEmpty || busy) return;
    input.clear(); setState(() => messages.add({'role': 'user', 'text': q})); setState(() => busy = true);
    final a = await widget.chat.ask(q);
    widget.log.add('AI', 'Conversation');
    if (!mounted) return;
    setState(() { messages.add({'role': 'jarvis', 'text': a}); busy = false; });
    if (await Prefs().getBool('voice', true)) await widget.tts.speak(a);
  }

  @override Widget build(BuildContext context) => Column(children: [
    Expanded(child: messages.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.auto_awesome, size: 72, color: Colors.cyan.withOpacity(.75)), const SizedBox(height: 18),
      const Text('Bonjour. JARVIS NEO Mobile est opérationnel.', style: TextStyle(fontSize: 18)), const SizedBox(height: 8),
      const Text('Voix, IA, appareils, fichiers et automatisations.', style: TextStyle(color: Colors.grey)),
    ])) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (context, i) {
      final m = messages[i]; final user = m['role'] == 'user';
      return Align(alignment: user ? Alignment.centerRight : Alignment.centerLeft, child: Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: user ? Colors.cyan.withOpacity(.18) : Colors.white.withOpacity(.06), border: Border.all(color: user ? Colors.cyan.withOpacity(.25) : Colors.white.withOpacity(.08))),
        child: Text(m['text']!),
      ));
    })),
    SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [
      Expanded(child: TextField(controller: input, onSubmitted: (_) => send(), decoration: InputDecoration(hintText: 'Parler à JARVIS…', prefixIcon: const Icon(Icons.chat_bubble_outline), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)))),
      const SizedBox(width: 8), IconButton.filled(onPressed: widget.onVoice, icon: Icon(widget.listening ? Icons.stop : Icons.mic)), const SizedBox(width: 4),
      FloatingActionButton.small(onPressed: busy ? null : send, child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_upward)),
    ])))
  ]);
}

class ChatService {
  Future<String> ask(String text) async {
    final p = await SharedPreferences.getInstance();
    final key = p.getString('groq_key') ?? ''; final model = p.getString('groq_model') ?? 'llama-3.1-8b-instant';
    if (key.isEmpty) return 'Mode local : aucune clé Groq configurée. JARVIS a bien reçu : "$text"';
    try {
      final r = await http.post(Uri.parse('https://api.groq.com/openai/v1/chat/completions'), headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'}, body: jsonEncode({
        'model': model, 'messages': [{'role': 'system', 'content': 'You are JARVIS NEO Mobile. Answer in French, concise, helpful and action-oriented. Minimize tokens.'}, {'role': 'user', 'content': text}], 'temperature': .3,
      }));
      if (r.statusCode == 200) { final j = jsonDecode(r.body); return j['choices'][0]['message']['content'] ?? 'Réponse vide.'; }
      return 'IA cloud indisponible (${r.statusCode}). JARVIS recommande le mode local.';
    } catch (_) { return 'Connexion IA indisponible. JARVIS reste en mode local.'; }
  }
}

class Prefs { Future<bool> getBool(String key, bool def) async => (await SharedPreferences.getInstance()).getBool(key) ?? def; }
class ActivityLog { final entries = <String>[]; void add(String type, String text) { entries.insert(0, '$type • $text'); if (entries.length > 100) entries.removeLast(); } }

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const SectionTitle('Écosystème JARVIS'), DeviceCard('JARVIS NEO PC', 'Connexion à établir', Icons.computer, false), DeviceCard('Téléphone', 'Cet appareil • actif', Icons.smartphone, true), DeviceCard('Google Home', 'Prêt à connecter', Icons.home_outlined, false),
    const SizedBox(height: 20), Card(child: ListTile(leading: const Icon(Icons.add_link), title: const Text('Ajouter un appareil'), subtitle: const Text('Détection automatique ou code à 6 chiffres'), trailing: const Icon(Icons.chevron_right), onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Appairage'), content: Text('Le protocole JARVIS NEO utilisera la découverte locale ou un code à 6 chiffres.'))))),
  ]);
}
class DeviceCard extends StatelessWidget { final String name, sub; final IconData icon; final bool on; const DeviceCard(this.name, this.sub, this.icon, this.on, {super.key}); @override Widget build(BuildContext context) => Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(name), subtitle: Text(sub), trailing: Icon(on ? Icons.check_circle : Icons.radio_button_unchecked, color: on ? Colors.cyan : null))); }

class FilesPage extends StatelessWidget {
  const FilesPage({super.key});
  Future<void> pick(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(withData: false, allowMultiple: true);
    if (!context.mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.files.length} fichier(s) sélectionné(s) pour JARVIS.')));
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const SectionTitle('Fichiers & IA'), ActionTile('Analyser un fichier', 'Sélectionner PDF, DOCX, XLSX, PPTX, images et autres formats compatibles', Icons.document_scanner, () {}),
    ActionTile('Importer pour analyse', 'Ouvre le sélecteur de fichiers du téléphone', Icons.upload_file, () => pick(context)),
    const ActionTile('Créer un document', 'PDF, DOCX, XLSX, PPTX, CSV, TXT', Icons.create_new_folder, null),
    const ActionTile('Convertir / modifier', 'Traitement local prioritaire pour économiser les tokens', Icons.transform, null),
    const ActionTile('Nettoyer le stockage', 'Doublons, gros fichiers et éléments inutiles', Icons.cleaning_services, null),
  ]);
}
class ActionTile extends StatelessWidget { final String title, sub; final IconData icon; final VoidCallback? action; const ActionTile(this.title, this.sub, this.icon, this.action, {super.key}); @override Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: Icon(icon, color: Colors.cyan), title: Text(title), subtitle: Text(sub), trailing: const Icon(Icons.chevron_right), onTap: action)); }

class RoutinesPage extends StatelessWidget { const RoutinesPage({super.key}); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const SectionTitle('Routines'), FilledButton.icon(onPressed: () => _info(context), icon: const Icon(Icons.add), label: const Text('Créer'))]),
  const ActionTile('Mode nuit', 'Heure + présence + appareils autorisés', Icons.nightlight_round, null), const ActionTile('Arrivée à la maison', 'Géofence + Wi-Fi + appareils domestiques', Icons.home, null), const ActionTile('Batterie faible', 'Économie d’énergie + notifications', Icons.battery_alert, null),
  const ActionTile('Langage naturel', 'Décrire la routine, puis validation avant activation', Icons.auto_awesome, null),
]); static void _info(BuildContext c) => showDialog(context: c, builder: (_) => const AlertDialog(title: Text('Création de routine'), content: Text('Le moteur de routines sera relié aux événements, permissions et appareils autorisés.'))); }

class SentinelPage extends StatelessWidget { const SentinelPage({super.key}); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
  Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.cyan.withOpacity(.3))), child: const Row(children: [Icon(Icons.shield, color: Colors.cyan, size: 42), SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('SENTINEL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('Surveillance intelligente')]))])),
  const SizedBox(height: 14), const ActionTile('Confidentialité', 'Permissions, caméra, micro, localisation et accès applicatifs', Icons.lock_outline, null), const ActionTile('Réseau', 'Qualité, connexions et anomalies', Icons.wifi_find, null), const ActionTile('Applications', 'Comportements et accès inhabituels', Icons.apps, null), const ActionTile('Stockage', 'Analyse des fichiers et risques potentiels', Icons.sd_storage, null),
]); }

class SettingsPage extends StatefulWidget { final ValueChanged<bool> onTheme; const SettingsPage({super.key, required this.onTheme}); @override State<SettingsPage> createState() => _SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage> {
  final keyCtrl = TextEditingController(); bool voice = true, auto = false; String model = 'llama-3.1-8b-instant';
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { final p = await SharedPreferences.getInstance(); keyCtrl.text = p.getString('groq_key') ?? ''; voice = p.getBool('voice') ?? true; auto = p.getBool('auto') ?? false; model = p.getString('groq_model') ?? model; if (mounted) setState(() {}); }
  Future<void> save() async { final p = await SharedPreferences.getInstance(); await p.setString('groq_key', keyCtrl.text.trim()); await p.setBool('voice', voice); await p.setBool('auto', auto); await p.setString('groq_model', model); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paramètres enregistrés localement.'))); }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const SectionTitle('IA & tokens'), TextField(controller: keyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Clé API Groq', helperText: 'Stockée localement, jamais codée en dur.')),
    const SizedBox(height: 12), DropdownButtonFormField<String>(value: model, decoration: const InputDecoration(labelText: 'Modèle cloud'), items: const ['llama-3.1-8b-instant', 'llama-3.3-70b-versatile', 'qwen/qwen3-32b'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => model = v!)),
    SwitchListTile(title: const Text('Voix'), subtitle: const Text('Lire les réponses de JARVIS'), value: voice, onChanged: (v) => setState(() => voice = v)), SwitchListTile(title: const Text('Autonomie adaptative'), subtitle: const Text('Choisir cloud/local selon le contexte'), value: auto, onChanged: (v) => setState(() => auto = v)),
    const Divider(), const SectionTitle('Sécurité'), const ListTile(leading: Icon(Icons.fingerprint), title: Text('Biométrie + PIN'), subtitle: Text('Déverrouillage et actions sensibles')), const ListTile(leading: Icon(Icons.admin_panel_settings), title: Text('Permissions par application'), subtitle: Text('Accès précis et révocable')),
    const Divider(), const SectionTitle('Compte & synchronisation'), const ListTile(leading: Icon(Icons.passkey), title: Text('Compte JARVIS NEO'), subtitle: Text('Passkey / biométrie / profils')), const ListTile(leading: Icon(Icons.backup), title: Text('Sauvegarde chiffrée'), subtitle: Text('Sélective, automatique et restaurable')),
    FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('Enregistrer')),
  ]);
}

class SectionTitle extends StatelessWidget { final String text; const SectionTitle(this.text, {super.key}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))); }
