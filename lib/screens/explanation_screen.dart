import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/openai_service.dart';
import '../models/history_item.dart';
import '../widgets/formatted_text.dart';
import '../services/sanitizer.dart';
import '../services/normalizer.dart';

class ExplanationScreen extends StatefulWidget {
  final String extractedText;

  const ExplanationScreen({
    super.key,
    required this.extractedText,
  });

  @override
  State<ExplanationScreen> createState() => _ExplanationScreenState();
}

class _ExplanationScreenState extends State<ExplanationScreen> {
  String? explanation;
  late final DateTime generatedTime;

  @override
  void initState() {
    super.initState();
    generatedTime = DateTime.now();
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    final raw = await OpenAIService.explainText(widget.extractedText);
    final cleaned = sanitizeExplanation(raw);
    final normalized = normalizeExplanation(cleaned);

    setState(() {
      explanation = normalized;
    });

    final settings = Hive.box('settings');
    final saveHistory = settings.get('saveHistory', defaultValue: true);

    if (saveHistory) {
      final box = Hive.box('history');
      final item = HistoryItem(
        extractedText: widget.extractedText,
        explanation: normalized,
        timestamp: generatedTime,
      );

      box.add(item.toMap());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Explanation")),
      bottomNavigationBar:
          explanation == null ? null : _buildBottomActionBar(context),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: explanation == null ? _buildLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            "Analyzing document...",
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Generated on ${_formatTimestamp(generatedTime)}",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade300, thickness: 1),
          const SizedBox(height: 16),

          // ⭐ Sanitized + formatted text
          FormattedText(text: explanation!),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ⭐ Updated unified bottom action bar
  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: "Share",
            onPressed: () {
              Share.share(explanation!);
            },
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    return "${time.month}/${time.day}/${time.year}  "
        "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
  }
}