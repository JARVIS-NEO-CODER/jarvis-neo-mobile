class TokenBudget {
  static String compact(String text, {int maxChars = 5000}) {
    final t = text.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars)}\n[contexte réduit automatiquement pour économiser les tokens]';
  }
  static String systemPrompt({String? instructions}) => 'JARVIS NEO Mobile. Répondre en français, utile et concis. Minimiser les tokens. ${instructions ?? ''}';
}
