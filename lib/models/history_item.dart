class HistoryItem {
  final String extractedText;
  final String explanation;
  final DateTime timestamp;

  HistoryItem({
    required this.extractedText,
    required this.explanation,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'extractedText': extractedText,
      'explanation': explanation,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      extractedText: map['extractedText'],
      explanation: map['explanation'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}