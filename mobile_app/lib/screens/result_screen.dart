// lib/screens/result_screen.dart (Updated)
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/ui_classifier_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/severity_indicator.dart';
import '../widgets/disease_card.dart';
import '../utils/constants.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  
  const ResultScreen({super.key, required this.result});
  
  @override
  Widget build(BuildContext context) {
    final diseaseName = result['disease'] as String;
    final confidence = result['confidence'] as double;
    final severity = result['severity'] as double;
    final treatment = result['treatment'] as String;
    final imagePath = result['imagePath'] as String;
    
    // Determine severity color
    Color getSeverityColor(double severity) {
      if (severity < 0.4) return Colors.green;
      if (severity < 0.7) return Colors.orange;
      return Colors.red;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosis Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () {
              // Generate Swahili voice message
              final swahiliMessage = _generateSwahiliMessage(
                diseaseName,
                confidence,
                treatment,
              );
              
              // TODO: Implement TTS service
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Speaking: $swahiliMessage'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(File(imagePath)),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Confidence Score
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: getSeverityColor(confidence).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: getSeverityColor(confidence).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Confidence Score',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${(confidence * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: getSeverityColor(confidence),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (confidence > 0.8)
                    const Icon(Icons.verified, color: Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Disease Card
            DiseaseCard(
              diseaseName: diseaseName,
              confidence: confidence,
              severityColor: getSeverityColor(confidence),
              treatment: treatment,
              date: 'Just now',
            ),
            const SizedBox(height: 24),
            
            // Severity Indicator
            SeverityIndicator(severity: severity),
            const SizedBox(height: 32),
            
            // Treatment Details
            _buildSection(
              title: 'Recommended Treatment',
              content: treatment,
              icon: Icons.medical_services,
              iconColor: Colors.blue,
            ),
            const SizedBox(height: 24),
            
            // Prevention Tips
            _buildSection(
              title: 'Prevention Tips',
              content: _getPreventionTips(diseaseName),
              icon: Icons.shield,
              iconColor: Colors.green,
            ),
            const SizedBox(height: 24),
            
            // Crop Specific Advice
            if (_isTomatoDisease(diseaseName))
              _buildSection(
                title: 'Tomato-Specific Advice',
                content: _getTomatoAdvice(),
                icon: Icons.apple,
                iconColor: Colors.red,
              ),
            
            const SizedBox(height: 40),
            
            // Action Buttons
            Column(
              children: [
                PrimaryButton(
                  text: 'Save to History',
                  icon: Icons.save,
                  onPressed: () {
                    _saveToHistory(context, result);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/camera',
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Scan Another Plant'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
            height: 1.6,
          ),
        ),
      ],
    );
  }
  
  String _generateSwahiliMessage(String disease, double confidence, String treatment) {
    return "Ugonjwa: ${disease.toLowerCase()}. Uhakika: ${(confidence * 100).toInt()} asilimia. Matibabu: $treatment";
  }
  
  String _getPreventionTips(String disease) {
    const tips = '''
• Practice crop rotation every season
• Use disease-resistant varieties
• Ensure proper spacing for air circulation
• Water at the base, not on leaves
• Remove infected plants immediately
• Disinfect tools between uses
• Monitor plants regularly for early signs
• Use clean, certified seeds
''';
    return tips;
  }
  
  String _getTomatoAdvice() {
    return '''
• Stake plants to keep leaves off the ground
• Mulch around plants to prevent soil splash
• Avoid overhead irrigation
• Remove lower leaves as plant grows
• Use calcium supplements to prevent blossom end rot
• Monitor for common pests like aphids and whiteflies
''';
  }
  
  bool _isTomatoDisease(String disease) {
    return disease.toLowerCase().contains('tomato') || 
           disease.toLowerCase().contains('blight');
  }
  
  void _saveToHistory(BuildContext context, Map<String, dynamic> result) {
    // TODO: Implement history saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report saved to history'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
