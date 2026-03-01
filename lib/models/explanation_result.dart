class ExplanationResult {
  final String summary;
  final String requiredAction;
  final String deadline;
  final String moneyInvolved;
  final String consequences;
  final String fullExplanation;

  ExplanationResult({
    required this.summary,
    required this.requiredAction,
    required this.deadline,
    required this.moneyInvolved,
    required this.consequences,
    required this.fullExplanation,
  });

  factory ExplanationResult.fromJson(Map<String, dynamic> json) {
    return ExplanationResult(
      summary: json["summary"] ?? "",
      requiredAction: json["required_action"] ?? "",
      deadline: json["deadline"] ?? "",
      moneyInvolved: json["money_involved"] ?? "",
      consequences: json["consequences"] ?? "",
      fullExplanation: json["full_explanation"] ?? "",
    );
  }
}