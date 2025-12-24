// Camera Screen for scanning plants
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mkulima_ai/core/theme/theme.dart';
import 'package:mkulima_ai/features/scan/presentation/providers/scan_provider.dart';
import 'package:mkulima_ai/features/scan/presentation/widgets/scan_overlay.dart';
import 'package:mkulima_ai/features/scan/presentation/widgets/scan_button.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Initialize ML model on startup
    ref.read(scanProvider.notifier).initializeModel();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false,
      );

      await _controller.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (!_isInitialized) return;

    try {
      final scanNotifier = ref.read(scanProvider.notifier);
      
      // Show loading state
      scanNotifier.setLoading(true);
      
      // Capture image
      final image = await _controller.takePicture();
      
      // Process with ML
      await scanNotifier.analyzeImage(image.path);
      
      // Navigate to results if successful
      if (scanNotifier.state.result != null) {
        Navigator.of(context).pushNamed(
          '/scan/result',
          arguments: scanNotifier.state.result,
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      ref.read(scanProvider.notifier).setLoading(false);
    }
  }

  Future<void> _pickFromGallery() async {
    final scanNotifier = ref.read(scanProvider.notifier);
    
    try {
      scanNotifier.setLoading(true);
      await scanNotifier.pickAndAnalyzeImage();
      
      if (scanNotifier.state.result != null) {
        Navigator.of(context).pushNamed(
          '/scan/result',
          arguments: scanNotifier.state.result,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gallery error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      scanNotifier.setLoading(false);
    }
  }

  void _toggleFlash() {
    if (_controller.value.isInitialized) {
      setState(() {
        _isFlashOn = !_isFlashOn;
        _controller.setFlashMode(
          _isFlashOn ? FlashMode.torch : FlashMode.off,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final scanState = ref.watch(scanProvider);
    final scanNotifier = ref.read(scanProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            if (_isInitialized)
              CameraPreview(_controller)
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.green,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Initializing camera...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Scan Overlay Guide
            if (_isInitialized)
              const ScanOverlay(),

            // Top Controls
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  
                  // Flash Toggle
                  IconButton(
                    onPressed: _toggleFlash,
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 32,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  // Model Status
                  if (!scanNotifier.isModelLoaded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.downloading, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Loading AI model...',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Scan Button
                  ScanButton(
                    isLoading: scanState.isLoading,
                    isModelReady: scanNotifier.isModelLoaded,
                    onTap: _takePicture,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Gallery Button
                  TextButton.icon(
                    onPressed: scanState.isLoading ? null : _pickFromGallery,
                    icon: const Icon(
                      Icons.photo_library,
                      color: Colors.white70,
                    ),
                    label: Text(
                      'Choose from Gallery',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
