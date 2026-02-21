import 'package:flutter/material.dart';
import 'image_review_screen.dart';
import 'camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEFF1F5), // soft grey
              Color(0xFFFFFFFF), // pure white
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Title
                const Text(
                  "Explain This",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 16),

                // Supporting line
                Text(
                  "Take a photo of any document, form, or letter and receive a clear, easy‑to‑understand explanation.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 40),

                // Subtle icon
                Center(
                  child: Icon(
                    Icons.description_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                ),

                const Spacer(),

                // Main action button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(
                      "Take a Photo",
                      style: TextStyle(fontSize: 18),
                    ),
                    onPressed: () async {
                      final imagePath = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CameraScreen(),
                        ),
                      );

                      if (!context.mounted) return;

                      if (imagePath != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ImageReviewScreen(imagePath: imagePath),
                          ),
                        );
                      }
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Privacy reassurance
                Center(
                  child: Text(
                    "Private by design. Photos stay on your device.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}