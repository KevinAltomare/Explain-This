class HistoryItem {
  final String extractedText;
  final String summary;
  final String requiredAction;
  final String deadline;
  final String moneyInvolved;
  final String consequences;
  final String fullExplanation;
  final DateTime timestamp;

  HistoryItem({
    required this.extractedText,
    required this.summary,
    required this.requiredAction,
    required this.deadline,
    required this.moneyInvolved,
    required this.consequences,
    required this.fullExplanation,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'extractedText': extractedText,
      'summary': summary,
      'requiredAction': requiredAction,
      'deadline': deadline,
      'moneyInvolved': moneyInvolved,
      'consequences': consequences,
      'fullExplanation': fullExplanation,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    // Backward compatibility: old entries only had "explanation"
    final hasStructured = map.containsKey('fullExplanation');

    if (!hasStructured) {
      final explanation = map['explanation'] as String? ?? '';
      return HistoryItem(
        extractedText: map['extractedText'] ?? '',
        summary: _fallbackSummary(explanation),
        requiredAction: '',
        deadline: '',
        moneyInvolved: '',
        consequences: '',
        fullExplanation: explanation,
        timestamp: DateTime.parse(map['timestamp']),
      );
    }

    return HistoryItem(
      extractedText: map['extractedText'] ?? '',
      summary: map['summary'] ?? '',
      requiredAction: map['requiredAction'] ?? '',
      deadline: map['deadline'] ?? '',
      moneyInvolved: map['moneyInvolved'] ?? '',
      consequences: map['consequences'] ?? '',
      fullExplanation: map['fullExplanation'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  static String _fallbackSummary(String explanation) {
    final cleaned = explanation.trim();
    if (cleaned.isEmpty) return "Saved explanation";
    final end = cleaned.indexOf('.');
    if (end != -1) {
      return cleaned.substring(0, end + 1).trim();
    }
    return cleaned.length > 80 ? '${cleaned.substring(0, 80)}…' : cleaned;
  }
}