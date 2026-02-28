import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../errors/app_error.dart';
import '../secrets.dart';
import 'dart:async';

class OpenAIService {
  static const String _url = "https://api.openai.com/v1/chat/completions";

  // ------------------------------------------------------------
  // INTERNAL REQUEST HANDLER
  // ------------------------------------------------------------
  static Future<String> _sendRequest(Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $openAiApiKey",
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      switch (response.statusCode) {
        case 200:
          final data = jsonDecode(response.body);

          if (data["choices"] == null ||
              data["choices"].isEmpty ||
              data["choices"][0]["message"] == null ||
              data["choices"][0]["message"]["content"] == null) {
            throw AppError(
              AppErrorType.invalidResponse,
              "The explanation service returned an unexpected response.",
            );
          }

          return data["choices"][0]["message"]["content"];

        case 401:
          throw AppError(
            AppErrorType.invalidApiKey,
            "Your API key appears to be invalid.",
          );

        case 429:
          throw AppError(
            AppErrorType.rateLimited,
            "The explanation service is receiving too many requests. Please try again shortly.",
          );

        case 500:
        case 502:
        case 503:
        case 504:
          throw AppError(
            AppErrorType.modelUnavailable,
            "The explanation service is temporarily unavailable.",
          );

        default:
          throw AppError(
            AppErrorType.unexpected,
            "Unexpected error: ${response.statusCode}. Please try again.",
          );
      }
    }

    // Network failure
    on SocketException {
      throw AppError(
        AppErrorType.networkFailure,
        "We couldn’t reach the explanation service. Check your connection and try again.",
      );
    }

    // Timeout
    on TimeoutException {
      throw AppError(
        AppErrorType.timeout,
        "The explanation service took too long to respond.",
      );
    }

    // Anything else
    catch (_) {
      throw AppError(
        AppErrorType.unexpected,
        "Something unexpected happened. Please try again.",
      );
    }
  }

  // ------------------------------------------------------------
  // GENERATE TEXT (used for Spanish translation)
  // ------------------------------------------------------------
  static Future<String> generateText(String prompt) async {
    return _sendRequest({
      "model": "gpt-4o-mini",
      "messages": [
        {"role": "user", "content": prompt}
      ],
      "temperature": 0.2,
    });
  }

  // ------------------------------------------------------------
  // EXPLAIN TEXT (main feature)
  // ------------------------------------------------------------
  static Future<String> explainText(String extractedText) async {
    return _sendRequest({
      "model": "gpt-4o-mini",
      "messages": [
        {
          "role": "system",
          "content":
              "You explain documents in clear, calm, adult language. Your goal is to help the reader understand the meaning of the text and what, if anything, they need to do. You remove irrelevant details, simplify complex language, and avoid legal or bureaucratic jargon. You do not add information that is not present in the original text."
        },
        {
          "role": "user",
          "content":
              "Rewrite the following text so the reader quickly understands what it means and any actions they may need to take.\n\n"
                  "Your explanation should:\n"
                  "- Use plain, natural English\n"
                  "- Focus on meaning, not formatting\n"
                  "- Remove greetings, closings, signatures, names, and filler\n"
                  "- Avoid legal jargon unless necessary for accuracy\n"
                  "- Keep the tone neutral, calm, and helpful\n"
                  "- Only describe actions that are clearly required\n"
                  "- Do not use Markdown, headings, bullet points, or emojis\n"
                  "- Do not mention that you are rewriting the text\n\n"
                  "Text:\n$extractedText"
        }
      ],
      "temperature": 0.2,
    });
  }
}