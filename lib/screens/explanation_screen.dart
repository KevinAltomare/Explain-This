import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../services/openai_service.dart';
import '../models/history_item.dart';
import '../models/explanation_result.dart';
import '../widgets/formatted_text.dart';
import '../services/sanitizer.dart';
import '../services/normalizer.dart';
import '../services/ocr_service.dart';
import 'package:explain_this/services/billing_service.dart';

import '../errors/app_error.dart';
import '../errors/error_screen.dart';
import '../services/usage_manager.dart';
import '../screens/paywall_screen.dart';


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
  ExplanationResult? result;
  late final DateTime generatedTime;

  @override
  void initState() {
    super.initState();
    generatedTime = DateTime.now();
    _process();
  }

  // ------------------------------------------------------------
  // OCR + MODEL PROCESSING
  // ------------------------------------------------------------
  Future<void> _process() async {
    try {

    final bool isPremium = await BillingService.instance.isPremium();

    final allowed = await UsageManager.canUseExplanation(isPremium: isPremium);
    
    if (!isPremium && !allowed) {
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PaywallScreen(),
          ),
      );
      return;
    }

    await UsageManager.incrementUsage();




      final extractedText = await OcrService.extractText(widget.imagePath);

      final raw = await OpenAIService.explainText(extractedText);
      final parsed = OpenAIService.parseExplanation(raw);

      final cleaned = sanitizeExplanation(parsed.fullExplanation);
      final normalized = normalizeExplanation(cleaned);

      String language = 'en';
      try {
        final settings = Hive.box('settings');
        language = settings.get('language', defaultValue: 'en');
      } catch (_) {
        language = 'en';
      }

      final translatedExplanation = language == 'es'
          ? await _translateToSpanish(normalized)
          : normalized;

      if (!mounted) return;
      setState(() {
        result = ExplanationResult(
          summary: parsed.summary,
          requiredAction: parsed.requiredAction,
          deadline: parsed.deadline,
          moneyInvolved: parsed.moneyInvolved,
          consequences: parsed.consequences,
          fullExplanation: translatedExplanation,
        );
      });

      try {
        final settings = Hive.box('settings');
        final saveHistory = settings.get('saveHistory', defaultValue: true);

        if (saveHistory) {
          final box = Hive.box('history');
          final item = HistoryItem(
            extractedText: extractedText,
            summary: parsed.summary,
            requiredAction: parsed.requiredAction,
            deadline: parsed.deadline,
            moneyInvolved: parsed.moneyInvolved,
            consequences: parsed.consequences,
            fullExplanation: translatedExplanation,
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

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            error: e,
            onRetry: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Go back to Camera and trigger retake
            },
          ),
        ),
      );

    } catch (_) {
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            error: AppError(
              AppErrorType.unexpected,
              "Something unexpected happened.\nPlease try again.",
            ),
            onRetry: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
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
  // SEMANTIC FIELD CHECK
  // ------------------------------------------------------------
  bool _isMeaningful(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v == "none stated") return false;
    if (v == "none stated.") return false;
    if (v == "none") return false;
    return true;
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
          result == null ? null : _buildBottomActionBar(context),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: result == null
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
    final r = result!;

    final fields = [
      _FieldData(
        icon: Icons.description_outlined,
        label: "Summary",
        value: r.summary,
        alwaysShow: false,
      ),
      _FieldData(
        icon: Icons.check_circle_outline,
        label: "Required Action",
        value: r.requiredAction,
        alwaysShow: true,
      ),
      _FieldData(
        icon: Icons.schedule_outlined,
        label: "Deadline",
        value: r.deadline,
        alwaysShow: false,
      ),
      _FieldData(
        icon: Icons.attach_money,
        label: "Money Involved",
        value: r.moneyInvolved,
        alwaysShow: false,
      ),
      _FieldData(
        icon: Icons.warning_amber_outlined,
        label: "Consequences",
        value: r.consequences,
        alwaysShow: false,
      ),
    ];

    final visibleFields = fields.where((f) {
      if (f.alwaysShow) return true;
      return _isMeaningful(f.value);
    }).toList();

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

          const SizedBox(height: 16),

          if (visibleFields.isNotEmpty) ...[
            for (final field in visibleFields) _buildPremiumCard(theme, field),
            const SizedBox(height: 24),
          ],

          FormattedText(text: r.fullExplanation),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(ThemeData theme, _FieldData data) {
    final bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            data.icon,
            size: 28,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
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
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.share, color: theme.colorScheme.onSurface),
            tooltip: "Share",
            onPressed: () {
              Share.share(result!.fullExplanation);
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

class _FieldData {
  final IconData icon;
  final String label;
  final String value;
  final bool alwaysShow;

  _FieldData({
    required this.icon,
    required this.label,
    required this.value,
    this.alwaysShow = false,
  });
}