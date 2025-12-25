/*
 * Mkulima AI - TensorFlow Lite Classifier Service
 * No longer uses tflite_flutter_helper (discontinued)
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PredictionResult {
  final String diseaseName;
  final double confidence;
  final double severity;
  final String treatment;

  PredictionResult({
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.treatment,
  });

  @override
  String toString() {
    return 'PredictionResult(diseaseName: $diseaseName, confidence: ${(confidence * 100).toStringAsFixed(1)}%, severity: $severity)';
  }
}

class ClassifierService {
  static final ClassifierService _instance = ClassifierService._internal();
  factory ClassifierService() => _instance;
  ClassifierService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;
  
  static const String _modelPath = 'assets/models/mkulima_ai_model.tflite';
  static const String _labelsPath = 'assets/models/class_labels.json';

  Future<void> initialize() async {
    if (_isModelLoaded) return;

    try {
      debugPrint('🔄 Starting ML model initialization...');

      // Load labels
      await _loadLabels();

      // Load model
      await _loadModel();

      _isModelLoaded = true;
      
      debugPrint('✅ ML Model initialized successfully');
      debugPrint('   Labels: ${_labels.length} diseases');

    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize ML model: $e');
      debugPrint('Stack trace: $stackTrace');
      
      _isModelLoaded = false;
      rethrow;
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelsJson = await rootBundle.loadString(_labelsPath);
      final Map<String, dynamic> decoded = jsonDecode(labelsJson);
      
      _labels = List.generate(decoded.length, (i) {
        return decoded[i.toString()] ?? 'Unknown_Disease_$i';
      });
      
      debugPrint('📋 Loaded ${_labels.length} disease labels');
    } catch (e) {
      debugPrint('❌ Error loading labels: $e');
      _labels = [
        'Tomato_Early_blight',
        'Tomato_Late_blight',
        'Tomato_healthy',
        'Potato___Early_blight',
        'Potato___Late_blight',
        'Potato___healthy',
        'Pepper__bell___Bacterial_spot',
        'Pepper__bell___healthy',
      ];
    }
  }

  Future<void> _loadModel() async {
    try {
      final interpreterOptions = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = !kDebugMode;
      
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: interpreterOptions,
      );
      
      debugPrint('🤖 Model loaded from: $_modelPath');
    } catch (e) {
      debugPrint('❌ Error loading model: $e');
      rethrow;
    }
  }

  Future<PredictionResult> predict(String imagePath) async {
    if (!_isModelLoaded) {
      debugPrint('⚠️ Model not loaded, initializing...');
      await initialize();
    }

    if (_interpreter == null) {
      throw Exception('ML model not available');
    }

    Stopwatch stopwatch = Stopwatch()..start();

    try {
      final imageFile = File(imagePath);
      
      if (!await imageFile.exists()) {
        throw FileSystemException('Image file not found', imagePath);
      }

      debugPrint('🔍 Analyzing image: ${imageFile.path}');
      
      // Get model input shape
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];
      
      debugPrint('   Model input: $inputShape');
      
      // Preprocess image
      final inputBuffer = await _preprocessImage(imagePath, inputHeight, inputWidth);
      
      // Prepare output buffer
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputBuffer = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);
      
      // Run inference
      _interpreter!.run(inputBuffer, outputBuffer);
      
      // Get probabilities
      final probabilities = outputBuffer.reshape([outputShape.reduce((a, b) => a * b)]);
      
      if (probabilities.isEmpty) {
        throw Exception('No prediction results returned');
      }
      
      // Find highest probability
      double maxProbability = 0.0;
      int maxIndex = 0;
      
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProbability) {
          maxProbability = probabilities[i];
          maxIndex = i;
        }
      }
      
      // Get predicted label
      final predictedLabel = _labels.length > maxIndex 
          ? _labels[maxIndex] 
          : 'Unknown_Disease_$maxIndex';
      
      // Calculate severity
      final severity = _calculateSeverity(maxProbability);
      
      // Get treatment
      final treatment = _getTreatmentRecommendation(predictedLabel, maxProbability);
      
      stopwatch.stop();
      
      debugPrint('🎯 Prediction completed in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('   Disease: $predictedLabel');
      debugPrint('   Confidence: ${(maxProbability * 100).toStringAsFixed(1)}%');
      debugPrint('   Severity: ${(severity * 100).toStringAsFixed(1)}%');

      return PredictionResult(
        diseaseName: predictedLabel,
        confidence: maxProbability,
        severity: severity,
        treatment: treatment,
      );
      
    } catch (e, stackTrace) {
      debugPrint('❌ Prediction error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to analyze image: ${e.toString()}');
    }
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(
    String imagePath, 
    int targetHeight, 
    int targetWidth
  ) async {
    try {
      // Read image file
      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      
      // Resize image
      final resizedImage = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
      );
      
      // Convert to float array and normalize
      final inputArray = List.generate(
        1, 
        (_) => List.generate(
          targetHeight,
          (h) => List.generate(
            targetWidth,
            (w) => List.generate(
              3,
              (c) {
                final pixel = resizedImage.getPixel(w, h);
                double value;
                switch (c) {
                  case 0: value = img.getRed(pixel).toDouble(); break;
                  case 1: value = img.getGreen(pixel).toDouble(); break;
                  case 2: value = img.getBlue(pixel).toDouble(); break;
                  default: value = 0.0;
                }
                // Normalize to [-1, 1]
                return (value - 127.5) / 127.5;
              },
            ),
          ),
        ),
      );
      
      return inputArray;
    } catch (e) {
      debugPrint('❌ Image preprocessing error: $e');
      rethrow;
    }
  }

  double _calculateSeverity(double confidence) {
    if (confidence > 0.9) return 0.9;
    if (confidence > 0.75) return 0.75;
    if (confidence > 0.5) return 0.5;
    return 0.3;
  }

  String _getTreatmentRecommendation(String diseaseName, double confidence) {
    final treatments = {
      'Tomato_Early_blight': 'Apply copper-based fungicide weekly.',
      'Tomato_Late_blight': 'Use fungicides with chlorothalonil.',
      'Tomato_healthy': 'Plant is healthy! Continue regular care.',
      'Potato___Early_blight': 'Apply fungicides containing chlorothalonil.',
      'Potato___Late_blight': 'Destroy infected plants immediately.',
      'Potato___healthy': 'Potato plant is healthy.',
      'Pepper__bell___Bacterial_spot': 'Use copper sprays.',
      'Pepper__bell___healthy': 'Pepper plant is healthy.',
    };
    
    if (treatments.containsKey(diseaseName)) {
      return treatments[diseaseName]!;
    }
    
    return 'For ${confidence > 0.7 ? "severe" : "mild"} infection: '
        'Remove affected leaves and improve air circulation.';
  }

  String formatDiseaseName(String rawName) {
    return rawName
        .replaceAll('_', ' ')
        .replaceAll('__', ' - ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }

  bool isHealthyPlant(String diseaseName) {
    return diseaseName.toLowerCase().contains('healthy');
  }

  bool get isModelLoaded => _isModelLoaded;
  int get labelCount => _labels.length;

  Future<void> dispose() async {
    try {
      _interpreter?.close();
      _interpreter = null;
      _isModelLoaded = false;
      debugPrint('♻️ ClassifierService disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing ClassifierService: $e');
    }
  }
}

ClassifierService get classifierService => ClassifierService();
