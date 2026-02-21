// lib/services/sanitizer.dart

String sanitizeExplanation(String text) {
  String cleaned = text.trim();

  // Remove conversational intros
  final intros = [
    "sure",
    "here's",
    "here is",
    "let me",
    "absolutely",
    "of course",
    "i can",
    "i will",
  ];

  for (final intro in intros) {
    if (cleaned.toLowerCase().startsWith(intro)) {
      final firstPeriod = cleaned.indexOf('.');
      if (firstPeriod != -1) {
        cleaned = cleaned.substring(firstPeriod + 1).trim();
      }
    }
  }

  // Remove greetings
  cleaned = cleaned.replaceAll(RegExp(
    r'^(dear|hello|hi|greetings)[^,\n]*,',
    caseSensitive: false,
    multiLine: true,
  ), '');

  // Remove closings
  cleaned = cleaned.replaceAll(RegExp(
    r'(sincerely|warmly|best regards|best|thank you|thanks)[^,\n]*,?',
    caseSensitive: false,
  ), '');

  // Remove Markdown bold/italics
  cleaned = cleaned.replaceAll('**', '');
  cleaned = cleaned.replaceAll('*', '');
  cleaned = cleaned.replaceAll('_', '');

  // Remove Markdown headings
  cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');

  // Normalize spacing
  cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return cleaned.trim();
}