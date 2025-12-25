/*
 * Mkulima AI - Classifier Service
 * TensorFlow Lite ML Model Integration
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

/// Prediction result from ML model
class PredictionResult {
  final String diseaseName;
  final double confidence;
  final double severity;
  final String treatment;
  final List<double> allProbabilities;
  final int predictionIndex;

  PredictionResult({
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.treatment,
    required this.allProbabilities,
    required this.predictionIndex,
  });

  @override
  String toString() {
    return 'PredictionResult(diseaseName: $diseaseName, confidence: ${(confidence * 100).toStringAsFixed(1)}%, severity: $severity)';
  }
}

/// Main classifier service for plant disease detection
class ClassifierService {
  // Singleton instance
  static final ClassifierService _instance = ClassifierService._internal();
  factory ClassifierService() => _instance;
  ClassifierService._internal();

  // Model and state management
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;
  bool _isInitializing = false;
  StreamController<double>? _progressController;
  
  // Model configuration
  static const String _modelPath = 'assets/models/mkulima_ai_model.tflite';
  static const String _labelsPath = 'assets/models/class_labels.json';
  static const int _inputSize = 224; // Model input size (adjust based on your model)
  static const int _numThreads = 4;

  /// Initialize the ML model and labels
  Future<void> initialize({bool forceReload = false}) async {
    if (_isModelLoaded && !forceReload) return;
    if (_isInitializing) {
      await _waitForInitialization();
      return;
    }

    _isInitializing = true;
    _progressController = StreamController<double>.broadcast();

    try {
      debugPrint('🔄 Starting ML model initialization...');
      _progressController?.add(0.1);

      // Load labels
      await _loadLabels();
      _progressController?.add(0.3);

      // Load model
      await _loadModel();
      _progressController?.add(0.7);

      // Verify model
      await _verifyModel();
      _progressController?.add(0.9);

      _isModelLoaded = true;
      _progressController?.add(1.0);
      
      debugPrint('✅ ML Model initialized successfully');
      debugPrint('   Labels: ${_labels.length} diseases');
      debugPrint('   Model: ${_interpreter != null ? "Loaded" : "Failed"}');

    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize ML model: $e');
      debugPrint('Stack trace: $stackTrace');
      
      _isModelLoaded = false;
      _progressController?.addError(e);
      
      rethrow;
    } finally {
      _isInitializing = false;
      await _progressController?.close();
      _progressController = null;
    }
  }

  /// Load disease labels from JSON
  Future<void> _loadLabels() async {
    try {
      final labelsJson = await rootBundle.loadString(_labelsPath);
      final Map<String, dynamic> decoded = jsonDecode(labelsJson);
      
      // Convert map to sorted list
      _labels = List.generate(decoded.length, (i) {
        final label = decoded[i.toString()] ?? 'Unknown_Disease_$i';
        return label.toString();
      });
      
      debugPrint('📋 Loaded ${_labels.length} disease labels');
      if (_labels.length < 3) {
        debugPrint('⚠️ Warning: Very few labels loaded');
      }
    } catch (e) {
      debugPrint('❌ Error loading labels: $e');
      // Provide fallback labels
      _labels = [
        'Tomato_Early_blight',
        'Tomato_Late_blight',
        'Tomato_healthy',
      ];
    }
  }

  /// Load TensorFlow Lite model
  Future<void> _loadModel() async {
    try {
      final interpreterOptions = InterpreterOptions()
        ..threads = _numThreads
        ..useNnApiForAndroid = !kDebugMode // Disable in debug for better errors
        ..allowFp16PrecisionForFp32 = true;
      
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: interpreterOptions,
      );
      
      debugPrint('🤖 Model loaded from: $_modelPath');
    } catch (e) {
      debugPrint('❌ Error loading model: $e');
      // Check if asset exists
      try {
        await rootBundle.load(_modelPath);
        debugPrint('✅ Model asset exists but failed to load');
      } catch (assetError) {
        debugPrint('❌ Model asset not found: $assetError');
      }
      rethrow;
    }
  }

  /// Verify model configuration
  Future<void> _verifyModel() async {
    if (_interpreter == null) {
      throw Exception('Interpreter is null');
    }

    try {
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      debugPrint('🔍 Model Verification:');
      debugPrint('   Input tensors: ${inputTensors.length}');
      debugPrint('   Output tensors: ${outputTensors.length}');
      
      for (var i = 0; i < inputTensors.length; i++) {
        final tensor = inputTensors[i];
        debugPrint('   Input $i: shape=${tensor.shape}, type=${tensor.type}');
      }
      
      for (var i = 0; i < outputTensors.length; i++) {
        final tensor = outputTensors[i];
        debugPrint('   Output $i: shape=${tensor.shape}, type=${tensor.type}');
      }
      
      // Test with dummy data to ensure model runs
      await _testModel();
      
    } catch (e) {
      debugPrint('❌ Model verification failed: $e');
      rethrow;
    }
  }

  /// Test model with dummy data
  Future<void> _testModel() async {
    try {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      
      // Create dummy input
      final totalElements = inputShape.reduce((a, b) => a * b);
      final dummyInput = List<double>.filled(totalElements, 0.5);
      final reshapedInput = dummyInput.reshape(inputShape);
      
      // Prepare output buffer
      final outputBuffer = TensorBuffer.createFixedSize(
        outputShape,
        _interpreter!.getOutputTensor(0).type,
      );
      
      // Run inference
      _interpreter!.run(reshapedInput, outputBuffer.buffer);
      
      debugPrint('🧪 Model test passed');
      debugPrint('   Input shape: $inputShape');
      debugPrint('   Output shape: $outputShape');
      
    } catch (e) {
      debugPrint('❌ Model test failed: $e');
      throw Exception('Model test failed: $e');
    }
  }

  /// Wait for initialization if already in progress
  Future<void> _waitForInitialization() async {
    final completer = Completer<void>();
    final subscription = _progressController?.stream.listen(
      (progress) {
        if (progress == 1.0) completer.complete();
      },
      onError: (error) => completer.completeError(error),
    );
    
    await completer.future;
    subscription?.cancel();
  }

  /// Preprocess image for model input
  TensorImage _preprocessImage(File imageFile) {
    try {
      final tensorImage = TensorImage.fromFile(imageFile);
      
      // Get model input dimensions
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];
      
      // Create image processor
      final imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputHeight, inputWidth, ResizeMethod.BILINEAR))
        .add(NormalizeOp(127.5, 127.5)) // Normalize to [-1, 1]
        .build();
      
      return imageProcessor.process(tensorImage);
    } catch (e) {
      debugPrint('❌ Image preprocessing error: $e');
      rethrow;
    }
  }

  /// Run prediction on image
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
      
      // Preprocess image
      final inputTensor = _preprocessImage(imageFile);
      
      // Get model info
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputType = _interpreter!.getOutputTensor(0).type;
      
      debugPrint('   Model input: $inputShape');
      debugPrint('   Model output: $outputShape');
      
      // Prepare output buffer
      final outputBuffer = TensorBuffer.createFixedSize(outputShape, outputType);
      
      // Run inference
      _interpreter!.run(inputTensor.buffer, outputBuffer.buffer);
      
      // Get probabilities
      final probabilities = outputBuffer.getDoubleList();
      
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
      
      // Calculate severity (confidence-based)
      final severity = _calculateSeverity(maxProbability);
      
      // Get treatment recommendation
      final treatment = _getTreatmentRecommendation(predictedLabel, maxProbability);
      
      stopwatch.stop();
      
      debugPrint('🎯 Prediction completed in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('   Disease: $predictedLabel');
      debugPrint('   Confidence: ${(maxProbability * 100).toStringAsFixed(1)}%');
      debugPrint('   Severity: ${(severity * 100).toStringAsFixed(1)}%');
      debugPrint('   Index: $maxIndex/${_labels.length}');
      
      // Log top 3 predictions in debug mode
      if (kDebugMode) {
        final sortedIndices = List<int>.generate(
          probabilities.length, 
          (i) => i,
        )..sort((a, b) => probabilities[b].compareTo(probabilities[a]));
        
        debugPrint('   Top 3 predictions:');
        for (int i = 0; i < 3 && i < sortedIndices.length; i++) {
          final idx = sortedIndices[i];
          final label = _labels.length > idx ? _labels[idx] : 'Unknown';
          debugPrint('     ${i + 1}. $label: ${(probabilities[idx] * 100).toStringAsFixed(1)}%');
        }
      }

      return PredictionResult(
        diseaseName: predictedLabel,
        confidence: maxProbability,
        severity: severity,
        treatment: treatment,
        allProbabilities: probabilities,
        predictionIndex: maxIndex,
      );
      
    } catch (e, stackTrace) {
      debugPrint('❌ Prediction error: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to analyze image: ${e.toString()}');
    }
  }

  /// Calculate severity based on confidence
  double _calculateSeverity(double confidence) {
    // Adjust these thresholds based on your model's performance
    if (confidence > 0.9) return 0.9; // Critical
    if (confidence > 0.75) return 0.75; // High
    if (confidence > 0.5) return 0.5; // Medium
    return 0.3; // Low
  }

  /// Get treatment recommendation based on disease
  String _getTreatmentRecommendation(String diseaseName, double confidence) {
    // Treatment database - expand this based on your labels
    final treatments = {
      'Tomato_Early_blight': 'Apply copper-based fungicide weekly. Remove infected leaves and ensure proper spacing.',
      'Tomato_Late_blight': 'Immediate action required! Use fungicides with chlorothalonil. Destroy infected plants.',
      'Tomato_Bacterial_spot': 'Use copper sprays. Avoid overhead watering and practice crop rotation.',
      'Tomato_Leaf_Mold': 'Improve air circulation, reduce humidity, and apply fungicides.',
      'Tomato_Septoria_leaf_spot': 'Remove infected leaves. Apply fungicide and avoid working with wet plants.',
      'Tomato_Spider_mites_Two_spotted_spider_mite': 'Use miticides or insecticidal soap. Increase humidity.',
      'Tomato__Target_Spot': 'Apply fungicides. Remove affected leaves and ensure proper spacing.',
      'Tomato__Tomato_YellowLeaf__Curl_Virus': 'Control whiteflies using insecticides. Remove infected plants.',
      'Tomato__Tomato_mosaic_virus': 'Use virus-free seeds. Disinfect tools and avoid smoking near plants.',
      'Tomato_healthy': 'Your tomato plant is healthy! Continue regular care and monitoring.',
      'Potato___Early_blight': 'Apply fungicides containing chlorothalonil. Remove infected foliage.',
      'Potato___Late_blight': 'Destroy infected plants immediately. Use resistant varieties.',
      'Potato___healthy': 'Potato plant is healthy. Maintain proper soil moisture and drainage.',
      'Pepper__bell___Bacterial_spot': 'Use copper sprays. Avoid working when plants are wet.',
      'Pepper__bell___healthy': 'Pepper plant is healthy. Ensure adequate sunlight and nutrients.',
    };
    
    // Format disease name for lookup
    final formattedName = diseaseName
        .replaceAll('_', ' ')
        .replaceAll('  ', ' ')
        .trim();
    
    // Return specific treatment or generic advice
    if (treatments.containsKey(diseaseName)) {
      return treatments[diseaseName]!;
    }
    
    // Try to find partial match
    for (final entry in treatments.entries) {
      if (formattedName.contains(entry.key.split('_').first)) {
        return entry.value;
      }
    }
    
    // Generic fallback
    return 'For ${confidence > 0.7 ? "severe" : "mild"} infection: '
        'Remove affected leaves, improve air circulation, '
        'and consult local agricultural extension officer.';
  }

  /// Get all available disease labels
  List<String> getAvailableDiseases() {
    return List.from(_labels);
  }

  /// Format disease name for display
  String formatDiseaseName(String rawName) {
    return rawName
        .replaceAll('_', ' ')
        .replaceAll('  ', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ');
  }

  /// Check if disease indicates healthy plant
  bool isHealthyPlant(String diseaseName) {
    return diseaseName.toLowerCase().contains('healthy');
  }

  /// Get model status
  bool get isModelLoaded => _isModelLoaded;
  
  /// Get initialization progress stream
  Stream<double>? get initializationProgress => _progressController?.stream;

  /// Get number of loaded labels
  int get labelCount => _labels.length;

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _interpreter?.close();
      _interpreter = null;
      _isModelLoaded = false;
      await _progressController?.close();
      debugPrint('♻️ ClassifierService disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing ClassifierService: $e');
    }
  }

  /// Clear and reload model (for hot reload support)
  Future<void> reloadModel() async {
    await dispose();
    await initialize(forceReload: true);
  }
}

// Global instance getter
ClassifierService get classifierService => ClassifierService();
