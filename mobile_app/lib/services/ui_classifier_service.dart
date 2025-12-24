// lib/services/ui_classifier_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'classifier_service.dart';

class UIClassifierService {
  static bool _isModelLoaded = false;
  static bool _isLoading = false;
  
  /// Initialize model at app startup
  static Future<void> initialize() async {
    try {
      _isLoading = true;
      await ClassifierService.loadModelAndLabels();
      _isModelLoaded = true;
      debugPrint('✅ ML Model loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading model: $e');
      _isModelLoaded = false;
    } finally {
      _isLoading = false;
    }
  }
  
  /// Get prediction with UI-friendly error handling
  static Future<PredictionResult> predictWithUI(String imagePath) async {
    if (!_isModelLoaded) {
      await initialize();
    }
    
    try {
      final result = await ClassifierService.predict(imagePath);
      
      // Format label for display
      final formattedLabel = _formatLabel(result.diseaseName);
      
      return PredictionResult(
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
