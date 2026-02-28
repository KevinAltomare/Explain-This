import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../errors/app_error.dart';
import '../errors/error_screen.dart';
import 'image_review_screen.dart';

class InAppCameraScreen extends StatefulWidget {
  const InAppCameraScreen({super.key});

  @override
  State<InAppCameraScreen> createState() => _InAppCameraScreenState();
}

class _InAppCameraScreenState extends State<InAppCameraScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;

  // Zoom state
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  bool _supportsZoom = false;

  // Torch state
  bool _torchOn = false;

  // Exposure state
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  double _exposureOffset = 0.0;

  // Focus support
  bool _supportsFocus = false;

  // Restart overlay
  bool _isRestartingCamera = false;

  // Zoom unsupported message
  bool _zoomUnsupported = false;
  Timer? _zoomMessageTimer;

  // Tap ripple
  Offset? _tapPosition;
  late AnimationController _tapRippleController;
  late Animation<double> _tapRippleScale;
  late Animation<double> _tapRippleOpacity;

  // Flash overlay
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;

  // Shutter animation
  late AnimationController _shutterScaleController;
  late Animation<double> _shutterScale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Tap ripple
    _tapRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _tapRippleScale = Tween<double>(begin: 0.7, end: 1.4).animate(
      CurvedAnimation(parent: _tapRippleController, curve: Curves.easeOut),
    );
    _tapRippleOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _tapRippleController, curve: Curves.easeOut),
    );

    // Flash overlay
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _flashOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

    // Shutter animation
    _shutterScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.85,
      upperBound: 1.0,
    );
    _shutterScale = CurvedAnimation(
      parent: _shutterScaleController,
      curve: Curves.easeOut,
    );

    _startCameraFlow();
  }

  // ------------------------------------------------------------
  // LIFECYCLE
  // ------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _controller = null;
      _isInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _startCameraFlow();
    }
  }

  // ------------------------------------------------------------
  // GALLERY IMPORT
  // ------------------------------------------------------------

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 95,
      );

      if (picked == null) {
        if (mounted) {
          setState(() => _isRestartingCamera = true);
          await Future.delayed(const Duration(milliseconds: 150));
          await _startCameraFlow();
          if (mounted) {
            setState(() => _isRestartingCamera = false);
          }
        }
        return;
      }

      final file = File(picked.path);
      if (!file.existsSync()) {
        throw AppError(
          AppErrorType.fileMissing,
          "The selected image could not be opened.",
        );
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageReviewScreen(imagePath: picked.path),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            error: e is AppError
                ? e
                : AppError(
                    AppErrorType.unexpected,
                    "Something went wrong while selecting the image.",
                  ),
            onRetry: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // CAMERA FLOW
  // ------------------------------------------------------------

  Future<void> _startCameraFlow() async {
    try {
      await _ensureCameraPermission();
      await _initializeCamera();

      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isInitialized = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            error: e is AppError
                ? e
                : AppError(
                    AppErrorType.unexpected,
                    "Something unexpected happened.\nPlease try again.",
                  ),
            onRetry: _startCameraFlow,
          ),
        ),
      );
    }
  }

  Future<void> _ensureCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) return;

    final result = await Permission.camera.request();
    if (result.isGranted) return;

    throw AppError(
      AppErrorType.cameraPermission,
      "Camera access is required.\nEnable it in Settings to continue.",
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );

      await _controller?.dispose();
      _controller = null;
      _isInitialized = false;

      final controller = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _controller = controller;
      await controller.initialize();
      if (!mounted) return;

      // Zoom
      _maxZoom = await controller.getMaxZoomLevel();
      _minZoom = await controller.getMinZoomLevel();
      _supportsZoom = _maxZoom > _minZoom;
      _currentZoom = 1.0;

      // Exposure
      _minExposureOffset = await controller.getMinExposureOffset();
      _maxExposureOffset = await controller.getMaxExposureOffset();
      _exposureOffset = 0.0;
      try {
        await controller.setExposureOffset(_exposureOffset);
      } catch (_) {}

      // Focus
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      _supportsFocus = controller.value.focusMode != FocusMode.locked;

      // Torch off
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      _torchOn = false;
    } catch (_) {
      throw AppError(
        AppErrorType.cameraUnavailable,
        "The camera couldn't be started.\nTry closing other apps and try again.",
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _zoomMessageTimer?.cancel();
    _controller?.dispose();
    _tapRippleController.dispose();
    _flashController.dispose();
    _shutterScaleController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // TORCH
  // ------------------------------------------------------------

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      await controller.setFlashMode(
        _torchOn ? FlashMode.off : FlashMode.torch,
      );

      if (!mounted) return;
      setState(() => _torchOn = !_torchOn);
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // ZOOM UNSUPPORTED MESSAGE
  // ------------------------------------------------------------

  void _showZoomUnsupportedMessage() {
    if (!_zoomUnsupported) {
      setState(() => _zoomUnsupported = true);
    }

    _zoomMessageTimer?.cancel();
    _zoomMessageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _zoomUnsupported = false);
      }
    });
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: _isInitialized
            ? _buildCameraPreview(theme)
            : _buildLoading(theme),
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: CircularProgressIndicator(
        color: theme.colorScheme.primary,
      ),
    );
  }

  // ------------------------------------------------------------
  // CAMERA PREVIEW
  // ------------------------------------------------------------

  Widget _buildCameraPreview(ThemeData theme) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoading(theme);
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: IgnorePointer(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize!.height,
                height: controller.value.previewSize!.width,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),

        // Restart overlay
        if (_isRestartingCamera)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

        // Gesture detector
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: _handleFocusTap,

            onScaleStart: (details) {
              _baseZoom = _currentZoom;
            },

            onScaleUpdate: (details) async {
              final controller = _controller;
              if (controller == null || !controller.value.isInitialized) return;

              // Use supportsZoom so analyzer stops complaining
              if (!_supportsZoom) {
                _showZoomUnsupportedMessage();
                return;
              }

              final requestedZoom =
                  (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);

              // Detect fake zoom support (your TCL case)
              if (requestedZoom > 1.0 && _currentZoom == 1.0) {
                _showZoomUnsupportedMessage();
              }

              setState(() => _currentZoom = requestedZoom);

              try {
                await controller.setZoomLevel(requestedZoom);
              } catch (_) {
                _showZoomUnsupportedMessage();
              }
            },
          ),
        ),

        // Zoom unsupported message
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _zoomUnsupported ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Zoom not supported on this device",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Tap ripple
        if (_tapPosition != null)
          Positioned(
            left: _tapPosition!.dx - 24,
            top: _tapPosition!.dy - 24,
            child: AnimatedBuilder(
              animation: _tapRippleController,
              builder: (context, child) {
                return Opacity(
                  opacity: _tapRippleOpacity.value,
                  child: Transform.scale(
                    scale: _tapRippleScale.value,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Flash overlay
        FadeTransition(
          opacity: _flashOpacity,
          child: Container(color: Colors.white),
        ),

        // Torch toggle
        Positioned(
          top: 16,
          right: 20,
          child: IconButton(
            icon: Icon(
              _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: theme.colorScheme.onSurface,
              size: 28,
            ),
            onPressed: _toggleTorch,
          ),
        ),

        // Exposure slider
        if (_maxExposureOffset != _minExposureOffset)
          Positioned(
            right: 20,
            bottom: 140,
            top: 80,
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: _exposureOffset.clamp(
                    _minExposureOffset,
                    _maxExposureOffset,
                  ),
                  min: _minExposureOffset,
                  max: _maxExposureOffset,
                  onChanged: (value) async {
                    final controller = _controller;
                    if (controller == null ||
                        !controller.value.isInitialized) {
                      return;
                    }

                    setState(() => _exposureOffset = value);
                    try {
                      await controller.setExposureOffset(value);
                    } catch (_) {}
                  },
                ),
              ),
            ),
          ),

        // Gallery button
        Positioned(
          bottom: 40,
          left: 20,
          child: IconButton(
            icon: Icon(
              Icons.photo_library_outlined,
              color: theme.colorScheme.onSurface,
              size: 30,
            ),
            tooltip: "Choose from library",
            onPressed: _pickFromGallery,
          ),
        ),

        // Shutter button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: ScaleTransition(
              scale: _shutterScale,
              child: GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.onSurface,
                      width: 6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // TAP TO FOCUS
  // ------------------------------------------------------------

  void _handleFocusTap(TapDownDetails details) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final localPos = details.localPosition;

    setState(() => _tapPosition = localPos);
    _tapRippleController.forward(from: 0.0);

    if (!_supportsFocus) return;

    try {
      await controller.setFocusPoint(
        Offset(
          localPos.dx / MediaQuery.of(context).size.width,
          localPos.dy / MediaQuery.of(context).size.height,
        ),
      );
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // CAPTURE
  // ------------------------------------------------------------

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      _shutterScaleController.reverse(from: 1.0);
      _shutterScaleController.forward();

      _flashController.forward(from: 0.0);
      await Future.delayed(const Duration(milliseconds: 80));
      _flashController.reverse();

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}

      final file = await controller.takePicture();
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageReviewScreen(imagePath: file.path),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ErrorScreen(
            error: AppError(
              AppErrorType.cameraFailure,
              "Something went wrong while capturing the image.\nPlease try again.",
            ),
            onRetry: _takePhoto,
          ),
        ),
      );
    }
  }
}