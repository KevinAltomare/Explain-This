import 'package:flutter/material.dart';
import 'dart:io';
import 'camera_screen.dart';
import 'ocr_screen.dart';

class ImageReviewScreen extends StatelessWidget {
  final String imagePath;

  const ImageReviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Photo'),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // RETAKE BUTTON — now reopens the camera
                OutlinedButton(
                  onPressed: () async {
                    final newImagePath = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CameraScreen(),
                      ),
                    );
                    if (!context.mounted) return;


                    if (newImagePath != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ImageReviewScreen(imagePath: newImagePath),
                        ),
                      );
                    }
                  },
                  child: const Text('Retake'),
                ),

                // USE THIS PHOTO — goes to OCR
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            OcrScreen(imagePath: imagePath),
                      ),
                    );
                  },
                  child: const Text('Use this photo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}