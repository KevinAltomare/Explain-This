import 'package:flutter/material.dart';

class FormattedText extends StatelessWidget {
  final String text;

  const FormattedText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final spans = _format(text);
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(
              fontSize: 16,
              height: 1.5,
            ),
        children: spans,
      ),
    );
  }

  List<InlineSpan> _format(String input) {
    final lines = input.split('\n');
    final List<InlineSpan> spans = [];

    for (var raw in lines) {
      final normalized = raw.trimRight().toLowerCase();
      final line = raw.trim();

      // BLANK LINE → vertical spacing
      if (line.isEmpty) {
        spans.add(
          const WidgetSpan(
            child: SizedBox(
              height: 14,
              width: double.infinity,
            ),
          ),
        );
        continue;
      }

      // SECTION: What you need to know
      if (normalized == "what you need to know:") {
        spans.add(
          const TextSpan(
            text: "What you need to know:\n",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
        );

        spans.add(
          const WidgetSpan(
            child: SizedBox(
              height: 8,
              width: double.infinity,
            ),
          ),
        );
        continue;
      }

      // SECTION: What you need to do
      if (normalized == "what you need to do:") {
        // ⭐ Guaranteed spacing BEFORE this section
        spans.add(
          const WidgetSpan(
            child: SizedBox(
              height: 20,
              width: double.infinity,
            ),
          ),
        );

        spans.add(
          const TextSpan(
            text: "What you need to do:\n",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
        );

        spans.add(
          const WidgetSpan(
            child: SizedBox(
              height: 8,
              width: double.infinity,
            ),
          ),
        );
        continue;
      }

      // BULLETS
      final bulletMatch = RegExp(r'^[-•*]\s+(.*)').firstMatch(line);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)!;

        spans.add(
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 10),
                    child: Icon(Icons.circle, size: 7),
                  ),
                  Expanded(child: Text(content)),
                ],
              ),
            ),
          ),
        );
        continue;
      }

      // NORMAL PARAGRAPH
      spans.add(TextSpan(text: "$line\n"));
    }

    return spans;
  }
}