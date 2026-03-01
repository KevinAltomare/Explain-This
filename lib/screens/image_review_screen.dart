import 'package:flutter/material.dart';
import 'dart:io';
import 'explanation_screen.dart';
import 'main_navigation.dart'; // <-- import the global mainNavKey

class ImageReviewScreen extends StatelessWidget {
  final String imagePath;

  const ImageReviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Photo'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Retake',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // IMPORTANT FIX:
                      // Remove ImageReviewScreen from the Scan tab navigator
                      Navigator.of(context).pop();

                      // Then push ExplanationScreen on the main navigator
                      mainNavKey.currentState!.push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ExplanationScreen(imagePath: imagePath),
                        ),
                      );
                    },
                    child: const Text(
                      'Use this photo',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}