import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'pages/control_center_page.dart';
import 'pages/pc_connection_page.dart';
import 'pages/sentinel_page.dart';

void main() => runApp(const JarvisApp());

class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key});
  @override State<JarvisApp> createState() => _JarvisAppState();
}
class _JarvisAppState extends State<JarvisApp> {
  ThemeMode mode = ThemeMode.dark;
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'JARVIS NEO Mobile', debugShowCheckedModeBanner: false, themeMode: mode,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan)),
    darkTheme: ThemeData.dark(useMaterial3: true).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark), scaffoldBackgroundColor: const Color(0xff070b12)),
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
  bool listening = false;

  Future<void> toggleVoice() async {
    if (listening) { await speech.stop(); if (mounted) setState(() => listening = false); return; }
    if (!await speech.initialize()) return;
    if (mounted) setState(() => listening = true);
    await speech.listen(localeId: 'fr_FR', onResult: (r) { if (r.finalResult && r.recognizedWords.trim().isNotEmpty) _voice(r.recognizedWords.trim()); });
  }
  Future<void> _voice(String text) async {
    await speech.stop();
    if (mounted) setState(() => listening = false);
    final answer = await chat.ask(text);
    if (await Prefs.getBool('voice', true)) await tts.speak(answer);
  }
  @override Widget build(BuildContext context) {
    final pages = [CommandPage(chat: chat, tts: tts, onVoice: toggleVoice, listening: listening), const ControlCenterPage(), const PcConnectionPage(), const FilesPage(), const RoutinesPage(), const SentinelPage(), SettingsPage(onTheme: widget.onTheme)];
    const destinations = [
      NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'JARVIS'),
      NavigationDestination(icon: Icon(Icons.dashboard_customize), label: 'Cockpit'),
      NavigationDestination(icon: Icon(Icons.computer), label: 'PC'),
      NavigationDestination(icon: Icon(Icons.folder_open), label: 'Fichiers'),
      NavigationDestination(icon: Icon(Icons.bolt), label: 'Routines'),
      NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Sentinel'),
      NavigationDestination(icon: Icon(Icons.tune), label: 'Réglages'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('J.A.R.V.I.S. NEO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.1))),
      body: pages[tab], bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: destinations),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(onPressed: toggleVoice, icon: Icon(listening ? Icons.stop : Icons.mic), label: Text(listening ? 'Écoute…' : 'Parler')) : null,
    );
  }
}

class CommandPage extends StatefulWidget {
  final ChatService chat; final FlutterTts tts; final VoidCallback onVoice; final bool listening;
  const CommandPage({super.key, required this.chat, required this.tts, required this.onVoice, required this.listening});
  @override State<CommandPage> createState() => _CommandPageState();
}
class _CommandPageState extends State<CommandPage> {
  final input = TextEditingController(); final messages = <Map<String, String>>[]; bool busy = false;
  Future<void> send() async {
    final q = input.text.trim(); if (q.isEmpty || busy) return; input.clear();
    setState(() { messages.add({'role': 'user', 'text': q}); busy = true; });
    final a = await widget.chat.ask(q); if (!mounted) return;
    setState(() { messages.add({'role': 'jarvis', 'text': a}); busy = false; });
    if (await Prefs.getBool('voice', true)) await widget.tts.speak(a);
  }
  @override void dispose() { input.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Column(children: [
    Expanded(child: messages.isEmpty ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome, size: 72, color: Colors.cyan), SizedBox(height: 18), Text('JARVIS NEO Mobile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Parle à JARVIS ou ouvre le Cockpit pour piloter le PC.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))])) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (_, i) { final m = messages[i]; final user = m['role'] == 'user'; return Align(alignment: user ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .84), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: user ? Colors.cyan.withOpacity(.18) : Colors.white.withOpacity(.06)), child: Text(m['text'] ?? ''))); })),
    SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: input, onSubmitted: (_) => send(), decoration: const InputDecoration(hintText: 'Parler à JARVIS…', prefixIcon: Icon(Icons.chat_bubble_outline)))), const SizedBox(width: 8), IconButton.filled(onPressed: widget.onVoice, icon: Icon(widget.listening ? Icons.stop : Icons.mic)), const SizedBox(width: 4), FloatingActionButton.small(onPressed: busy ? null : send, child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_upward))]))),
  ]);
}

class ChatService {
  Future<String> ask(String text) async {
    final p = await SharedPreferences.getInstance(); final key = p.getString('groq_key') ?? ''; final model = p.getString('groq_model') ?? 'llama-3.1-8b-instant';
    if (key.isEmpty) return 'JARVIS a reçu : "$text". Configure une clé Groq pour activer l’IA cloud.';
    try {
      final r = await http.post(Uri.parse('https://api.groq.com/openai/v1/chat/completions'), headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'}, body: jsonEncode({'model': model, 'messages': [{'role': 'system', 'content': 'You are JARVIS NEO Mobile. Réponds en français, utile, concis et orienté action.'}, {'role': 'user', 'content': text}], 'temperature': .3}));
      if (r.statusCode != 200) return 'IA cloud indisponible (${r.statusCode}).';
      final data = jsonDecode(r.body) as Map<String, dynamic>; final choices = data['choices'];
      if (choices is List && choices.isNotEmpty && choices.first['message'] is Map && choices.first['message']['content'] != null) return choices.first['message']['content'].toString();
      return 'Réponse IA vide.';
    } catch (_) { return 'Connexion IA indisponible.'; }
  }
}

class FilesPage extends StatefulWidget { const FilesPage({super.key}); @override State<FilesPage> createState() => _FilesPageState(); }
class _FilesPageState extends State<FilesPage> {
  final files = <PlatformFile>[];
  Future<void> pick() async { final r = await FilePicker.platform.pickFiles(allowMultiple: true); if (r != null) setState(() => files.addAll(r.files)); }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [const SectionTitle('Fichiers & IA'), ActionTile('Importer', 'Sélectionner plusieurs fichiers sur le téléphone', Icons.upload_file, pick), ActionTile('Analyser avec JARVIS', 'Préparer les fichiers sélectionnés pour analyse', Icons.document_scanner, files.isEmpty ? null : () => _info(context, 'Analyse', 'Les fichiers sont sélectionnés et prêts pour le moteur d’analyse.')), if (files.isNotEmpty) Card(child: Column(children: files.map((f) => ListTile(leading: const Icon(Icons.insert_drive_file), title: Text(f.name), subtitle: Text('${f.size} octets'), trailing: IconButton(onPressed: () => setState(() => files.remove(f)), icon: const Icon(Icons.close)))).toList()))]);
}

class RoutinesPage extends StatefulWidget { const RoutinesPage({super.key}); @override State<RoutinesPage> createState() => _RoutinesPageState(); }
class _RoutinesPageState extends State<RoutinesPage> {
  final routines = <String, bool>{'Mode nuit': false, 'Arrivée à la maison': false, 'Batterie faible': false, 'Mode conduite': false};
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [const SectionTitle('Routines'), const Text('Active ou désactive les scénarios enregistrés. Leur exécution réelle dépend des événements et appareils autorisés.'), const SizedBox(height: 10), ...routines.keys.map((n) => Card(child: SwitchListTile(title: Text(n), subtitle: const Text('Validation conservée côté JARVIS'), value: routines[n]!, onChanged: (v) => setState(() => routines[n] = v))))]);
}

class SettingsPage extends StatefulWidget { final ValueChanged<bool> onTheme; const SettingsPage({super.key, required this.onTheme}); @override State<SettingsPage> createState() => _SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage> {
  final keyCtrl = TextEditingController(); bool voice = true; bool adaptive = false; bool biometric = false; String model = 'llama-3.1-8b-instant';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); keyCtrl.text = p.getString('groq_key') ?? ''; voice = p.getBool('voice') ?? true; adaptive = p.getBool('auto') ?? false; biometric = p.getBool('biometric') ?? false; model = p.getString('groq_model') ?? model; if (mounted) setState(() {}); }
  Future<void> _save() async { final p = await SharedPreferences.getInstance(); await p.setString('groq_key', keyCtrl.text.trim()); await p.setString('groq_model', model); await p.setBool('voice', voice); await p.setBool('auto', adaptive); await p.setBool('biometric', biometric); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paramètres enregistrés localement.'))); }
  @override void dispose() { keyCtrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [const SectionTitle('Réglages'), TextField(controller: keyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Clé Groq', helperText: 'Stockée localement, jamais codée dans le dépôt.')), const SizedBox(height: 10), DropdownButtonFormField<String>(value: model, decoration: const InputDecoration(labelText: 'Modèle Groq'), items: const [DropdownMenuItem(value: 'llama-3.1-8b-instant', child: Text('Llama 3.1 8B')), DropdownMenuItem(value: 'llama-3.3-70b-versatile', child: Text('Llama 3.3 70B')), DropdownMenuItem(value: 'qwen/qwen3-32b', child: Text('Qwen 3 32B'))], onChanged: (v) { if (v != null) setState(() => model = v); }), SwitchListTile(title: const Text('Réponses vocales'), value: voice, onChanged: (v) => setState(() => voice = v)), SwitchListTile(title: const Text('Routage adaptatif'), value: adaptive, onChanged: (v) => setState(() => adaptive = v)), SwitchListTile(title: const Text('Biométrie'), subtitle: const Text('Préférence enregistrée pour protéger les actions sensibles.'), value: biometric, onChanged: (v) => setState(() => biometric = v)), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Enregistrer')), const SizedBox(height: 12), SwitchListTile(title: const Text('Mode clair'), value: false, onChanged: widget.onTheme)]);
}

class SectionTitle extends StatelessWidget { final String text; const SectionTitle(this.text, {super.key}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))); }
class ActionTile extends StatelessWidget { final String title, subtitle; final IconData icon; final VoidCallback? onTap; const ActionTile(this.title, this.subtitle, this.icon, this.onTap, {super.key}); @override Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap)); }
class Prefs { static Future<bool> getBool(String key, bool fallback) async => (await SharedPreferences.getInstance()).getBool(key) ?? fallback; }
void _info(BuildContext context, String title, String message) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
