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

  bool _initializing = true; // 🔥 prevents double init on cold start

  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;
  bool _supportsZoom = false;

  bool _torchOn = false;

  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  double _exposureOffset = 0.0;

  bool _supportsFocus = false;

  bool _isRestartingCamera = false;

  bool _zoomUnsupported = false;
  Timer? _zoomMessageTimer;

  Offset? _tapPosition;
  late AnimationController _tapRippleController;
  late Animation<double> _tapRippleScale;
  late Animation<double> _tapRippleOpacity;

  late AnimationController _flashController;
  late Animation<double> _flashOpacity;

  late AnimationController _shutterScaleController;
  late Animation<double> _shutterScale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _flashOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );

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

    // 🔥 Cold-start fix: delay camera init until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _startCameraFlow();
      _initializing = false; // 🔥 allow lifecycle resume AFTER first init
    });
  }

  // ------------------------------------------------------------
  // LIFECYCLE — DISPOSE ON PAUSE, RESTART ON RESUME
  // ------------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_initializing) return; // 🔥 prevent double init on cold start
      if (!_isRestartingCamera) {
        _restartCameraSafely();
      }
    }
  }

  Future<void> _restartCameraSafely() async {
    if (!mounted) return;

    setState(() => _isRestartingCamera = true);

    try {
      await _controller?.dispose();
      _controller = null;
      _isInitialized = false;

      await Future.delayed(const Duration(milliseconds: 150));
      await _startCameraFlow();
    } finally {
      if (mounted) {
        setState(() => _isRestartingCamera = false);
      }
    }
  }

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

      Navigator.of(context).push(
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

      await controller.setZoomLevel(1.0);

      _maxZoom = await controller.getMaxZoomLevel();
      _minZoom = await controller.getMinZoomLevel();
      _supportsZoom = _maxZoom > _minZoom;
      _currentZoom = 1.0;

      _minExposureOffset = await controller.getMinExposureOffset();
      _maxExposureOffset = await controller.getMaxExposureOffset();
      _exposureOffset = 0.0;
      try {
        await controller.setExposureOffset(_exposureOffset);
      } catch (_) {}

      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      _supportsFocus = controller.value.focusMode != FocusMode.locked;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: _isInitialized
          ? _buildCameraPreview(theme)
          : _buildLoading(theme),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: CircularProgressIndicator(
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildCameraPreview(ThemeData theme) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoading(theme);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleFocusTap,
            onScaleStart: (details) {
              _baseZoom = _currentZoom;
            },
            onScaleUpdate: (details) async {
              final controller = _controller;
              if (controller == null || !controller.value.isInitialized) return;

              if (!_supportsZoom) {
                _showZoomUnsupportedMessage();
                return;
              }

              if (details.scale.isNaN || details.scale <= 0) return;

              final newZoom =
                  (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);

              _currentZoom = newZoom;

              try {
                await controller.setZoomLevel(newZoom);
              } catch (_) {
                _showZoomUnsupportedMessage();
              }
            },
            child: CameraPreview(controller),
          ),
        ),

        if (_isRestartingCamera)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha:0.6),
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

        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _zoomUnsupported ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha:0.6),
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

        IgnorePointer(
          ignoring: true,
          child: FadeTransition(
            opacity: _flashOpacity,
            child: Container(color: Colors.white),
          ),
        ),

        Positioned(
          top: 50,
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

        if (_maxExposureOffset != _minExposureOffset)
          Positioned(
            right: 20,
            bottom: 180,
            top: 200,
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
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

        Positioned(
          bottom: 40,
          left: 20,
          child: IconButton(
            icon: Icon(
              Icons.photo_library_outlined,
              color: theme.colorScheme.onSurface,
              size: 30,
            ),
            onPressed: _pickFromGallery,
          ),
        ),

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

      Navigator.of(context).push(
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