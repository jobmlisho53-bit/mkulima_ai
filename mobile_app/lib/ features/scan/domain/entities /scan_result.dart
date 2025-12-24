class ScanResult {
  final String imagePath;
  final String diseaseName;
  final double confidence; // 0.0 to 1.0
  final double severity;   // 0.0 to 1.0
  final String treatment;
  final DateTime timestamp;
  final String? scientificName;
  final String? additionalInfo;

  ScanResult({
    required this.imagePath,
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.treatment,
    required this.timestamp,
    this.scientificName,
    this.additionalInfo,
  });

  // Helper method to check if plant is healthy
  bool get isHealthy => diseaseName.toLowerCase().contains('healthy');

  // Format confidence as percentage
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  // Format severity level
  String get severityLevel {
    if (severity < 0.4) return 'Low';
    if (severity < 0.7) return 'Medium';
    return 'High';
  }

  // Get color based on severity
  int get severityColor {
    if (severity < 0.4) return 0xFF4CAF50; // Green
    if (severity < 0.7) return 0xFFFF9800; // Orange
    return 0xFFF44336; // Red
  }
}
