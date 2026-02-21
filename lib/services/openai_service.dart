import 'dart:convert';
import 'package:http/http.dart' as http;
import '../secrets.dart';

class OpenAIService {
  static const String _url = "https://api.openai.com/v1/chat/completions";

  static Future<String> explainText(String extractedText) async {
    final response = await http.post(
      Uri.parse(_url),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $openAiApiKey",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "system",
            "content":
                "You explain documents in clear, neutral, adult language. You extract meaning, identify required actions, and remove irrelevant details. You never preserve the original tone or formatting."
          },
          {
            "role": "user",
            "content":
                "Explain the following text so the reader quickly understands the essential meaning and any required actions.\n\n"
                "Always produce two sections in this exact order:\n\n"
                "What you need to know:\n"
                "(A short explanation in 2–4 sentence paragraphs. Extract the key meaning. Remove greetings, closings, signatures, names, emotional tone, filler, repeated information, and anything not essential.)\n\n"
                "What you need to do:\n"
                "(List only the actions the reader must take. Use bullet points ONLY if the original text contains bullet points or if actions are naturally listed. If no action is required, write: No action is required.)\n\n"
                "IMPORTANT: Always include one blank line between the end of the “What you need to know:” section and the beginning of the “What you need to do:” section.\n\n"
                "Do NOT rewrite the document. Do NOT preserve the original style or structure. Do NOT use Markdown, headings, bold text, or numbered sections.\n\n"
                "Only return the explanation. Nothing else.\n\n"
                "Text:\n$extractedText"
          }
        ],
        "temperature": 0.2,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"];
    } else {
      return "Error: ${response.statusCode} — ${response.body}";
    }
  }
}