import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/openai_service.dart';
import '../models/history_item.dart';
import '../widgets/formatted_text.dart';
import '../services/sanitizer.dart';
import '../services/normalizer.dart';
import '../services/ocr_service.dart';


import '../errors/app_error.dart';
import '../errors/error_screen.dart';


class ExplanationScreen extends StatefulWidget {
  final String imagePath;

  const ExplanationScreen({
    super.key,
    required this.imagePath,
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
    _process();
  }

  // ------------------------------------------------------------
  // OCR + MODEL PROCESSING (Phase 4 integrated)
  // ------------------------------------------------------------
  Future<void> _process() async {
    try {
      // Step 1: OCR
      final extractedText = await OcrService.extractText(widget.imagePath);

      // Step 2: Generate English explanation
      final raw = await OpenAIService.explainText(extractedText);
      final cleaned = sanitizeExplanation(raw);
      final normalized = normalizeExplanation(cleaned);

      // Step 3: Language setting (safe read)
      String language = 'en';
      try {
        final settings = Hive.box('settings');
        language = settings.get('language', defaultValue: 'en');
      } catch (_) {
        // If settings box is corrupted, fallback to English
        language = 'en';
      }

      final finalOutput = language == 'es'
          ? await _translateToSpanish(normalized)
          : normalized;

      if (!mounted) return;
      setState(() {
        explanation = finalOutput;
      });

      // Step 4: Save to history (safe write)
      try {
        final settings = Hive.box('settings');
        final saveHistory = settings.get('saveHistory', defaultValue: true);

        if (saveHistory) {
          final box = Hive.box('history');
          final item = HistoryItem(
            extractedText: extractedText,
            explanation: finalOutput,
            timestamp: generatedTime,
          );

          box.add(item.toMap());
        }
      } catch (_) {
        throw AppError(
          AppErrorType.storageFailure,
          "Your device had trouble saving the explanation.\nThe app will still continue normally.",
        );
      }

    } on AppError catch (e) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            error: e,
            onRetry: () {
              Navigator.pop(context); // ErrorScreen
              Navigator.pop(context); // ExplanationScreen
              Navigator.pop(context); // ReviewPhotoScreen
            },
          ),
        ),
      );

    } catch (_) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            error: AppError(
              AppErrorType.unexpected,
              "Something unexpected happened.\nPlease try again.",
            ),
            onRetry: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ),
      );
    }
  }

  Future<String> _translateToSpanish(String englishText) async {
    final prompt = """
Translate the following explanation into clear, natural Spanish.
Keep the meaning, tone, and structure. Avoid literal translations of legal or bureaucratic language.
Use everyday Spanish that is easy for any adult to understand.

$englishText
""";

    final translated = await OpenAIService.generateText(prompt);
    return translated.trim();
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Explanation"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      bottomNavigationBar:
          explanation == null ? null : _buildBottomActionBar(context),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: explanation == null
            ? _buildLoading(theme)
            : _buildContent(theme),
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            "Analyzing document...",
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Generated on ${_formatTimestamp(generatedTime)}",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: 12),

          Divider(
            color: theme.colorScheme.outlineVariant,
            thickness: 1,
          ),

          const SizedBox(height: 16),

          FormattedText(text: explanation!),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              Icons.share,
              color: theme.colorScheme.onSurface,
            ),
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