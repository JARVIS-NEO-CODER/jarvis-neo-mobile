import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class JarvisCore {
  JarvisCore._();
  static final instance = JarvisCore._();
  Future<String> ask(String text) async {
    final p = await SharedPreferences.getInstance();
    final key = p.getString('groq_key') ?? '';
    final model = p.getString('groq_model') ?? 'llama-3.1-8b-instant';
    if (key.isEmpty) return 'Je peux exécuter cette commande via JARVIS NEO PC une fois connecté.';
    try {
      final response = await http.post(Uri.parse('https://api.groq.com/openai/v1/chat/completions'), headers: {'Authorization':'Bearer $key','Content-Type':'application/json'}, body: jsonEncode({'model':model,'messages':[{'role':'system','content':'You are JARVIS NEO Mobile. Answer in French, concise, useful. Minimize tokens.'},{'role':'user','content':text}], 'temperature':0.3}));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String,dynamic>;
        return (((json['choices'] as List).first as Map)['message'] as Map)['content']?.toString() ?? 'Réponse vide.';
      }
      debugPrint('Groq ${response.statusCode}: ${response.body}');
    } catch (e) { debugPrint('AI error: $e'); }
    return 'Le service IA cloud est indisponible. Mode local/PC recommandé.';
  }
}
