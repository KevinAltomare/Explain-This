import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isInitialized ? _buildCameraPreview() : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller!;
    final size = MediaQuery.of(context).size;

    final previewSize = controller.value.previewSize!;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    // ⭐ Correct rotated preview sizes
    final correctedWidth = isPortrait ? previewSize.height : previewSize.width;
    final correctedHeight = isPortrait ? previewSize.width : previewSize.height;

    final aspectRatio = correctedWidth / correctedHeight;

    return Stack(
      children: [
        // ⭐ Distortion-free preview
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.width / aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        ),

        // ⭐ Shutter button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _takePhoto,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 6),
                ),
              ),
            ),
          ),
        ),

        // ⭐ Back button
        Positioned(
          top: 50,
          left: 20,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Future<void> _takePhoto() async {
    if (!_controller!.value.isInitialized) return;

    try {
      final file = await _controller!.takePicture();

      if (!mounted) return;

      // ⭐ Return the image path to ImageReviewScreen
      Navigator.pop(context, file.path);

    } catch (e) {
      debugPrint("Photo capture error: $e");
    }
  }
}