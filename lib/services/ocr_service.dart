import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';

import '../errors/app_error.dart';

class OcrService {
  // Detects garbage OCR output (dots, lines, symbols, tiny fragments)
  static bool _looksLikeGarbage(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), '');

    if (cleaned.length < 4) return true;
    if (RegExp(r'^[^A-Za-z0-9]+$').hasMatch(cleaned)) return true;
    if (RegExp(r'^([A-Za-z0-9])\1*$').hasMatch(cleaned)) return true;

    return false;
  }

  static Future<String> extractText(String imagePath) async {
    try {
      final file = File(imagePath);

      // Phase 4: File existence check
      if (!file.existsSync()) {
        throw AppError(
          AppErrorType.fileMissing,
          "The photo could not be found.\nTry taking a new picture.",
        );
      }

      // Phase 4: File readability check
      if (file.lengthSync() == 0) {
        throw AppError(
          AppErrorType.fileMissing,
          "The photo appears to be unreadable.\nTry taking a new picture.",
        );
      }

      final inputImage = InputImage.fromFile(file);
      final textRecognizer = TextRecognizer();

      final result = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final text = result.text.trim();

      if (text.isEmpty || _looksLikeGarbage(text)) {
        throw AppError(
          AppErrorType.emptyScan,
          "I couldn’t find any readable text in the photo.\nTry taking a clearer picture.",
        );
      }

      return text;

    } on AppError {
      rethrow;

    } catch (_) {
      throw AppError(
        AppErrorType.ocrFailure,
        "Something went wrong while reading the text.\nPlease try again.",
      );
    }
  }
}