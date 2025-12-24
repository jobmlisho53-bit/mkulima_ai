// Result Screen for displaying ML predictions
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mkulima_ai/core/theme/theme.dart';
import 'package:mkulima_ai/features/scan/domain/entities/scan_result.dart';
import 'package:mkulima_ai/features/scan/presentation/widgets/severity_meter.dart';
import 'package:mkulima_ai/features/scan/presentation/widgets/treatment_card.dart';

class ResultScreen extends StatelessWidget {
  final ScanResult result;

  const ResultScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosis Result'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => _shareResult(context),
            icon: const Icon(Icons.share),
          ),
          IconButton(
            onPressed: () => _saveToHistory(context),
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview
            _buildImagePreview(context),
            const SizedBox(height: 24),
            
            // Confidence Score
            _buildConfidenceCard(theme),
            const SizedBox(height: 20),
            
            // Disease Name
            Text(
              result.diseaseName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: _getDiseaseColor(result.confidence),
              ),
            ),
            const SizedBox(height: 8),
            
            // Scientific Name (if available)
            if (result.scientificName != null)
              Text(
                result.scientificName!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Severity Meter
            SeverityMeter(severity: result.severity),
            const SizedBox(height: 24),
            
            // Treatment Recommendations
            TreatmentCard(treatment: result.treatment),
            const SizedBox(height: 24),
            
            // Prevention Tips
            _buildPreventionTips(theme),
            const SizedBox(height: 32),
            
            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(result.imagePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Image not available',
                    style: AppTheme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConfidenceCard(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getConfidenceColor(result.confidence).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getConfidenceColor(result.confidence).withOpacity(0.3),
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
                Text(
                  'AI Confidence',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '${(result.confidence * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _getConfidenceColor(result.confidence),
                  ),
                ),
              ],
            ),
          ),
          if (result.confidence > 0.85)
            const Chip(
              label: Text('High Accuracy'),
              backgroundColor: Colors.green,
              labelStyle: TextStyle(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildPreventionTips(AppTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              'Prevention Tips',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._generatePreventionTips().map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.circle, size: 6, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tip,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => _speakDiagnosis(context),
          icon: const Icon(Icons.volume_up),
          label: const Text('Listen in Swahili'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/scan',
            (route) => false,
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Scan Another Plant'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }

  List<String> _generatePreventionTips() {
    return [
      'Practice crop rotation every season',
      'Ensure proper spacing between plants for air circulation',
      'Water at the base, avoid wetting leaves',
      'Remove and destroy infected plant debris',
      'Use disease-resistant varieties when available',
      'Monitor plants regularly for early signs',
      'Disinfect tools between plants',
      'Avoid working in wet conditions',
    ];
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.8) return Colors.green;
    if (confidence > 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getDiseaseColor(double confidence) {
    if (confidence < 0.3) return Colors.green;
    if (confidence < 0.7) return Colors.orange;
    return Colors.red;
  }

  void _shareResult(BuildContext context) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing result...'),
      ),
    );
  }

  void _saveToHistory(BuildContext context) {
    // TODO: Implement save to history
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved to history'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _speakDiagnosis(BuildContext context) {
    // TODO: Implement TTS in Swahili
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Speaking diagnosis in Swahili...'),
      ),
    );
  }
}
