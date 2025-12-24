import 'dart:io';
import 'package:mkulima_ai/features/scan/domain/entities/scan_result.dart';
import 'package:mkulima_ai/features/scan/domain/repositories/scan_repository.dart';
import 'package:mkulima_ai/services/classifier_service.dart'; // YOUR ML SERVICE

class ScanRepositoryImpl implements ScanRepository {
  @override
  Future<void> initializeModel() async {
    try {
      print('🔄 Initializing ML model...');
      await ClassifierService.loadModelAndLabels();
      print('✅ ML model loaded successfully');
    } catch (e) {
      print('❌ Error loading ML model: $e');
      throw Exception('Failed to initialize AI model: $e');
    }
  }

  @override
  Future<ScanResult> analyzeImage(String imagePath) async {
    try {
      print('🔍 Analyzing image: $imagePath');
      
      // CALL YOUR ML SERVICE HERE
      final result = await ClassifierService.predict(imagePath);
      
      print('✅ ML Prediction received: ${result.diseaseName} (${(result.confidence * 100).toStringAsFixed(1)}%)');
      
      // Format disease name for display
      final formattedDisease = _formatDiseaseName(result.diseaseName);
      
      // Get treatment recommendations
      final treatment = _getTreatment(formattedDisease, result.confidence);
      
      // Get severity level
      final severity = _calculateSeverity(result.confidence);
      
      return ScanResult(
        imagePath: imagePath,
        diseaseName: formattedDisease,
        confidence: result.confidence,
        severity: severity,
        treatment: treatment,
        timestamp: DateTime.now(),
        scientificName: _getScientificName(formattedDisease),
      );
    } catch (e) {
      print('❌ Error analyzing image: $e');
      throw Exception('Failed to analyze image: $e');
    }
  }

  // Helper methods
  String _formatDiseaseName(String name) {
    // Convert "Tomato_Early_blight" to "Tomato Early Blight"
    return name
        .replaceAll('_', ' ')
        .replaceAll('__', ' - ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  double _calculateSeverity(double confidence) {
    // Map confidence to severity (0.0 to 1.0)
    if (confidence > 0.8) return 0.8; // High severity for high confidence
    if (confidence > 0.6) return 0.5; // Medium severity
    return 0.3; // Low severity
  }

  String _getTreatment(String disease, double confidence) {
    // Treatment recommendations based on disease
    final treatments = {
      'Tomato Early Blight': 'Apply copper-based fungicide weekly. Remove infected leaves and ensure proper air circulation.',
      'Tomato Late Blight': 'Use fungicides containing chlorothalonil or mancozeb. Destroy infected plants immediately.',
      'Tomato Bacterial Spot': 'Use copper sprays. Avoid overhead watering and practice crop rotation.',
      'Tomato Leaf Mold': 'Improve air circulation, reduce humidity, and apply fungicides.',
      'Tomato Septoria Leaf Spot': 'Remove infected leaves and apply fungicide. Avoid working with wet plants.',
      'Tomato Spider Mites': 'Use miticides or insecticidal soap. Increase humidity to deter mites.',
      'Tomato Target Spot': 'Apply fungicides and remove affected leaves. Ensure proper spacing.',
      'Tomato Yellow Leaf Curl Virus': 'Control whiteflies using insecticides. Remove and destroy infected plants.',
      'Tomato Mosaic Virus': 'Use virus-free seeds. Disinfect tools and avoid smoking near plants.',
      'Tomato Healthy': 'Your tomato plant is healthy! Continue regular watering and fertilization.',
      'Potato Early Blight': 'Apply fungicides containing chlorothalonil. Remove infected foliage.',
      'Potato Late Blight': 'Destroy infected plants. Use resistant varieties and proper spacing.',
      'Potato Healthy': 'Your potato plant is healthy. Maintain proper soil moisture.',
      'Pepper Bell Bacterial Spot': 'Use copper sprays. Avoid working when plants are wet.',
      'Pepper Bell Healthy': 'Your pepper plant is healthy. Ensure adequate sunlight.',
    };
    
    return treatments[disease] ?? 
        'For ${confidence > 0.6 ? "severe" : "mild"} infection: Remove affected leaves, improve air circulation, and consult local agricultural expert.';
  }

  String? _getScientificName(String disease) {
    final scientificNames = {
      'Tomato Early Blight': 'Alternaria solani',
      'Tomato Late Blight': 'Phytophthora infestans',
      'Tomato Bacterial Spot': 'Xanthomonas campestris pv. vesicatoria',
      'Tomato Leaf Mold': 'Fulvia fulva',
      'Tomato Septoria Leaf Spot': 'Septoria lycopersici',
      'Tomato Yellow Leaf Curl Virus': 'Begomovirus',
      'Tomato Mosaic Virus': 'Tobamovirus',
      'Potato Early Blight': 'Alternaria solani',
      'Potato Late Blight': 'Phytophthora infestans',
    };
    
    return scientificNames[disease];
  }
}
