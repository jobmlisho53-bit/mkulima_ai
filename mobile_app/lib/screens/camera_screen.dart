// lib/screens/camera_screen.dart (Updated)
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../widgets/primary_button.dart';
import '../widgets/loading_overlay.dart';
import '../services/ui_classifier_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isProcessing = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Initialize ML model in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UIClassifierService.initialize();
    });
  }
  
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.first;
      
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.medium,
      );
      
      _initializeControllerFuture = _controller.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera error: $e';
      });
    }
  }
  
  Future<void> _takePicture() async {
    if (!UIClassifierService.isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ML model is still loading...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });
      
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      
      // Call ML service
      final result = await UIClassifierService.predictWithUI(image.path);
      
      // Navigate to result screen
      Navigator.pushReplacementNamed(
        context,
        '/result',
        arguments: {
          'imagePath': image.path,
          'disease': result.diseaseName,
          'confidence': result.confidence,
          'severity': result.severity,
          'treatment': result.treatment,
        },
      );
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  Future<void> _pickFromGallery() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      _processImage(pickedFile.path);
    }
  }
  
  Future<void> _processImage(String imagePath) async {
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });
      
      final result = await UIClassifierService.predictWithUI(imagePath);
      
      Navigator.pushReplacementNamed(
        context,
        '/result',
        arguments: {
          'imagePath': imagePath,
          'disease': result.diseaseName,
          'confidence': result.confidence,
          'severity': result.severity,
          'treatment': result.treatment,
        },
      );
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Plant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _isProcessing ? null : _pickFromGallery,
            tooltip: 'Pick from gallery',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          if (_errorMessage == null)
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _initializeCamera,
                    child: const Text('Retry Camera'),
                  ),
                ],
              ),
            ),
          
          // Scan Guide Overlay
          if (_errorMessage == null)
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.green.withOpacity(0.8),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.eco,
                      color: Colors.green,
                      size: 50,
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        AppConstants.scanInstruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Processing Overlay
          if (_isProcessing) const LoadingOverlay(),
          
          // Model Status Indicator
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: UIClassifierService.isModelLoaded 
                    ? Colors.green.withOpacity(0.8)
                    : Colors.orange.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    UIClassifierService.isModelLoaded 
                        ? Icons.check_circle 
                        : Icons.sync,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    UIClassifierService.isModelLoaded 
                        ? 'AI Ready' 
                        : 'Loading AI...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!UIClassifierService.isModelLoaded && !UIClassifierService.isLoading)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'AI model loading...',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(height: 10),
            PrimaryButton(
              text: _isProcessing ? 'Processing...' : 'Capture & Analyze',
              icon: _isProcessing ? null : Icons.camera_alt,
              onPressed: _isProcessing ? null : _takePicture,
              isLoading: _isProcessing,
            ),
          ],
        ),
      ),
    );
  }
}
