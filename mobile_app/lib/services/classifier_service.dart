import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

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
}

class ClassifierService {
  static Interpreter? _interpreter;
  static List<String> _labels = [];
  static bool _isInitialized = false;

  /// Initialize model and labels
  static Future<void> loadModelAndLabels() async {
    if (_isInitialized) return;

    try {
      print('📦 Loading ML model...');
      
      // Load labels from your JSON file
      final labelsJson = await rootBundle.loadString('assets/models/class_labels.json');
      final Map<String, dynamic> decoded = jsonDecode(labelsJson);
      
      // Convert map to list, sort by key
      _labels = List.generate(decoded.length, (i) => decoded[i.toString()] ?? 'Unknown');
      
      print('📋 Loaded ${_labels.length} disease labels');
      print('Labels: $_labels');

      // Load TFLite model
      final interpreterOptions = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;

      _interpreter = await Interpreter.fromAsset(
        'assets/models/mkulima_ai_model.tflite',
        options: interpreterOptions,
      );

      // Print model info
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      
      print('🤖 Model loaded successfully');
      print('   Input shape: $inputShape');
      print('   Output shape: $outputShape');
      
      _isInitialized = true;
    } catch (e) {
      print('❌ Error loading model: $e');
      rethrow;
    }
  }

  /// Preprocess image for model input
  static TensorImage _preprocessImage(File imageFile) {
    try {
      final tensorImage = TensorImage.fromFile(imageFile);
      
      // Get model input shape (assuming [1, height, width, 3])
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];
      
      print('🖼️ Preprocessing image to $inputWidth×$inputHeight');

      // Resize and normalize image
      final imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputHeight, inputWidth, ResizeMethod.BILINEAR))
        .add(NormalizeOp(0, 255)) // Normalize to [0, 1]
        .build();

      return imageProcessor.process(tensorImage);
    } catch (e) {
      print('❌ Error preprocessing image: $e');
      rethrow;
    }
  }

  /// Run prediction on image
  static Future<PredictionResult> predict(String imagePath) async {
    if (!_isInitialized) {
      await loadModelAndLabels();
    }

    try {
      final imageFile = File(imagePath);
      
      if (!imageFile.existsSync()) {
        throw Exception('Image file not found: $imagePath');
      }

      print('🔬 Running inference on image...');
      
      // Preprocess image
      final inputTensor = _preprocessImage(imageFile);
      
      // Prepare output buffer
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final outputType = _interpreter!.getOutputTensor(0).type;
      final outputBuffer = TensorBuffer.createFixedSize(outputShape, outputType);
      
      // Run inference
      _interpreter!.run(inputTensor.buffer, outputBuffer.buffer);
      
      // Get probabilities
      final probabilities = outputBuffer.getDoubleList();
      
      // Find max probability and index
      double maxProb = 0;
      int maxIndex = 0;
      
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }
      
      // Get predicted label
      final predictedLabel = _labels.length > maxIndex 
          ? _labels[maxIndex] 
          : 'Unknown Disease';
      
      print('🎯 Prediction: $predictedLabel (${(maxProb * 100).toStringAsFixed(1)}%)');
      print('   All probabilities: $probabilities');

      // Get treatment
      final treatment = _getTreatment(predictedLabel, maxProb);
      
      return PredictionResult(
        diseaseName: predictedLabel,
        confidence: maxProb,
        severity: maxProb, // Using confidence as severity for now
        treatment: treatment,
      );
    } catch (e) {
      print('❌ Error during prediction: $e');
      throw Exception('Failed to analyze image: $e');
    }
  }

  /// Get treatment recommendation based on disease
  static String _getTreatment(String disease, double confidence) {
    // Basic treatment mapping - you can expand this
    final treatments = {
      'Tomato_Early_blight': 'Apply copper-based fungicide weekly. Remove infected leaves.',
      'Tomato_Late_blight': 'Use fungicides containing chlorothalonil. Destroy infected plants.',
      'Tomato_Bacterial_spot': 'Use copper sprays. Avoid overhead watering.',
      'Tomato_Leaf_Mold': 'Improve air circulation. Reduce humidity.',
      'Tomato_Septoria_leaf_spot': 'Remove infected leaves. Apply fungicide.',
      'Tomato_Spider_mites_Two_spotted_spider_mite': 'Use miticides or insecticidal soap.',
      'Tomato__Target_Spot': 'Apply fungicides. Remove affected leaves.',
      'Tomato__Tomato_YellowLeaf__Curl_Virus': 'Control whiteflies. Remove infected plants.',
      'Tomato__Tomato_mosaic_virus': 'Use virus-free seeds. Disinfect tools.',
      'Tomato_healthy': 'Plant is healthy! Continue regular care.',
      'Potato___Early_blight': 'Apply fungicides. Practice crop rotation.',
      'Potato___Late_blight': 'Use fungicides. Destroy infected plants.',
      'Potato___healthy': 'Potato plant is healthy.',
      'Pepper__bell___Bacterial_spot': 'Use copper sprays. Avoid working when wet.',
      'Pepper__bell___healthy': 'Pepper plant is healthy.',
    };

    return treatments[disease] ?? 
        'Consult local agricultural expert for ${(confidence * 100).toStringAsFixed(1)}% confident diagnosis.';
  }

  /// Check if model is ready
  static bool get isReady => _isInitialized;
}      return PredictionResult(
        diseaseName: formattedLabel,
        confidence: result.confidence,
        severity: result.confidence, // Using confidence as severity for now
        treatment: _getTreatment(formattedLabel),
      );
    } catch (e) {
      debugPrint('❌ Prediction error: $e');
      throw Exception('Failed to analyze image. Please try again.');
    }
  }
  
  /// Format label from "Tomato_Early_blight" to "Tomato Early Blight"
  static String _formatLabel(String label) {
    return label
        .replaceAll('_', ' ')
        .replaceAll('  ', ' ')
        .replaceAll('Tomato ', '') // Remove duplicate Tomato prefix
        .trim();
  }
  
  /// Get treatment based on disease
  static String _getTreatment(String disease) {
    final treatments = {
      'Early blight': 'Apply copper-based fungicide weekly. Remove infected leaves.',
      'Late blight': 'Use fungicides containing chlorothalonil or mancozeb.',
      'Bacterial spot': 'Use copper sprays and practice crop rotation.',
      'Leaf Mold': 'Improve air circulation and reduce humidity.',
      'Septoria leaf spot': 'Remove infected leaves and apply fungicide.',
      'Spider mites': 'Use miticides or insecticidal soap.',
      'Target Spot': 'Apply fungicides and remove affected leaves.',
      'Yellow Leaf Curl Virus': 'Control whiteflies and remove infected plants.',
      'Tomato mosaic virus': 'Use virus-free seeds and disinfect tools.',
      'healthy': 'Your plant is healthy! Continue regular care.',
      'Potato Early blight': 'Apply fungicides and practice crop rotation.',
      'Potato Late blight': 'Use fungicides and destroy infected plants.',
      'Potato healthy': 'Potato plant is healthy.',
      'Pepper bell Bacterial spot': 'Use copper sprays and avoid overhead watering.',
      'Pepper bell healthy': 'Pepper plant is healthy.',
    };
    
    return treatments[disease] ?? 'Consult local agricultural expert for treatment.';
  }
  
  static bool get isModelLoaded => _isModelLoaded;
  static bool get isLoading => _isLoading;
}
