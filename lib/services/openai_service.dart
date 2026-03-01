import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../errors/app_error.dart';
import '../secrets.dart';
import 'dart:async';

import '../models/explanation_result.dart'; // ← make sure this import exists

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
  // PARSE EXPLANATION JSON (added here)
  // ------------------------------------------------------------
  static ExplanationResult parseExplanation(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      return ExplanationResult.fromJson(decoded);
    } catch (_) {
      throw AppError(
        AppErrorType.invalidResponse,
        "The explanation service returned invalid data.",
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
  // EXPLAIN TEXT (main feature) — JSON STRUCTURED VERSION
  // ------------------------------------------------------------
  static Future<String> explainText(String extractedText) async {
    return _sendRequest({
      "model": "gpt-4o-mini",
      "messages": [
        {
          "role": "system",
          "content":
              "You are a document clarity assistant. Your job is to explain official documents in simple, calm, everyday English so an average adult can quickly understand what the document means and what, if anything, they need to do.\n\n"
              "Extract only what is clearly stated. Do not guess or add information. If something is unclear, say that it is unclear. Remove greetings, signatures, disclaimers, and formatting noise. Keep the tone neutral, calm, and practical.\n\n"
              "Return your answer as valid JSON with the following fields:\n"
              "- summary: A short explanation of what the document is about.\n"
              "- required_action: What the reader must do, if anything. If no action is required, write: \"No action appears to be required.\"\n"
              "- deadline: Any dates or deadlines mentioned. If none, write: \"None stated.\"\n"
              "- money_involved: Any payments, charges, refunds, or amounts mentioned. If none, write: \"None stated.\"\n"
              "- consequences: Any consequences of ignoring or delaying action. If none, write: \"None stated.\"\n"
              "- full_explanation: A natural-language explanation written in multiple short paragraphs. Use lists only when they make sense for clarity. Do not use markdown or emojis.\n\n"
              "Do not include any text outside the JSON."
        },
        {
          "role": "user",
          "content":
              "Explain the following document and extract the required information.\n\nText:\n$extractedText"
        }
      ],
      "temperature": 0.2,
    });
  }
}