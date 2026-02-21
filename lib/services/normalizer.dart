// lib/services/normalizer.dart

String normalizeExplanation(String text) {
  String out = text;

  // 1. Normalize Unicode bullets to a single bullet style
  out = out.replaceAll(RegExp(r'[•●▪▫‣⁃]'), '•');

  // 2. Normalize Unicode dashes to a simple hyphen
  out = out.replaceAll(RegExp(r'[–—‒―]'), '-');

  // 3. Remove invisible / zero-width characters
  out = out.replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060]'), '');

  // 4. Normalize trailing whitespace on every line
  out = out
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n');

  // 5. Normalize section labels (remove accidental spaces)
  out = out.replaceAll(
      RegExp(r'^what you need to know:\s*$', caseSensitive: false, multiLine: true),
      'What you need to know:');

  out = out.replaceAll(
      RegExp(r'^what you need to do:\s*$', caseSensitive: false, multiLine: true),
      'What you need to do:');

  // 6. Ensure exactly one blank line between the two sections
  out = out.replaceAll(
      RegExp(r'What you need to know:\n+(?=What you need to do:)'),
      'What you need to know:\n\n');

  // 7. Collapse 3+ blank lines into 2
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  // 8. Ensure bullets start on their own line
  out = out.replaceAllMapped(
  RegExp(r'(?<!\n)([-•]\s+)'),
  (match) => '\n${match.group(1)}',
);



  // 9. Trim final whitespace
  return out.trim();
}